class_name TitanBehavior
extends BossBehavior
## El Titán (docs/specs/boss-titan.md): a BossBehavior with an armoured body
## and breakable hands. It adds two moves: HandSlamMoveData (a hand crashes on
## a locked point and then rests on the floor as a weak point) and
## SweepMoveData (a low sweep to jump over). Hits landed while the target is
## near a resting hand skip the armour and also hurt that hand; a broken hand
## disappears and stuns the Titán for break_stun_time.
## Uses EnemyStats.behavior_config as a TitanConfig.

enum Stage2 { WINDUP, ACTIVE, REST, RECOVERY }

## Hand health left, as a fraction of hand_health_fraction × max health (0 left, 1 right).
var _hand_ratio: Array[float] = [1.0, 1.0]
var _hand_broken: Array[bool] = [false, false]
## Hand resting on the floor after a slam: 0 left, 1 right, −1 none.
var _resting_hand: int = -1
## Hand the target is close enough to for its hits to land on it (−1 none).
var _weak_hand: int = -1
var _stun_left: float = 0.0
var _next_left: bool = false
var _other_stage: Stage2 = Stage2.WINDUP
var _move_hand_left: bool = false
var _impact_point: Vector3 = Vector3.ZERO


func setup(owner_enemy: Enemy) -> void:
	super.setup(owner_enemy)
	enemy.health.damaged.connect(_on_damaged)


func reset() -> void:
	super.reset()
	_hand_ratio[0] = 1.0
	_hand_ratio[1] = 1.0
	_hand_broken[0] = false
	_hand_broken[1] = false
	_resting_hand = -1
	_weak_hand = -1
	_stun_left = 0.0
	_next_left = false
	enemy.health.damage_reduction = _titan().body_armor


func get_hand_health(left: bool) -> float:
	return _hand_ratio[_index(left)] * _hand_max_health()


func is_hand_broken(left: bool) -> bool:
	return _hand_broken[_index(left)]


func is_hand_resting(left: bool) -> bool:
	return _resting_hand == _index(left)


func is_stunned() -> bool:
	return _stun_left > 0.0


func get_impact_point() -> Vector3:
	return _impact_point


## Hand used by the hand move in progress.
func is_move_hand_left() -> bool:
	return _move_hand_left


func get_other_stage() -> Stage2:
	return _other_stage


func physics_update(delta: float) -> void:
	_update_weak_point()
	if _stun_left > 0.0:
		_update_rings(delta)
		enemy.stand_still(delta)
		_stun_left -= delta
		if _stun_left <= 0.0:
			_stun_left = 0.0
			enemy.get_body().position.y = enemy.get_body_rest_height()
			_finish_move()
	else:
		super.physics_update(delta)
	_update_armor()


func _hands_left() -> int:
	return (0 if _hand_broken[0] else 1) + (0 if _hand_broken[1] else 1)


# --- Armour and weak points ----------------------------------------------------

func _update_weak_point() -> void:
	_weak_hand = -1
	if _resting_hand < 0 or enemy.target == null:
		return
	var left: bool = _resting_hand == 0
	var hands: EnemyHands = enemy.get_hands()
	var hand: Vector3 = hands.get_hand_global_position(left)
	var target: Vector3 = enemy.target.global_position
	var reach: float = hands.get_hand_radius(left) + _titan().weak_point_margin
	if Vector2(target.x - hand.x, target.z - hand.z).length() <= reach:
		_weak_hand = _resting_hand


func _update_armor() -> void:
	var exposed: bool = _stun_left > 0.0 or _weak_hand >= 0
	enemy.health.damage_reduction = 0.0 if exposed else _titan().body_armor


## Damage taken near a resting hand also hurts that hand.
func _on_damaged(amount: float) -> void:
	if _weak_hand < 0 or _hand_broken[_weak_hand]:
		return
	var left: bool = _weak_hand == 0
	var config: TitanConfig = _titan()
	_hand_ratio[_weak_hand] = maxf(_hand_ratio[_weak_hand] - amount / _hand_max_health(), 0.0)
	var hands: EnemyHands = enemy.get_hands()
	hands.set_hand_size(left, config.hand_size_for(_hand_ratio[_weak_hand]))
	hands.shake_hand(left, config.hit_shake_time, config.hit_shake_amount)
	if _hand_ratio[_weak_hand] <= 0.0:
		_break_hand(_weak_hand)


func _break_hand(index: int) -> void:
	var hands: EnemyHands = enemy.get_hands()
	_hand_broken[index] = true
	hands.set_hand_visible(index == 0, false)
	if _resting_hand == index:
		_resting_hand = -1
	_weak_hand = -1
	_stun_left = _titan().break_stun_time
	_phase = Phase.OTHER
	_other_stage = Stage2.RECOVERY
	enemy.get_body().position.y = enemy.get_body_rest_height() - _titan().stun_body_drop * enemy.get_body_scale()
	hands.return_to_rest()
	hands.announce_pose(&"stunned", _titan().break_stun_time)


func _hand_max_health() -> float:
	return enemy.health.max_health * _titan().hand_health_fraction


# --- Hand slam and sweep -------------------------------------------------------

func _begin_other_move(move: BossMoveData) -> void:
	if _hands_left() <= 0:
		_finish_move()
		return
	_move_hand_left = _pick_hand()
	_other_stage = Stage2.WINDUP
	_time = 0.0
	var hands: EnemyHands = enemy.get_hands()
	var rest: Vector3 = hands.get_left_rest() if _move_hand_left else hands.get_right_rest()
	if move is HandSlamMoveData:
		var slam: HandSlamMoveData = move as HandSlamMoveData
		_impact_point = _target_floor_point()
		hands.move_hand(_move_hand_left, rest + _side(slam.raise_offset), _windup(slam.attack.windup_time))
		hands.announce_windup(slam.attack.model_clip, _windup(slam.attack.windup_time))
		enemy.get_telegraph().show_circle(_impact_point, slam.impact_radius, _windup(slam.attack.windup_time) + slam.attack.active_time)
	elif move is SweepMoveData:
		var sweep: SweepMoveData = move as SweepMoveData
		_has_hit = false
		hands.move_hand(_move_hand_left, rest + _side(sweep.attack.hand_windup_offset), _windup(sweep.attack.windup_time))
		hands.announce_windup(sweep.attack.model_clip, _windup(sweep.attack.windup_time))
		enemy.get_telegraph().show_sector(enemy.global_position, enemy.get_facing(), sweep.attack.hit_range, sweep.attack.hit_arc_degrees, _windup(sweep.attack.windup_time))


func _update_other_move(delta: float) -> void:
	var move: BossMoveData = _config().moves[_move_index]
	if move is HandSlamMoveData:
		_update_slam(move as HandSlamMoveData, delta)
	elif move is SweepMoveData:
		_update_sweep(move as SweepMoveData, delta)
	else:
		_finish_move()


func _update_slam(slam: HandSlamMoveData, delta: float) -> void:
	enemy.stand_still(delta)
	_time += delta
	var hands: EnemyHands = enemy.get_hands()
	match _other_stage:
		Stage2.WINDUP:
			var windup: float = _windup(slam.attack.windup_time)
			enemy.turn_towards(_offset_to_target(), deg_to_rad(slam.attack.windup_turn_speed) * delta)
			if _time < windup * slam.lock_fraction:
				_impact_point = _target_floor_point()
				enemy.get_telegraph().move_center(_impact_point)
			if _time >= windup:
				_time -= windup
				_other_stage = Stage2.ACTIVE
				var landing: Vector3 = _impact_point + Vector3.UP * hands.get_hand_radius(_move_hand_left)
				hands.move_hand(_move_hand_left, hands.to_local(landing), slam.attack.active_time)
				hands.announce_strike(slam.attack.model_clip, slam.attack.active_time)
		Stage2.ACTIVE:
			if _time >= slam.attack.active_time:
				_time -= slam.attack.active_time
				var target: Player = enemy.target
				enemy.get_telegraph().flash(true)
				if slam.is_hit(_impact_point, target.global_position):
					target.health.receive_hit_from(enemy.get_scaled_stats().damage * slam.attack.damage_multiplier, enemy)
				_other_stage = Stage2.REST
				_resting_hand = _index(_move_hand_left)
		Stage2.REST:
			if _time >= slam.hand_rest_time:
				_time -= slam.hand_rest_time
				_resting_hand = -1
				_other_stage = Stage2.RECOVERY
				hands.return_to_rest()
		Stage2.RECOVERY:
			if _time >= _scaled(slam.attack.recovery_time):
				_finish_move()


func _update_sweep(sweep: SweepMoveData, delta: float) -> void:
	enemy.stand_still(delta)
	_time += delta
	var hands: EnemyHands = enemy.get_hands()
	var rest: Vector3 = hands.get_left_rest() if _move_hand_left else hands.get_right_rest()
	match _other_stage:
		Stage2.WINDUP:
			var windup: float = _windup(sweep.attack.windup_time)
			enemy.turn_towards(_offset_to_target(), deg_to_rad(sweep.attack.windup_turn_speed) * delta)
			enemy.get_telegraph().follow(enemy.global_position, enemy.get_facing())
			if _time >= windup:
				_time -= windup
				_other_stage = Stage2.ACTIVE
				hands.move_hand(_move_hand_left, rest + _side(sweep.attack.hand_strike_offset), sweep.attack.active_time)
				hands.announce_strike(sweep.attack.model_clip, sweep.attack.active_time)
				enemy.get_telegraph().flash(false)
		Stage2.ACTIVE:
			var target: Player = enemy.target
			if not _has_hit and sweep.is_hit(enemy.global_position, enemy.get_facing(), target.global_position, enemy.get_target_padding()):
				_has_hit = true
				target.health.receive_hit_from(enemy.get_scaled_stats().damage * sweep.attack.damage_multiplier, enemy)
			if _time >= sweep.attack.active_time:
				_time -= sweep.attack.active_time
				_other_stage = Stage2.RECOVERY
				hands.return_to_rest()
		Stage2.RECOVERY, Stage2.REST:
			if _time >= _scaled(sweep.attack.recovery_time):
				_finish_move()


## Alternates between the hands still whole.
func _pick_hand() -> bool:
	var left: bool = _next_left
	if _hand_broken[_index(left)]:
		left = not left
	_next_left = not left
	return left


## Offsets are written for the right hand; the left hand mirrors x.
func _side(offset: Vector3) -> Vector3:
	return Vector3(-offset.x, offset.y, offset.z) if _move_hand_left else offset


func _target_floor_point() -> Vector3:
	var point: Vector3 = enemy.target.global_position
	return Vector3(point.x, enemy.global_position.y, point.z)


func _index(left: bool) -> int:
	return 0 if left else 1


func _titan() -> TitanConfig:
	return enemy.stats.behavior_config as TitanConfig


## Sector warnings: the boss's combos plus the sweep.
func get_telegraph_arcs() -> Array[float]:
	var arcs: Array[float] = super.get_telegraph_arcs()
	for move: BossMoveData in _config().moves:
		var sweep: SweepMoveData = move as SweepMoveData
		if sweep != null:
			arcs.append(sweep.attack.hit_arc_degrees)
	return arcs
