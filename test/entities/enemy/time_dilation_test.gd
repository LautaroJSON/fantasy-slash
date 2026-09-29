extends GdUnitTestSuite
## Slow time of the enemies after a perfect dodge (docs/specs/perfect-dodge.md,
## AC1177–AC1179).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CONFIG: PerfectDodgeConfig = preload("res://data/player/perfect_dodge_config.tres")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const FROST_CHILL: DebuffData = preload("res://data/debuffs/frost_chill.tres")
const TOLERANCE: float = 0.02

var _registry: EnemyRegistry
var _player: Player


func before_test() -> void:
	Session.character_class = load("res://data/classes/warrior/warrior.tres") as CharacterClassData
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(80.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)


func after_test() -> void:
	Session.character_class = null
	Engine.time_scale = 1.0


func _spawn(stats: EnemyStats, at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	if stats != null:
		enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _flat_travel(enemy: Enemy, from: Vector3) -> float:
	return Vector2(enemy.global_position.x - from.x, enemy.global_position.z - from.z).length()


func test_ac1177_a_perfect_dodge_slows_every_enemy_including_a_boss_for_a_moment() -> void:
	var grunt: Enemy = _spawn(null, Vector3(15.0, 0.0, 15.0))
	var boss: Enemy = _spawn(VERDUGO, Vector3(-15.0, 0.0, 15.0))
	var attacker: Enemy = _spawn(null, Vector3(15.0, 0.0, -15.0))
	_player.dash.reset_cooldown()
	assert_bool(_player.dash.try_dash(Vector3.RIGHT)).is_true()
	await _physics_frames(3)
	_player.health.receive_hit_from(8.0, attacker)
	for enemy: Enemy in [grunt, boss, attacker]:
		assert_float(enemy.get_time_dilation()).is_equal_approx(CONFIG.enemy_time_scale, 0.0001)
	assert_float(Engine.time_scale).is_equal(1.0)
	await _physics_frames(int(CONFIG.slow_duration * 60.0) + 3)
	for enemy: Enemy in [grunt, boss, attacker]:
		assert_bool(enemy.is_time_dilated()).is_false()
		assert_float(enemy.get_time_dilation()).is_equal(1.0)


func test_ac1178_a_dilated_enemy_walks_and_acts_at_the_slow_speed() -> void:
	var slow_from := Vector3(12.0, 0.0, 0.0)
	var normal_from := Vector3(-12.0, 0.0, 0.0)
	var slow: Enemy = _spawn(null, slow_from)
	var normal: Enemy = _spawn(null, normal_from)
	slow.dilate_time(0.25, 5.0)
	await _physics_frames(30)
	assert_float(slow.get_speed_scale()).is_equal_approx(0.25, 0.0001)
	var slow_travel: float = _flat_travel(slow, slow_from)
	var normal_travel: float = _flat_travel(normal, normal_from)
	assert_float(normal_travel).is_greater(1.0)
	assert_float(slow_travel).is_equal_approx(normal_travel * 0.25, normal_travel * TOLERANCE + 0.05)


func test_ac1179_it_multiplies_with_slow_debuffs_and_yields_to_freezes_and_resets() -> void:
	var enemy: Enemy = _spawn(null, Vector3(12.0, 0.0, 0.0))
	enemy.debuffs.apply(FROST_CHILL, 0.5, 5.0)
	enemy.dilate_time(0.25, 5.0)
	await _physics_frames(2)
	assert_float(enemy.get_speed_scale()).is_equal_approx(enemy.debuffs.get_speed_scale() * 0.25, 0.0001)
	# A freeze wins: the enemy stays put, and the dilation still runs out.
	var frozen_at: Vector3 = enemy.global_position
	enemy.freeze_time(0.2)
	await _physics_frames(6)
	assert_vector(enemy.global_position).is_equal_approx(frozen_at, Vector3.ONE * 0.001)
	# Deactivating and activating again clear it.
	enemy.dilate_time(0.25, 5.0)
	enemy.deactivate()
	assert_bool(enemy.is_time_dilated()).is_false()
	enemy.dilate_time(0.25, 5.0)
	enemy.activate(Vector3(12.0, 0.0, 0.0), _player)
	assert_bool(enemy.is_time_dilated()).is_false()
	# One that comes out after the dodge is not slowed.
	var late: Enemy = _spawn(null, Vector3(-12.0, 0.0, 0.0))
	assert_float(late.get_time_dilation()).is_equal(1.0)
