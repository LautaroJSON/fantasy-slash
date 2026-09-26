extends GdUnitTestSuite

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const BAR_CONFIG: HealthBarConfig = preload("res://data/ui/enemy_health_bar_config.tres")

var _registry: EnemyRegistry
var _enemy: Enemy
var _bar: EnemyHealthBar


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_enemy = auto_free(ENEMY_SCENE.instantiate())
	_enemy.registry = _registry
	add_child(_enemy)
	_enemy.activate(Vector3.ZERO, null)
	_bar = _enemy.get_node("HealthBar") as EnemyHealthBar


func test_ac28_bar_is_hidden_and_full_until_the_first_hit() -> void:
	assert_bool(_bar.visible).is_false()
	assert_float(_bar.get_fill_ratio()).is_equal_approx(1.0, 0.0001)
	assert_float(_bar.get_trail_ratio()).is_equal_approx(1.0, 0.0001)


func test_ac28_hit_shows_the_bar_and_drops_the_fill_instantly() -> void:
	_enemy.health.receive_hit(15.0)
	assert_bool(_bar.visible).is_true()
	assert_float(_bar.get_fill_ratio()).is_equal_approx(0.625, 0.0001)
	assert_float(_bar.get_trail_ratio()).is_equal_approx(1.0, 0.0001)


func test_ac29_trail_holds_then_drains_down_to_the_fill() -> void:
	_enemy.health.receive_hit(15.0)
	_bar.advance(BAR_CONFIG.trail_hold_time - 0.05)
	assert_float(_bar.get_trail_ratio()).is_equal_approx(1.0, 0.0001)
	_bar.advance(0.1)
	for i: int in 60:
		_bar.advance(1.0 / 60.0)
		assert_float(_bar.get_trail_ratio()).is_greater_equal(_bar.get_fill_ratio())
	assert_float(_bar.get_trail_ratio()).is_equal_approx(0.625, 0.0001)


func test_ac30_second_hit_keeps_the_trail_and_restarts_the_hold() -> void:
	_enemy.health.receive_hit(15.0)
	_bar.advance(BAR_CONFIG.trail_hold_time + 0.05)
	_bar.advance(0.1)
	var trail_before: float = _bar.get_trail_ratio()
	assert_float(trail_before).is_less(1.0)
	_enemy.health.receive_hit(15.0)
	assert_float(_bar.get_fill_ratio()).is_equal_approx(0.25, 0.0001)
	assert_float(_bar.get_trail_ratio()).is_equal_approx(trail_before, 0.0001)
	_bar.advance(BAR_CONFIG.trail_hold_time - 0.05)
	assert_float(_bar.get_trail_ratio()).is_equal_approx(trail_before, 0.0001)


func test_ac31_recycled_enemy_comes_back_with_a_hidden_full_bar() -> void:
	_enemy.health.receive_hit(15.0)
	_enemy.health.receive_hit(1000.0)
	assert_bool(_enemy.visible).is_false()
	_enemy.activate(Vector3(3.0, 0.0, 0.0), null)
	assert_bool(_bar.visible).is_false()
	assert_float(_bar.get_fill_ratio()).is_equal_approx(1.0, 0.0001)
	assert_float(_bar.get_trail_ratio()).is_equal_approx(1.0, 0.0001)
