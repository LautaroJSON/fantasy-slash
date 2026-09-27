class_name AfflictionBarRow
extends Node3D
## Thin Affliction bars under an enemy's floating health bar, one per
## Affliction the player holds, in the order they were taken
## (docs/specs/affliction.md). Child of the health bar, so it shares its
## visibility, camera facing, scale and shake. The rows (QuadMesh background
## and fill) are created once in _ready; a row flashes with flash_material
## right after its bar triggers.

@export var afflictions: AfflictionComponent
@export var config: AfflictionConfig
## Width and height of the health bar above.
@export var health_bar_config: HealthBarConfig

var _backgrounds: Array[MeshInstance3D] = []
var _fills: Array[MeshInstance3D] = []
var _loadout: AfflictionLoadout = null


func _ready() -> void:
	_create_rows()
	afflictions.changed.connect(update_fills)
	refresh()


## The player whose Afflictions the rows show (null = none); called on activation.
func bind(loadout: AfflictionLoadout) -> void:
	if _loadout == loadout:
		refresh()
		return
	if _loadout != null:
		_loadout.changed.disconnect(refresh)
	_loadout = loadout
	if _loadout != null:
		_loadout.changed.connect(refresh)
	refresh()


## Shows one row per held Affliction.
func refresh() -> void:
	var shown: int = get_shown_count()
	for i: int in _backgrounds.size():
		_backgrounds[i].visible = i < shown
		_fills[i].visible = false
	update_fills()


## Fill width and material of every shown row.
func update_fills() -> void:
	var shown: int = get_shown_count()
	for i: int in shown:
		var ratio: float = get_fill_ratio(i)
		var fill: MeshInstance3D = _fills[i]
		fill.visible = ratio > 0.0
		fill.material_override = config.flash_material if afflictions.is_flashing(i) else _loadout.get_type(i).bar_material
		if fill.visible:
			var width: float = health_bar_config.size.x * ratio
			fill.scale = Vector3(width, config.bar_height, 1.0)
			fill.position.x = (width - health_bar_config.size.x) / 2.0


func get_shown_count() -> int:
	if _loadout == null:
		return 0
	return mini(_loadout.get_type_count(), _backgrounds.size())


func get_visible_row_count() -> int:
	var count: int = 0
	for background: MeshInstance3D in _backgrounds:
		if background.visible:
			count += 1
	return count


## Fraction of the width the row's fill covers: full while flashing.
func get_fill_ratio(slot: int) -> float:
	return 1.0 if afflictions.is_flashing(slot) else afflictions.get_ratio(slot)


func get_fill(slot: int) -> MeshInstance3D:
	return _fills[slot]


func get_background(slot: int) -> MeshInstance3D:
	return _backgrounds[slot]


func _create_rows() -> void:
	var quad := QuadMesh.new()
	for i: int in config.max_types:
		var y: float = _row_y(i)
		var background := MeshInstance3D.new()
		background.mesh = quad
		background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background.material_override = config.background_material
		background.scale = Vector3(health_bar_config.size.x, config.bar_height, 1.0)
		background.position = Vector3(0.0, y, 0.0)
		add_child(background)
		var fill := MeshInstance3D.new()
		fill.mesh = quad
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fill.position = Vector3(0.0, y, _fill_depth())
		add_child(fill)
		_backgrounds.append(background)
		_fills.append(fill)


## Centre of row `slot`: below the health bar, bar_gap apart.
func _row_y(slot: int) -> float:
	var first: float = -(health_bar_config.size.y / 2.0 + config.bar_gap + config.bar_height / 2.0)
	return first - slot * (config.bar_height + config.bar_gap)


## Same offset toward the camera as the health bar's fill over its background.
func _fill_depth() -> float:
	return 0.002
