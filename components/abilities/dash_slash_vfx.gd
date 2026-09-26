class_name DashSlashVfx
extends Node3D
## Effects of the horizontal slash of a dash that cuts the Spin short (visual
## only): when the dash ends, sparks fly sideways along the path and a flash
## bursts at its tip. The sweep itself is shown by the weapon and its trail.
## Built from primitives and one-shot CPUParticles3D (Principle II); every node
## is created once and reused (Principle V). Must be top_level so it stays
## where the dash went.

## Smallest size drawn, so no scale ever collapses to zero. Structural.
const MIN_SIZE: float = 0.001

@export var config: DashSlashVfxConfig
## White, unshaded, additive: sparks and flash.
@export var glow_material: StandardMaterial3D

var _sparks: CPUParticles3D = null
var _flash: MeshInstance3D = null
var _flash_light: OmniLight3D = null
var _width: float = 0.0
var _length: float = 0.0
var _elapsed: float = 0.0
var _following: bool = false
var _flashing: bool = false


func _ready() -> void:
	_create_sparks()
	_create_flash()
	_stop()


func _process(delta: float) -> void:
	advance(delta)


## Starts following a dash from `origin` (the player's feet), facing `yaw`;
## the sparks will spread over a band `width` wide.
func begin(origin: Vector3, yaw: float, width: float) -> void:
	global_position = origin
	global_basis = Basis(Vector3.UP, yaw)
	_width = width
	_length = 0.0
	_elapsed = 0.0
	_following = true
	_flashing = false
	_flash.hide()
	_flash_light.hide()
	set_process(false)


## Records how far the dash got: `point` is the player's feet now.
func extend_to(point: Vector3) -> void:
	if not _following:
		return
	_length = maxf(-to_local(point).z, _length)


## The dash ended: sparks fly along the path and the tip flashes.
func finish() -> void:
	if not _following:
		return
	_following = false
	_flashing = true
	_elapsed = 0.0
	_burst_sparks()
	_flash.position = Vector3(0.0, config.blade_height, -_length)
	_flash_light.position = _flash.position
	_update_flash(0.0)
	_flash.show()
	_flash_light.show()
	set_process(true)


func advance(delta: float) -> void:
	if not _flashing:
		return
	_elapsed += delta
	_update_flash(minf(_elapsed / config.flash_duration, 1.0))
	if _elapsed >= config.flash_duration:
		_stop()


func is_playing() -> bool:
	return _following or _flashing


## Distance covered by the followed dash, in meters.
func get_path_length() -> float:
	return _length


func get_sparks() -> CPUParticles3D:
	return _sparks


func get_flash() -> MeshInstance3D:
	return _flash


## The sphere grows to flash_radius and fades while the light dims to zero.
func _update_flash(progress: float) -> void:
	_flash.scale = Vector3.ONE * maxf(config.flash_radius * progress, MIN_SIZE)
	_flash.transparency = lerpf(config.flash_start_transparency, 1.0, progress)
	_flash_light.light_energy = config.flash_energy * (1.0 - progress)


## Spread over the whole path, flying sideways in the horizontal plane.
func _burst_sparks() -> void:
	_sparks.position = Vector3(0.0, config.blade_height, -_length / 2.0)
	_sparks.emission_box_extents = Vector3(_width / 2.0, 0.0, maxf(_length, MIN_SIZE) / 2.0)
	_sparks.restart()
	_sparks.emitting = true


## One-shot burst: every spark leaves at once, flat and in any horizontal
## direction, and fades out.
func _create_sparks() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * config.spark_size
	box.material = glow_material
	_sparks = CPUParticles3D.new()
	_sparks.mesh = box
	_sparks.amount = config.spark_amount
	_sparks.lifetime = config.spark_lifetime
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.emitting = false
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparks.direction = Vector3.RIGHT
	_sparks.spread = 180.0
	_sparks.flatness = 1.0
	_sparks.gravity = Vector3.ZERO
	_sparks.initial_velocity_min = config.spark_speed_min
	_sparks.initial_velocity_max = config.spark_speed_max
	_sparks.color_ramp = _fade_out_ramp()
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


## Opaque white to transparent: multiplies the material's color over the lifetime.
func _fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(Color.WHITE, 0.0))
	return ramp


func _create_flash() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.material = glow_material
	_flash = MeshInstance3D.new()
	_flash.mesh = sphere
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.omni_range = config.flash_range
	_flash_light.shadow_enabled = false
	add_child(_flash_light)


## Flash and light hide; the sparks finish on their own.
func _stop() -> void:
	_following = false
	_flashing = false
	_flash.hide()
	_flash_light.hide()
	set_process(false)
