class_name ChargerBehavior
extends EnemyBehavior
## Embestidor: keeps between min_trigger_range and trigger_range of the target,
## winds up (turning slowly), locks the direction and charges in a straight
## line for charge_distance. The charge hits once; running into a wall stuns
## it for wall_stun_time. Uses EnemyStats.attacks[0] as a ChargeAttackData.
## See docs/specs/enemy-types.md.

enum Phase { CHASE, WINDUP, CHARGE, RECOVERY }

var _phase: Phase = Phase.CHASE
var _phase_time: float = 0.0
var _cooldown_left: float = 0.0
var _charge_direction: Vector3 = Vector3.ZERO
var _traveled: float = 0.0
var _recovery_duration: float = 0.0
var _has_hit: bool = false
var _hit_wall: bool = false


func reset() -> void:
	_phase = Phase.CHASE
	_phase_time = 0.0
	_cooldown_left = 0.0
	_traveled = 0.0
	_has_hit = false
	_hit_wall = false


func is_attacking() -> bool:
	return _phase != Phase.CHASE


func get_phase() -> Phase:
	return _phase


## True when the last charge ended against a wall.
func ended_on_wall() -> bool:
	return _hit_wall


func get_traveled() -> float:
	return _traveled


## Knockback never interrupts it and cannot stop a charge.
func resists_knockback(_direction: Vector3) -> bool:
	return _phase == Phase.CHARGE


func physics_update(delta: float) -> void:
	var target: Player = enemy.target
	if target == null or target.health.is_dead():
		if is_attacking() and _phase != Phase.CHARGE:
			_finish(false)
		if _phase != Phase.CHARGE:
			enemy.stand_still(delta)
			return
	var attack: ChargeAttackData = _attack()
	match _phase:
		Phase.CHASE:
			_chase(attack, delta)
		Phase.WINDUP:
			enemy.stand_still(delta)
			enemy.turn_towards(_offset_to_target(), deg_to_rad(attack.windup_turn_speed) * delta)
			enemy.get_telegraph().follow(enemy.global_position, enemy.get_facing())
			_phase_time += delta
			if _phase_time >= enemy.windup(attack.windup_time):
				_begin_charge(attack)
		Phase.CHARGE:
			_charge(attack, delta)
		Phase.RECOVERY:
			enemy.stand_still(delta)
			_phase_time += delta
			if _phase_time >= _recovery_duration:
				_finish(true)


func _chase(attack: ChargeAttackData, delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var offset: Vector3 = _offset_to_target()
	var distance: float = offset.length()
	var speed: float = enemy.get_scaled_stats().move_speed
	if distance < attack.min_trigger_range:
		enemy.move_with_velocity(-offset.normalized() * speed, delta)
		enemy.face(offset)
	elif _cooldown_left <= 0.0 and distance <= attack.trigger_range and enemy.can_start_attack():
		enemy.stand_still(delta)
		enemy.face(offset)
		_phase = Phase.WINDUP
		_phase_time = 0.0
		enemy.begin_attack()
		enemy.get_telegraph().show_line(enemy.global_position, enemy.get_facing(), attack.charge_distance + attack.hit_range, 2.0 * attack.hit_range, enemy.windup(attack.windup_time))
		enemy.get_hands().play_windup(attack, enemy.windup(attack.windup_time))
	elif distance > enemy.get_scaled_stats().attack_range:
		enemy.move_towards(offset.normalized(), delta)
	else:
		enemy.stand_still(delta)
		enemy.face(offset)


func _begin_charge(attack: ChargeAttackData) -> void:
	_phase = Phase.CHARGE
	_charge_direction = enemy.get_facing()
	_traveled = 0.0
	_has_hit = false
	_hit_wall = false
	enemy.get_hands().play_strike(attack, attack.active_time)
	enemy.get_telegraph().flash(false)


## The last step is shortened so the charge never exceeds charge_distance.
func _charge(attack: ChargeAttackData, delta: float) -> void:
	var remaining: float = attack.charge_distance - _traveled
	var speed: float = minf(attack.charge_speed, remaining / delta)
	var before: Vector3 = enemy.global_position
	enemy.move_with_velocity(_charge_direction * speed, delta)
	var step := Vector3(enemy.global_position.x - before.x, 0.0, enemy.global_position.z - before.z)
	_traveled += step.length()
	_try_hit(attack)
	if enemy.hit_wall():
		_hit_wall = true
		_begin_recovery(attack.wall_stun_time, attack)
	elif _traveled >= attack.charge_distance - 0.001:
		_begin_recovery(attack.recovery_time, attack)


func _try_hit(attack: ChargeAttackData) -> void:
	var target: Player = enemy.target
	if _has_hit or target == null or target.health.is_dead():
		return
	if attack.is_hit(enemy.global_position, _charge_direction, target.global_position, enemy.get_target_padding()):
		_has_hit = true
		target.health.receive_hit_from(enemy.get_scaled_stats().damage * attack.damage_multiplier, enemy)


func _begin_recovery(duration: float, attack: ChargeAttackData) -> void:
	_phase = Phase.RECOVERY
	_phase_time = 0.0
	_recovery_duration = duration
	enemy.get_hands().play_pose(attack.stun_hand_offset, enemy.get_hands().config.return_time, &"stunned")


func _finish(completed: bool) -> void:
	_phase = Phase.CHASE
	_phase_time = 0.0
	enemy.get_hands().return_to_rest()
	enemy.end_attack()
	if not completed:
		enemy.get_telegraph().clear()
	if completed:
		_cooldown_left = enemy.get_scaled_stats().attack_interval


func _attack() -> ChargeAttackData:
	return enemy.stats.attacks[0] as ChargeAttackData


func _offset_to_target() -> Vector3:
	var offset: Vector3 = enemy.target.global_position - enemy.global_position
	return Vector3(offset.x, 0.0, offset.z)


## The charge is shown as a line, not a sector.
func get_telegraph_arcs() -> Array[float]:
	return []


## A stun cancels the attack in progress, interruptible or not.
func stunned() -> void:
	if is_attacking():
		_finish(false)
