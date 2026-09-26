extends GdUnitTestSuite
## Spawn-in (docs/specs/enemy-group-ai.md): 0.9 s rising from 2 m below.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CONFIG: GroupAIConfig = preload("res://data/enemies/group_ai_config.tres")

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


func _spawn_rising(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	enemy.begin_spawn_in(CONFIG)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_ac453_while_rising_it_neither_moves_nor_attacks() -> void:
	var enemy: Enemy = _spawn_rising(Vector3(0.0, 0.0, -1.5))
	var start: Vector3 = enemy.global_position
	await _physics_frames(30)
	assert_bool(enemy.is_spawning_in()).is_true()
	assert_float(Vector2(enemy.global_position.x - start.x, enemy.global_position.z - start.z).length()).is_less(0.01)
	assert_bool(enemy.get_behavior().is_attacking()).is_false()
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)
	assert_bool(enemy.get_spawn_marker().visible).is_true()
	assert_float(enemy.get_body().position.y).is_less(enemy.get_body_rest_height() - 0.05)


func test_ac454_after_spawn_in_time_it_is_in_place_and_acts() -> void:
	var enemy: Enemy = _spawn_rising(Vector3(0.0, 0.0, -1.5))
	await _physics_frames(int(CONFIG.spawn_in_time * 60.0) + 2)
	assert_bool(enemy.is_spawning_in()).is_false()
	assert_bool(enemy.get_spawn_marker().visible).is_false()
	assert_float(enemy.get_body().position.y).is_equal_approx(enemy.get_body_rest_height(), 0.0001)
	assert_float(enemy.get_hands().position.y).is_equal_approx(0.0, 0.0001)
	await _physics_frames(3)
	assert_bool(enemy.get_behavior().is_attacking()).is_true()


func test_ac455_while_rising_it_is_alive_and_can_be_hit() -> void:
	var enemy: Enemy = _spawn_rising(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(5)
	assert_int(_registry.alive_count()).is_equal(1)
	assert_float(enemy.health.receive_hit(10.0)).is_greater(0.0)


func test_ac457_activate_cancels_a_spawn_in() -> void:
	var enemy: Enemy = _spawn_rising(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(5)
	enemy.activate(Vector3(0.0, 0.0, -10.0), _player)
	assert_bool(enemy.is_spawning_in()).is_false()
	assert_bool(enemy.get_spawn_marker().visible).is_false()
	assert_float(enemy.get_body().position.y).is_equal_approx(enemy.get_body_rest_height(), 0.0001)
