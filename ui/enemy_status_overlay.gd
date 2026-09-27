class_name EnemyStatusOverlay
extends Control
## Status icons of the common enemies, drawn in screen space over their health
## bars (LoL style, docs/specs/status-icons.md). Each enemy with statuses gets a
## pooled StatusIconRow centred on its projected bar, sized so the row spans the
## bar's width, and shown even while the bar is hidden (not hit yet). Bosses
## are skipped: their statuses live in the HUD boss bar.
## Rows are created once; a row's icons are rewritten only when its enemy or
## the enemy's DebuffComponent.revision changes, and its clocks every frame.

@export var config: EnemyStatusOverlayConfig

## Set by the Hud; without it the overlay shows nothing (unit tests).
var registry: EnemyRegistry = null

var _rows: Array[StatusIconRow] = []
## Enemy each row shows (null = free), and the revision its icons show.
var _row_enemies: Array[Enemy] = []
var _row_revisions: PackedInt32Array = PackedInt32Array()
var _visible_rows: int = 0
## Times a row's icons were rewritten (docs/specs/status-icons.md, AC912).
var _content_writes: int = 0
var _camera: Camera3D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_rows()


func _process(_delta: float) -> void:
	update_rows()


## Assigns a row to each eligible enemy, rewrites its icons when needed,
## sizes and places it over the bar, and hides the rows left over.
func update_rows() -> void:
	var used: int = 0
	if registry != null and _refresh_camera():
		for enemy: Object in registry.get_active():
			if used == _rows.size():
				break
			# Enemies freed without leaving the registry (scene teardown) are skipped.
			if is_instance_valid(enemy) and _is_eligible(enemy as Enemy):
				_show_row(used, enemy as Enemy)
				used += 1
	_hide_rows_from(used)
	_visible_rows = used


func get_visible_row_count() -> int:
	return _visible_rows


func get_row(index: int) -> StatusIconRow:
	return _rows[index]


func get_row_enemy(index: int) -> Enemy:
	return _row_enemies[index] if index < _visible_rows else null


## Centre of the row's visible slots, in overlay coordinates.
func get_row_center(index: int) -> Vector2:
	var row: StatusIconRow = _rows[index]
	return row.position + Vector2(row.get_shown_width(), row.get_side()) / 2.0


func get_content_write_count() -> int:
	return _content_writes


func _is_eligible(enemy: Enemy) -> bool:
	if enemy.debuffs.get_active().is_empty():
		return false
	if enemy.health_bar.is_suppressed() or enemy.is_spawning_in():
		return false
	return not _camera.is_position_behind(enemy.health_bar.global_position)


func _show_row(index: int, enemy: Enemy) -> void:
	var row: StatusIconRow = _rows[index]
	_resize_row(row, enemy)
	if _row_enemies[index] != enemy or _row_revisions[index] != enemy.debuffs.revision:
		_row_enemies[index] = enemy
		_row_revisions[index] = enemy.debuffs.revision
		_write_icons(row, enemy)
	_update_clocks(row, enemy)
	row.position = _bar_screen_center(enemy) + config.row_offset_px - Vector2(row.get_shown_width(), row.get_side()) / 2.0
	row.visible = true


func _write_icons(row: StatusIconRow, enemy: Enemy) -> void:
	_content_writes += 1
	var active: Array[DebuffComponent.ActiveDebuff] = enemy.debuffs.get_active()
	var shown: int = row.set_shown(active.size())
	for i: int in shown:
		row.icon(i).show_debuff(active[i])


func _update_clocks(row: StatusIconRow, enemy: Enemy) -> void:
	var active: Array[DebuffComponent.ActiveDebuff] = enemy.debuffs.get_active()
	for i: int in mini(active.size(), row.get_visible_icon_count()):
		row.icon(i).update_debuff_time(active[i])


## Side from the bar's on-screen width; only applied past the threshold.
func _resize_row(row: StatusIconRow, enemy: Enemy) -> void:
	var side: float = config.icon_side(_bar_screen_width(enemy))
	if absf(side - row.get_side()) > config.resize_threshold_px:
		row.set_side(side)


func _bar_screen_center(enemy: Enemy) -> Vector2:
	return _camera.unproject_position(enemy.health_bar.global_position)


## The bar always faces the camera, so its ends lie along the camera's right.
func _bar_screen_width(enemy: Enemy) -> float:
	var center: Vector3 = enemy.health_bar.global_position
	var half: Vector3 = _camera.global_basis.x * (config.health_bar.size.x / 2.0)
	return _camera.unproject_position(center + half).distance_to(_camera.unproject_position(center - half))


func _hide_rows_from(first: int) -> void:
	for i: int in range(first, _rows.size()):
		if _rows[i].visible or _row_enemies[i] != null:
			_rows[i].visible = false
			_row_enemies[i] = null


func _refresh_camera() -> bool:
	if _camera == null or not is_instance_valid(_camera) or not _camera.current:
		_camera = get_viewport().get_camera_3d()
	return _camera != null


func _create_rows() -> void:
	_row_enemies.resize(config.max_rows)
	_row_revisions.resize(config.max_rows)
	for i: int in config.max_rows:
		var row: StatusIconRow = StatusIconRow.create(config.status_icon, config.icons_per_bar, config.max_icon_size_px, config.spacing_px)
		row.visible = false
		add_child(row)
		_rows.append(row)
