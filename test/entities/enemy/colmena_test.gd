extends GdUnitTestSuite
## La Colmena (docs/specs/boss-colmena.md). Calls are answered by a stand-in
## for WaveManager: it spawns target-less grunts far away and hands them back,
## so the minions never interfere. Without a pace, the call windup is 1.5 s.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const COLMENA_STATS: EnemyStats = preload("res://data/enemies/colmena_stats.tres")
const COLMENA: ColmenaConfig = preload("res://data/enemies/configs/colmena_boss.tres")
const RAGE: RageConfig = preload("res://data/enemies/rage/rage_config.tres")
const LETHAL_HIT: float = 100000.0
## Removes 100 (the Colmena has no defense at level 1).
const HIT: float = 100.0

var _registry: EnemyRegistry
var _player: Player
## Every summon_requested received: [enemy, SummonData].
var _calls: Array = []


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(80.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_player.health.is_invulnerable = true
	_calls.clear()


func _spawn(at: Vector3, level: int = 1) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = COLMENA_STATS
	enemy.registry = _registry
	add_child(enemy)
	enemy.summon_requested.connect(_on_summon)
	enemy.activate(at, _player, level)
	return enemy


## Stand-in for WaveManager: one target-less grunt per entry, 40 m away.
func _on_summon(boss: Enemy, summon: SummonData) -> void:
	_calls.append([boss, summon])
	for i: int in summon.stats.size():
		var minion: Enemy = auto_free(ENEMY_SCENE.instantiate())
		minion.registry = _registry
		add_child(minion)
		minion.activate(Vector3(40.0 + 2.0 * i, 0.0, 40.0), null)
		(boss.get_behavior() as ColmenaBehavior).add_minion(minion)


func _colmena(enemy: Enemy) -> ColmenaBehavior:
	return enemy.get_behavior() as ColmenaBehavior


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _kill_minions(enemy: Enemy) -> void:
	var minions: Array[Enemy] = []
	minions.assign(_colmena(enemy).get_minions())
	for minion: Enemy in minions:
		minion.health.receive_hit(LETHAL_HIT)


func _aura(enemy: Enemy) -> MeshInstance3D:
	return enemy.get_node("Body/ShieldAura") as MeshInstance3D


func test_ac528_calls_the_phase_one_batch_after_its_windup() -> void:
	_spawn(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(80)
	assert_int(_calls.size()).is_equal(0)
	await _physics_frames(20)
	assert_int(_calls.size()).is_equal(1)
	assert_object(_calls[0][1]).is_same(COLMENA.summon_phase_one)


func test_ac529_shielded_while_minions_live() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(100)
	assert_int(_colmena(enemy).get_minion_count()).is_equal(4)
	assert_bool(_colmena(enemy).is_shielded()).is_true()
	assert_float(enemy.health.receive_hit(HIT)).is_equal_approx(0.0, 0.0001)
	assert_bool(enemy.debuffs.has_debuff(COLMENA.shield_status.id)).is_true()
	assert_bool(_aura(enemy).visible).is_true()


func test_ac530_exposed_after_the_last_minion_then_calls_again() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(100)
	_kill_minions(enemy)
	await _physics_frames(2)
	assert_bool(_colmena(enemy).is_exposed()).is_true()
	assert_float(enemy.health.receive_hit(HIT)).is_equal_approx(100.0, 0.001)
	assert_bool(enemy.debuffs.has_debuff(COLMENA.shield_status.id)).is_false()
	assert_bool(_aura(enemy).visible).is_false()
	await _physics_frames(int(COLMENA.exposed_time_phase_one * 60.0) + 2)
	assert_bool(_colmena(enemy).is_shielded()).is_true()
	await _physics_frames(100)
	assert_int(_calls.size()).is_equal(2)


func test_ac531_keeps_its_distance() -> void:
	var close: Enemy = _spawn(Vector3(0.0, 0.0, -3.0))
	var far: Enemy = _spawn(Vector3(0.0, 0.0, -15.0))
	var fine: Enemy = _spawn(Vector3(8.0, 0.0, 0.0))
	await _physics_frames(100)
	_kill_minions(close)
	_kill_minions(far)
	_kill_minions(fine)
	await _physics_frames(60)
	assert_float(absf(close.global_position.z)).is_greater(3.2)
	assert_float(absf(far.global_position.z)).is_less(14.8)
	assert_vector(fine.global_position * Vector3(1, 0, 1)).is_equal_approx(Vector3(8.0, 0.0, 0.0), Vector3(0.05, 0.05, 0.05))


func test_ac532_pulses_only_when_the_player_is_close() -> void:
	var near: Enemy = _spawn(Vector3(0.0, 0.0, -3.5))
	var away: Enemy = _spawn(Vector3(20.0, 0.0, -8.0))
	await _physics_frames(100)
	var pulsed: bool = false
	# Recovery of the call (0.6 s) + attack_interval (1 s) + pulse windup (0.8 s).
	for i: int in 200:
		await get_tree().physics_frame
		near.global_position = Vector3(0.0, 0.0, -3.5)
		if _colmena(near).is_ring_active(0):
			pulsed = true
		assert_bool(_colmena(away).is_ring_active(0)).is_false()
	assert_bool(pulsed).is_true()


func test_ac533_phase_two_batch_and_shorter_window() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(100)
	_kill_minions(enemy)
	await _physics_frames(2)
	enemy.health.receive_hit(enemy.health.max_health * 0.5 + enemy.health.defense + 1.0)
	# The change of phase waits for the end of the call's recovery.
	await _wait_phase_two(enemy)
	assert_int(_colmena(enemy).get_boss_phase()).is_equal(2)
	for i: int in 400:
		await get_tree().physics_frame
		if _calls.size() >= 2:
			break
	assert_object(_calls[_calls.size() - 1][1]).is_same(COLMENA.summon_phase_two)
	_kill_minions(enemy)
	await _physics_frames(int(COLMENA.exposed_time_phase_two * 60.0) - 10)
	assert_bool(_colmena(enemy).is_exposed()).is_true()
	await _physics_frames(15)
	assert_bool(_colmena(enemy).is_exposed()).is_false()


func test_ac534_minions_die_with_the_colmena() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(100)
	var minions: Array[Enemy] = []
	minions.assign(_colmena(enemy).get_minions())
	enemy.health.is_invulnerable = false
	enemy.health.receive_hit(LETHAL_HIT)
	for minion: Enemy in minions:
		assert_bool(minion.health.is_dead()).is_true()
	assert_int(_registry.alive_count()).is_equal(0)


func test_ac535_activate_clears_minions_shield_and_phase() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(100)
	_kill_minions(enemy)
	await _physics_frames(2)
	enemy.health.receive_hit(enemy.health.max_health * 0.5 + enemy.health.defense + 1.0)
	await _wait_phase_two(enemy)
	enemy.activate(Vector3(0.0, 0.0, -8.0), _player)
	assert_int(_colmena(enemy).get_minion_count()).is_equal(0)
	assert_int(_colmena(enemy).get_boss_phase()).is_equal(1)
	assert_bool(_colmena(enemy).is_shielded()).is_true()
	assert_bool(enemy.health.is_invulnerable).is_true()
	assert_bool(enemy.debuffs.has_debuff(COLMENA.shield_status.id)).is_true()


func test_ac536_scales_with_level_and_rage() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -30.0), 5)
	enemy.enrage(RAGE, 2)
	var expected := EnemyStats.new()
	COLMENA_STATS.write_scaled(5, expected)
	RAGE.write_raged(2, expected)
	assert_float(enemy.get_scaled_stats().damage).is_equal_approx(expected.damage, 0.0001)
	assert_float(enemy.health.max_health).is_equal_approx(expected.max_health, 0.0001)
	# enrage restarts the health: the shield must still be up.
	assert_bool(enemy.health.is_invulnerable).is_true()


func _wait_phase_two(enemy: Enemy) -> void:
	for i: int in 300:
		await get_tree().physics_frame
		if _colmena(enemy).get_boss_phase() == 2:
			return
