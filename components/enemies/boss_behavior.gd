class_name BossBehavior
extends EnemyBehavior
## A boss with a repertoire of moves (docs/specs/boss-verdugo.md): between moves
## it closes in for attack_interval, then BossMoveTable picks the next move by
## distance (never the same one twice in a row when there is another). Moves:
## ComboMoveData (a chain of telegraphed hits, stepping forward before each),
## ShockwaveMoveData (floor rings to jump or dash through) and GrabMoveData (a
## lunge that holds the target, then slams it). At phase_two.health_threshold
## it stops once, invulnerable, and comes back faster (phase 2).
## Uses EnemyStats.behavior_config as a BossConfig.

## OTHER: a move type added by a subclass (_begin_other_move/_update_other_move).
enum Phase { CHASE, COMBO, SHOCKWAVE, GRAB, HOLD, TRANSITION, RECOVERY, OTHER }
## Stage inside COMBO, SHOCKWAVE and GRAB.
enum Stage { WINDUP, ACTIVE, RECOVERY }

var _phase: Phase = Phase.CHASE
var _stage: Stage = Stage.WINDUP
var _time: float = 0.0
var _cooldown_left: float = 0.0
var _boss_phase: int = 1
var _phase_two_pending: bool = false
var _move_index: int = -1
var _last_move: int = -1
var _recovery_duration: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Combo.
var _step_index: int = 0
var _step: EnemyAttackData = null
var _has_hit: bool = false
# Shockwave rings (one slot per ring node of the enemy).
var _wave: ShockwaveMoveData = null
var _wave_center: Vector3 = Vector3.ZERO
var _ring_active: Array[bool] = []
var _ring_radius: Array[float] = []
var _ring_hit: Array[bool] = []
var _rings_left: int = 0
var _ring_timer: float = 0.0
# Grab.
var _lunge_direction: Vector3 = Vector3.ZERO
var _lunge_length: float = 0.0
var _traveled: float = 0.0


func setup(owner_enemy: Enemy) -> void:
	super.setup(owner_enemy)
	_rng.randomize()
	var rings: int = enemy.get_shockwave_count()
	_ring_active.resize(rings)
	_ring_radius.resize(rings)
	_ring_hit.resize(rings)


func reset() -> void:
	_release_target()
	_phase = Phase.CHASE
	_stage = Stage.WINDUP
	_time = 0.0
	_cooldown_left = 0.0
	_boss_phase = 1
	_phase_two_pending = false
	_move_index = -1
	_last_move = -1
	_rings_left = 0
	_ring_active.fill(false)


## Seeds the move choice (tests).
func set_seed(value: int) -> void:
	_rng.seed = value


func get_phase() -> Phase:
	return _phase


func get_stage() -> Stage:
	return _stage


## 1 or 2.
func get_boss_phase() -> int:
	return _boss_phase


## Index in BossConfig.moves of the move in progress (or the last one).
func get_move_index() -> int:
	return _move_index


func get_last_move() -> int:
	return _last_move


func get_ring_radius(index: int) -> float:
	return _ring_radius[index]


func is_ring_active(index: int) -> bool:
	return _ring_active[index]


func is_attacking() -> bool:
	return _phase != Phase.CHASE


## Mid-move pushes would break the move (a lunge, a hold): it stands firm.
func resists_knockback(_direction: Vector3) -> bool:
	return is_attacking()


func deactivated() -> void:
	_release_target()


func physics_update(delta: float) -> void:
	_update_rings(delta)
	var target: Player = enemy.target
	if target == null or target.health.is_dead():
		_release_target()
		enemy.stand_still(delta)
		return
	if _boss_phase == 1 and _phase != Phase.TRANSITION and enemy.health.get_health_ratio() <= _config().phase_two.health_threshold:
		_phase_two_pending = true
	match _phase:
		Phase.CHASE:
			_chase(delta)
		Phase.COMBO:
			_combo(delta)
		Phase.SHOCKWAVE:
			_shockwave(delta)
		Phase.GRAB:
			_grab(delta)
		Phase.HOLD:
			_hold(delta)
		Phase.TRANSITION:
			_transition(delta)
		Phase.OTHER:
			_update_other_move(delta)
		Phase.RECOVERY:
			enemy.stand_still(delta)
			_time += delta
			if _time >= _recovery_duration:
				_finish_move()


func _chase(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _phase_two_pending:
		_begin_transition()
		enemy.stand_still(delta)
		return
	var offset: Vector3 = _offset_to_target()
	var distance: float = offset.length()
	if _cooldown_left <= 0.0:
		var index: int = BossMoveTable.pick(_config().moves, distance, _boss_phase, _last_move, _rng.randf(), _hands_left())
		if index >= 0:
			enemy.stand_still(delta)
			enemy.face(offset)
			_begin_move(index)
			return
	_chase_motion(offset, distance, delta)


func _begin_move(index: int) -> void:
	_move_index = index
	var move: BossMoveData = _config().moves[index]
	_stage = Stage.WINDUP
	_time = 0.0
	if move is ComboMoveData:
		_phase = Phase.COMBO
		_step_index = 0
		_begin_step()
	elif move is ShockwaveMoveData:
		_phase = Phase.SHOCKWAVE
		_wave = move as ShockwaveMoveData
		enemy.get_hands().play_windup(_wave.attack, _windup(_wave.attack.windup_time))
	elif move is GrabMoveData:
		_phase = Phase.GRAB
		var grab: GrabMoveData = move as GrabMoveData
		enemy.get_hands().play_windup(grab.attack, _windup(grab.attack.windup_time))
		var planned: float = clampf(_offset_to_target().length() - grab.stop_distance, 0.0, grab.lunge_distance)
		enemy.get_telegraph().show_line(enemy.global_position, enemy.get_facing(), planned + grab.attack.hit_range, grab.attack.hit_range, _windup(grab.attack.windup_time))
	else:
		_phase = Phase.OTHER
		_begin_other_move(move)


# --- Combo -------------------------------------------------------------------

func _begin_step() -> void:
	var combo: ComboMoveData = _config().moves[_move_index] as ComboMoveData
	_step = combo.step_at(_step_index)
	_stage = Stage.WINDUP
	_time = 0.0
	_has_hit = false
	enemy.get_hands().play_windup(_step, _windup(_step.windup_time))
	enemy.get_telegraph().show_sector(enemy.global_position, enemy.get_facing(), _step.hit_range, _step.hit_arc_degrees, _windup(_step.windup_time))


## Steps advance_distance towards the target during each windup.
func _combo(delta: float) -> void:
	var combo: ComboMoveData = _config().moves[_move_index] as ComboMoveData
	var offset: Vector3 = _offset_to_target()
	_time += delta
	match _stage:
		Stage.WINDUP:
			var windup: float = _windup(_step.windup_time)
			enemy.turn_towards(offset, deg_to_rad(_step.windup_turn_speed) * delta)
			enemy.move_with_velocity(enemy.get_facing() * combo.advance_distance / windup, delta)
			enemy.get_telegraph().follow(enemy.global_position, enemy.get_facing())
			if _time >= windup:
				_time -= windup
				_stage = Stage.ACTIVE
				enemy.get_hands().play_strike(_step, _step.active_time)
				enemy.get_telegraph().flash(false)
		Stage.ACTIVE:
			enemy.stand_still(delta)
		Stage.RECOVERY:
			enemy.stand_still(delta)
			if _time >= _scaled(_step.recovery_time):
				_step_index += 1
				if _step_index < combo.step_count(_boss_phase):
					_begin_step()
				else:
					_finish_move()
			return
	if _stage == Stage.ACTIVE:
		_try_hit(_step, _step.damage_multiplier)
		if _time >= _step.active_time:
			_time -= _step.active_time
			_stage = Stage.RECOVERY
			enemy.get_hands().return_to_rest()


func _try_hit(attack: EnemyAttackData, multiplier: float) -> void:
	var target: Player = enemy.target
	if _has_hit or not attack.is_hit(enemy.global_position, enemy.get_facing(), target.global_position, enemy.get_target_padding()):
		return
	_has_hit = true
	target.health.receive_hit_from(enemy.get_scaled_stats().damage * multiplier, enemy)


# --- Shockwave ---------------------------------------------------------------

func _shockwave(delta: float) -> void:
	enemy.stand_still(delta)
	_time += delta
	if _stage == Stage.WINDUP:
		enemy.turn_towards(_offset_to_target(), deg_to_rad(_wave.attack.windup_turn_speed) * delta)
		if _time >= _windup(_wave.attack.windup_time):
			_slam()
		return
	# Recovery: later rings go off ring_delay apart.
	if _rings_left > 0:
		_ring_timer -= delta
		if _ring_timer <= 0.0:
			_launch_ring()
	if _time >= _recovery_duration:
		_finish_move()


func _slam() -> void:
	_stage = Stage.RECOVERY
	_time = 0.0
	_wave_center = enemy.global_position
	_rings_left = mini(_wave.ring_count(_boss_phase), _ring_active.size())
	_recovery_duration = maxf(_scaled(_wave.attack.recovery_time), _wave.ring_delay * float(_rings_left - 1))
	enemy.get_hands().play_strike(_wave.attack, _wave.attack.active_time)
	_launch_ring()


func _launch_ring() -> void:
	for i: int in _ring_active.size():
		if _ring_active[i]:
			continue
		_ring_active[i] = true
		_ring_radius[i] = _wave.start_radius
		_ring_hit[i] = false
		_pose_ring(i)
		enemy.get_shockwave(i).visible = true
		break
	_rings_left -= 1
	_ring_timer = _wave.ring_delay


## Rings keep growing after the move ends; each hits a grounded target once.
func _update_rings(delta: float) -> void:
	for i: int in _ring_active.size():
		if not _ring_active[i]:
			continue
		_ring_radius[i] += _wave.speed * delta
		if _ring_radius[i] >= _wave.max_radius:
			_ring_active[i] = false
			enemy.get_shockwave(i).visible = false
			continue
		_pose_ring(i)
		var target: Player = enemy.target
		if _ring_hit[i] or target == null or target.health.is_dead():
			continue
		if _wave.is_hit(_wave_center, _ring_radius[i], target.global_position):
			_ring_hit[i] = true
			target.health.receive_hit_from(enemy.get_scaled_stats().damage * _wave.attack.damage_multiplier, enemy)


func _pose_ring(index: int) -> void:
	var ring: MeshInstance3D = enemy.get_shockwave(index)
	ring.global_position = _wave_center
	ring.global_basis = Basis.IDENTITY.scaled(Vector3(_ring_radius[index], 1.0, _ring_radius[index]))


# --- Grab --------------------------------------------------------------------

func _grab(delta: float) -> void:
	var grab: GrabMoveData = _config().moves[_move_index] as GrabMoveData
	_time += delta
	if _stage == Stage.WINDUP:
		enemy.stand_still(delta)
		enemy.turn_towards(_offset_to_target(), deg_to_rad(grab.attack.windup_turn_speed) * delta)
		enemy.get_telegraph().follow(enemy.global_position, enemy.get_facing())
		if _time >= _windup(grab.attack.windup_time):
			_stage = Stage.ACTIVE
			_lunge_direction = enemy.get_facing()
			_lunge_length = clampf(_offset_to_target().length() - grab.stop_distance, 0.0, grab.lunge_distance)
			_traveled = 0.0
			enemy.get_hands().play_strike(grab.attack, _lunge_length / grab.lunge_speed)
			enemy.get_telegraph().flash(false)
		return
	# Lunge: the last step is shortened so it covers exactly its length.
	var remaining: float = _lunge_length - _traveled
	var before: Vector3 = enemy.global_position
	enemy.move_with_velocity(_lunge_direction * minf(grab.lunge_speed, remaining / delta), delta)
	_traveled += Vector2(enemy.global_position.x - before.x, enemy.global_position.z - before.z).length()
	var target: Player = enemy.target
	if not target.health.is_invulnerable and grab.attack.is_hit(enemy.global_position, _lunge_direction, target.global_position, enemy.get_target_padding()):
		_phase = Phase.HOLD
		_time = 0.0
		target.begin_hold(grab.hold_time)
		return
	if _traveled >= _lunge_length - 0.001 or enemy.hit_wall():
		_begin_recovery(grab.miss_recovery_time)


## The target is held; when hold_time ends the boss slams it.
func _hold(delta: float) -> void:
	var grab: GrabMoveData = _config().moves[_move_index] as GrabMoveData
	enemy.stand_still(delta)
	_time += delta
	if _time < grab.hold_time:
		return
	var target: Player = enemy.target
	target.end_hold()
	target.health.receive_hit_from(enemy.get_scaled_stats().damage * grab.slam_multiplier, enemy)
	_begin_recovery(_scaled(grab.attack.recovery_time))


# --- Phases and helpers ------------------------------------------------------

func _begin_transition() -> void:
	enemy.get_telegraph().clear()
	_phase = Phase.TRANSITION
	_time = 0.0
	_phase_two_pending = false
	enemy.health.is_invulnerable = true
	var phase_two: BossPhaseData = _config().phase_two
	var pose_time: float = phase_two.transition_pose_time if phase_two.transition_pose_time > 0.0 else enemy.get_hands().config.return_time
	enemy.get_hands().play_pose(phase_two.transition_hand_offset, pose_time, &"transition", phase_two.transition_hand_rotation)


func _transition(delta: float) -> void:
	enemy.stand_still(delta)
	_time += delta
	if _time < _config().phase_two.transition_time:
		return
	enemy.health.is_invulnerable = false
	_boss_phase = 2
	enemy.get_hands().announce_phase(2)
	enemy.get_hands().set_size_multiplier(_config().phase_two.phase_two_hand_scale)
	enemy.get_hands().return_to_rest()
	_phase = Phase.CHASE
	_cooldown_left = 0.0


func _begin_recovery(duration: float) -> void:
	_phase = Phase.RECOVERY
	_time = 0.0
	_recovery_duration = duration
	enemy.get_hands().return_to_rest()


func _finish_move() -> void:
	_phase = Phase.CHASE
	_time = 0.0
	_last_move = _move_index
	_cooldown_left = enemy.get_scaled_stats().attack_interval
	enemy.get_hands().return_to_rest()


## A windup at this boss's pace (enemy-pace.md) and phase.
func _windup(seconds: float) -> float:
	return enemy.windup(_scaled(seconds))


## Windups and recoveries are faster in phase 2.
func _scaled(seconds: float) -> float:
	return seconds * (_config().phase_two.time_scale if _boss_phase == 2 else 1.0)


func _release_target() -> void:
	if _phase == Phase.HOLD and enemy.target != null:
		enemy.target.end_hold()
	if _phase == Phase.HOLD or _phase == Phase.TRANSITION:
		enemy.health.is_invulnerable = false
		_phase = Phase.CHASE


func _config() -> BossConfig:
	return enemy.stats.behavior_config as BossConfig


func _offset_to_target() -> Vector3:
	var offset: Vector3 = enemy.target.global_position - enemy.global_position
	return Vector3(offset.x, 0.0, offset.z)


# --- Hooks for subclasses ------------------------------------------------------

## A move of a type this class does not know (the phase is already OTHER).
func _begin_other_move(_move: BossMoveData) -> void:
	_finish_move()


## Every frame of an OTHER move; call _finish_move() or _begin_recovery() to end it.
func _update_other_move(_delta: float) -> void:
	_finish_move()


## Movement between moves (by default it closes in to attack_range).
func _chase_motion(offset: Vector3, distance: float, delta: float) -> void:
	if distance > enemy.get_scaled_stats().attack_range:
		enemy.move_towards(offset.normalized(), delta)
	else:
		enemy.stand_still(delta)
		enemy.face(offset)


## Hands the boss can still use (moves with needs_hand need one).
func _hands_left() -> int:
	return 2


## Sector warnings: the hits of every combo (phase 2 extras included).
func get_telegraph_arcs() -> Array[float]:
	var arcs: Array[float] = []
	for move: BossMoveData in _config().moves:
		var combo: ComboMoveData = move as ComboMoveData
		if combo == null:
			continue
		for step: EnemyAttackData in combo.steps:
			arcs.append(step.hit_arc_degrees)
		for step: EnemyAttackData in combo.phase_two_extra_steps:
			arcs.append(step.hit_arc_degrees)
	return arcs
