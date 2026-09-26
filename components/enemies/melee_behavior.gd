class_name MeleeBehavior
extends EnemyBehavior
## Chases the target and hits it with telegraphed attacks from EnemyStats.attacks
## (cycled in order): CHASE → WINDUP → ACTIVE → RECOVERY → CHASE, with
## attack_interval seconds of cooldown before the next windup.
## See docs/specs/enemy-attack-telegraph.md.

enum Phase { CHASE, WINDUP, ACTIVE, RECOVERY }

var _phase: Phase = Phase.CHASE
var _phase_time: float = 0.0
var _cooldown_left: float = 0.0
var _attack_index: int = 0
var _attack: EnemyAttackData = null
var _has_hit: bool = false
## Seconds until the place on the ring is chosen again.
var _slot_timer: float = 0.0


func reset() -> void:
	_slot_timer = 0.0
	_phase = Phase.CHASE
	_phase_time = 0.0
	_cooldown_left = 0.0
	_attack_index = 0
	_attack = null
	_has_hit = false


func is_attacking() -> bool:
	return _phase != Phase.CHASE


func get_phase() -> Phase:
	return _phase


func knocked_back() -> void:
	if _phase == Phase.WINDUP and _attack.interruptible:
		_end_attack(false)


func physics_update(delta: float) -> void:
	var target: Player = enemy.target
	if target == null or target.health.is_dead():
		if is_attacking():
			_end_attack(false)
		enemy.stand_still(delta)
		return
	var offset: Vector3 = target.global_position - enemy.global_position
	offset.y = 0.0
	match _phase:
		Phase.CHASE:
			_chase(offset, delta)
		Phase.WINDUP:
			enemy.stand_still(delta)
			enemy.turn_towards(offset, deg_to_rad(_attack.windup_turn_speed) * delta)
			enemy.get_telegraph().follow(enemy.global_position, enemy.get_facing())
			_advance(delta)
		Phase.ACTIVE, Phase.RECOVERY:
			enemy.stand_still(delta)
			_advance(delta)
	if _phase == Phase.ACTIVE:
		_try_hit(target)


func _chase(offset: Vector3, delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if enemy.uses_attack_tokens():
		_chase_in_turns(offset, delta)
		return
	var distance: float = offset.length()
	var next: EnemyAttackData = _next_attack()
	if next != null and _cooldown_left <= 0.0 and distance <= next.trigger_range:
		enemy.stand_still(delta)
		_face_target(offset, delta)
		_begin_windup(next)
	elif distance > enemy.get_scaled_stats().attack_range:
		_approach(offset.normalized(), delta)
	else:
		enemy.stand_still(delta)
		_face_target(offset, delta)


## With attack turns (docs/specs/enemy-group-ai.md): wait on a place of the
## ring at wait distance asking for a token; with it, close in on the place at
## attack_range and attack once in trigger range.
func _chase_in_turns(offset: Vector3, delta: float) -> void:
	var coordinator: AttackCoordinator = enemy.coordinator
	var distance: float = offset.length()
	var next: EnemyAttackData = _next_attack()
	var attack_range: float = enemy.get_scaled_stats().attack_range
	var wait_distance: float = coordinator.get_wait_distance(attack_range)
	var tolerance: float = coordinator.config.arrive_tolerance
	var cleared: bool = coordinator.has_token(enemy)
	if not cleared and next != null and _cooldown_left <= 0.0 and distance <= wait_distance + tolerance:
		cleared = enemy.can_start_attack()
	if cleared:
		if distance <= next.trigger_range:
			enemy.stand_still(delta)
			_face_target(offset, delta)
			_begin_windup(next)
		else:
			_approach(offset.normalized(), delta)
		return
	_slot_timer -= delta
	if _slot_timer <= 0.0 or coordinator.get_slot(enemy) < 0:
		_slot_timer = coordinator.config.slot_refresh_time
		coordinator.claim_slot(enemy)
	var goal: Vector3 = _ring_goal(offset, wait_distance)
	if goal.length() > tolerance:
		enemy.walk(goal.normalized(), delta)
	else:
		enemy.stand_still(delta)
	_face_target(offset, delta)


## Flat offset from the enemy to its place on the ring of `radius`. Without a
## free place it waits one step farther out on its current bearing.
func _ring_goal(offset: Vector3, radius: float) -> Vector3:
	var coordinator: AttackCoordinator = enemy.coordinator
	var slot: int = coordinator.get_slot(enemy)
	var point: Vector3
	if slot >= 0:
		point = coordinator.slot_position(slot, radius)
	else:
		point = enemy.target.global_position - offset.normalized() * (radius + coordinator.config.overflow_step)
	var goal: Vector3 = point - enemy.global_position
	return Vector3(goal.x, 0.0, goal.z)


## Walks towards the target (subclasses may turn more slowly).
func _approach(direction: Vector3, delta: float) -> void:
	enemy.move_towards(direction, delta)


## Faces the target while not attacking (subclasses may turn more slowly).
func _face_target(offset: Vector3, _delta: float) -> void:
	enemy.face(offset)


func _next_attack() -> EnemyAttackData:
	var attacks: Array[EnemyAttackData] = enemy.stats.attacks
	if attacks.is_empty():
		return null
	return attacks[_attack_index % attacks.size()]


func _begin_windup(attack: EnemyAttackData) -> void:
	_attack = attack
	_phase = Phase.WINDUP
	_phase_time = 0.0
	_has_hit = false
	enemy.begin_attack()
	enemy.get_hands().play_windup(attack, enemy.windup(attack.windup_time))
	enemy.get_telegraph().show_sector(enemy.global_position, enemy.get_facing(), attack.hit_range, attack.hit_arc_degrees, enemy.windup(attack.windup_time))


## Windup → active and recovery → chase. Active → recovery happens in
## _try_hit(), so the last active frame still checks the hit.
func _advance(delta: float) -> void:
	_phase_time += delta
	if _phase == Phase.WINDUP and _phase_time >= enemy.windup(_attack.windup_time):
		_phase_time -= enemy.windup(_attack.windup_time)
		_phase = Phase.ACTIVE
		enemy.get_hands().play_strike(_attack, _attack.active_time)
		enemy.get_telegraph().flash(false)
	elif _phase == Phase.RECOVERY and _phase_time >= _attack.recovery_time:
		_end_attack(true)


func _begin_recovery() -> void:
	_phase = Phase.RECOVERY
	enemy.get_hands().return_to_rest()


## One hit per attack. A dodge with iframes (0 damage) also uses up the hit.
func _try_hit(target: Player) -> void:
	if not _has_hit and _attack.is_hit(enemy.global_position, enemy.get_facing(), target.global_position, enemy.get_target_padding()):
		_has_hit = true
		target.health.receive_hit(enemy.get_scaled_stats().damage * _attack.damage_multiplier)
	if _phase_time >= _attack.active_time:
		_phase_time -= _attack.active_time
		_begin_recovery()


## `completed` attacks start the cooldown and move on to the next attack;
## cancelled ones (interrupted windup, target lost) may start again at once.
func _end_attack(completed: bool) -> void:
	if _phase != Phase.RECOVERY:
		enemy.get_hands().return_to_rest()
	_phase = Phase.CHASE
	_phase_time = 0.0
	_attack = null
	enemy.end_attack()
	if not completed:
		enemy.get_telegraph().clear()
	if completed:
		_cooldown_left = enemy.get_scaled_stats().attack_interval
		_attack_index += 1
