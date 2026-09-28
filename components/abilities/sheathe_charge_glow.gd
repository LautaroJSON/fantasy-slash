class_name SheatheChargeGlow
extends Node3D
## Pulse of light at the mouth of the sheath on every charge milestone of
## Sheathe (docs/specs/sheathe-visual-rework.md §2.3): a brief OmniLight3D and a
## small white sphere that grows while it fades, brighter on every milestone
## and strongest at full charge. Never a steady glow (Principle II: brief
## lights only). Both nodes are created once and reused (Principle V). Must be
## top_level: the owner moves it to the mouth of the sheath with follow().

## Smallest size drawn, so no scale ever collapses to zero. Structural.
const MIN_SIZE: float = 0.001

@export var config: SheatheConfig
## White, unshaded, additive (the wind cut's glow).
@export var glow_material: StandardMaterial3D

var _light: OmniLight3D = null
var _sphere: MeshInstance3D = null
var _energy: float = 0.0
var _radius: float = 0.0
var _duration: float = 0.0
var _left: float = 0.0


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.material = glow_material
	_sphere = MeshInstance3D.new()
	_sphere.mesh = mesh
	_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sphere)
	_light = OmniLight3D.new()
	_light.omni_range = config.glow_range
	_light.shadow_enabled = false
	add_child(_light)
	_stop()


func _process(delta: float) -> void:
	advance(delta)


## Starts the pulse of milestone `index` (1-based); a new one restarts it.
func pulse(index: int, is_full: bool) -> void:
	_energy = config.glow_energy_for(index, is_full)
	_radius = config.glow_full_radius if is_full else config.glow_radius
	_duration = config.glow_full_duration if is_full else config.glow_duration
	_left = _duration
	_light.show()
	_sphere.show()
	_apply(0.0)
	set_process(true)


## Keeps the pulse on the mouth of the sheath.
func follow(point: Vector3) -> void:
	global_position = point


## The light dims to zero while the sphere grows to its radius and fades.
func advance(delta: float) -> void:
	if not is_pulsing():
		return
	_left = maxf(_left - delta, 0.0)
	if not is_pulsing():
		_stop()
		return
	_apply(1.0 - _left / _duration)


func is_pulsing() -> bool:
	return _left > 0.0


func get_light() -> OmniLight3D:
	return _light


func get_sphere() -> MeshInstance3D:
	return _sphere


func _apply(progress: float) -> void:
	_light.light_energy = _energy * (1.0 - progress)
	_sphere.scale = Vector3.ONE * maxf(_radius * progress, MIN_SIZE)
	_sphere.transparency = lerpf(config.glow_start_transparency, 1.0, progress)


func _stop() -> void:
	_left = 0.0
	_light.hide()
	_sphere.hide()
	set_process(false)
