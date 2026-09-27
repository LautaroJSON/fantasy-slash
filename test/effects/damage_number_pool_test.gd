extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const CONFIG: DamageNumberConfig = preload("res://data/ui/damage_number_config.tres")
const MATERIAL: StandardMaterial3D = preload("res://materials/damage_number_material.tres")
const CRIT_MATERIAL: StandardMaterial3D = preload("res://materials/damage_number_crit_material.tres")
const NO_CRIT_ROLL: float = 0.99
const CRIT_ROLL: float = 0.0

var _registry: EnemyRegistry
var _player: Player
var _pool: DamageNumberPool


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	# Strikes land at the humanoid clip's hit window: the tests drive it by
	# hand, and a unit combo keeps one strike = one old swing.
	ComboDriver.drive_by_hand(_player)
	ComboDriver.use_unit_combo(_player)
	_pool = auto_free(DamageNumberPool.new())
	_pool.player = _player
	_pool.config = CONFIG
	_pool.material = MATERIAL
	_pool.crit_material = CRIT_MATERIAL
	add_child(_pool)


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func test_ac32_normal_hit_shows_a_plain_number_above_the_enemy() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	assert_int(_pool.active_count()).is_equal(1)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_str(number.get_text()).is_equal("15")
	assert_bool(number.is_crit()).is_false()
	assert_vector(number.scale).is_equal_approx(Vector3.ONE * CONFIG.normal_scale, Vector3(0.001, 0.001, 0.001))
	assert_float(number.global_position.y).is_equal_approx(enemy.global_position.y + CONFIG.spawn_height, 0.001)
	assert_float(Vector2(number.global_position.x - enemy.global_position.x, number.global_position.z - enemy.global_position.z).length()).is_less_equal(CONFIG.spread * sqrt(2.0) + 0.001)


func test_ac33_critical_hit_shows_a_bigger_number() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	ComboDriver.strike(_player, CRIT_ROLL)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_str(number.get_text()).is_equal("30" + CONFIG.crit_suffix)
	assert_bool(number.is_crit()).is_true()
	assert_vector(number.scale).is_equal_approx(Vector3.ONE * CONFIG.crit_pop_scale, Vector3(0.001, 0.001, 0.001))


func test_ac33_every_digit_renders_geometry() -> void:
	# Regression: emboldened fonts left some digits (e.g. "4") without geometry.
	for digit: int in 10:
		_pool.spawn(float(digit), true, Vector3.ZERO)
		var number: DamageNumber = _pool.get_last_spawned()
		assert_int(number.mesh.get_faces().size()).is_greater(0)


func test_ac34_number_rises_fades_and_returns_to_the_pool() -> void:
	_pool.spawn(15.0, false, Vector3.ZERO)
	var number: DamageNumber = _pool.get_last_spawned()
	number.advance(CONFIG.lifetime * CONFIG.fade_start * 0.9)
	assert_float(number.transparency).is_equal_approx(CONFIG.normal_transparency, 0.0001)
	assert_float(number.global_position.y).is_greater(0.0)
	number.advance(CONFIG.lifetime * 0.2)
	assert_float(number.transparency).is_greater(CONFIG.normal_transparency)
	number.advance(CONFIG.lifetime)
	assert_bool(number.is_active()).is_false()
	assert_bool(number.visible).is_false()
	assert_int(_pool.active_count()).is_equal(0)


func test_ac35_full_pool_recycles_the_oldest_number() -> void:
	for i: int in CONFIG.pool_size + 5:
		_pool.spawn(float(i), false, Vector3.ZERO)
		assert_int(_pool.active_count()).is_less_equal(CONFIG.pool_size)
	assert_int(_pool.active_count()).is_equal(CONFIG.pool_size)
	assert_str(_pool.get_last_spawned().get_text()).is_equal(str(CONFIG.pool_size + 4))


func test_ac136_normal_number_is_white_smaller_and_dimmer() -> void:
	_pool.spawn(15.0, false, Vector3.ZERO)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_str(number.get_text()).is_equal("15")
	assert_object(number.material_override).is_same(MATERIAL)
	assert_vector(number.scale).is_equal_approx(Vector3.ONE * CONFIG.normal_scale, Vector3(0.001, 0.001, 0.001))
	assert_float(number.transparency).is_equal_approx(CONFIG.normal_transparency, 0.0001)


func test_ac137_crit_number_is_amber_with_suffix_and_pops() -> void:
	_pool.spawn(22.5, true, Vector3.ZERO)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_str(number.get_text()).is_equal("23!")
	assert_object(number.material_override).is_same(CRIT_MATERIAL)
	assert_float(number.transparency).is_equal_approx(0.0, 0.0001)
	assert_float(number.scale.x).is_equal_approx(CONFIG.crit_pop_scale, 0.001)
	number.advance(CONFIG.crit_pop_duration / 2.0)
	assert_float(number.scale.x).is_between(CONFIG.crit_scale + 0.001, CONFIG.crit_pop_scale - 0.001)
	number.advance(CONFIG.crit_pop_duration)
	assert_float(number.scale.x).is_equal_approx(CONFIG.crit_scale, 0.001)


func test_ac138_crit_floats_slower_and_longer() -> void:
	_pool.spawn(15.0, false, Vector3.ZERO)
	var normal: DamageNumber = _pool.get_last_spawned()
	_pool.spawn(22.5, true, Vector3.ZERO)
	var crit: DamageNumber = _pool.get_last_spawned()
	normal.advance(0.1)
	crit.advance(0.1)
	assert_float(crit.global_position.y).is_less(normal.global_position.y)
	normal.advance(0.8)
	crit.advance(0.8)
	assert_bool(normal.is_active()).is_false()
	assert_bool(crit.is_active()).is_true()
	crit.advance(0.2)
	assert_bool(crit.is_active()).is_false()


func test_ac139_fade_starts_from_each_base_transparency() -> void:
	_pool.spawn(22.5, true, Vector3.ZERO)
	var crit: DamageNumber = _pool.get_last_spawned()
	crit.advance(CONFIG.crit_lifetime * CONFIG.fade_start * 0.9)
	assert_float(crit.transparency).is_equal_approx(0.0, 0.0001)
	crit.advance(CONFIG.crit_lifetime * 0.2)
	assert_float(crit.transparency).is_between(0.001, 0.999)


func test_ac140_recycled_crit_comes_back_as_a_normal_number() -> void:
	for i: int in CONFIG.pool_size:
		_pool.spawn(22.5, true, Vector3.ZERO)
	var oldest: DamageNumber = _pool.get_last_spawned()
	for i: int in CONFIG.pool_size:
		_pool.spawn(15.0, false, Vector3.ZERO)
	assert_bool(oldest.is_crit()).is_false()
	assert_str(oldest.get_text()).is_equal("15")
	assert_object(oldest.material_override).is_same(MATERIAL)
	assert_vector(oldest.scale).is_equal_approx(Vector3.ONE * CONFIG.normal_scale, Vector3(0.001, 0.001, 0.001))
	oldest.advance(CONFIG.lifetime + 0.01)
	assert_bool(oldest.is_active()).is_false()
