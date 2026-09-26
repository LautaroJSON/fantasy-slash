extends GdUnitTestSuite
## Rules shared by every enemy type (docs/specs/enemy-types.md).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const RAGE: RageConfig = preload("res://data/enemies/rage/rage_config.tres")
const CHARGER: EnemyStats = preload("res://data/enemies/charger_stats.tres")
const LEAPER: EnemyStats = preload("res://data/enemies/leaper_stats.tres")
const HARASSER: EnemyStats = preload("res://data/enemies/harasser_stats.tres")
const SHIELDBEARER: EnemyStats = preload("res://data/enemies/shieldbearer_stats.tres")

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


func _types() -> Array[EnemyStats]:
	return [CHARGER, LEAPER, HARASSER, SHIELDBEARER] as Array[EnemyStats]


## Where each type starts an attack at once (the player faces −Z, so +Z is behind).
func _attack_spot(stats: EnemyStats) -> Vector3:
	match stats:
		CHARGER:
			return Vector3(0.0, 0.0, -5.0)
		LEAPER:
			return Vector3(0.0, 0.0, -6.0)
		HARASSER:
			return Vector3(0.0, 0.0, 4.0)
	return Vector3(0.0, 0.0, 1.9)


func _spawn(stats: EnemyStats, at: Vector3, level: int = 1) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player, level)
	return enemy


func test_ac437_every_type_scales_with_level_and_rage() -> void:
	for stats: EnemyStats in _types():
		var enemy: Enemy = _spawn(stats, Vector3(20.0, 0.0, 20.0), 5)
		enemy.enrage(RAGE, 2)
		var expected := EnemyStats.new()
		stats.write_scaled(5, expected)
		RAGE.write_raged(2, expected)
		assert_float(enemy.get_scaled_stats().damage).is_equal_approx(expected.damage, 0.0001)
		assert_float(enemy.get_scaled_stats().damage).is_greater(stats.damage)
		assert_float(enemy.health.max_health).is_equal_approx(expected.max_health, 0.0001)
		assert_float(enemy.get_scaled_stats().move_speed).is_equal_approx(expected.move_speed, 0.0001)
		enemy.deactivate()


func test_ac438_every_type_uses_its_hands_and_body_size() -> void:
	for stats: EnemyStats in _types():
		var enemy: Enemy = _spawn(stats, Vector3(20.0, 0.0, 20.0))
		var hands: EnemyHands = enemy.get_hands()
		assert_object(hands.config).is_same(stats.hands_config)
		assert_vector(hands.get_node("RightHand").scale).is_equal_approx(Vector3.ONE * stats.hands_config.hand_scale, Vector3(0.0001, 0.0001, 0.0001))
		assert_vector(hands.get_right_position()).is_equal_approx(stats.hands_config.rest_offset, Vector3(0.001, 0.001, 0.001))
		assert_vector(hands.scale).is_equal_approx(Vector3.ONE * stats.body_scale, Vector3(0.0001, 0.0001, 0.0001))
		assert_float(enemy.get_body_scale()).is_equal_approx(stats.body_scale, 0.0001)
		enemy.deactivate()


func test_ac439_reuse_mid_attack_resets_every_type() -> void:
	for stats: EnemyStats in _types():
		var enemy: Enemy = _spawn(stats, _attack_spot(stats))
		for i: int in 5:
			await get_tree().physics_frame
		assert_bool(enemy.get_behavior().is_attacking()).override_failure_message(stats.resource_path).is_true()
		enemy.deactivate()
		enemy.activate(Vector3(20.0, 0.0, 20.0), _player)
		assert_bool(enemy.get_behavior().is_attacking()).is_false()
		assert_vector(enemy.get_hands().get_right_position()).is_equal_approx(stats.hands_config.rest_offset, Vector3(0.001, 0.001, 0.001))
		assert_float(enemy.health.damage_reduction).is_equal_approx(0.0, 0.0001)
		enemy.deactivate()
