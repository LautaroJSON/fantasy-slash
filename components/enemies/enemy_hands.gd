class_name EnemyHands
extends Node3D
## The two floating hands of an enemy: they bob at rest, pull back during a
## windup and shoot forward on the strike (docs/specs/enemy-attack-telegraph.md).
## Offsets are local to the enemy; this node scales with its body_scale.
## Bosses may also move, hide, resize and shake one hand on its own
## (docs/specs/boss-titan.md).

@export var config: EnemyHandsConfig

var _left_from: Vector3 = Vector3.ZERO
var _right_from: Vector3 = Vector3.ZERO
var _left_to: Vector3 = Vector3.ZERO
var _right_to: Vector3 = Vector3.ZERO
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
	_left_base = get_left_rest()
	_right_base = get_right_rest()
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


## Radius of one hand sphere in world units (mesh radius × its global scale).
func get_hand_radius(left: bool) -> float:
	var hand: MeshInstance3D = _left if left else _right
	return (hand.mesh as SphereMesh).radius * hand.global_basis.x.length()


## The attacking hands pull back to hand_windup_offset over `duration`.
func play_windup(attack: EnemyAttackData, duration: float) -> void:
	_pick_hands(attack.hands)
	_move_attacking_hands(attack.hand_windup_offset, duration)


## The attacking hands (chosen by play_windup) shoot to hand_strike_offset.
func play_strike(attack: EnemyAttackData, duration: float) -> void:
	_move_attacking_hands(attack.hand_strike_offset, duration)


## Any other held pose (guard down, airborne, stunned): both hands go to their
## rest pose plus `offset` (the left one mirrored) and stay there.
func play_pose(offset: Vector3, duration: float) -> void:
	_use_left = true
	_use_right = true
	_move_attacking_hands(offset, duration)


## Moves one hand to `local_position` (this node's space); the other one stays.
func move_hand(left: bool, local_position: Vector3, duration: float) -> void:
	if left:
		_start_move(local_position, _right_base, duration)
	else:
		_start_move(_left_base, local_position, duration)
	_at_rest = false


func is_at_rest() -> bool:
	return _at_rest


func return_to_rest() -> void:
	_start_move(get_left_rest(), get_right_rest(), config.return_time)
	_at_rest = true
	# The bob restarts at 0, where the return ends.
	_bob_time = 0.0


func advance(delta: float) -> void:
	_left_shake_left = maxf(_left_shake_left - delta, 0.0)
	_right_shake_left = maxf(_right_shake_left - delta, 0.0)
	if _move_time < _move_duration:
		_move_time = minf(_move_time + delta, _move_duration)
		var weight: float = smoothstep(0.0, 1.0, _move_time / _move_duration)
		_left_base = _left_from.lerp(_left_to, weight)
		_right_base = _right_from.lerp(_right_to, weight)
	elif _at_rest:
		_bob_time += delta
		var bob: float = sin(_bob_time * TAU * config.bob_frequency) * config.bob_amplitude
		_left_base = get_left_rest() + Vector3.UP * bob
		_right_base = get_right_rest() - Vector3.UP * bob
	_apply_positions()


func _apply_positions() -> void:
	_left.position = _left_base + _shake_offset(_left_shake_left, _left_shake_amount, 0.0)
	_right.position = _right_base + _shake_offset(_right_shake_left, _right_shake_amount, PI)


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
func _move_attacking_hands(offset: Vector3, duration: float) -> void:
	var left_to: Vector3 = get_left_rest()
	var right_to: Vector3 = get_right_rest()
	if _use_left:
		left_to += _mirror(offset)
	if _use_right:
		right_to += offset
	_start_move(left_to, right_to, duration)
	_at_rest = false


func _start_move(left_to: Vector3, right_to: Vector3, duration: float) -> void:
	_left_from = _left_base
	_right_from = _right_base
	_left_to = left_to
	_right_to = right_to
	_move_time = 0.0
	_move_duration = duration
	if duration <= 0.0:
		_left_base = left_to
		_right_base = right_to
		_apply_positions()


func _mirror(offset: Vector3) -> Vector3:
	return Vector3(-offset.x, offset.y, offset.z)
