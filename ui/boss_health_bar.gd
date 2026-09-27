class_name BossHealthBar
extends VBoxContainer
## One boss health bar fixed in the HUD: title with name and level, health
## numbers, the same lost-health trail and shake as the floating 3D bars, and
## the boss's debuff icons (the shared status icons, docs/specs/status-icons.md). Pooled by BossBarStack: track() binds it to a boss,
## release() frees it (also when the boss dies).

var _config: BossBarConfig
var _enemy: Enemy = null
var _trail_state: HealthTrail = HealthTrail.new()
var _shake: ShakeState = ShakeState.new()
var _debuff_row: StatusIconRow
var _affliction_rows: AfflictionHudRows

@onready var _title: Label = $TitleLabel
@onready var _frame: Control = $BarFrame
## Moved sideways while shaking; not laid out by the container (child of the frame).
@onready var _bar: Control = $BarFrame/Bar
@onready var _background: ColorRect = $BarFrame/Bar/Background
@onready var _trail: ColorRect = $BarFrame/Bar/Trail
@onready var _fill: ColorRect = $BarFrame/Bar/Fill
@onready var _health_label: Label = $BarFrame/Bar/HealthLabel
@onready var _debuff_icons: HBoxContainer = $DebuffIcons


func _process(delta: float) -> void:
	advance(delta)


## Called once by the stack: sizes, colors and debuff icon slots.
func setup(config: BossBarConfig) -> void:
	_config = config
	_frame.custom_minimum_size = config.bar_size
	_bar.size = config.bar_size
	_background.size = config.bar_size
	_background.color = config.background_color
	_trail.color = config.trail_color
	_fill.color = config.fill_color
	_health_label.size = config.bar_size
	_create_debuff_row()
	_create_affliction_rows()
	release()


func track(enemy: Enemy) -> void:
	release()
	_enemy = enemy
	_enemy.health.health_changed.connect(_on_health_changed)
	_enemy.health.died.connect(release)
	_enemy.debuffs.changed.connect(_refresh_debuffs)
	_enemy.hit_notified.connect(_on_hit_notified)
	_title.text = _config.title_format % [enemy.stats.display_name, enemy.level]
	_trail_state.reset()
	_apply_ratios()
	_update_health_text(enemy.health.current_health, enemy.health.max_health)
	_refresh_debuffs()
	_affliction_rows.bind(enemy.afflictions, null if enemy.target == null else enemy.target.afflictions)
	show()
	set_process(true)


func release() -> void:
	if _enemy != null:
		_enemy.health.health_changed.disconnect(_on_health_changed)
		_enemy.health.died.disconnect(release)
		_enemy.debuffs.changed.disconnect(_refresh_debuffs)
		_enemy.hit_notified.disconnect(_on_hit_notified)
		_enemy = null
	_affliction_rows.unbind()
	_shake.stop()
	_bar.position.x = 0.0
	hide()
	set_process(false)


## Trail, shake and debuff times; called by _process and by tests.
func advance(delta: float) -> void:
	if _trail_state.advance(delta, _config.health_bar_config):
		_apply_ratios()
	_update_debuff_times()
	if _shake.is_active():
		var bar_config: HealthBarConfig = _config.health_bar_config
		_bar.position.x = _config.shake_amplitude_px * _shake.advance(delta, bar_config.shake_frequency)


func get_tracked() -> Enemy:
	return _enemy


func get_fill_ratio() -> float:
	return _trail_state.fill_ratio


func get_trail_ratio() -> float:
	return _trail_state.trail_ratio


func is_shaking() -> bool:
	return _shake.is_active()


func get_bar_offset() -> float:
	return _bar.position.x


func get_title_text() -> String:
	return _title.text


func get_health_text() -> String:
	return _health_label.text


func get_visible_debuff_count() -> int:
	return _debuff_row.get_visible_icon_count()


func get_debuff_icon(index: int) -> StatusIconView:
	return _debuff_row.icon(index)


func get_debuff_row() -> StatusIconRow:
	return _debuff_row


func get_debuff_stack_text(index: int) -> String:
	return _debuff_row.icon(index).get_stack_text()


func get_debuff_clock(index: int) -> CooldownClock:
	return _debuff_row.icon(index).get_clock()


func _on_health_changed(current: float, maximum: float) -> void:
	_update_health_text(current, maximum)
	if _trail_state.on_health(current, maximum, _config.health_bar_config):
		_apply_ratios()


## Same rule as the floating bar (crit or ≥ heavy_hit_fraction of max health).
func _on_hit_notified(applied: float, is_crit: bool) -> void:
	var bar_config: HealthBarConfig = _config.health_bar_config
	if EnemyHealthBar.should_shake(applied, _enemy.health.max_health, is_crit, bar_config):
		_shake.start(bar_config.shake_duration)


func _update_health_text(current: float, maximum: float) -> void:
	_health_label.text = _config.health_format % [ceili(current), ceili(maximum)]


func _apply_ratios() -> void:
	_set_segment(_trail, _trail_state.trail_ratio)
	_set_segment(_fill, _trail_state.fill_ratio)


## Left-anchored segment covering `ratio` of the bar width.
func _set_segment(segment: ColorRect, ratio: float) -> void:
	segment.visible = ratio > 0.0
	segment.size = Vector2(_config.bar_size.x * ratio, _config.bar_size.y)


func _create_debuff_row() -> void:
	_debuff_row = StatusIconRow.create(_config.status_icon, _config.max_debuff_icons, _config.debuff_icon_size_px, _config.debuff_spacing_px)
	_debuff_icons.add_child(_debuff_row)


func _refresh_debuffs() -> void:
	var active: Array[DebuffComponent.ActiveDebuff] = _enemy.debuffs.get_active()
	var shown: int = _debuff_row.set_shown(active.size())
	for i: int in shown:
		_debuff_row.icon(i).show_debuff(active[i])


## Clock of each shown debuff.
func _update_debuff_times() -> void:
	if _enemy == null:
		return
	var active: Array[DebuffComponent.ActiveDebuff] = _enemy.debuffs.get_active()
	for i: int in mini(active.size(), _debuff_row.get_visible_icon_count()):
		_debuff_row.icon(i).update_debuff_time(active[i])


func get_affliction_rows() -> AfflictionHudRows:
	return _affliction_rows


## Affliction rows right under the bar, above the status icons (docs/specs/affliction.md).
func _create_affliction_rows() -> void:
	_affliction_rows = AfflictionHudRows.create(_config.affliction_config, _config.bar_size.x)
	add_child(_affliction_rows)
	move_child(_affliction_rows, _frame.get_index() + 1)
