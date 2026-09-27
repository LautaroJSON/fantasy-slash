class_name AfflictionHudRows
extends VBoxContainer
## Affliction bars of a boss, under its HUD health bar (docs/specs/affliction.md):
## one thin row per Affliction the player holds, colored like the 3D bars
## (bar_material.albedo_color, flash_material while flashing). Rows are
## created once in create(); bind() follows a boss and the player's loadout.

var _config: AfflictionConfig
var _width: float = 0.0
var _backgrounds: Array[ColorRect] = []
var _fills: Array[ColorRect] = []
var _afflictions: AfflictionComponent = null
var _loadout: AfflictionLoadout = null


static func create(config: AfflictionConfig, width: float) -> AfflictionHudRows:
	var rows := AfflictionHudRows.new()
	rows._config = config
	rows._width = width
	rows.name = &"AfflictionBars"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override(&"separation", roundi(config.hud_bar_gap_px))
	rows._create_rows()
	return rows


func bind(afflictions: AfflictionComponent, loadout: AfflictionLoadout) -> void:
	unbind()
	_afflictions = afflictions
	_loadout = loadout
	_afflictions.changed.connect(update_fills)
	if _loadout != null:
		_loadout.changed.connect(refresh)
	refresh()


func unbind() -> void:
	if _afflictions != null:
		_afflictions.changed.disconnect(update_fills)
	if _loadout != null:
		_loadout.changed.disconnect(refresh)
	_afflictions = null
	_loadout = null
	refresh()


func refresh() -> void:
	var shown: int = get_shown_count()
	for i: int in _backgrounds.size():
		_backgrounds[i].visible = i < shown
	update_fills()


func update_fills() -> void:
	for i: int in get_shown_count():
		var fill: ColorRect = _fills[i]
		fill.size = Vector2(_width * get_fill_ratio(i), _config.hud_bar_height_px)
		fill.color = _fill_material(i).albedo_color


func get_shown_count() -> int:
	if _loadout == null or _afflictions == null:
		return 0
	return mini(_loadout.get_type_count(), _backgrounds.size())


func get_visible_row_count() -> int:
	var count: int = 0
	for background: ColorRect in _backgrounds:
		if background.visible:
			count += 1
	return count


## Fraction of the width the fill covers: full while flashing.
func get_fill_ratio(slot: int) -> float:
	return 1.0 if _afflictions.is_flashing(slot) else _afflictions.get_ratio(slot)


func get_fill_color(slot: int) -> Color:
	return _fills[slot].color


func get_fill_width(slot: int) -> float:
	return _fills[slot].size.x


func _fill_material(slot: int) -> StandardMaterial3D:
	if _afflictions.is_flashing(slot):
		return _config.flash_material
	return _loadout.get_type(slot).bar_material


func _create_rows() -> void:
	for i: int in _config.max_types:
		var background := ColorRect.new()
		background.custom_minimum_size = Vector2(_width, _config.hud_bar_height_px)
		background.color = _config.hud_background_color
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.visible = false
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(fill)
		add_child(background)
		_backgrounds.append(background)
		_fills.append(fill)
