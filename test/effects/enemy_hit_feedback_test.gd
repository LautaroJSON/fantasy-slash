extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const BAR_CONFIG: HealthBarConfig = preload("res://data/ui/enemy_health_bar_config.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const NO_CRIT_ROLL: float = 0.99
const CRIT_ROLL: float = 0.0
## A quarter of an oscillation: the shake offset is at its peak there.
const PEAK_DELTA_FACTOR: float = 0.25

var _registry: EnemyRegistry
var _player: Player
var _feedback: EnemyHitFeedback


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
	_feedback = auto_free(EnemyHitFeedback.new())
	_feedback.player = _player
	add_child(_feedback)


func _spawn_enemy(at: Vector3, level: int) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player, level)
	return enemy


func _rest_position() -> Vector3:
	return Vector3(0.0, BAR_CONFIG.height_offset, 0.0)


func test_ac141_should_shake_on_crit_or_a_third_of_max_health() -> void:
	assert_bool(EnemyHealthBar.should_shake(1.0, 40.0, true, BAR_CONFIG)).is_true()
	assert_bool(EnemyHealthBar.should_shake(14.0, 40.0, false, BAR_CONFIG)).is_true()
	assert_bool(EnemyHealthBar.should_shake(13.0, 40.0, false, BAR_CONFIG)).is_false()


func test_ac142_crit_shakes_the_bar_then_it_settles_at_rest() -> void:
	# Level 10 (112 HP) so the 22.5 crit is far below a third of max health.
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5), 10)
	ComboDriver.strike(_player, CRIT_ROLL)
	var bar: EnemyHealthBar = enemy.health_bar
	assert_bool(bar.is_shaking()).is_true()
	bar.advance_shake(PEAK_DELTA_FACTOR / BAR_CONFIG.shake_frequency)
	assert_float(bar.position.distance_to(_rest_position())).is_greater(0.001)
	bar.advance_shake(BAR_CONFIG.shake_duration)
	assert_bool(bar.is_shaking()).is_false()
	assert_vector(bar.position).is_equal_approx(_rest_position(), Vector3(0.0001, 0.0001, 0.0001))


func test_ac142_heavy_normal_hit_shakes_the_bar() -> void:
	# Level 1 (40 HP): a 15 normal hit is above a third of max health.
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5), 1)
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	assert_bool(enemy.health_bar.is_shaking()).is_true()


func test_ac143_small_normal_hit_does_not_shake() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5), 10)
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	assert_float(enemy.health.current_health).is_less(enemy.health.max_health)
	assert_bool(enemy.health_bar.is_shaking()).is_false()


func test_ac143_bleed_tick_does_not_shake_even_when_heavy() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -8.0), 1)
	# 40 % of max health per tick: heavy, but a debuff tick is not a player hit.
	enemy.debuffs.apply(BLEED, 0.4)
	enemy.debuffs.advance(BLEED.tick_interval)
	assert_float(enemy.health.current_health).is_less(enemy.health.max_health)
	assert_bool(enemy.health_bar.is_shaking()).is_false()


func test_ac144_reset_stops_the_shake() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5), 10)
	ComboDriver.strike(_player, CRIT_ROLL)
	var bar: EnemyHealthBar = enemy.health_bar
	bar.advance_shake(PEAK_DELTA_FACTOR / BAR_CONFIG.shake_frequency)
	enemy.activate(Vector3(3.0, 0.0, -8.0), _player, 1)
	assert_bool(bar.is_shaking()).is_false()
	assert_vector(bar.position).is_equal_approx(_rest_position(), Vector3(0.0001, 0.0001, 0.0001))
