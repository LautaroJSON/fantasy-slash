class_name HarasserBehavior
extends EnemyBehavior
## Hostigador: circles the target at orbit_radius and strikes on an opening
## (the target shows its back, has just attacked, or max_patience ran out):
## a short windup and a lunge along a locked direction that stops
## stop_distance short of the target. Uses EnemyStats.attacks[0] as a
## LungeAttackData and EnemyStats.behavior_config as a HarasserConfig.
## See docs/specs/enemy-types.md.

enum Phase { ORBIT, WINDUP, LUNGE, RECOVERY }

var _phase: Phase = Phase.ORBIT
var _phase_time: float = 0.0
var _cooldown_left: float = 0.0
var _patience: float = 0.0
var _opening_left: float = 0.0
## 1 = counter-clockwise, -1 = clockwise (seen from above).
var _orbit_sign: float = 1.0
var _flip_left: float = 0.0
var _lunge_direction: Vector3 = Vector3.ZERO
var _lunge_length: float = 0.0
var _traveled: float = 0.0
var _has_hit: bool = false
## Player whose attack_performed signal is connected.
var _watched: Player = null


func reset() -> void:
	_phase = Phase.ORBIT
	_phase_time = 0.0
	_cooldown_left = 0.0
	_patience = 0.0
	_opening_left = 0.0
	_orbit_sign = 1.0 if randi() % 2 == 0 else -1.0
	_flip_left = _config().orbit_flip_time
	_has_hit = false
	_watch(enemy.target)


func is_attacking() -> bool:
	return _phase != Phase.ORBIT


func get_phase() -> Phase:
	return _phase


func knocked_back() -> void:
	if _phase == Phase.WINDUP and _attack().interruptible:
		_finish(false)


func physics_update(delta: float) -> void:
	var target: Player = enemy.target
	if target == null or target.health.is_dead():
		if is_attacking():
			_finish(false)
		enemy.stand_still(delta)
		return
	var attack: LungeAttackData = _attack()
	match _phase:
		Phase.ORBIT:
			_orbit(attack, delta)
		Phase.WINDUP:
			enemy.stand_still(delta)
			enemy.turn_towards(_offset_to_target(), deg_to_rad(attack.windup_turn_speed) * delta)
			enemy.get_telegraph().follow(enemy.global_position, enemy.get_facing())
			_phase_time += delta
			if _phase_time >= enemy.windup(attack.windup_time):
				_begin_lunge(attack)
		Phase.LUNGE:
			_lunge(attack, delta)
		Phase.RECOVERY:
			enemy.stand_still(delta)
			_phase_time += delta
			if _phase_time >= attack.recovery_time:
				_finish(true)


func _orbit(attack: LungeAttackData, delta: float) -> void:
	var config: HarasserConfig = _config()
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_opening_left = maxf(_opening_left - delta, 0.0)
	_patience += delta
	_flip_left -= delta
	var offset: Vector3 = _offset_to_target()
	var distance: float = offset.length()
	if _cooldown_left <= 0.0 and distance <= attack.trigger_range and _has_opening(offset) and enemy.can_start_attack():
		enemy.stand_still(delta)
		enemy.face(offset)
		_phase = Phase.WINDUP
		_phase_time = 0.0
		enemy.begin_attack()
		var planned: float = clampf(distance - attack.stop_distance, 0.0, attack.lunge_distance)
		enemy.get_telegraph().show_line(enemy.global_position, enemy.get_facing(), planned + attack.hit_range, attack.hit_range, enemy.windup(attack.windup_time))
		enemy.get_hands().play_windup(attack, enemy.windup(attack.windup_time))
		return
	if _flip_left <= 0.0:
		_flip()
	var inward: Vector3 = offset.normalized()
	var tangent: Vector3 = inward.cross(Vector3.UP) * _orbit_sign
	var radial: float = clampf(distance - config.orbit_radius, -1.0, 1.0)
	var direction: Vector3 = (tangent + inward * radial).normalized()
	enemy.move_with_velocity(direction * enemy.get_scaled_stats().move_speed, delta)
	enemy.face(offset)
	if enemy.hit_wall():
		_flip()


func _has_opening(offset: Vector3) -> bool:
	var config: HarasserConfig = _config()
	if _opening_left > 0.0 or _patience >= config.max_patience:
		return true
	return config.is_back_turned(enemy.target.get_facing(), -offset)


func _flip() -> void:
	_orbit_sign = -_orbit_sign
	_flip_left = _config().orbit_flip_time


func _begin_lunge(attack: LungeAttackData) -> void:
	var offset: Vector3 = _offset_to_target()
	_lunge_direction = enemy.get_facing()
	_lunge_length = clampf(offset.length() - attack.stop_distance, 0.0, attack.lunge_distance)
	_traveled = 0.0
	_has_hit = false
	_phase = Phase.LUNGE
	_phase_time = 0.0
	enemy.get_hands().play_strike(attack, _lunge_length / attack.lunge_speed)
	enemy.get_telegraph().flash(false)


## The last step is shortened so the lunge covers exactly its length.
func _lunge(attack: LungeAttackData, delta: float) -> void:
	var remaining: float = _lunge_length - _traveled
	var before: Vector3 = enemy.global_position
	enemy.move_with_velocity(_lunge_direction * minf(attack.lunge_speed, remaining / delta), delta)
	_traveled += Vector3(enemy.global_position.x - before.x, 0.0, enemy.global_position.z - before.z).length()
	var target: Player = enemy.target
	if not _has_hit and attack.is_hit(enemy.global_position, _lunge_direction, target.global_position, enemy.get_target_padding()):
		_has_hit = true
		target.health.receive_hit_from(enemy.get_scaled_stats().damage * attack.damage_multiplier, enemy)
	if _traveled >= _lunge_length - 0.001 or enemy.hit_wall():
		_phase = Phase.RECOVERY
		_phase_time = 0.0
		enemy.get_hands().return_to_rest()


func _finish(completed: bool) -> void:
	_phase = Phase.ORBIT
	_phase_time = 0.0
	_patience = 0.0
	_opening_left = 0.0
	enemy.get_hands().return_to_rest()
	enemy.end_attack()
	if not completed:
		enemy.get_telegraph().clear()
	if completed:
		_cooldown_left = enemy.get_scaled_stats().attack_interval


func _watch(player: Player) -> void:
	if _watched == player:
		return
	if _watched != null and _watched.attack_performed.is_connected(_on_attack_performed):
		_watched.attack_performed.disconnect(_on_attack_performed)
	_watched = player
	if _watched != null:
		_watched.attack_performed.connect(_on_attack_performed)


func _on_attack_performed() -> void:
	_opening_left = _config().opening_window


func _attack() -> LungeAttackData:
	return enemy.stats.attacks[0] as LungeAttackData


func _config() -> HarasserConfig:
	return enemy.stats.behavior_config as HarasserConfig


func _offset_to_target() -> Vector3:
	var offset: Vector3 = enemy.target.global_position - enemy.global_position
	return Vector3(offset.x, 0.0, offset.z)


## The lunge is shown as a line, not a sector.
func get_telegraph_arcs() -> Array[float]:
	return []


## A stun cancels the attack in progress, interruptible or not.
func stunned() -> void:
	if is_attacking():
		_finish(false)
