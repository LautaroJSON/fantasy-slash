extends GdUnitTestSuite
## Hostigador (docs/specs/enemy-types.md): orbits at 4 m, strikes on an
## opening, 0.3 s windup and a lunge that stops 1 m short; 7 × 1.8 - 3 = 9.6.
## The player faces −Z by default.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const STATS: EnemyStats = preload("res://data/enemies/harasser_stats.tres")
const CONFIG: HarasserConfig = preload("res://data/enemies/configs/harasser_config.tres")
const LUNGE: LungeAttackData = preload("res://data/enemies/attacks/harasser_lunge.tres")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const PHYSICS_FPS: float = 60.0

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


func _spawn(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = STATS
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _harasser(enemy: Enemy) -> HarasserBehavior:
	return enemy.get_behavior() as HarasserBehavior


## Keeps the player looking at the enemy, so its back is never shown.
func _face(enemy: Enemy) -> void:
	var to_enemy: Vector3 = enemy.global_position - _player.global_position
	(_player.get_node("Visual") as Node3D).rotation.y = atan2(-to_enemy.x, -to_enemy.z)


func _flat_distance(enemy: Enemy) -> float:
	return Vector2(enemy.global_position.x - _player.global_position.x, enemy.global_position.z - _player.global_position.z).length()


func test_ac426_orbits_without_an_opening() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -4.0))
	var start: Vector3 = enemy.global_position
	for i: int in 200:
		_face(enemy)
		await get_tree().physics_frame
		assert_int(_harasser(enemy).get_phase()).is_equal(HarasserBehavior.Phase.ORBIT)
	assert_float(_flat_distance(enemy)).is_between(CONFIG.orbit_radius - 0.5, CONFIG.orbit_radius + 0.5)
	assert_float(enemy.global_position.distance_to(start)).is_greater(2.0)


func test_ac427_strikes_when_the_player_shows_its_back() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, 4.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_harasser(enemy).get_phase()).is_equal(HarasserBehavior.Phase.WINDUP)


func test_ac428_strikes_right_after_a_player_attack() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -4.0))
	for i: int in 10:
		_face(enemy)
		await get_tree().physics_frame
	assert_int(_harasser(enemy).get_phase()).is_equal(HarasserBehavior.Phase.ORBIT)
	_player.attack_performed.emit()
	_face(enemy)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_harasser(enemy).get_phase()).is_equal(HarasserBehavior.Phase.WINDUP)


func test_ac429_strikes_anyway_after_max_patience() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -4.0))
	var frames: int = 0
	while _harasser(enemy).get_phase() == HarasserBehavior.Phase.ORBIT and frames < 400:
		_face(enemy)
		await get_tree().physics_frame
		frames += 1
	var expected: int = int(CONFIG.max_patience * PHYSICS_FPS)
	assert_int(frames).is_between(expected - 3, expected + 3)


func test_ac430_the_lunge_stops_short_and_hits_once() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, 4.0))
	for i: int in 60:
		await get_tree().physics_frame
	assert_float(_flat_distance(enemy)).is_between(LUNGE.stop_distance - 0.15, LUNGE.stop_distance + 0.15)
	assert_float(_player.health.current_health).is_equal_approx(90.4, 0.0001)


func test_ac431_player_facing_and_attack_signal() -> void:
	var visual: Node3D = _player.get_node("Visual") as Node3D
	visual.rotation.y = 0.5
	var forward: Vector3 = -visual.global_basis.z
	assert_vector(_player.get_facing()).is_equal_approx(Vector3(forward.x, 0.0, forward.z).normalized(), Vector3(0.0001, 0.0001, 0.0001))
	var count: Array[int] = [0]
	_player.attack_performed.connect(func() -> void: count[0] += 1)
	assert_bool(_player.attack.try_attack_with_roll(0.99)).is_true()
	assert_int(count[0]).is_equal(1)
	_player.basic_ability.equip(THRUST)
	assert_bool(_player.basic_ability.try_cast()).is_true()
	assert_int(count[0]).is_equal(2)
