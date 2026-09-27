class_name VirtualStick
extends Control
## Floating movement stick: a touch in the stick zone moves its center to the
## thumb, the knob follows the thumb and, past the radius, the center is
## dragged along (docs/specs/mobile-touch-controls.md). Covers its parent so
## points are in the same space as TouchControls; reads no events itself.
## Redraws only when the center or the knob moves.

const NO_FINGER: int = -1

@export var config: TouchControlsConfig

var _rest_center: Vector2 = Vector2.ZERO
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _finger: int = NO_FINGER


func _draw() -> void:
	_draw_stick()


## Where the stick waits while no thumb is on it (set by the layout).
func set_rest_center(point: Vector2) -> void:
	_rest_center = point
	if _finger == NO_FINGER:
		_move_to(point, point)


func begin(finger: int, local_point: Vector2) -> void:
	_finger = finger
	_move_to(local_point, local_point)


func drag(local_point: Vector2) -> void:
	var offset: Vector2 = local_point - _center
	if offset.length() <= config.stick_radius:
		_move_to(_center, local_point)
	elif config.stick_follows_thumb:
		_move_to(local_point - offset.normalized() * config.stick_radius, local_point)
	else:
		_move_to(_center, _center + offset.normalized() * config.stick_radius)


func end() -> void:
	_finger = NO_FINGER
	_move_to(_rest_center, _rest_center)


## Length 0..1 (1 = knob on the ring); zero inside the dead zone.
func get_vector() -> Vector2:
	var ratio: Vector2 = (_knob - _center) / config.stick_radius
	if ratio.length() < config.stick_dead_zone:
		return Vector2.ZERO
	return ratio.limit_length(1.0)


func get_finger() -> int:
	return _finger


func is_held() -> bool:
	return _finger != NO_FINGER


func get_center() -> Vector2:
	return _center


func get_rest_center() -> Vector2:
	return _rest_center


func _move_to(center: Vector2, knob: Vector2) -> void:
	if center == _center and knob == _knob:
		return
	_center = center
	_knob = knob
	queue_redraw()


func _draw_stick() -> void:
	draw_circle(_center, config.stick_radius, config.stick_color)
	draw_arc(_center, config.stick_radius, 0.0, TAU, config.arc_point_count, config.knob_color, config.ring_width, true)
	draw_circle(_knob, config.stick_knob_radius, config.knob_color)
