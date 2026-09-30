class_name EnemyHands
extends Node3D
## The two floating hands of an enemy: they bob at rest, pull back during a
## windup and shoot forward on the strike (docs/specs/enemy-attack-telegraph.md).
## Offsets are local to the enemy; this node scales with its body_scale.
## Bosses may also move, hide, resize and shake one hand on its own
## (docs/specs/boss-titan.md).

## The model listens to these (docs/specs/enemy-models.md): the behaviors keep
## calling the hands and never the model.
signal windup_started(clip: StringName, duration: float)
signal strike_started(clip: StringName, duration: float)
signal pose_started(pose: StringName, duration: float)
signal rested
signal phase_started(phase: int)

@export var config: EnemyHandsConfig

var _left_from: Vector3 = Vector3.ZERO
var _right_from: Vector3 = Vector3.ZERO
var _left_to: Vector3 = Vector3.ZERO
var _right_to: Vector3 = Vector3.ZERO
## Rotation of each hand on top of config.hand_rotation (degrees), and the ends of its move.
var _left_rot: Vector3 = Vector3.ZERO
var _right_rot: Vector3 = Vector3.ZERO
var _left_rot_from: Vector3 = Vector3.ZERO
var _right_rot_from: Vector3 = Vector3.ZERO
var _left_rot_to: Vector3 = Vector3.ZERO
var _right_rot_to: Vector3 = Vector3.ZERO

## Positions before the shake is added.
var _left_base: Vector3 = Vector3.ZERO
var _right_base: Vector3 = Vector3.ZERO
var _move_time: float = 0.0
var _move_duration: float = 0.0
var _bob_time: float = 0.0
var _at_rest: bool = true
var _use_left: bool = false
var _use_right: bool = false
## ALTERNATE attacks: the next one uses the left hand.
var _left_next: bool = false
## Size of both hands relative to config.hand_scale, and of each one on top.
var _size_multiplier: float = 1.0
var _left_size: float = 1.0
var _right_size: float = 1.0
var _left_shake_left: float = 0.0
var _right_shake_left: float = 0.0
var _left_shake_amount: float = 0.0
var _right_shake_amount: float = 0.0

@onready var _left: MeshInstance3D = $LeftHand
@onready var _right: MeshInstance3D = $RightHand


func _ready() -> void:
	reset()


func _physics_process(delta: float) -> void:
	advance(delta)


## Uses another type's hands (rest pose, bob, size) and goes back to rest.
func apply_config(new_config: EnemyHandsConfig) -> void:
	config = new_config
	reset()


## Puts the model's fists, claws or blades on the hands (once, when the enemy is
## created) and turns them by config.hand_rotation.
func set_hand_meshes(left_mesh: Mesh, right_mesh: Mesh, material: Material) -> void:
	_left.mesh = left_mesh
	_right.mesh = right_mesh
	if material != null:
		_left.material_override = material
		_right.material_override = material
	_apply_rotations()


## Hands at rest, whole, visible and still; the next ALTERNATE attack uses the right hand.
func reset() -> void:
	_size_multiplier = 1.0
	_left_size = 1.0
	_right_size = 1.0
	_apply_sizes()
	_left.visible = true
	_right.visible = true
	_left_shake_left = 0.0
	_right_shake_left = 0.0
	_left_next = false
	_at_rest = true
	_bob_time = 0.0
	_move_time = 0.0
	_move_duration = 0.0
	_left_rot = _rest_rotation(true)
	_right_rot = _rest_rotation(false)
	_left_rot_to = _left_rot
	_right_rot_to = _right_rot
	_left_base = get_left_rest()
	_right_base = get_right_rest()
	_apply_rotations()
	_apply_positions()


## Hands size relative to config.hand_scale (e.g. a boss in phase 2).
func set_size_multiplier(multiplier: float) -> void:
	_size_multiplier = multiplier
	_apply_sizes()


## Size of one hand on top of set_size_multiplier (e.g. a damaged boss hand).
func set_hand_size(left: bool, multiplier: float) -> void:
	if left:
		_left_size = multiplier
	else:
		_right_size = multiplier
	_apply_sizes()


func set_hand_visible(left: bool, shown: bool) -> void:
	(_left if left else _right).visible = shown


func is_hand_visible(left: bool) -> bool:
	return (_left if left else _right).visible


## Shakes one hand for `time` seconds by up to `amount` (local units).
func shake_hand(left: bool, time: float, amount: float) -> void:
	if left:
		_left_shake_left = time
		_left_shake_amount = amount
	else:
		_right_shake_left = time
		_right_shake_amount = amount


func is_hand_shaking(left: bool) -> bool:
	return (_left_shake_left if left else _right_shake_left) > 0.0


func get_left_rest() -> Vector3:
	return _mirror(config.rest_offset)


func get_right_rest() -> Vector3:
	return config.rest_offset


func get_left_position() -> Vector3:
	return _left.position


func get_right_position() -> Vector3:
	return _right.position


func get_hand_global_position(left: bool) -> Vector3:
	return (_left if left else _right).global_position


## Radius of one hand in world units (config.hand_radius × its global scale).
func get_hand_radius(left: bool) -> float:
	var hand: MeshInstance3D = _left if left else _right
	return config.hand_radius * hand.global_basis.x.length()


## The attacking hands pull back to hand_windup_offset over `duration`.
func play_windup(attack: EnemyAttackData, duration: float) -> void:
	_pick_hands(attack.hands)
	_move_attacking_hands(attack.hand_windup_offset, attack.hand_windup_rotation, duration)
	windup_started.emit(attack.model_clip, duration)


## The attacking hands (chosen by play_windup) shoot to hand_strike_offset.
func play_strike(attack: EnemyAttackData, duration: float) -> void:
	_move_attacking_hands(attack.hand_strike_offset, attack.hand_strike_rotation, duration)
	strike_started.emit(attack.model_clip, duration)


## Any other held pose (guard down, airborne, stunned): both hands go to their
## rest pose plus `offset` (the left one mirrored) and stay there. `pose` names
## the clip the model plays (&"stunned", &"airborne", &"guard_down", &"transition").
func play_pose(offset: Vector3, duration: float, pose: StringName = &"pose", rotation: Vector3 = Vector3.ZERO) -> void:
	_use_left = true
	_use_right = true
	_move_attacking_hands(offset, rotation, duration)
	pose_started.emit(pose, duration)


## Moves one hand to `local_position` (this node's space); the other one stays.
func move_hand(left: bool, local_position: Vector3, duration: float) -> void:
	if left:
		_start_move(local_position, _right_base, _left_rot, _right_rot, duration)
	else:
		_start_move(_left_base, local_position, _left_rot, _right_rot, duration)
	_at_rest = false


## Tells the model a move that the hands do on their own (a boss hand crashing down,
## a pose) without moving them: the windup, the strike or a held pose.
func announce_windup(clip: StringName, duration: float) -> void:
	windup_started.emit(clip, duration)


func announce_strike(clip: StringName, duration: float) -> void:
	strike_started.emit(clip, duration)


func announce_pose(pose: StringName, duration: float) -> void:
	pose_started.emit(pose, duration)


## A boss entered `phase` (1 or 2): the model may change (a glow that stays lit).
func announce_phase(phase: int) -> void:
	phase_started.emit(phase)


func is_at_rest() -> bool:
	return _at_rest


func return_to_rest() -> void:
	_start_move(get_left_rest(), get_right_rest(), _rest_rotation(true), _rest_rotation(false), config.return_time)
	_at_rest = true
	# The bob restarts at 0, where the return ends.
	_bob_time = 0.0
	rested.emit()


func advance(delta: float) -> void:
	_left_shake_left = maxf(_left_shake_left - delta, 0.0)
	_right_shake_left = maxf(_right_shake_left - delta, 0.0)
	if _move_time < _move_duration:
		_move_time = minf(_move_time + delta, _move_duration)
		var weight: float = smoothstep(0.0, 1.0, _move_time / _move_duration)
		_left_base = _left_from.lerp(_left_to, weight)
		_right_base = _right_from.lerp(_right_to, weight)
		_left_rot = _left_rot_from.lerp(_left_rot_to, weight)
		_right_rot = _right_rot_from.lerp(_right_rot_to, weight)
		_apply_rotations()
	elif _at_rest:
		_bob_time += delta
		var bob: float = sin(_bob_time * TAU * config.bob_frequency) * config.bob_amplitude
		_left_base = get_left_rest() + Vector3.UP * bob
		_right_base = get_right_rest() - Vector3.UP * bob
	_apply_positions()


func _apply_positions() -> void:
	_left.position = _left_base + _shake_offset(_left_shake_left, _left_shake_amount, 0.0)
	_right.position = _right_base + _shake_offset(_right_shake_left, _right_shake_amount, PI)
	if config.off_hand_follows:
		_left.position = _right.position + _right.quaternion * config.off_hand_grip


## The right hand takes config.hand_rotation and the left one mirrors Y and Z, each
## turned in the enemy's space by its rotation offset. A two-handed weapon takes the
## right hand's rotation in both.
func _apply_rotations() -> void:
	_set_rotation(_right, config.hand_rotation, _right_rot)
	if config.off_hand_follows:
		_left.quaternion = _right.quaternion
	else:
		_set_rotation(_left, _mirror_rotation(config.hand_rotation), _left_rot)


## Sets `hand` to `base` degrees turned by `offset` degrees (exactly `base` with no offset).
func _set_rotation(hand: MeshInstance3D, base: Vector3, offset: Vector3) -> void:
	if offset.is_zero_approx():
		hand.rotation_degrees = base
		return
	var turned: Basis = Basis.from_euler(offset * (PI / 180.0)) * Basis.from_euler(base * (PI / 180.0))
	hand.quaternion = turned.get_rotation_quaternion()


## Rotation of a hand at rest: config.rest_rotation (mirrored for the left hand).
func _rest_rotation(left: bool) -> Vector3:
	return _mirror_rotation(config.rest_rotation) if left else config.rest_rotation


func _mirror_rotation(rotation: Vector3) -> Vector3:
	return Vector3(rotation.x, -rotation.y, -rotation.z)


func _shake_offset(time_left: float, amount: float, phase: float) -> Vector3:
	if time_left <= 0.0:
		return Vector3.ZERO
	var angle: float = time_left * TAU * config.shake_frequency + phase
	return Vector3(sin(angle), cos(angle * 1.3), sin(angle * 0.7)) * amount


func _apply_sizes() -> void:
	_left.scale = Vector3.ONE * config.hand_scale * _size_multiplier * _left_size
	_right.scale = Vector3.ONE * config.hand_scale * _size_multiplier * _right_size


func _pick_hands(hands: EnemyAttackData.Hands) -> void:
	match hands:
		EnemyAttackData.Hands.BOTH:
			_use_left = true
			_use_right = true
		EnemyAttackData.Hands.LEFT:
			_use_left = true
			_use_right = false
		EnemyAttackData.Hands.RIGHT:
			_use_left = false
			_use_right = true
		EnemyAttackData.Hands.ALTERNATE:
			_use_left = _left_next
			_use_right = not _left_next
			_left_next = not _left_next


## Offsets are written for the right hand; the left hand mirrors x.
func _move_attacking_hands(offset: Vector3, rotation: Vector3, duration: float) -> void:
	var left_to: Vector3 = get_left_rest()
	var right_to: Vector3 = get_right_rest()
	var left_rot_to: Vector3 = _rest_rotation(true)
	var right_rot_to: Vector3 = _rest_rotation(false)
	if _use_left:
		left_to += _mirror(offset)
		left_rot_to += _mirror_rotation(rotation)
	if _use_right:
		right_to += offset
		right_rot_to += rotation
	_start_move(left_to, right_to, left_rot_to, right_rot_to, duration)
	_at_rest = false


func _start_move(left_to: Vector3, right_to: Vector3, left_rot_to: Vector3, right_rot_to: Vector3, duration: float) -> void:
	_left_from = _left_base
	_right_from = _right_base
	_left_to = left_to
	_right_to = right_to
	_left_rot_from = _left_rot
	_right_rot_from = _right_rot
	_left_rot_to = left_rot_to
	_right_rot_to = right_rot_to
	_move_time = 0.0
	_move_duration = duration
	if duration <= 0.0:
		_left_base = left_to
		_right_base = right_to
		_left_rot = left_rot_to
		_right_rot = right_rot_to
		_apply_rotations()
		_apply_positions()


func _mirror(offset: Vector3) -> Vector3:
	return Vector3(-offset.x, offset.y, offset.z)
