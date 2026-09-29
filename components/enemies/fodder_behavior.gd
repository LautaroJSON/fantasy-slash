class_name FodderBehavior
extends MeleeBehavior
## Esbirro: chases like the Bruto but takes no place on the ring. Without a
## token it walks to EnemyStats.behavior_config.swarm_distance (a FodderConfig)
## and waits there facing the player, so the horde bunches up around the
## player. Its tokens come from their own pool (EnemyStats.token_group).
## See docs/specs/fodder-minion.md.


## Waits at swarm_distance for a token of the fodder pool; with it, closes in
## on the player and attacks once in trigger range.
func _chase_in_turns(offset: Vector3, delta: float) -> void:
	var coordinator: AttackCoordinator = enemy.coordinator
	var distance: float = offset.length()
	var next: EnemyAttackData = _next_attack()
	var tolerance: float = coordinator.config.arrive_tolerance
	var swarm_distance: float = (enemy.stats.behavior_config as FodderConfig).swarm_distance
	var cleared: bool = coordinator.has_token(enemy)
	if not cleared and next != null and _cooldown_left <= 0.0 and distance <= swarm_distance + tolerance:
		cleared = enemy.can_start_attack()
	if cleared:
		if distance <= next.trigger_range:
			enemy.stand_still(delta)
			_face_target(offset, delta)
			_begin_windup(next)
		else:
			_approach(offset.normalized(), delta)
		return
	if distance > swarm_distance + tolerance:
		enemy.walk(offset.normalized(), delta)
	else:
		enemy.stand_still(delta)
	_face_target(offset, delta)
