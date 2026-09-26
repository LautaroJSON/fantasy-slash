class_name ShieldbearerBehavior
extends MeleeBehavior
## Escudero: a MeleeBehavior that keeps its guard up while it is not attacking.
## With the guard up it turns slowly (guard_turn_speed) and hits and pushes
## coming from inside block_arc are reduced / ignored. The guard drops from
## the windup until guard_down_time after the recovery.
## See docs/specs/enemy-types.md.

var _guard_down_left: float = 0.0
var _guard_was_up: bool = true


func reset() -> void:
	super.reset()
	_guard_down_left = 0.0
	_guard_was_up = true
	enemy.health.damage_reduction = 0.0


func physics_update(delta: float) -> void:
	var was_attacking: bool = is_attacking()
	super.physics_update(delta)
	if was_attacking and not is_attacking():
		_guard_down_left = _guard().guard_down_time
	elif not is_attacking():
		_guard_down_left = maxf(_guard_down_left - delta, 0.0)
	_update_guard()


func is_guarding() -> bool:
	return not is_attacking() and _guard_down_left <= 0.0


func resists_knockback(direction: Vector3) -> bool:
	# `direction` points away from the pusher, so the pusher lies along −direction.
	return is_guarding() and _guard().blocks(enemy.get_facing(), -direction)


func _approach(direction: Vector3, delta: float) -> void:
	enemy.walk(direction, delta)
	_face_target(direction, delta)


func _face_target(offset: Vector3, delta: float) -> void:
	enemy.turn_towards(offset, deg_to_rad(_guard().guard_turn_speed) * delta)


## Blocks with the target in front while guarding; hands in guard (rest) or
## lowered to the sides while the guard is down.
func _update_guard() -> void:
	var guarding: bool = is_guarding()
	var blocking: bool = false
	if guarding and enemy.target != null:
		var to_target: Vector3 = enemy.target.global_position - enemy.global_position
		blocking = _guard().blocks(enemy.get_facing(), Vector3(to_target.x, 0.0, to_target.z))
	enemy.health.damage_reduction = _guard().block_reduction if blocking else 0.0
	var hands: EnemyHands = enemy.get_hands()
	if guarding and not _guard_was_up:
		hands.return_to_rest()
	elif not guarding and hands.is_at_rest():
		hands.play_pose(_guard().guard_down_offset, hands.config.return_time)
	_guard_was_up = guarding


func _guard() -> GuardConfig:
	return enemy.stats.behavior_config as GuardConfig
