class_name KingBehavior
extends BossBehavior
## El Rey (docs/specs/boss-king.md): a BossBehavior with two moves of its own,
## both on the ground. ThrustMoveData is a lunge with the point forward along a
## line locked at the end of the windup (a chain of them in phase 2), and
## SweepMoveData is a 360° spin that cannot be jumped (its clear_height is huge).
## The combos (the slashes and the Judgment) and the ring (the Oath) are the
## base class's. Uses EnemyStats.behavior_config as a BossConfig.

enum KingStage { WINDUP, LUNGE, CHAIN_WAIT, ACTIVE }

var _king_stage: KingStage = KingStage.WINDUP
var _thrusts_left: int = 0
var _thrust_direction: Vector3 = Vector3.FORWARD
var _thrust_length: float = 0.0
var _thrust_traveled: float = 0.0


func reset() -> void:
	super.reset()
	_thrusts_left = 0


func get_king_stage() -> KingStage:
	return _king_stage


## Direction of the thrust in progress (locked when its windup ends).
func get_thrust_direction() -> Vector3:
	return _thrust_direction


## Thrusts still to go in the move in progress, the current one included.
func get_thrusts_left() -> int:
	return _thrusts_left


func _begin_other_move(move: BossMoveData) -> void:
	if move is ThrustMoveData:
		var thrust: ThrustMoveData = move as ThrustMoveData
		_thrusts_left = thrust.thrusts(_boss_phase)
		_begin_thrust_windup(thrust, thrust.attack.windup_time)
	elif move is SweepMoveData:
		var sweep: SweepMoveData = move as SweepMoveData
		_king_stage = KingStage.WINDUP
		_has_hit = false
		var windup: float = _windup(sweep.attack.windup_time)
		enemy.get_hands().play_windup(sweep.attack, windup)
		enemy.get_telegraph().show_sector(enemy.global_position, enemy.get_facing(), sweep.attack.hit_range, sweep.attack.hit_arc_degrees, windup)
	else:
		_finish_move()


func _update_other_move(delta: float) -> void:
	var move: BossMoveData = _config().moves[_move_index]
	if move is ThrustMoveData:
		_update_thrust(move as ThrustMoveData, delta)
	elif move is SweepMoveData:
		_update_spin(move as SweepMoveData, delta)
	else:
		_finish_move()


# --- Thrust ------------------------------------------------------------------

func _begin_thrust_windup(thrust: ThrustMoveData, seconds: float) -> void:
	_king_stage = KingStage.WINDUP
	_time = 0.0
	_has_hit = false
	var windup: float = _windup(seconds)
	enemy.get_hands().play_windup(thrust.attack, windup)
	var planned: float = thrust.lunge_length(_offset_to_target().length())
	enemy.get_telegraph().show_line(enemy.global_position, enemy.get_facing(), planned + thrust.attack.hit_range, thrust.line_width, windup)


func _update_thrust(thrust: ThrustMoveData, delta: float) -> void:
	_time += delta
	match _king_stage:
		KingStage.WINDUP:
			enemy.stand_still(delta)
			enemy.turn_towards(_offset_to_target(), deg_to_rad(thrust.attack.windup_turn_speed) * delta)
			enemy.get_telegraph().follow(enemy.global_position, enemy.get_facing())
			if _time >= _windup(thrust.attack.windup_time if _thrusts_left == thrust.thrusts(_boss_phase) else thrust.chain_windup_time):
				_king_stage = KingStage.LUNGE
				_thrust_direction = enemy.get_facing()
				_thrust_length = thrust.lunge_length(_offset_to_target().length())
				_thrust_traveled = 0.0
				enemy.get_hands().play_strike(thrust.attack, maxf(_thrust_length / thrust.thrust_speed, 0.05))
				enemy.get_telegraph().flash(false)
		KingStage.LUNGE:
			var remaining: float = _thrust_length - _thrust_traveled
			var before: Vector3 = enemy.global_position
			enemy.move_with_velocity(_thrust_direction * minf(thrust.thrust_speed, remaining / delta), delta)
			_thrust_traveled += Vector2(enemy.global_position.x - before.x, enemy.global_position.z - before.z).length()
			_try_thrust_hit(thrust)
			if _thrust_traveled >= _thrust_length - 0.001 or enemy.hit_wall():
				_end_thrust(thrust)
		KingStage.CHAIN_WAIT:
			enemy.stand_still(delta)
			if _time >= thrust.chain_delay:
				_begin_thrust_windup(thrust, thrust.chain_windup_time)


## One hit per thrust: a target that dashes through is spared the rest of it.
func _try_thrust_hit(thrust: ThrustMoveData) -> void:
	var target: Player = enemy.target
	if _has_hit or not thrust.attack.is_hit(enemy.global_position, _thrust_direction, target.global_position, enemy.get_target_padding()):
		return
	_has_hit = true
	target.health.receive_hit_from(enemy.get_scaled_stats().damage * thrust.attack.damage_multiplier, enemy)


func _end_thrust(thrust: ThrustMoveData) -> void:
	_thrusts_left -= 1
	if _thrusts_left > 0:
		_king_stage = KingStage.CHAIN_WAIT
		_time = 0.0
		return
	_begin_recovery(_scaled(thrust.attack.recovery_time))


# --- Spin --------------------------------------------------------------------

func _update_spin(sweep: SweepMoveData, delta: float) -> void:
	enemy.stand_still(delta)
	_time += delta
	match _king_stage:
		KingStage.WINDUP:
			var windup: float = _windup(sweep.attack.windup_time)
			enemy.turn_towards(_offset_to_target(), deg_to_rad(sweep.attack.windup_turn_speed) * delta)
			enemy.get_telegraph().follow(enemy.global_position, enemy.get_facing())
			if _time >= windup:
				_time -= windup
				_king_stage = KingStage.ACTIVE
				enemy.get_hands().play_strike(sweep.attack, sweep.attack.active_time)
				enemy.get_telegraph().flash(false)
		KingStage.ACTIVE:
			var target: Player = enemy.target
			if not _has_hit and sweep.is_hit(enemy.global_position, enemy.get_facing(), target.global_position, enemy.get_target_padding()):
				_has_hit = true
				target.health.receive_hit_from(enemy.get_scaled_stats().damage * sweep.attack.damage_multiplier, enemy)
			if _time >= sweep.attack.active_time:
				_begin_recovery(_scaled(sweep.attack.recovery_time))


## Sector warnings: the combos plus the arc of the spin.
func get_telegraph_arcs() -> Array[float]:
	var arcs: Array[float] = super.get_telegraph_arcs()
	for move: BossMoveData in _config().moves:
		var sweep: SweepMoveData = move as SweepMoveData
		if sweep != null:
			arcs.append(sweep.attack.hit_arc_degrees)
	return arcs
