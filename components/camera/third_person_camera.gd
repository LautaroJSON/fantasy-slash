class_name ThirdPersonCamera
extends Node3D
## Orbit camera driven by the mouse or the right stick that follows a target.
## Independent from the target's movement direction. Mouse motion is read
## here only (Principle VI).

const ACTION_CAMERA_LEFT: StringName = &"camera_left"
const ACTION_CAMERA_RIGHT: StringName = &"camera_right"
const ACTION_CAMERA_UP: StringName = &"camera_up"
const ACTION_CAMERA_DOWN: StringName = &"camera_down"

@export var target: Node3D
@export var config: CameraConfig

var _yaw: float = 0.0
var _pitch: float = 0.0
var _shake_strength: float = 0.0
var _shake_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Field of view kick (e.g. the dash, docs/specs/dash-feel.md): degrees added
## at the start, eased back to the base over the return time.
var _fov_base: float = 0.0
var _fov_kick: float = 0.0
var _fov_kick_total: float = 0.0
var _fov_kick_left: float = 0.0

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	_spring_arm.spring_length = config.spring_length
	_fov_base = _camera.fov
	_apply_rotation()
	capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	_handle_mouse_motion(event)


func _physics_process(_delta: float) -> void:
	_follow_target()


func _process(delta: float) -> void:
	_update_stick_look(delta)
	_update_shake(delta)
	_update_fov_kick(delta)


## Shakes the view; strength in [0, 1]. A new shake restarts the timer and
## keeps the stronger of the running and the new strength.
func shake(strength: float) -> void:
	_shake_strength = maxf(strength, _shake_strength if _shake_left > 0.0 else 0.0)
	_shake_left = config.shake_duration


## Widens the view by `amount_deg` at once and eases it back over
## `return_time` seconds. A new kick restarts it; kicks never add up.
func kick_fov(amount_deg: float, return_time: float) -> void:
	_fov_kick = amount_deg
	_fov_kick_total = return_time
	_fov_kick_left = return_time
	_camera.fov = _fov_base + amount_deg


func get_fov() -> float:
	return _camera.fov


func get_base_fov() -> float:
	return _fov_base


func stop_shake() -> void:
	_shake_left = 0.0
	_shake_strength = 0.0
	_set_view_offset(Vector2.ZERO)


## Strength of the running shake, in [0, 1] (0 when not shaking).
func get_shake_strength() -> float:
	return _shake_strength if _shake_left > 0.0 else 0.0


## Current view offset in meters (zero when not shaking).
func get_shake_offset() -> Vector2:
	return Vector2(_camera.h_offset, _camera.v_offset)


func rotate_camera(yaw_delta: float, pitch_delta: float) -> void:
	_yaw = wrapf(_yaw + yaw_delta, -PI, PI)
	_pitch = clampf(_pitch + pitch_delta, deg_to_rad(config.min_pitch_deg), deg_to_rad(config.max_pitch_deg))
	_apply_rotation()


## Turns the view with the right stick: `look` is the stick vector (down = +y),
## scaled by the stick speeds. Down looks down, like the mouse; invert_y flips it.
func apply_stick_look(look: Vector2, delta: float) -> void:
	if look == Vector2.ZERO:
		return
	rotate_camera(-look.x * config.stick_yaw_speed * delta, -look.y * config.stick_pitch_speed * delta * _y_sign())


func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch


## Converts 2D movement input (forward = (0, -1)) to a world XZ direction
## relative to the camera yaw. Keeps the input length.
func to_world_direction(input: Vector2) -> Vector3:
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw)


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _handle_mouse_motion(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	rotate_camera(-motion.relative.x * config.mouse_sensitivity, -motion.relative.y * config.mouse_sensitivity * _y_sign())


func _update_stick_look(delta: float) -> void:
	apply_stick_look(Input.get_vector(ACTION_CAMERA_LEFT, ACTION_CAMERA_RIGHT, ACTION_CAMERA_UP, ACTION_CAMERA_DOWN), delta)


func _y_sign() -> float:
	return -1.0 if config.invert_y else 1.0


## Random offset whose amplitude decays linearly to zero over shake_duration.
func _update_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		stop_shake()
		return
	var amplitude: float = config.shake_max_offset * _shake_strength * (_shake_left / config.shake_duration)
	_set_view_offset(Vector2(_rng.randf_range(-amplitude, amplitude), _rng.randf_range(-amplitude, amplitude)))


func _set_view_offset(offset: Vector2) -> void:
	_camera.h_offset = offset.x
	_camera.v_offset = offset.y


func _follow_target() -> void:
	global_position = target.global_position + config.follow_offset


func _apply_rotation() -> void:
	rotation.y = _yaw
	if _spring_arm != null:
		_spring_arm.rotation.x = _pitch


## Ease-out back to the base field of view.
func _update_fov_kick(delta: float) -> void:
	if _fov_kick_left <= 0.0:
		return
	_fov_kick_left = maxf(_fov_kick_left - delta, 0.0)
	var remaining: float = _fov_kick_left / _fov_kick_total
	_camera.fov = _fov_base + _fov_kick * remaining * remaining
