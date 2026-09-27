extends GdUnitTestSuite
## docs/specs/affliction.md: the Affliction bars of an enemy (AfflictionComponent).

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CONFIG: AfflictionConfig = preload("res://data/combat/affliction_config.tres")
const SHIELDBEARER: EnemyStats = preload("res://data/enemies/shieldbearer_stats.tres")
const FRAME: float = 1.0 / 60.0


func _spawn_enemy() -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	add_child(enemy)
	enemy.activate(Vector3.ZERO, null)
	return enemy


func _advance(bars: AfflictionComponent, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		var step: float = minf(FRAME, left)
		bars.advance(step)
		left -= step


func test_ac861_buildup_formula() -> void:
	assert_float(AfflictionLoadout.buildup(20.0, 1.0, 0.0, 0.0)).is_equal_approx(20.0, 0.0001)
	assert_float(AfflictionLoadout.buildup(20.0, 2.3, 0.2, 0.5)).is_equal_approx(27.6, 0.0001)


func test_ac863_the_rest_of_a_filling_hit_is_dropped() -> void:
	var bars: AfflictionComponent = _spawn_enemy().afflictions
	assert_bool(bars.add_buildup(0, 90.0)).is_false()
	assert_float(bars.get_ratio(0)).is_equal_approx(0.9, 0.0001)
	assert_bool(bars.add_buildup(0, 20.0)).is_true()
	assert_float(bars.get_buildup(0)).is_equal(0.0)
	assert_bool(bars.is_flashing(0)).is_true()


func test_ac869_a_bar_drains_after_five_idle_seconds() -> void:
	var bars: AfflictionComponent = _spawn_enemy().afflictions
	bars.add_buildup(0, 60.0)
	bars.add_buildup(1, 30.0)
	_advance(bars, 5.0)
	assert_float(bars.get_buildup(0)).is_equal_approx(60.0, 0.01)
	_advance(bars, 1.0)
	assert_float(bars.get_buildup(0)).is_equal_approx(45.0, 0.01)
	bars.add_buildup(1, 10.0)
	_advance(bars, 1.0)
	assert_float(bars.get_buildup(0)).is_equal_approx(30.0, 0.01)
	assert_float(bars.get_buildup(1)).is_equal_approx(25.0, 0.01)
	bars.add_buildup(0, 1.0)
	_advance(bars, 4.9)
	assert_float(bars.get_buildup(0)).is_equal_approx(31.0, 0.01)
	_advance(bars, 0.5)
	assert_float(bars.get_buildup(0)).is_equal_approx(31.0 - 15.0 * 0.4, 0.01)
	_advance(bars, 5.0)
	assert_float(bars.get_buildup(0)).is_equal(0.0)


func test_ac870_reactivating_empties_the_bars() -> void:
	var enemy: Enemy = _spawn_enemy()
	enemy.afflictions.add_buildup(0, 50.0)
	enemy.afflictions.add_buildup(2, 70.0)
	enemy.deactivate()
	enemy.activate(Vector3.ZERO, null)
	for slot: int in CONFIG.max_types:
		assert_float(enemy.afflictions.get_ratio(slot)).is_equal(0.0)


func test_resistance_comes_from_the_enemy_type() -> void:
	var enemy: Enemy = _spawn_enemy()
	assert_float(enemy.afflictions.get_resistance()).is_equal(0.0)
	enemy.afflictions.setup(SHIELDBEARER)
	assert_float(enemy.afflictions.get_resistance()).is_equal(0.25)


func test_ac886_the_flash_ends_after_its_duration() -> void:
	var bars: AfflictionComponent = _spawn_enemy().afflictions
	bars.add_buildup(0, 100.0)
	assert_bool(bars.is_flashing(0)).is_true()
	_advance(bars, CONFIG.flash_duration + FRAME)
	assert_bool(bars.is_flashing(0)).is_false()
	assert_float(bars.get_ratio(0)).is_equal(0.0)
