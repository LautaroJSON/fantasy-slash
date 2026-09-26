extends GdUnitTestSuite
## Telegraphed enemy attacks (docs/specs/enemy-attack-telegraph.md). The grunt
## punch: 0.5 s windup, 0.15 s active, 0.45 s recovery, then 0.4 s of
## attack_interval; 8 × 1.5 damage - 3 player defense = 9 per hit.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
## boss-colmena (AC542): the Escudero is the non-interruptible melee enemy of
## reference (the Coloso and the Gemelos are gone).
const BOSS_STATS: EnemyStats = preload("res://data/enemies/shieldbearer_stats.tres")
const GRUNT_PUNCH: EnemyAttackData = preload("res://data/enemies/attacks/grunt_punch.tres")
const HANDS_CONFIG: EnemyHandsConfig = preload("res://data/enemies/enemy_hands_config.tres")
const PHYSICS_FPS: float = 60.0

var _registry: EnemyRegistry
var _player: Player


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)


func _spawn(stats: EnemyStats, at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _melee(enemy: Enemy) -> MeleeBehavior:
	return enemy.get_behavior() as MeleeBehavior


func test_ac400_no_damage_before_the_windup_ends() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(25)
	assert_int(_melee(enemy).get_phase()).is_equal(MeleeBehavior.Phase.WINDUP)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac401_player_in_the_arc_is_hit_once_per_attack() -> void:
	_spawn(GRUNT_STATS, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(45)
	assert_float(_player.health.current_health).is_equal_approx(91.0, 0.0001)
	# Rest of the active window, recovery and cooldown: still one hit.
	await _physics_frames(50)
	assert_float(_player.health.current_health).is_equal_approx(91.0, 0.0001)


func test_ac402_leaving_the_range_during_the_windup_avoids_the_hit() -> void:
	_spawn(GRUNT_STATS, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(10)
	_player.global_position = Vector3(0.0, 0.0, 2.0)
	await _physics_frames(40)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac403_side_step_faster_than_the_turn_avoids_the_hit() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(5)
	assert_int(_melee(enemy).get_phase()).is_equal(MeleeBehavior.Phase.WINDUP)
	# ~102° to the side, within reach: 90°/s over the remaining windup is not enough.
	_player.global_position = Vector3(1.9, 0.0, -1.9)
	await _physics_frames(40)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac405_recovery_neither_moves_nor_turns() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(45)
	assert_int(_melee(enemy).get_phase()).is_equal(MeleeBehavior.Phase.RECOVERY)
	var position: Vector3 = enemy.global_position
	var yaw: float = enemy.rotation.y
	_player.global_position = Vector3(3.0, 0.0, 3.0)
	await _physics_frames(10)
	assert_int(_melee(enemy).get_phase()).is_equal(MeleeBehavior.Phase.RECOVERY)
	assert_vector(enemy.global_position).is_equal_approx(position, Vector3(0.001, 0.001, 0.001))
	assert_float(enemy.rotation.y).is_equal_approx(yaw, 0.0001)


func test_ac406_attacks_are_spaced_by_the_whole_cycle() -> void:
	_spawn(GRUNT_STATS, Vector3(0.0, 0.0, -1.5))
	var hit_frames: Array[int] = []
	var last_health: float = _player.health.current_health
	for frame: int in 200:
		await get_tree().physics_frame
		if _player.health.current_health < last_health:
			hit_frames.append(frame)
			last_health = _player.health.current_health
	assert_int(hit_frames.size()).is_equal(2)
	var cycle: float = GRUNT_PUNCH.get_total_time() + GRUNT_STATS.attack_interval
	assert_int(hit_frames[1] - hit_frames[0]).is_greater_equal(int(cycle * PHYSICS_FPS) - 1)


func test_ac407_knockback_during_the_windup_cancels_the_attack() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(15)
	enemy.apply_knockback(Vector3(0.0, 0.0, -1.0), 5.0)
	assert_int(_melee(enemy).get_phase()).is_equal(MeleeBehavior.Phase.CHASE)
	# The punch would have landed at ~frame 30.
	await _physics_frames(30)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac407_ac495_boss_windup_is_not_interruptible() -> void:
	var boss: Enemy = _spawn(BOSS_STATS, Vector3(0.0, 0.0, -2.0))
	await _physics_frames(10)
	assert_int(_melee(boss).get_phase()).is_equal(MeleeBehavior.Phase.WINDUP)
	boss.apply_knockback(Vector3(0.0, 0.0, -1.0), 2.0)
	assert_int(_melee(boss).get_phase()).is_equal(MeleeBehavior.Phase.WINDUP)


func test_ac408_hands_rest_pull_back_and_strike_forward() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -1.5))
	var hands: EnemyHands = enemy.get_hands()
	assert_vector(hands.get_right_position()).is_equal_approx(HANDS_CONFIG.rest_offset, Vector3(0.001, 0.001, 0.001))
	assert_vector(hands.get_left_position()).is_equal_approx(hands.get_left_rest(), Vector3(0.001, 0.001, 0.001))
	# End of the windup: the punching (right) hand is behind its rest pose.
	await _physics_frames(28)
	assert_float(hands.get_right_position().z).is_greater(HANDS_CONFIG.rest_offset.z + GRUNT_PUNCH.hand_windup_offset.z * 0.5)
	# Strike: at its peak (end of the active window) it is ahead of its rest pose.
	var foremost: float = hands.get_right_position().z
	for i: int in 15:
		await get_tree().physics_frame
		foremost = minf(foremost, hands.get_right_position().z)
	assert_float(foremost).is_less(HANDS_CONFIG.rest_offset.z + GRUNT_PUNCH.hand_strike_offset.z * 0.5)


func test_ac408_idle_hands_bob_around_the_rest_pose() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -12.0))
	var hands: EnemyHands = enemy.get_hands()
	await _physics_frames(20)
	var offset: Vector3 = hands.get_right_position() - HANDS_CONFIG.rest_offset
	assert_float(offset.x).is_equal_approx(0.0, 0.001)
	assert_float(offset.z).is_equal_approx(0.0, 0.001)
	assert_float(absf(offset.y)).is_less_equal(HANDS_CONFIG.bob_amplitude + 0.001)


func test_ac410_ac495_hands_scale_with_the_body() -> void:
	var grunt: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -12.0))
	var boss: Enemy = _spawn(BOSS_STATS, Vector3(6.0, 0.0, -12.0))
	assert_vector(grunt.get_hands().scale).is_equal_approx(Vector3.ONE, Vector3(0.0001, 0.0001, 0.0001))
	assert_vector(boss.get_hands().scale).is_equal_approx(Vector3.ONE * BOSS_STATS.body_scale, Vector3(0.0001, 0.0001, 0.0001))


func test_ac411_reactivation_resets_the_attack_and_the_hands() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(33)
	assert_bool(_melee(enemy).is_attacking()).is_true()
	enemy.deactivate()
	enemy.activate(Vector3(0.0, 0.0, -12.0), _player)
	assert_bool(_melee(enemy).is_attacking()).is_false()
	assert_vector(enemy.get_hands().get_right_position()).is_equal_approx(HANDS_CONFIG.rest_offset, Vector3(0.001, 0.001, 0.001))
