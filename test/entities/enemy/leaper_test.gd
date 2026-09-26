extends GdUnitTestSuite
## Saltador (docs/specs/enemy-types.md): 0.7 s windup (42 frames), 0.8 s leap
## (48 frames) up to 2 m high, slam radius 2 m, 9 × 2 - 3 = 15 per hit.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const STATS: EnemyStats = preload("res://data/enemies/leaper_stats.tres")
const LEAP: LeapAttackData = preload("res://data/enemies/attacks/leaper_leap.tres")
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


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _leaper(enemy: Enemy) -> LeaperBehavior:
	return enemy.get_behavior() as LeaperBehavior


func test_ac421_landing_point_is_locked_at_the_end_of_the_windup() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -6.0))
	await _physics_frames(46)
	assert_int(_leaper(enemy).get_phase()).is_equal(LeaperBehavior.Phase.AIRBORNE)
	assert_float(_leaper(enemy).get_landing_point().z).is_equal_approx(0.0, 0.1)
	_player.global_position = Vector3(0.0, 0.0, 4.0)
	await _physics_frames(60)
	assert_int(_leaper(enemy).get_phase()).is_not_equal(LeaperBehavior.Phase.AIRBORNE)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac422_the_slam_hits_once_inside_its_radius() -> void:
	_spawn(Vector3(0.0, 0.0, -6.0))
	await _physics_frames(110)
	assert_float(_player.health.current_health).is_equal_approx(85.0, 0.0001)


func test_ac423_jumps_high_and_lands_after_leap_time() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -6.0))
	var highest: float = 0.0
	var airborne_frames: int = 0
	for i: int in 150:
		await get_tree().physics_frame
		highest = maxf(highest, enemy.global_position.y)
		if _leaper(enemy).get_phase() == LeaperBehavior.Phase.AIRBORNE:
			airborne_frames += 1
	assert_float(highest).is_greater(1.5)
	var expected: int = int(LEAP.leap_time * PHYSICS_FPS)
	assert_int(airborne_frames).is_between(expected - 4, expected + 4)


func test_ac424_leap_length_is_clamped() -> void:
	var start := Vector3(0.0, 0.0, -6.0)
	var enemy: Enemy = _spawn(start)
	await _physics_frames(20)
	_player.global_position = Vector3(0.0, 0.0, 10.0)
	await _physics_frames(120)
	var landing: Vector3 = _leaper(enemy).get_landing_point()
	assert_float(Vector2(landing.x - start.x, landing.z - start.z).length()).is_less_equal(LEAP.max_leap_distance + 0.01)
	assert_float(Vector2(enemy.global_position.x - landing.x, enemy.global_position.z - landing.z).length()).is_less(0.5)


func test_ac425_push_cancels_the_windup_but_not_the_leap() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -6.0))
	await _physics_frames(10)
	enemy.apply_knockback(Vector3(0.0, 0.0, -1.0), 3.0)
	assert_int(_leaper(enemy).get_phase()).is_equal(LeaperBehavior.Phase.CHASE)
	# Let it wind up again and take off.
	for i: int in 120:
		await get_tree().physics_frame
		if _leaper(enemy).get_phase() == LeaperBehavior.Phase.AIRBORNE:
			break
	assert_int(_leaper(enemy).get_phase()).is_equal(LeaperBehavior.Phase.AIRBORNE)
	enemy.apply_knockback(Vector3(0.0, 0.0, -1.0), 3.0)
	assert_bool(enemy.is_knocked_back()).is_false()
	assert_int(_leaper(enemy).get_phase()).is_equal(LeaperBehavior.Phase.AIRBORNE)
