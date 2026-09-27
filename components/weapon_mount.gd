class_name WeaponMount
extends Node
## Keeps the class weapon in the humanoid's right hand
## (docs/specs/humanoid-player-model.md): whenever no ability, sweep or ability
## animation owns the weapon pivot, the pivot follows the hand at the weapon's
## grip offset. After an ability it blends back into the hand.

@export var player: Player
## The weapon pivot (Visual/SwordPivot); the weapon model hangs from it.
@export var pivot: Node3D
@export var humanoid: LowPolyHumanoid
@export var sword_swing: SwordSwing
## Ability animations that move the pivot (the SwingPlayer).
@export var swing_player: AnimationPlayer
@export var config: PlayerAnimationConfig

var _hand: Node3D = null
var _grip: Transform3D = Transform3D.IDENTITY
var _mounted: bool = false
var _blend_left: float = 0.0
var _blend_from: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	update(delta)


## Takes the grip offset of the class weapon and starts following the hand.
func setup(weapon: WeaponData) -> void:
	_hand = humanoid.get_right_hand()
	_grip = Transform3D(Basis.from_euler(weapon.grip_rotation), weapon.grip_position)
	_mounted = false
	set_process(true)


func update(delta: float) -> void:
	if not is_hand_free():
		_mounted = false
		return
	if not _mounted:
		_start_blend()
	pivot.global_transform = _blended_pose(delta)


## True when nothing else animates the weapon pivot.
func is_hand_free() -> bool:
	return not sword_swing.is_active() and not swing_player.is_playing() and not player.is_casting()


func is_mounted() -> bool:
	return _mounted


## Pivot pose that puts the weapon's grip in the hand (without the hand's scale).
func get_hand_pose() -> Transform3D:
	var pose: Transform3D = _hand.global_transform * _grip
	return Transform3D(pose.basis.orthonormalized(), pose.origin)


func _start_blend() -> void:
	_mounted = true
	_blend_from = pivot.global_transform
	_blend_left = config.weapon_mount_blend


func _blended_pose(delta: float) -> Transform3D:
	var target: Transform3D = get_hand_pose()
	if _blend_left <= 0.0:
		return target
	_blend_left = maxf(_blend_left - delta, 0.0)
	var weight: float = 1.0 - _blend_left / config.weapon_mount_blend
	return _blend_from.interpolate_with(target, weight)
