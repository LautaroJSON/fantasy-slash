class_name CircleSlashVfx
extends MeshInstance3D
## Circular slash VFX of the Parry's empowered riposte: a white vortex
## (docs/specs/riposte-levels.md §2.2, after parry-riposte-rework.md §2.6).
## Its band's head starts on the player's left and sweeps 360° (front, right,
## back) in sweep_duration while the band spirals in towards its tail; thin
## streaks whirl with it at several radii and heights, and a flat spiral marks
## the floor. burst() throws sparks, dust and a flash on the hit. It grows with
## the "Contragolpe" level. Every ribbon is rebuilt each frame on one
## ImmediateMesh made once, and the streak table is computed once for the
## largest level (Principle V). Top level: it stays where the slash was dealt.

## Golden-ratio steps spread the streak table evenly without randomness.
const SPREAD_A: float = 0.618034
const SPREAD_B: float = 0.754878
const SPREAD_C: float = 0.569840

@export var config: CircleSlashVfxConfig

var _immediate: ImmediateMesh = null
var _elapsed: float = 0.0
var _playing: bool = false
var _radius: float = 0.0
var _level: int = 1
var _band_width: float = 0.0
var _streak_count: int = 0
var _flash_left: float = 0.0
var _flash_energy: float = 0.0
## Streak table (one entry per streak of the largest level), filled once.
var _streak_radius := PackedFloat32Array()
var _streak_height := PackedFloat32Array()
var _streak_width := PackedFloat32Array()
var _streak_offset := PackedFloat32Array()
var _streak_tail := PackedFloat32Array()
var _streak_speed := PackedFloat32Array()

@onready var _sparks: CPUParticles3D = $Sparks
@onready var _dust: CPUParticles3D = $Dust
@onready var _flash: OmniLight3D = $Flash


func _ready() -> void:
	top_level = true
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	visible = false
	_flash.visible = false
	_build_streak_table()


func _process(delta: float) -> void:
	advance(delta)


## Starts the vortex around `center` (its −Z is the front), with the hit
## radius, at "Contragolpe" `level`.
func play(center: Node3D, radius: float, level: int) -> void:
	global_transform = Transform3D(center.global_basis.orthonormalized(), center.global_position)
	_radius = radius
	_level = level
	_band_width = config.get_band_width(level)
	_streak_count = config.get_streak_count(level)
	_elapsed = 0.0
	_playing = true
	visible = true
	_rebuild()


## Sparks, dust and flash on the hit, on the ring of the hit radius.
func burst() -> void:
	_emit(_sparks, config.get_spark_amount(_level))
	_emit(_dust, config.get_dust_amount(_level))
	_flash_energy = config.get_flash_energy(_level)
	_flash_left = config.flash_duration
	_flash.omni_range = _radius
	_flash.light_energy = _flash_energy
	_flash.visible = _flash_energy > 0.0


func advance(delta: float) -> void:
	_advance_flash(delta)
	if not _playing:
		return
	_elapsed += delta
	if _elapsed >= config.sweep_duration + config.fade_duration:
		_stop()
		return
	_rebuild()


func is_playing() -> bool:
	return _playing


## Degrees the band's head has swept from the player's left (0 to 360).
func get_head_degrees() -> float:
	return minf(_elapsed / config.sweep_duration, 1.0) * 360.0


## Alpha of the band's head now: head_alpha while sweeping, then fading to 0.
func get_head_alpha() -> float:
	return config.head_alpha * _fade()


func get_level() -> int:
	return _level


func get_band_width() -> float:
	return _band_width


func get_streak_count() -> int:
	return _streak_count


## Inner edge of the band at `along` (0 = its tail, 1 = its head), in meters.
func get_band_inner_radius(along: float) -> float:
	return lerpf(_radius * config.inner_radius_ratio, _radius - _band_width, along)


## Radius of streak `index` at `along` (0 = its tail, 1 = its head), in meters.
func get_streak_radius(index: int, along: float) -> float:
	return _radius * _streak_radius[index] * lerpf(config.streak_spiral_ratio, 1.0, along)


func get_streak_height(index: int) -> float:
	return _streak_height[index]


func get_streak_offset(index: int) -> float:
	return _streak_offset[index]


func get_sparks() -> CPUParticles3D:
	return _sparks


func get_dust() -> CPUParticles3D:
	return _dust


func get_flash() -> OmniLight3D:
	return _flash


func _build_streak_table() -> void:
	var count: int = config.get_max_streak_count()
	_streak_radius.resize(count)
	_streak_height.resize(count)
	_streak_width.resize(count)
	_streak_offset.resize(count)
	_streak_tail.resize(count)
	_streak_speed.resize(count)
	for i: int in count:
		var a: float = fposmod(0.5 + i * SPREAD_A, 1.0)
		var b: float = fposmod(0.5 + i * SPREAD_B, 1.0)
		var c: float = fposmod(0.5 + i * SPREAD_C, 1.0)
		_streak_radius[i] = lerpf(config.streak_radius_min, config.streak_radius_max, a)
		_streak_height[i] = lerpf(config.streak_height_min, config.streak_height_max, b)
		_streak_width[i] = lerpf(config.streak_width_min, config.streak_width_max, c)
		_streak_offset[i] = fposmod(i * SPREAD_A * 360.0, 360.0) * 0.25
		_streak_tail[i] = lerpf(config.streak_tail_min, config.streak_tail_max, b)
		_streak_speed[i] = lerpf(config.streak_speed_min, config.streak_speed_max, c)


func _emit(particles: CPUParticles3D, amount: int) -> void:
	if amount <= 0:
		return
	particles.amount = amount
	particles.emission_ring_radius = _radius
	particles.emission_ring_inner_radius = _radius * 0.85
	particles.restart()
	particles.emitting = true


func _advance_flash(delta: float) -> void:
	if not _flash.visible:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash.visible = false
		return
	_flash.light_energy = _flash_energy * _flash_left / config.flash_duration


## 1 while sweeping, then down to 0 over fade_duration.
func _fade() -> float:
	if _elapsed <= config.sweep_duration:
		return 1.0
	return maxf(1.0 - (_elapsed - config.sweep_duration) / config.fade_duration, 0.0)


func _stop() -> void:
	_playing = false
	visible = false
	_immediate.clear_surfaces()


func _rebuild() -> void:
	_immediate.clear_surfaces()
	var fade: float = _fade()
	var head: float = get_head_degrees()
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, config.material)
	_add_band(head, fade)
	for i: int in _streak_count:
		_add_streak(i, fade)
	_add_floor(head, fade)
	_immediate.surface_end()


func _add_band(head: float, fade: float) -> void:
	var tail: float = maxf(head - config.tail_degrees, 0.0)
	var count: int = _sample_count(head - tail)
	for i: int in count:
		var from: float = float(i) / count
		var to: float = float(i + 1) / count
		_add_quad(
			lerpf(tail, head, from), lerpf(tail, head, to),
			_band_edges(from), _band_edges(to),
			Vector2(_band_height(from), _band_height(to)),
			config.band_lift,
			Vector2(from, to) * config.head_alpha * fade)


## Inner (x) and outer (y) radius of the band at `along`.
func _band_edges(along: float) -> Vector2:
	return Vector2(get_band_inner_radius(along), lerpf(_radius * config.outer_radius_ratio, _radius, along))


func _band_height(along: float) -> float:
	return config.height + config.tail_rise * (1.0 - along)


func _add_streak(index: int, fade: float) -> void:
	var sweep: float = _elapsed / config.sweep_duration * 360.0 * _streak_speed[index]
	var head: float = _streak_offset[index] + sweep
	var tail: float = head - minf(_streak_tail[index], sweep)
	if head - tail <= 0.0:
		return
	var count: int = _sample_count(head - tail)
	var half: float = _streak_width[index] / 2.0
	var height: float = _streak_height[index]
	for i: int in count:
		var from: float = float(i) / count
		var to: float = float(i + 1) / count
		var r_from: float = get_streak_radius(index, from)
		var r_to: float = get_streak_radius(index, to)
		_add_quad(
			lerpf(tail, head, from), lerpf(tail, head, to),
			Vector2(r_from - half, r_from + half), Vector2(r_to - half, r_to + half),
			Vector2(height, height),
			config.streak_lift,
			Vector2(from, to) * config.streak_alpha * fade)


func _add_floor(head: float, fade: float) -> void:
	var tail: float = head - config.floor_turns_degrees
	var count: int = _sample_count(config.floor_turns_degrees)
	var half: float = config.floor_width / 2.0
	for i: int in count:
		var from: float = float(i) / count
		var to: float = float(i + 1) / count
		var r_from: float = _radius * lerpf(config.floor_inner_ratio, 1.0, from)
		var r_to: float = _radius * lerpf(config.floor_inner_ratio, 1.0, to)
		_add_quad(
			lerpf(tail, head, from), lerpf(tail, head, to),
			Vector2(r_from - half, r_from), Vector2(r_to - half, r_to),
			Vector2(config.floor_height, config.floor_height),
			0.0,
			Vector2(from, to) * config.floor_alpha * fade)


func _sample_count(span_degrees: float) -> int:
	return maxi(ceili(span_degrees / (360.0 / float(config.segments))), 1)


## One flat quad of a ribbon between two angles (degrees from the left),
## with the inner (x) and outer (y) radius, height and alpha at each end; the
## outer edge is `lift` meters higher (a funnel the low camera can see).
func _add_quad(angle_from: float, angle_to: float, edges_from: Vector2, edges_to: Vector2, heights: Vector2, lift: float, alphas: Vector2) -> void:
	var dir_from: Vector3 = _direction(angle_from)
	var dir_to: Vector3 = _direction(angle_to)
	var inner_from: Vector3 = dir_from * edges_from.x + Vector3.UP * heights.x
	var outer_from: Vector3 = dir_from * edges_from.y + Vector3.UP * (heights.x + lift)
	var inner_to: Vector3 = dir_to * edges_to.x + Vector3.UP * heights.y
	var outer_to: Vector3 = dir_to * edges_to.y + Vector3.UP * (heights.y + lift)
	var color_from := Color(1.0, 1.0, 1.0, alphas.x)
	var color_to := Color(1.0, 1.0, 1.0, alphas.y)
	_vertex(inner_from, color_from)
	_vertex(outer_from, color_from)
	_vertex(outer_to, color_to)
	_vertex(inner_from, color_from)
	_vertex(outer_to, color_to)
	_vertex(inner_to, color_to)


func _vertex(point: Vector3, color: Color) -> void:
	_immediate.surface_set_color(color)
	_immediate.surface_add_vertex(point)


## 0° is the player's left (−X), 90° the front (−Z).
func _direction(degrees: float) -> Vector3:
	var radians: float = deg_to_rad(degrees)
	return Vector3(-cos(radians), 0.0, -sin(radians))
