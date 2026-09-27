class_name DashAfterimageVfx
extends DashVfxModule
## Module A (docs/specs/dash-feel.md): translucent copies of the body left
## behind while the player dashes (and is invulnerable). Each copy is the
## humanoid's body meshes frozen at one fraction of the dash, fading out.
## The copies are built once in setup() (constitution II, player afterimages).

@export var config: DashAfterimageConfig
## White, unshaded, translucent.
@export var material: StandardMaterial3D

var _sources: Array[MeshInstance3D] = []
## Pool: `count` copies, each one MeshInstance3D per body mesh.
var _copies: Array[Array] = []
## Seconds each copy has been fading; < 0 = hidden.
var _ages: PackedFloat32Array = PackedFloat32Array()
## Copies already left in the running dash.
var _left: int = 0


func _process(delta: float) -> void:
	advance(delta)


func setup(player: Player) -> void:
	var humanoid: LowPolyHumanoid = player.get_node("Visual/Humanoid") as LowPolyHumanoid
	_sources.assign(humanoid.get_body_meshes())
	_ages.resize(config.count)
	for i: int in config.count:
		var copy: Array[MeshInstance3D] = []
		for source: MeshInstance3D in _sources:
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = source.mesh
			mesh_instance.material_override = material
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.hide()
			add_child(mesh_instance)
			copy.append(mesh_instance)
		_copies.append(copy)
		_ages[i] = -1.0
	set_process(false)


func dash_started(dash: DashComponent) -> void:
	_left = 0
	dash_step(dash)


## Leaves the next copy once the dash reaches its fraction.
func dash_step(dash: DashComponent) -> void:
	while _left < config.count and dash.get_progress() >= config.fractions[_left]:
		_leave_copy(_left)
		_left += 1


func dash_ended(_dash: DashComponent, _cancelled: bool) -> void:
	_left = config.count


## Fades the copies; hides them after `lifetime`.
func advance(delta: float) -> void:
	var fading: bool = false
	for i: int in config.count:
		if _ages[i] < 0.0:
			continue
		_ages[i] += delta
		if _ages[i] >= config.lifetime:
			_ages[i] = -1.0
			_show_copy(i, false)
			continue
		_set_alpha(i, config.start_alpha * (1.0 - _ages[i] / config.lifetime))
		fading = true
	set_process(fading)


func get_copy_count() -> int:
	return config.count


func is_copy_visible(index: int) -> bool:
	return _ages[index] >= 0.0


## Alpha of copy `index` (0 when hidden).
func get_copy_alpha(index: int) -> float:
	if _ages[index] < 0.0:
		return 0.0
	return 1.0 - (_copies[index][0] as MeshInstance3D).transparency


func get_copy_meshes(index: int) -> Array:
	return _copies[index]


func _leave_copy(index: int) -> void:
	var copy: Array = _copies[index]
	for part: int in _sources.size():
		(copy[part] as MeshInstance3D).global_transform = _sources[part].global_transform
	_ages[index] = 0.0
	_set_alpha(index, config.start_alpha)
	_show_copy(index, true)
	set_process(true)


func _set_alpha(index: int, alpha: float) -> void:
	for mesh_instance: MeshInstance3D in _copies[index]:
		mesh_instance.transparency = 1.0 - alpha


func _show_copy(index: int, shown: bool) -> void:
	for mesh_instance: MeshInstance3D in _copies[index]:
		mesh_instance.visible = shown
