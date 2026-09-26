class_name AbilityRectIndicator
extends Node3D
## Outline of a rectangular ability hitbox on the ground, built from four thin
## BoxMesh segments (Principle II). Shown while the ability is cast, then fades
## out after the hit. Must be top_level so it stays where the cast happened.

## Named Edge, not Side: Side is a global enum of the engine.
enum Edge {
	LEFT,
	RIGHT,
	FAR,
	NEAR,
}

@export var config: AbilityIndicatorConfig
@export var material: StandardMaterial3D

## Created once in _ready and reused on every cast (Principle V).
var _segments: Array[MeshInstance3D] = []
var _showing: bool = false
var _fading: bool = false
var _fade_elapsed: float = 0.0
var _transparency: float = 1.0
## Resting transparency while shown; a pulse returns to it.
var _base_transparency: float = 1.0
var _pulsing: bool = false
var _pulse_elapsed: float = 0.0


func _ready() -> void:
	_create_segments()
	_hide_indicator()


func _process(delta: float) -> void:
	advance(delta)


## Places the outline starting at `origin` (the player's feet) and extending
## `length` towards `yaw`, `width` wide. Stays still until start_fade().
func show_rect(origin: Vector3, yaw: float, length: float, width: float) -> void:
	resize(origin, yaw, length, width)
	_fading = false
	_fade_elapsed = 0.0
	_pulsing = false
	_showing = true
	_base_transparency = config.start_transparency
	_apply_transparency(_base_transparency)
	show()
	set_process(true)


## Moves and resizes the shown outline without touching its transparency
## (e.g. a charge that grows the reach while the player walks).
func resize(origin: Vector3, yaw: float, length: float, width: float) -> void:
	global_position = origin + Vector3.UP * config.ground_offset
	global_basis = Basis(Vector3.UP, yaw)
	_layout_segments(length, width)


## Changes the resting transparency while it is shown (e.g. fully charged).
func set_transparency(value: float) -> void:
	_base_transparency = value
	if not _pulsing:
		_apply_transparency(value)


## Briefly drops to pulse_transparency and returns to the resting transparency
## over pulse_duration (no pulse when pulse_duration is 0).
func pulse() -> void:
	if not _showing or _fading or config.pulse_duration <= 0.0:
		return
	_pulsing = true
	_pulse_elapsed = 0.0
	_apply_transparency(config.pulse_transparency)


func start_fade() -> void:
	if not _showing:
		return
	_pulsing = false
	_fading = true
	_fade_elapsed = 0.0


func advance(delta: float) -> void:
	if _pulsing:
		_advance_pulse(delta)
	if not _fading:
		return
	_fade_elapsed += delta
	if _fade_elapsed >= config.fade_duration:
		_hide_indicator()
		return
	_apply_transparency(lerpf(config.start_transparency, 1.0, _fade_elapsed / config.fade_duration))


func is_showing() -> bool:
	return _showing


func is_pulsing() -> bool:
	return _pulsing


func get_segment_count() -> int:
	return _segments.size()


func get_segment(edge: Edge) -> MeshInstance3D:
	return _segments[edge]


func get_transparency() -> float:
	return _transparency


func _create_segments() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	for i: int in Edge.size():
		var segment := MeshInstance3D.new()
		segment.mesh = box
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(segment)
		_segments.append(segment)


## Local space: forward is -Z. The end edges span the width plus one line so
## the corners close.
func _layout_segments(length: float, width: float) -> void:
	var half_width: float = width / 2.0
	var side_scale := Vector3(config.line_width, config.line_thickness, length)
	var edge_scale := Vector3(width + config.line_width, config.line_thickness, config.line_width)
	_place(Edge.LEFT, Vector3(-half_width, 0.0, -length / 2.0), side_scale)
	_place(Edge.RIGHT, Vector3(half_width, 0.0, -length / 2.0), side_scale)
	_place(Edge.FAR, Vector3(0.0, 0.0, -length), edge_scale)
	_place(Edge.NEAR, Vector3.ZERO, edge_scale)


func _place(edge: Edge, at: Vector3, size: Vector3) -> void:
	var segment: MeshInstance3D = _segments[edge]
	segment.position = at
	segment.scale = size


func _apply_transparency(value: float) -> void:
	_transparency = value
	for segment: MeshInstance3D in _segments:
		segment.transparency = value


func _hide_indicator() -> void:
	_pulsing = false
	_showing = false
	_fading = false
	hide()
	set_process(false)


func _advance_pulse(delta: float) -> void:
	_pulse_elapsed += delta
	if _pulse_elapsed >= config.pulse_duration:
		_pulsing = false
		_apply_transparency(_base_transparency)
		return
	_apply_transparency(lerpf(config.pulse_transparency, _base_transparency, _pulse_elapsed / config.pulse_duration))
