extends GdUnitTestSuite

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")


func _make_registry() -> EnemyRegistry:
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	return registry


func _spawn_enemy(registry: EnemyRegistry, at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


func test_ac7_find_nearest_returns_null_without_enemies() -> void:
	var registry: EnemyRegistry = _make_registry()
	assert_object(registry.find_nearest(Vector3.ZERO)).is_null()


func test_ac7_find_nearest_returns_closest_active_enemy() -> void:
	var registry: EnemyRegistry = _make_registry()
	_spawn_enemy(registry, Vector3(0.0, 0.0, -6.0))
	var near: Enemy = _spawn_enemy(registry, Vector3(2.0, 0.0, 0.0))
	_spawn_enemy(registry, Vector3(-4.0, 0.0, 0.0))
	assert_object(registry.find_nearest(Vector3.ZERO)).is_same(near)
	assert_int(registry.alive_count()).is_equal(3)


func test_ac7_deactivated_enemy_is_not_a_candidate() -> void:
	var registry: EnemyRegistry = _make_registry()
	var near: Enemy = _spawn_enemy(registry, Vector3(1.0, 0.0, 0.0))
	var far: Enemy = _spawn_enemy(registry, Vector3(5.0, 0.0, 0.0))
	near.deactivate()
	assert_object(registry.find_nearest(Vector3.ZERO)).is_same(far)
	assert_int(registry.alive_count()).is_equal(1)
