extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
## boss-titan: the Titán is the big body of reference (the Coloso is gone).
const BIG_STATS: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const BAR_CONFIG: HealthBarConfig = preload("res://data/ui/enemy_health_bar_config.tres")
const NUMBER_CONFIG: DamageNumberConfig = preload("res://data/ui/damage_number_config.tres")
const NUMBER_MATERIAL: StandardMaterial3D = preload("res://materials/damage_number_material.tres")
const NUMBER_CRIT_MATERIAL: StandardMaterial3D = preload("res://materials/damage_number_crit_material.tres")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const NO_CRIT_ROLL: float = 0.99
## Grunt capsule radius in enemy.tscn.
const BASE_RADIUS: float = 0.4

var _registry: EnemyRegistry
var _player: Player


func before_test() -> void:
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


func _collision(enemy: Enemy) -> CollisionShape3D:
	return enemy.get_node("CollisionShape3D") as CollisionShape3D


func test_ac147_grunt_body_is_unchanged() -> void:
	var grunt: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -8.0))
	assert_float(grunt.get_body_scale()).is_equal_approx(1.0, 0.0001)
	assert_float(grunt.get_hit_padding()).is_equal_approx(0.0, 0.0001)
	assert_vector(_collision(grunt).scale).is_equal_approx(Vector3.ONE, Vector3(0.0001, 0.0001, 0.0001))
	assert_float(_collision(grunt).position.y).is_equal_approx(0.9, 0.0001)
	assert_float(grunt.health_bar.position.y).is_equal_approx(BAR_CONFIG.height_offset, 0.0001)
	assert_vector(grunt.health_bar.scale).is_equal_approx(Vector3.ONE, Vector3(0.0001, 0.0001, 0.0001))


func test_ac148_ac494_big_body_and_bar_are_scaled() -> void:
	var big: Enemy = _spawn(BIG_STATS, Vector3(0.0, 0.0, -8.0))
	var body: MeshInstance3D = big.get_node("Body") as MeshInstance3D
	assert_vector(_collision(big).scale).is_equal_approx(Vector3.ONE * BIG_STATS.body_scale, Vector3(0.0001, 0.0001, 0.0001))
	assert_vector(body.scale).is_equal_approx(Vector3.ONE * BIG_STATS.body_scale, Vector3(0.0001, 0.0001, 0.0001))
	assert_float(_collision(big).position.y).is_equal_approx(0.9 * BIG_STATS.body_scale, 0.0001)
	assert_float(big.health_bar.position.y).is_equal_approx(BAR_CONFIG.height_offset * BIG_STATS.body_scale, 0.0001)
	assert_vector(big.health_bar.scale).is_equal_approx(Vector3.ONE * BIG_STATS.health_bar_scale, Vector3(0.0001, 0.0001, 0.0001))
	assert_float(big.get_hit_padding()).is_equal_approx(BASE_RADIUS * (BIG_STATS.body_scale - 1.0), 0.0001)


func test_ac148_shake_settles_at_the_raised_rest_position() -> void:
	var big: Enemy = _spawn(BIG_STATS, Vector3(0.0, 0.0, -8.0))
	big.health_bar.notify_hit(1.0, true)
	big.health_bar.advance_shake(BAR_CONFIG.shake_duration + 0.01)
	assert_float(big.health_bar.position.y).is_equal_approx(BAR_CONFIG.height_offset * BIG_STATS.body_scale, 0.0001)


func test_ac149_basic_attack_reaches_a_big_body() -> void:
	var big: Enemy = _spawn(BIG_STATS, Vector3(0.0, 0.0, -2.5))
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_float(big.health.current_health).is_less(big.health.max_health)


func test_ac149_grunt_reach_is_unchanged() -> void:
	var just_out_of_reach: float = _player.stats.get_stat(PlayerStats.Stat.ATTACK_RANGE) + 0.1
	var grunt: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -just_out_of_reach))
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_float(grunt.health.current_health).is_equal_approx(grunt.health.max_health, 0.0001)


func test_ac149_thrust_reaches_a_big_body_beside_the_line() -> void:
	_player.basic_ability.equip(THRUST)
	var half_width: float = THRUST.hit_width / 2.0
	var big: Enemy = _spawn(BIG_STATS, Vector3(half_width + 0.5, 0.0, -2.0))
	var grunt: Enemy = _spawn(GRUNT_STATS, Vector3(-(half_width + 0.5), 0.0, -2.0))
	assert_bool(_player.basic_ability.try_cast()).is_true()
	_player.basic_ability.advance(_player.basic_ability.get_stat(AbilityData.Stat.CAST_DURATION))
	assert_float(big.health.current_health).is_less(big.health.max_health)
	assert_float(grunt.health.current_health).is_equal_approx(grunt.health.max_health, 0.0001)


func test_ac150_damage_numbers_appear_above_a_big_body() -> void:
	var numbers: DamageNumberPool = auto_free(DamageNumberPool.new())
	numbers.player = _player
	numbers.config = NUMBER_CONFIG
	numbers.material = NUMBER_MATERIAL
	numbers.crit_material = NUMBER_CRIT_MATERIAL
	add_child(numbers)
	var big: Enemy = _spawn(BIG_STATS, Vector3(0.0, 0.0, -2.5))
	_player.attack.try_attack_with_roll(NO_CRIT_ROLL)
	var number: DamageNumber = numbers.get_last_spawned()
	assert_float(number.global_position.y).is_equal_approx(big.global_position.y + NUMBER_CONFIG.spawn_height * BIG_STATS.body_scale, 0.001)
