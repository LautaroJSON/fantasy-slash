class_name WindCutVfx
extends Node3D
## Wind cut of the Sheathe slash (visual only): two walls rise from the ground
## along the slash and open upwards in a V, sparks jump and dust rises along the
## slash, and a flash (sphere and brief light) bursts at its tip. Built from
## primitives and one-shot CPUParticles3D (Principle II); every node is created
## once and reused (Principle V). Must be top_level so it stays where the slash
## landed.

enum Wall {
	LEFT,
	RIGHT,
}

## Smallest size drawn, so no scale ever collapses to zero. Structural.
const MIN_SIZE: float = 0.001

@export var config: WindCutConfig
## White, unshaded, additive: walls, sparks and flash.
@export var glow_material: StandardMaterial3D
## Earth-colored dust.
@export var dust_material: StandardMaterial3D

var _walls: Array[MeshInstance3D] = []
var _sparks: CPUParticles3D = null
var _dust: CPUParticles3D = null
var _flash: MeshInstance3D = null
var _flash_light: OmniLight3D = null
var _length: float = 0.0
var _height: float = 0.0
var _elapsed: float = 0.0
var _playing: bool = false


func _ready() -> void:
	_create_walls()
	_create_sparks()
	_create_dust()
	_create_flash()
	_stop()


func _process(delta: float) -> void:
	advance(delta)


## Starts the cut at `origin` (the player's feet) along `yaw`, `length` long;
## the walls rise to max_height x `factor`.
func play(origin: Vector3, yaw: float, length: float, factor: float) -> void:
	global_position = origin
	global_basis = Basis(Vector3.UP, yaw)
	_length = length
	_height = config.max_height * factor
	_elapsed = 0.0
	_playing = true
	_layout_walls(0.0)
	_apply_wall_transparency(config.start_transparency)
	for wall: MeshInstance3D in _walls:
		wall.show()
	_burst(_sparks, Vector3(0.0, 0.0, length / 2.0))
	_burst(_dust, Vector3(config.dust_width / 2.0, 0.0, length / 2.0))
	_flash.position = Vector3(0.0, config.flash_height, -length)
	_flash_light.position = _flash.position
	_update_flash(0.0)
	_flash.show()
	_flash_light.show()
	set_process(true)


func advance(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_advance_walls()
	_update_flash(minf(_elapsed / config.flash_duration, 1.0))
	if _elapsed >= maxf(config.grow_duration + config.fade_duration, config.flash_duration):
		_stop()


func is_playing() -> bool:
	return _playing


func get_wall(wall: Wall) -> MeshInstance3D:
	return _walls[wall]


func get_sparks() -> CPUParticles3D:
	return _sparks


func get_dust() -> CPUParticles3D:
	return _dust


func get_flash() -> MeshInstance3D:
	return _flash


func get_flash_light() -> OmniLight3D:
	return _flash_light


## Current height of the walls, in meters.
func get_wall_height() -> float:
	return _walls[Wall.LEFT].scale.y


## Current length of the walls, in meters.
func get_wall_length() -> float:
	return _walls[Wall.LEFT].scale.z


func _advance_walls() -> void:
	if _elapsed < config.grow_duration:
		_layout_walls(_elapsed / config.grow_duration)
		return
	_layout_walls(1.0)
	var fade: float = minf((_elapsed - config.grow_duration) / config.fade_duration, 1.0)
	_apply_wall_transparency(lerpf(config.start_transparency, 1.0, fade))


## Local space: forward is -Z. Each wall stands on the slash's centre line,
## tilted outwards from the vertical, rising to `progress` of its height.
func _layout_walls(progress: float) -> void:
	var half_angle: float = deg_to_rad(config.half_angle_degrees)
	var height: float = maxf(_height * progress, MIN_SIZE)
	_place_wall(Wall.LEFT, half_angle, height)
	_place_wall(Wall.RIGHT, -half_angle, height)


## A positive tilt leans the wall's top towards -X (the player's left).
func _place_wall(wall: Wall, tilt: float, height: float) -> void:
	var mesh_instance: MeshInstance3D = _walls[wall]
	var up: Vector3 = Basis(Vector3.BACK, tilt) * Vector3.UP
	mesh_instance.rotation = Vector3(0.0, 0.0, tilt)
	mesh_instance.position = up * height / 2.0 + Vector3(0.0, 0.0, -_length / 2.0)
	mesh_instance.scale = Vector3(config.wall_thickness, height, maxf(_length, MIN_SIZE))


func _apply_wall_transparency(value: float) -> void:
	for wall: MeshInstance3D in _walls:
		wall.transparency = value


## The sphere grows to flash_radius and fades while the light dims to zero.
func _update_flash(progress: float) -> void:
	var radius: float = maxf(config.flash_radius * progress, MIN_SIZE)
	_flash.scale = Vector3.ONE * radius
	_flash.transparency = lerpf(config.start_transparency, 1.0, progress)
	_flash_light.light_energy = config.flash_energy * (1.0 - progress)


## Places the emitter at the middle of the slash, spread over its length.
func _burst(particles: CPUParticles3D, extents: Vector3) -> void:
	particles.position = Vector3(0.0, 0.0, -_length / 2.0)
	particles.emission_box_extents = extents
	particles.restart()
	particles.emitting = true


func _create_walls() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = glow_material
	for i: int in Wall.size():
		var wall := MeshInstance3D.new()
		wall.mesh = box
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wall)
		_walls.append(wall)


func _create_sparks() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * config.spark_size
	box.material = glow_material
	_sparks = _make_particles(box, config.spark_amount, config.spark_lifetime)
	_sparks.spread = config.spark_spread_degrees
	_sparks.initial_velocity_min = config.spark_speed_min
	_sparks.initial_velocity_max = config.spark_speed_max
	_sparks.gravity = Vector3.DOWN * config.spark_gravity


func _create_dust() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = config.dust_size / 2.0
	sphere.height = config.dust_size
	sphere.material = dust_material
	_dust = _make_particles(sphere, config.dust_amount, config.dust_lifetime)
	_dust.spread = 0.0
	_dust.initial_velocity_min = config.dust_rise_speed_min
	_dust.initial_velocity_max = config.dust_rise_speed_max
	_dust.gravity = Vector3.ZERO


## One-shot burst: every particle leaves at once, upwards, and fades out.
func _make_particles(mesh: Mesh, amount: int, lifetime: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.mesh = mesh
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.direction = Vector3.UP
	particles.color_ramp = _fade_out_ramp()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles


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


## Walls, flash and light hide; the particles finish on their own.
func _stop() -> void:
	_playing = false
	for wall: MeshInstance3D in _walls:
		wall.hide()
	_flash.hide()
	_flash_light.hide()
	set_process(false)
