class_name WeaponMount
extends Node
## Keeps the class weapon in the humanoid's right hand
## (docs/specs/humanoid-player-model.md): whenever no ability, sweep or ability
## animation owns the weapon pivot, the pivot follows the hand at the weapon's
## grip offset. After an ability it blends back into the hand. While held in the
## sheath (Sheathe charging, docs/specs/sheath-socket-hand-grip.md) the pivot
## follows the scabbard socket instead, before anything else.

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
## Socket on the torso the scabbard hangs from; null without a scabbard.
var _sheath_socket: Node3D = null
var _in_sheath: bool = false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	update(delta)


## Takes the grip offset of the class weapon and its scabbard socket (or null),
## and starts following the hand.
func setup(weapon: WeaponData, sheath_socket: Node3D) -> void:
	_sheath_socket = sheath_socket
	_in_sheath = false
	_hand = humanoid.get_right_hand()
	_grip = Transform3D(Basis.from_euler(weapon.grip_rotation), weapon.grip_position)
	_mounted = false
	if not humanoid.anim.mixer_applied.is_connected(_on_mixer_applied):
		humanoid.anim.mixer_applied.connect(_on_mixer_applied)
	set_process(true)


## Places the weapon pivot, then brings the hands back onto their targets on
## the weapon (the animation placed them before the weapon moved this frame).
func update(delta: float) -> void:
	_update_pivot(delta)
	humanoid.refresh_hand_targets()


func _update_pivot(delta: float) -> void:
	if _in_sheath and _sheath_socket != null:
		_mounted = false
		pivot.global_transform = get_sheath_pose()
		return
	if not is_hand_free():
		_mounted = false
		return
	if not _mounted:
		_start_blend()
	pivot.global_transform = _blended_pose(delta)


## Holds the weapon in its scabbard (true) or lets it go (false).
func hold_in_sheath(held: bool) -> void:
	_in_sheath = held
	if held and _sheath_socket != null:
		pivot.global_transform = get_sheath_pose()


func is_holding_in_sheath() -> bool:
	return _in_sheath


## Pivot pose of the weapon sheathed: the scabbard socket, without scale.
func get_sheath_pose() -> Transform3D:
	var pose: Transform3D = _sheath_socket.global_transform
	return Transform3D(pose.basis.orthonormalized(), pose.origin)


## True when nothing else animates the weapon pivot. A cast that keeps the
## weapon in the hand (Sheathe's release, docs/specs/sheathe-release-animation.md)
## leaves it to the hand.
func is_hand_free() -> bool:
	if sword_swing.is_active() or swing_player.is_playing():
		return false
	return not player.is_casting() or player.is_weapon_in_hand_cast()


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


## The torso has just been animated this frame: a sheathed weapon follows it
## without a frame of lag.
func _on_mixer_applied() -> void:
	if _in_sheath and _sheath_socket != null:
		pivot.global_transform = get_sheath_pose()
