class_name HeldInputGuard
extends RefCounted
## Ignores gameplay actions that were already held when the game resumed from a
## pause, until they are released. Keeps the button that closed a menu (B also
## dashes, A also jumps) from triggering its gameplay action on the first frame
## back (docs/specs/gamepad-support.md).

var _actions: Array[StringName] = []
## Blocked action -> physics frame it was blocked on.
var _blocked: Dictionary[StringName, int] = {}
var _last_frame: int = -1


func _init(actions: Array[StringName]) -> void:
	_actions.assign(actions)


## Called first thing every physics frame with Engine.get_physics_frames().
## A skipped frame means the owner was paused in between.
func update(physics_frame: int) -> void:
	if _last_frame >= 0 and physics_frame > _last_frame + 1:
		_block_held(physics_frame)
	_unblock_released(physics_frame)
	_last_frame = physics_frame


func is_just_pressed(action: StringName) -> bool:
	return not is_blocked(action) and Input.is_action_just_pressed(action)


func is_pressed(action: StringName) -> bool:
	return not is_blocked(action) and Input.is_action_pressed(action)


func is_blocked(action: StringName) -> bool:
	return _blocked.has(action)


func _block_held(physics_frame: int) -> void:
	for action: StringName in _actions:
		if Input.is_action_pressed(action) or Input.is_action_just_pressed(action):
			_blocked[action] = physics_frame


## Actions blocked on this frame stay blocked for it even if already released
## (a tap that both pressed and released while paused).
func _unblock_released(physics_frame: int) -> void:
	for action: StringName in _actions:
		if _blocked.has(action) and _blocked[action] < physics_frame and not Input.is_action_pressed(action):
			_blocked.erase(action)
