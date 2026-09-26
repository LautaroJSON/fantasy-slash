extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const BAR_CONFIG: HealthBarConfig = preload("res://data/ui/enemy_health_bar_config.tres")
const LETHAL_HIT: float = 100000.0

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


func _spawn_enemy(at: Vector3, level: int) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player, level)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_ac130_level_5_enemy_has_scaled_health_and_damage() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5), 5)
	assert_int(enemy.level).is_equal(5)
	assert_float(enemy.health.max_health).is_equal_approx(72.0, 0.0001)
	assert_float(enemy.get_scaled_stats().damage).is_equal_approx(11.2, 0.0001)
	await _physics_frames(65)
	# One telegraphed punch in 65 frames: 11.2 × 1.5 damage - 3 player defense = 13.8.
	assert_float(_player.health.current_health).is_equal_approx(86.2, 0.0001)


func test_ac131_shared_stats_resource_is_never_mutated() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -8.0), 10)
	_spawn_enemy(Vector3(3.0, 0.0, -8.0), 10)
	assert_float(GRUNT_STATS.max_health).is_equal_approx(40.0, 0.0001)
	assert_float(GRUNT_STATS.damage).is_equal_approx(8.0, 0.0001)
	assert_float(GRUNT_STATS.move_speed).is_equal_approx(3.5, 0.0001)


func test_ac132_recycled_enemy_takes_the_new_level() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -8.0), 5)
	enemy.health.receive_hit(LETHAL_HIT)
	enemy.activate(Vector3(3.0, 0.0, -8.0), _player, 1)
	assert_int(enemy.level).is_equal(1)
	assert_float(enemy.health.max_health).is_equal_approx(GRUNT_STATS.max_health, 0.0001)
	assert_float(enemy.get_scaled_stats().damage).is_equal_approx(GRUNT_STATS.damage, 0.0001)
	assert_str(enemy.health_bar.get_level_text()).is_equal("lv. 1")


func test_ac133_label_shows_the_level_left_of_the_bar() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -8.0), 3)
	assert_str(enemy.health_bar.get_level_text()).is_equal("lv. 3")
	var label: MeshInstance3D = enemy.health_bar.get_node("LevelLabel") as MeshInstance3D
	var right_edge: float = label.position.x + label.mesh.get_aabb().end.x
	assert_float(right_edge).is_equal_approx(-BAR_CONFIG.size.x / 2.0 - BAR_CONFIG.level_gap, 0.02)


func test_ac133_label_is_hidden_with_the_bar_until_the_first_hit() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -8.0), 3)
	var label: MeshInstance3D = enemy.health_bar.get_node("LevelLabel") as MeshInstance3D
	assert_bool(label.is_visible_in_tree()).is_false()
	enemy.health.receive_hit(1.0)
	assert_bool(label.is_visible_in_tree()).is_true()


func test_ac133_pooled_enemies_do_not_share_the_label_text() -> void:
	var first: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -8.0), 2)
	var second: Enemy = _spawn_enemy(Vector3(3.0, 0.0, -8.0), 7)
	assert_str(first.health_bar.get_level_text()).is_equal("lv. 2")
	assert_str(second.health_bar.get_level_text()).is_equal("lv. 7")
