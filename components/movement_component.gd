class_name MovementComponent
extends Node
## Moves a CharacterBody3D on the XZ plane with acceleration, gravity and
## a visual that turns towards the movement direction.

@export var body: CharacterBody3D
@export var visual: Node3D
@export var stats: StatsComponent
@export var tuning: PlayerTuning

## While true, move() does not rotate the visual (used by the attack auto-aim).
var face_direction_locked: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


## `speed_factor` scales MOVE_SPEED (e.g. slowed while an ability is channelled).
func move(direction: Vector3, delta: float, speed_factor: float = 1.0) -> void:
	var max_speed: float = stats.get_stat(PlayerStats.Stat.MOVE_SPEED) * speed_factor
	body.velocity = compute_velocity(body.velocity, direction, delta, body.is_on_floor(), max_speed)
	body.move_and_slide()
	_turn_visual(direction, delta)


## Like move() but suspended in the air: no gravity, no vertical motion (e.g.
## the Berserker's air slash).
func hover_move(direction: Vector3, delta: float, speed_factor: float) -> void:
	var max_speed: float = stats.get_stat(PlayerStats.Stat.MOVE_SPEED) * speed_factor
	var horizontal: Vector3 = _next_horizontal(body.velocity, _flatten(direction), delta, max_speed)
	body.velocity = Vector3(horizontal.x, 0.0, horizontal.z)
	body.move_and_slide()
	_turn_visual(direction, delta)


## Stops horizontal motion at once (e.g. while casting); gravity still applies.
func hold(delta: float) -> void:
	body.velocity = Vector3(0.0, _next_vertical(body.velocity.y, delta, body.is_on_floor()), 0.0)
	body.move_and_slide()


## Only from the floor; no double jump.
func jump() -> void:
	if body.is_on_floor():
		body.velocity.y = stats.get_stat(PlayerStats.Stat.JUMP_VELOCITY)


## Pure: returns the next velocity without touching the body.
func compute_velocity(current: Vector3, direction: Vector3, delta: float, on_floor: bool, max_speed: float) -> Vector3:
	var horizontal: Vector3 = _next_horizontal(current, _flatten(direction), delta, max_speed)
	var vertical: float = _next_vertical(current.y, delta, on_floor)
	return Vector3(horizontal.x, vertical, horizontal.z)


func _next_horizontal(current: Vector3, direction: Vector3, delta: float, max_speed: float) -> Vector3:
	var horizontal := Vector3(current.x, 0.0, current.z)
	if direction == Vector3.ZERO:
		return horizontal.move_toward(Vector3.ZERO, tuning.deceleration * delta)
	return horizontal.move_toward(direction * max_speed, tuning.acceleration * delta)


func _next_vertical(current_y: float, delta: float, on_floor: bool) -> float:
	if not on_floor:
		return current_y - _gravity * delta
	return maxf(current_y, 0.0)


## Drops the Y component and caps the length at 1 (analog input keeps its magnitude).
func _flatten(direction: Vector3) -> Vector3:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() > 1.0:
		return flat.normalized()
	return flat


func _turn_visual(direction: Vector3, delta: float) -> void:
	var flat: Vector3 = _flatten(direction)
	if visual == null or face_direction_locked or flat == Vector3.ZERO:
		return
	var target_yaw: float = atan2(-flat.x, -flat.z)
	var weight: float = clampf(tuning.turn_speed * delta, 0.0, 1.0)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, weight)
