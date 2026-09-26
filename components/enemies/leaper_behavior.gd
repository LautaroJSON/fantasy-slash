class_name LeaperBehavior
extends EnemyBehavior
## Saltador: keeps between min_trigger_range and trigger_range of the target,
## crouches (windup), locks the landing point (the target's position, at most
## max_leap_distance away) and jumps there. Landing hits a circle once.
## Uses EnemyStats.attacks[0] as a LeapAttackData.
## See docs/specs/enemy-types.md.

enum Phase { CHASE, WINDUP, AIRBORNE, RECOVERY }

var _phase: Phase = Phase.CHASE
var _phase_time: float = 0.0
var _cooldown_left: float = 0.0
var _leap_velocity: Vector3 = Vector3.ZERO
var _landing_point: Vector3 = Vector3.ZERO
var _left_ground: bool = false


func reset() -> void:
	_phase = Phase.CHASE
	_phase_time = 0.0
	_cooldown_left = 0.0
	_left_ground = false


func is_attacking() -> bool:
	return _phase != Phase.CHASE


func get_phase() -> Phase:
	return _phase


func get_landing_point() -> Vector3:
	return _landing_point


## A windup is cancelled by a push; in the air it cannot be pushed.
func knocked_back() -> void:
	if _phase == Phase.WINDUP and _attack().interruptible:
		_finish(false)


func resists_knockback(_direction: Vector3) -> bool:
	return _phase == Phase.AIRBORNE


func physics_update(delta: float) -> void:
	var target: Player = enemy.target
	if (target == null or target.health.is_dead()) and _phase != Phase.AIRBORNE:
		if is_attacking():
			_finish(false)
		enemy.stand_still(delta)
		return
	var attack: LeapAttackData = _attack()
	match _phase:
		Phase.CHASE:
			_chase(attack, delta)
		Phase.WINDUP:
			enemy.stand_still(delta)
			enemy.turn_towards(_offset_to_target(), deg_to_rad(attack.windup_turn_speed) * delta)
			enemy.get_telegraph().move_center(_target_floor_point())
			_phase_time += delta
			if _phase_time >= enemy.windup(attack.windup_time):
				_launch(attack)
		Phase.AIRBORNE:
			_fly(attack, delta)
		Phase.RECOVERY:
			enemy.stand_still(delta)
			_phase_time += delta
			if _phase_time >= attack.recovery_time:
				_finish(true)


func _chase(attack: LeapAttackData, delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var offset: Vector3 = _offset_to_target()
	var distance: float = offset.length()
	if distance < attack.min_trigger_range:
		enemy.move_with_velocity(-offset.normalized() * enemy.get_scaled_stats().move_speed, delta)
		enemy.face(offset)
	elif _cooldown_left <= 0.0 and distance <= attack.trigger_range and enemy.can_start_attack():
		enemy.stand_still(delta)
		enemy.face(offset)
		_phase = Phase.WINDUP
		_phase_time = 0.0
		enemy.begin_attack()
		enemy.get_telegraph().show_circle(_target_floor_point(), attack.hit_range, enemy.windup(attack.windup_time) + attack.leap_time)
		enemy.get_hands().play_windup(attack, enemy.windup(attack.windup_time))
	elif distance > enemy.get_scaled_stats().attack_range:
		enemy.move_towards(offset.normalized(), delta)
	else:
		enemy.stand_still(delta)
		enemy.face(offset)


## Landing point: the target now, clamped to max_leap_distance.
func _launch(attack: LeapAttackData) -> void:
	var offset: Vector3 = _offset_to_target().limit_length(attack.max_leap_distance)
	_landing_point = enemy.global_position + offset
	enemy.get_telegraph().move_center(_landing_point)
	_leap_velocity = offset / attack.leap_time
	enemy.face(offset)
	enemy.launch(attack.get_launch_speed(), attack.get_leap_gravity() / enemy.get_gravity_strength())
	enemy.get_hands().play_pose(attack.air_hand_offset, attack.leap_time * 0.25)
	_phase = Phase.AIRBORNE
	_phase_time = 0.0
	_left_ground = false


## Lands when it touches the floor again (or after twice leap_time, in case
## something holds it in the air).
func _fly(attack: LeapAttackData, delta: float) -> void:
	enemy.move_with_velocity(_leap_velocity, delta)
	_phase_time += delta
	if enemy.is_airborne():
		_left_ground = true
		if _phase_time < attack.leap_time * 2.0:
			return
	elif not _left_ground:
		return
	_slam(attack)


func _slam(attack: LeapAttackData) -> void:
	var target: Player = enemy.target
	if target != null and not target.health.is_dead():
		if attack.is_hit(enemy.global_position, enemy.get_facing(), target.global_position, enemy.get_target_padding()):
			target.health.receive_hit(enemy.get_scaled_stats().damage * attack.damage_multiplier)
	enemy.get_hands().play_strike(attack, attack.active_time)
	enemy.get_telegraph().flash(true)
	_phase = Phase.RECOVERY
	_phase_time = 0.0


func _finish(completed: bool) -> void:
	_phase = Phase.CHASE
	_phase_time = 0.0
	enemy.get_hands().return_to_rest()
	enemy.end_attack()
	if not completed:
		enemy.get_telegraph().clear()
	if completed:
		_cooldown_left = enemy.get_scaled_stats().attack_interval


func _attack() -> LeapAttackData:
	return enemy.stats.attacks[0] as LeapAttackData


func _offset_to_target() -> Vector3:
	var offset: Vector3 = enemy.target.global_position - enemy.global_position
	return Vector3(offset.x, 0.0, offset.z)


## The target on the floor (the enemy's height), for the landing circle.
func _target_floor_point() -> Vector3:
	var point: Vector3 = enemy.target.global_position
	return Vector3(point.x, enemy.global_position.y, point.z)


## The landing circle is not a sector.
func get_telegraph_arcs() -> Array[float]:
	return []
