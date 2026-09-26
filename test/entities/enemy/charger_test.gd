extends GdUnitTestSuite
## Embestidor (docs/specs/enemy-types.md): 0.8 s windup (48 frames), charge at
## 13 m/s for 9 m, 10 × 2 - 3 = 17 per hit.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const STATS: EnemyStats = preload("res://data/enemies/charger_stats.tres")
const CHARGE: ChargeAttackData = preload("res://data/enemies/attacks/charger_charge.tres")
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


func _charger(enemy: Enemy) -> ChargerBehavior:
	return enemy.get_behavior() as ChargerBehavior


func _flat_distance(enemy: Enemy) -> float:
	return Vector2(enemy.global_position.x - _player.global_position.x, enemy.global_position.z - _player.global_position.z).length()


## Frames the recovery lasts (from the end of the charge back to CHASE).
func _measure_recovery(enemy: Enemy) -> int:
	var frames: int = 0
	for i: int in 400:
		await get_tree().physics_frame
		if _charger(enemy).get_phase() == ChargerBehavior.Phase.RECOVERY:
			frames += 1
		elif frames > 0:
			break
	return frames


func test_ac416_winds_up_in_range_and_backs_off_when_too_close() -> void:
	var far: Enemy = _spawn(Vector3(0.0, 0.0, -5.0))
	await _physics_frames(2)
	assert_int(_charger(far).get_phase()).is_equal(ChargerBehavior.Phase.WINDUP)
	far.deactivate()
	var close: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	await _physics_frames(10)
	assert_int(_charger(close).get_phase()).is_equal(ChargerBehavior.Phase.CHASE)
	assert_float(_flat_distance(close)).is_greater(2.2)


func test_ac417_the_charge_keeps_its_locked_direction() -> void:
	_spawn(Vector3(0.0, 0.0, -5.0))
	await _physics_frames(50)
	_player.global_position = Vector3(6.0, 0.0, 0.0)
	await _physics_frames(60)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac418_hits_once_and_runs_through() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -5.0))
	await _physics_frames(100)
	assert_float(_player.health.current_health).is_equal_approx(83.0, 0.0001)
	assert_float(enemy.global_position.z).is_greater(1.0)


func test_ac419_the_charge_covers_at_most_charge_distance() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -5.0))
	await _physics_frames(100)
	assert_int(_charger(enemy).get_phase()).is_equal(ChargerBehavior.Phase.RECOVERY)
	assert_float(_charger(enemy).get_traveled()).is_between(CHARGE.charge_distance - 0.25, CHARGE.charge_distance + 0.001)
	assert_float(enemy.global_position.z).is_between(-5.0 + CHARGE.charge_distance - 0.25, -5.0 + CHARGE.charge_distance + 0.01)


func test_ac420_a_wall_stuns_it_longer() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -5.0))
	var wall: StaticBody3D = auto_free(TestWorld.make_box(Vector3(10.0, 3.0, 1.0), Vector3(0.0, 1.5, 3.0)))
	add_child(wall)
	var frames: int = await _measure_recovery(enemy)
	assert_bool(_charger(enemy).ended_on_wall()).is_true()
	assert_int(frames).is_between(int(CHARGE.wall_stun_time * PHYSICS_FPS) - 2, int(CHARGE.wall_stun_time * PHYSICS_FPS) + 2)


func test_ac420_without_a_wall_the_recovery_is_normal() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -5.0))
	var frames: int = await _measure_recovery(enemy)
	assert_bool(_charger(enemy).ended_on_wall()).is_false()
	assert_int(frames).is_between(int(CHARGE.recovery_time * PHYSICS_FPS) - 2, int(CHARGE.recovery_time * PHYSICS_FPS) + 2)
