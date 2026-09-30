class_name ColmenaBehavior
extends BossBehavior
## La Colmena (docs/specs/boss-colmena.md): a BossBehavior that keeps its
## distance and fights with minions. It calls a batch (Enemy.summon_requested;
## WaveManager spawns them and hands them back with add_minion), stays
## invulnerable while any lives, and is exposed for exposed_time once they are
## all dead; then it calls again. Its only move is a short pulse (a
## ShockwaveMoveData) against a target that comes too close. Dying kills the
## minions left. Uses EnemyStats.behavior_config as a ColmenaConfig.

var _minions: Array[Enemy] = []
var _exposed_left: float = 0.0
var _needs_summon: bool = true
var _summoning: bool = false


func reset() -> void:
	_drop_minions(false)
	super.reset()
	_exposed_left = 0.0
	_needs_summon = true
	_summoning = false
	_update_shield()


func add_minion(minion: Enemy) -> void:
	if _minions.has(minion):
		return
	_minions.append(minion)
	minion.killed.connect(_on_minion_killed)


func get_minion_count() -> int:
	return _minions.size()


func get_minions() -> Array[Enemy]:
	return _minions


func is_exposed() -> bool:
	return _exposed_left > 0.0


func is_shielded() -> bool:
	return not is_exposed()


func is_summoning() -> bool:
	return _summoning


## The Colmena died (or was returned to its pool): its minions die with it.
func deactivated() -> void:
	super.deactivated()
	_drop_minions(true)


func physics_update(delta: float) -> void:
	if _exposed_left > 0.0 and _phase != Phase.TRANSITION:
		_exposed_left = maxf(_exposed_left - delta, 0.0)
		if _exposed_left <= 0.0:
			_needs_summon = true
			enemy.get_hands().return_to_rest()
	var was_changing_phase: bool = _phase == Phase.TRANSITION
	super.physics_update(delta)
	# The change of phase cuts the exposed window short: it calls again at once.
	if was_changing_phase and _phase != Phase.TRANSITION:
		_exposed_left = 0.0
		_needs_summon = true
	_update_shield()


func _chase(delta: float) -> void:
	if _needs_summon and not _phase_two_pending and enemy.target != null:
		enemy.stand_still(delta)
		_begin_summon()
		return
	super._chase(delta)


## Keeps the target between keep_min_distance and keep_max_distance.
func _chase_motion(offset: Vector3, distance: float, delta: float) -> void:
	var config: ColmenaConfig = _colmena()
	if distance < config.keep_min_distance:
		enemy.walk(-offset.normalized(), delta)
		enemy.face(offset)
	elif distance > config.keep_max_distance:
		enemy.move_towards(offset.normalized(), delta)
	else:
		enemy.stand_still(delta)
		enemy.face(offset)


# --- Summon --------------------------------------------------------------------

func _begin_summon() -> void:
	var attack: EnemyAttackData = _colmena().summon_attack
	_needs_summon = false
	_summoning = true
	_phase = Phase.OTHER
	_time = 0.0
	_exposed_left = 0.0
	enemy.get_hands().play_windup(attack, _windup(attack.windup_time))


func _update_other_move(delta: float) -> void:
	if not _summoning:
		_finish_move()
		return
	var attack: EnemyAttackData = _colmena().summon_attack
	enemy.stand_still(delta)
	_time += delta
	if _time < _windup(attack.windup_time):
		return
	_summoning = false
	enemy.get_hands().play_strike(attack, attack.active_time)
	enemy.summon_requested.emit(enemy, _colmena().summon_for(_boss_phase))
	_begin_recovery(_scaled(attack.recovery_time))
	if _minions.is_empty():
		_expose()


func _on_minion_killed(minion: Enemy) -> void:
	_forget(minion)
	if _minions.is_empty() and not _summoning:
		_expose()


func _expose() -> void:
	_exposed_left = _colmena().exposed_time_for(_boss_phase)
	_announce_exposed()


## The model shows the exposed abdomen for as long as the window lasts.
func _announce_exposed() -> void:
	if _exposed_left > 0.0:
		enemy.get_hands().announce_pose(&"exposed", _exposed_left)


func _finish_move() -> void:
	super._finish_move()
	_announce_exposed()


## Drops every minion; `kill` executes the ones still active (the Colmena died).
func _drop_minions(kill: bool) -> void:
	while not _minions.is_empty():
		var minion: Enemy = _minions[_minions.size() - 1]
		_forget(minion)
		if kill and minion.is_inside_tree() and not minion.health.is_dead() and minion.visible:
			minion.health.execute()


func _forget(minion: Enemy) -> void:
	_minions.erase(minion)
	if minion.killed.is_connected(_on_minion_killed):
		minion.killed.disconnect(_on_minion_killed)


## Invulnerable with the shield up (and during the change of phase); the
## shield status is listed for the HUD icon and the aura.
func _update_shield() -> void:
	var shielded: bool = is_shielded()
	enemy.health.is_invulnerable = shielded or _phase == Phase.TRANSITION
	var status: DebuffData = _colmena().shield_status
	var listed: bool = enemy.debuffs.has_debuff(status.id)
	if shielded and not listed:
		enemy.debuffs.apply(status, 1.0)
	elif not shielded and listed:
		enemy.debuffs.remove(status.id)


func _colmena() -> ColmenaConfig:
	return enemy.stats.behavior_config as ColmenaConfig


func state_restored() -> void:
	_update_shield()
