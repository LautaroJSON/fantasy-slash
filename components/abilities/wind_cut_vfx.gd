class_name WindCutVfx
extends Node3D
## Wind cut of the Sheathe slash (visual only, docs/specs/sheathe-visual-rework.md).
## play() marks the slash with a thin line on the ground; burst() makes it
## explode: segmented walls rise in a wave from the player to the tip, opening
## upwards in a V and thinning out from the edges inwards as they fade, a
## crescent and its echo fly forwards at chest height, a crack opens on the
## ground, sparks jump and dust rises along the slash, and a flash (sphere and
## brief light) bursts at its tip. Built from primitives, one flat ArrayMesh
## (the crescent, built once) and one-shot CPUParticles3D (Principle II); every
## node is created once and reused (Principle V). Must be top_level so it stays
## where the slash landed.

enum WallSide {
	LEFT,
	RIGHT,
}

enum Stage {
	IDLE,
	LINE,
	BURST,
}

## Smallest size drawn, so no scale ever collapses to zero. Structural.
const MIN_SIZE: float = 0.001
## Height of the line and the crack pieces, in meters, and how far over the
## ground they lie (no z-fighting). Structural.
const FLAT_HEIGHT: float = 0.01
const LINE_LIFT: float = 0.02
const CRACK_LIFT: float = 0.012
## Length of each crack piece relative to its slot (they overlap a little).
const CRACK_OVERLAP: float = 1.1

@export var config: WindCutConfig
## White, unshaded, additive: line, walls, crescent, sparks and flash.
@export var glow_material: StandardMaterial3D
## Earth-colored dust.
@export var dust_material: StandardMaterial3D
## Very dark grey crack on the ground.
@export var crack_material: StandardMaterial3D

## Segment i of a side is at side * segment_count + i; i = 0 is the one
## nearest to the player.
var _segments: Array[MeshInstance3D] = []
var _line: MeshInstance3D = null
var _crescent: MeshInstance3D = null
var _echo: MeshInstance3D = null
var _crack: Array[MeshInstance3D] = []
var _sparks: CPUParticles3D = null
var _dust: CPUParticles3D = null
var _flash: MeshInstance3D = null
var _flash_light: OmniLight3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _stage: Stage = Stage.IDLE
var _length: float = 0.0
var _height: float = 0.0
var _crescent_size: float = 1.0
## Seconds since play() and since burst().
var _elapsed: float = 0.0
var _burst_elapsed: float = 0.0


func _ready() -> void:
	_create_line()
	_create_segments()
	_create_crescents()
	_create_crack()
	_create_sparks()
	_create_dust()
	_create_flash()
	_stop()


func _process(delta: float) -> void:
	advance(delta)


## Marks the slash at `origin` (the player's feet) along `yaw`, `length` long,
## with a line on the ground; `factor` (the charge factor) scales the walls and
## the crescent of the burst. A cut still playing starts over.
func play(origin: Vector3, yaw: float, length: float, factor: float) -> void:
	_stop()
	global_position = origin
	global_basis = Basis(Vector3.UP, yaw)
	_length = length
	_height = config.max_height * factor
	_crescent_size = maxf(factor, config.crescent_min_scale)
	_elapsed = 0.0
	_stage = Stage.LINE
	_layout_crack()
	_update_line()
	_line.show()
	set_process(true)


## The cut explodes along the marked line (see the class comment).
func burst() -> void:
	if _stage != Stage.LINE:
		return
	_stage = Stage.BURST
	_burst_elapsed = 0.0
	_line.hide()
	_burst(_sparks, Vector3(0.0, 0.0, _length / 2.0))
	_burst(_dust, Vector3(config.dust_width / 2.0, 0.0, _length / 2.0))
	_flash.position = Vector3(0.0, config.flash_height, -_length)
	_flash_light.position = _flash.position
	_flash.show()
	_flash_light.show()
	_update_burst()


func advance(delta: float) -> void:
	match _stage:
		Stage.LINE:
			_elapsed += delta
			_update_line()
		Stage.BURST:
			_elapsed += delta
			_burst_elapsed += delta
			_update_burst()
			if _burst_elapsed >= _burst_duration():
				_stop()


func is_playing() -> bool:
	return _stage != Stage.IDLE


func is_bursting() -> bool:
	return _stage == Stage.BURST


func get_line() -> MeshInstance3D:
	return _line


func get_segment(side: WallSide, index: int) -> MeshInstance3D:
	return _segments[side * config.segment_count + index]


func get_crescent() -> MeshInstance3D:
	return _crescent


func get_echo() -> MeshInstance3D:
	return _echo


func get_crack_piece(index: int) -> MeshInstance3D:
	return _crack[index]


func get_sparks() -> CPUParticles3D:
	return _sparks


func get_dust() -> CPUParticles3D:
	return _dust


func get_flash() -> MeshInstance3D:
	return _flash


func get_flash_light() -> OmniLight3D:
	return _flash_light


## Height segment `index` reaches before fading, in meters: highest in the
## middle, edge_height_ratio of that at the ends.
func get_segment_peak_height(index: int) -> float:
	var t: float = (index + 0.5) / config.segment_count
	return _height * lerpf(config.edge_height_ratio, 1.0, sin(PI * t))


## Seconds after the burst when segment `index` starts to fade (after rising).
func get_segment_fade_start(index: int) -> float:
	var from_middle: float = absf((index + 0.5) / config.segment_count - 0.5) * 2.0
	return index * config.wave_step + config.grow_duration + config.fade_stagger * (1.0 - from_middle)


## Every part of the burst has ended by then.
func _burst_duration() -> float:
	var last: int = config.segment_count - 1
	var walls: float = 0.0
	for i: int in config.segment_count:
		walls = maxf(walls, get_segment_fade_start(i) + config.fade_duration)
	var crescent: float = config.echo_delay + config.crescent_travel + config.crescent_fade if _crescent.mesh != null else 0.0
	var crack: float = config.crack_duration + config.crack_fade + (config.crack_count - 1) * config.crack_open_step
	return maxf(maxf(walls, crescent), maxf(maxf(crack, config.flash_duration), last * config.wave_step))


func _update_line() -> void:
	var length: float = maxf(_length * minf(_elapsed / config.line_grow_duration, 1.0), MIN_SIZE)
	_line.position = Vector3(0.0, LINE_LIFT, -length / 2.0)
	_line.scale = Vector3(config.line_width, FLAT_HEIGHT, length)


func _update_burst() -> void:
	for i: int in config.segment_count:
		_update_segment(i)
	_update_crescent(_crescent, _burst_elapsed, 1.0, config.crescent_start_transparency)
	_update_crescent(_echo, _burst_elapsed - config.echo_delay, config.echo_scale, config.echo_start_transparency)
	for i: int in config.crack_count:
		_update_crack_piece(i)
	var flash: float = minf(_burst_elapsed / config.flash_duration, 1.0)
	_flash.scale = Vector3.ONE * maxf(config.flash_radius * flash, MIN_SIZE)
	_flash.transparency = lerpf(config.start_transparency, 1.0, flash)
	_flash_light.light_energy = config.flash_energy * (1.0 - flash)
	if flash >= 1.0:
		_flash.hide()
		_flash_light.hide()


## Local space: forward is -Z. Each segment stands on the slash's centre line,
## tilted outwards from the vertical, rising to its peak, then thinning out.
func _update_segment(index: int) -> void:
	var rise_at: float = index * config.wave_step
	var fade_at: float = get_segment_fade_start(index)
	var visible_now: bool = _burst_elapsed >= rise_at and _burst_elapsed < fade_at + config.fade_duration
	var grow: float = clampf((_burst_elapsed - rise_at) / config.grow_duration, 0.0, 1.0)
	var fade: float = clampf((_burst_elapsed - fade_at) / config.fade_duration, 0.0, 1.0)
	var height: float = maxf(get_segment_peak_height(index) * grow * lerpf(1.0, config.fade_height_ratio, fade), MIN_SIZE)
	var thickness: float = maxf(config.wall_thickness * lerpf(1.0, config.fade_thickness_ratio, fade), MIN_SIZE)
	var slot: float = _length / config.segment_count
	var centre: float = -(index + 0.5) * slot
	var half_angle: float = deg_to_rad(config.half_angle_degrees)
	for side: int in WallSide.size():
		var tilt: float = half_angle if side == WallSide.LEFT else -half_angle
		var segment: MeshInstance3D = _segments[side * config.segment_count + index]
		segment.visible = visible_now
		var up: Vector3 = Basis(Vector3.BACK, tilt) * Vector3.UP
		segment.rotation = Vector3(0.0, 0.0, tilt)
		segment.position = up * height / 2.0 + Vector3(0.0, 0.0, centre)
		segment.scale = Vector3(thickness, height, maxf(slot * config.segment_fill, MIN_SIZE))
		segment.transparency = lerpf(config.start_transparency, 1.0, fade)


## `age` in seconds since this crescent left; `size` relative to the crescent.
func _update_crescent(crescent: MeshInstance3D, age: float, size: float, start_transparency: float) -> void:
	var life: float = config.crescent_travel + config.crescent_fade
	crescent.visible = crescent.mesh != null and age >= 0.0 and age < life
	if not crescent.visible:
		return
	var travel: float = minf(age / config.crescent_travel, 1.0)
	var eased: float = 1.0 - (1.0 - travel) * (1.0 - travel)
	var distance: float = lerpf(config.crescent_start, maxf(_length, config.crescent_start), eased)
	crescent.position = Vector3(0.0, config.crescent_height, -distance)
	crescent.rotation = Vector3(0.0, 0.0, deg_to_rad(config.crescent_roll_degrees))
	crescent.scale = Vector3.ONE * lerpf(config.crescent_start_scale, 1.0, travel) * _crescent_size * size
	crescent.transparency = lerpf(start_transparency, 1.0, age / life)


func _update_crack_piece(index: int) -> void:
	var piece: MeshInstance3D = _crack[index]
	var open_at: float = index * config.crack_open_step
	var fade: float = clampf((_burst_elapsed - open_at - config.crack_duration) / config.crack_fade, 0.0, 1.0)
	piece.visible = _burst_elapsed >= open_at and fade < 1.0
	piece.transparency = fade


## Random broken line along the slash, drawn anew for every cut.
func _layout_crack() -> void:
	_rng.randomize()
	var slot: float = _length / config.crack_count
	for i: int in config.crack_count:
		var piece: MeshInstance3D = _crack[i]
		var jitter: float = deg_to_rad(_rng.randf_range(-config.crack_jitter_degrees, config.crack_jitter_degrees))
		var shift: float = _rng.randf_range(-config.crack_offset, config.crack_offset)
		piece.position = Vector3(shift, CRACK_LIFT, -(i + 0.5) * slot)
		piece.rotation = Vector3(0.0, jitter, 0.0)
		piece.scale = Vector3(config.crack_width, FLAT_HEIGHT, maxf(slot * CRACK_OVERLAP, MIN_SIZE))


## Places the emitter at the middle of the slash, spread over its length.
func _burst(particles: CPUParticles3D, extents: Vector3) -> void:
	particles.position = Vector3(0.0, 0.0, -_length / 2.0)
	particles.emission_box_extents = extents
	particles.restart()
	particles.emitting = true


func _create_line() -> void:
	_line = _make_box(glow_material)
	_line.transparency = config.line_transparency


func _create_segments() -> void:
	var box := _unit_box(glow_material)
	for i: int in WallSide.size() * config.segment_count:
		_segments.append(_make_instance(box))


## No crescent (e.g. the air slash, crescent_segments = 0): both stay hidden.
func _create_crescents() -> void:
	var mesh: ArrayMesh = _build_crescent_mesh() if config.crescent_segments > 0 else null
	_crescent = _make_instance(mesh)
	_echo = _make_instance(mesh)


func _create_crack() -> void:
	var box := _unit_box(crack_material)
	for i: int in config.crack_count:
		_crack.append(_make_instance(box))


## Flat crescent on the XZ plane, facing up: an arc of crescent_arc_degrees
## whose apex (the outer edge, middle of the arc) lies at the origin and points
## to -Z, with the tips behind it. Its radial width is crescent_width in the
## middle and 0 at the tips.
func _build_crescent_mesh() -> ArrayMesh:
	var arc: float = deg_to_rad(config.crescent_arc_degrees)
	var radius: float = config.crescent_radius
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i: int in config.crescent_segments + 1:
		var angle: float = lerpf(-arc / 2.0, arc / 2.0, float(i) / config.crescent_segments)
		var direction := Vector3(sin(angle), 0.0, -cos(angle))
		var width: float = config.crescent_width * cos(PI * angle / arc)
		vertices.append(direction * radius + Vector3(0.0, 0.0, radius))
		vertices.append(direction * (radius - maxf(width, 0.0)) + Vector3(0.0, 0.0, radius))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	var indices := PackedInt32Array()
	for i: int in config.crescent_segments:
		var outer: int = i * 2
		indices.append_array([outer, outer + 2, outer + 1, outer + 1, outer + 2, outer + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, glow_material)
	return mesh


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
	_flash = _make_instance(sphere)
	_flash_light = OmniLight3D.new()
	_flash_light.omni_range = config.flash_range
	_flash_light.shadow_enabled = false
	add_child(_flash_light)


func _unit_box(material: Material) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	return box


func _make_box(material: Material) -> MeshInstance3D:
	return _make_instance(_unit_box(material))


func _make_instance(mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Everything drawn hides; the particles finish on their own.
func _stop() -> void:
	_stage = Stage.IDLE
	_line.hide()
	for segment: MeshInstance3D in _segments:
		segment.hide()
	_crescent.hide()
	_echo.hide()
	for piece: MeshInstance3D in _crack:
		piece.hide()
	_flash.hide()
	_flash_light.hide()
	set_process(false)
