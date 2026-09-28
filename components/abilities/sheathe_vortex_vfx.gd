class_name SheatheVortexVfx
extends MeshInstance3D
## Cut vortex of the Sheathe's burst (docs/specs/sheathe-vortex-vfx.md): the
## riposte's white vortex (CircleSlashVfx) turned into a corkscrew of light
## that shoots from the player's feet to the cut's tip. A wide band winds
## around the cut's axis, thin streaks race along it at several radii, a flat
## stripe marks the floor and a brief light rides the head. It grows with the
## level (charge). Every ribbon is rebuilt each frame on one ImmediateMesh made
## once, and the streak table is computed once for the largest level
## (Principle V). Top level: it stays where the cut was dealt.

## Golden-ratio steps spread the streak table evenly without randomness.
const SPREAD_A: float = 0.618034
const SPREAD_B: float = 0.754878
const SPREAD_C: float = 0.569840

@export var config: SheatheVortexConfig

var _immediate: ImmediateMesh = null
var _light: OmniLight3D = null
var _elapsed: float = 0.0
var _playing: bool = false
var _length: float = 0.0
var _level: int = 1
var _band_width: float = 0.0
var _streak_count: int = 0
var _light_energy: float = 0.0
## Streak table (one entry per streak of the largest level), filled once.
var _streak_radius := PackedFloat32Array()
var _streak_width := PackedFloat32Array()
var _streak_phase := PackedFloat32Array()
var _streak_tail := PackedFloat32Array()
var _streak_speed := PackedFloat32Array()
var _streak_turns := PackedFloat32Array()


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	_light = OmniLight3D.new()
	_light.shadow_enabled = false
	_light.omni_range = config.light_range
	add_child(_light)
	_build_streak_table()
	_stop()


func _process(delta: float) -> void:
	advance(delta)


## Starts the vortex at `origin` (the player's feet) along `yaw` (its −Z is
## the cut's direction), `length` meters long, at `level` (1 to 3).
func play(origin: Vector3, yaw: float, length: float, level: int) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	_length = maxf(length, 0.001)
	_level = level
	_band_width = config.get_band_width(level)
	_streak_count = config.get_streak_count(level)
	_light_energy = config.get_light_energy(level)
	_elapsed = 0.0
	_playing = true
	visible = true
	_light.visible = _light_energy > 0.0
	set_process(true)
	_rebuild()


func advance(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if _elapsed >= config.sweep_duration + config.fade_duration:
		_stop()
		return
	_rebuild()


func is_playing() -> bool:
	return _playing


func get_level() -> int:
	return _level


func get_streak_count() -> int:
	return _streak_count


## Meters the band's head has travelled along the cut (eased out).
func get_head_distance() -> float:
	var progress: float = minf(_elapsed / config.sweep_duration, 1.0)
	return _length * (1.0 - (1.0 - progress) * (1.0 - progress))


func _build_streak_table() -> void:
	var count: int = config.get_max_streak_count()
	_streak_radius.resize(count)
	_streak_width.resize(count)
	_streak_phase.resize(count)
	_streak_tail.resize(count)
	_streak_speed.resize(count)
	_streak_turns.resize(count)
	for i: int in count:
		var a: float = fposmod(0.5 + i * SPREAD_A, 1.0)
		var b: float = fposmod(0.5 + i * SPREAD_B, 1.0)
		var c: float = fposmod(0.5 + i * SPREAD_C, 1.0)
		_streak_radius[i] = lerpf(config.streak_radius_min, config.streak_radius_max, a)
		_streak_width[i] = lerpf(config.streak_width_min, config.streak_width_max, c)
		_streak_phase[i] = fposmod(i * SPREAD_A, 1.0) * TAU
		_streak_tail[i] = lerpf(config.streak_tail_min, config.streak_tail_max, b)
		_streak_speed[i] = lerpf(config.streak_speed_min, config.streak_speed_max, c)
		_streak_turns[i] = lerpf(config.streak_turns_min, config.streak_turns_max, b) * (1.0 if i % 2 == 0 else -1.0)


## 1 while sweeping, then down to 0 over fade_duration.
func _fade() -> float:
	if _elapsed <= config.sweep_duration:
		return 1.0
	return maxf(1.0 - (_elapsed - config.sweep_duration) / config.fade_duration, 0.0)


func _stop() -> void:
	_playing = false
	visible = false
	_light.visible = false
	_immediate.clear_surfaces()
	set_process(false)


func _rebuild() -> void:
	_immediate.clear_surfaces()
	var fade: float = _fade()
	var head: float = get_head_distance()
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, config.material)
	_add_band(head, fade)
	for i: int in _streak_count:
		_add_streak(i, fade)
	_add_floor(head, fade)
	_immediate.surface_end()
	_light.position = _axis_point(head)
	_light.light_energy = _light_energy * fade


## The wide band: from its tail to its head, winding `turns` around the axis,
## narrower and closer to the axis toward the tail.
func _add_band(head: float, fade: float) -> void:
	var tail: float = maxf(head - config.band_tail_length * _length, 0.0)
	if head - tail <= 0.0:
		return
	var count: int = _sample_count(head - tail)
	for i: int in count:
		var from: float = float(i) / count
		var to: float = float(i + 1) / count
		var s_from: float = lerpf(tail, head, from)
		var s_to: float = lerpf(tail, head, to)
		_add_quad(s_from, s_to, _band_angle(s_from), _band_angle(s_to),
			_band_edges(from), _band_edges(to), Vector2(from, to) * config.head_alpha * fade)


func _band_angle(distance: float) -> float:
	return TAU * config.turns * distance / _length


## Inner (x) and outer (y) radius of the band at `along` (0 tail, 1 head).
func _band_edges(along: float) -> Vector2:
	var outer: float = config.band_radius * lerpf(config.band_tail_ratio, 1.0, along)
	var width: float = _band_width * lerpf(config.band_tail_width_ratio, 1.0, along)
	return Vector2(maxf(outer - width, 0.0), outer)


## A thin streak: its head runs ahead at its own speed and stops at the tip,
## where its tail catches up and it vanishes.
func _add_streak(index: int, fade: float) -> void:
	var travelled: float = _length * minf(_elapsed / config.sweep_duration, 1.0) * _streak_speed[index]
	var head: float = minf(travelled, _length)
	var tail: float = clampf(travelled - _streak_tail[index] * _length, 0.0, head)
	if head - tail <= 0.0:
		return
	var count: int = _sample_count(head - tail)
	var half: float = _streak_width[index] / 2.0
	for i: int in count:
		var from: float = float(i) / count
		var to: float = float(i + 1) / count
		var s_from: float = lerpf(tail, head, from)
		var s_to: float = lerpf(tail, head, to)
		var r_from: float = _streak_radius[index] * lerpf(config.streak_spiral_ratio, 1.0, from)
		var r_to: float = _streak_radius[index] * lerpf(config.streak_spiral_ratio, 1.0, to)
		_add_quad(s_from, s_to, _streak_angle(index, s_from), _streak_angle(index, s_to),
			Vector2(r_from - half, r_from + half), Vector2(r_to - half, r_to + half),
			Vector2(from, to) * config.streak_alpha * fade)


func _streak_angle(index: int, distance: float) -> float:
	return _streak_phase[index] + TAU * _streak_turns[index] * distance / _length


## The flat stripe on the floor, from the feet to the head, brighter ahead.
func _add_floor(head: float, fade: float) -> void:
	if head <= 0.0:
		return
	var count: int = _sample_count(head)
	var half: float = config.floor_width / 2.0
	var y: float = config.floor_height
	for i: int in count:
		var from: float = float(i) / count
		var to: float = float(i + 1) / count
		var z_from: float = -head * from
		var z_to: float = -head * to
		var color_from := Color(1.0, 1.0, 1.0, from * config.floor_alpha * fade)
		var color_to := Color(1.0, 1.0, 1.0, to * config.floor_alpha * fade)
		_vertex(Vector3(-half, y, z_from), color_from)
		_vertex(Vector3(half, y, z_from), color_from)
		_vertex(Vector3(half, y, z_to), color_to)
		_vertex(Vector3(-half, y, z_from), color_from)
		_vertex(Vector3(half, y, z_to), color_to)
		_vertex(Vector3(-half, y, z_to), color_to)


func _sample_count(span: float) -> int:
	return maxi(ceili(span * config.segments_per_meter), 1)


## One quad of a ribbon between distances `s_from` and `s_to` along the cut,
## at angles around the axis, with the inner (x) and outer (y) radius and the
## alpha at each end.
func _add_quad(s_from: float, s_to: float, angle_from: float, angle_to: float, edges_from: Vector2, edges_to: Vector2, alphas: Vector2) -> void:
	var axis_from: Vector3 = _axis_point(s_from)
	var axis_to: Vector3 = _axis_point(s_to)
	var dir_from: Vector3 = _radial(angle_from)
	var dir_to: Vector3 = _radial(angle_to)
	var color_from := Color(1.0, 1.0, 1.0, alphas.x)
	var color_to := Color(1.0, 1.0, 1.0, alphas.y)
	var inner_from: Vector3 = axis_from + dir_from * edges_from.x
	var outer_from: Vector3 = axis_from + dir_from * edges_from.y
	var inner_to: Vector3 = axis_to + dir_to * edges_to.x
	var outer_to: Vector3 = axis_to + dir_to * edges_to.y
	_vertex(inner_from, color_from)
	_vertex(outer_from, color_from)
	_vertex(outer_to, color_to)
	_vertex(inner_from, color_from)
	_vertex(outer_to, color_to)
	_vertex(inner_to, color_to)
	# The same ribbon crossed (its width around the axis instead of across
	# it), so it never shows edge-on to the camera.
	var mid_from: Vector3 = axis_from + dir_from * (edges_from.x + edges_from.y) / 2.0
	var mid_to: Vector3 = axis_to + dir_to * (edges_to.x + edges_to.y) / 2.0
	var side_from: Vector3 = _tangent(angle_from) * (edges_from.y - edges_from.x) / 2.0
	var side_to: Vector3 = _tangent(angle_to) * (edges_to.y - edges_to.x) / 2.0
	_vertex(mid_from - side_from, color_from)
	_vertex(mid_from + side_from, color_from)
	_vertex(mid_to + side_to, color_to)
	_vertex(mid_from - side_from, color_from)
	_vertex(mid_to + side_to, color_to)
	_vertex(mid_to - side_to, color_to)


## Direction around the axis at `angle` (perpendicular to _radial).
func _tangent(angle: float) -> Vector3:
	return Vector3(-sin(angle), cos(angle), 0.0)


func _axis_point(distance: float) -> Vector3:
	return Vector3(0.0, config.axis_height, -distance)


## Direction from the axis at `angle` (0 = right, turning up), across the cut.
func _radial(angle: float) -> Vector3:
	return Vector3(cos(angle), sin(angle), 0.0)


func _vertex(point: Vector3, color: Color) -> void:
	_immediate.surface_set_color(color)
	_immediate.surface_add_vertex(point)
