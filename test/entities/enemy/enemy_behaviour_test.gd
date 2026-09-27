extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")

var _registry: EnemyRegistry
var _player: Player


func before_test() -> void:
	_add_static(TestWorld.make_floor(60.0))
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)


func _add_static(body: StaticBody3D) -> void:
	auto_free(body)
	add_child(body)


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_ac13_enemy_in_range_hits_every_attack_interval() -> void:
	# enemy-attack-telegraph: one punch every 1.5 s (0.5 windup + 0.15 active
	# + 0.45 recovery + 0.4 attack_interval), the first one lands at ~0.5 s.
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	await _physics_frames(25)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)
	await _physics_frames(10)
	# 8 damage × 1.5 - 3 defense = 9 per hit.
	assert_float(_player.health.current_health).is_equal_approx(91.0, 0.0001)
	await _physics_frames(60)
	assert_float(_player.health.current_health).is_equal_approx(91.0, 0.0001)
	await _physics_frames(40)
	assert_float(_player.health.current_health).is_equal_approx(82.0, 0.0001)


func test_ac13_enemy_out_of_range_chases_the_player() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(30)
	assert_float(enemy.global_position.z).is_greater(-7.0)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac13_enemy_stops_at_attack_range() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -8.0))
	await _physics_frames(180)
	var distance: float = Vector2(enemy.global_position.x, enemy.global_position.z).length()
	assert_float(distance).is_between(1.8, 2.0)


## Adapted by docs/specs/dash-iframes.md (AC551): the iframes last as long as
## the dash (0.2 s, 12 frames), so the dash is timed right before the punch.
func test_ac14_ac404_ac551_hits_during_the_dash_deal_no_damage() -> void:
	# A wall touching the player's right side blocks the dash, so the player
	# stays in range. The punch (at ~frame 30) lands inside the dash (25-37).
	_add_static(TestWorld.make_box(Vector3(1.0, 3.0, 10.0), Vector3(0.9, 1.5, 0.0)))
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	await _physics_frames(25)
	var dash: DashComponent = _player.get_node("DashComponent") as DashComponent
	assert_bool(dash.try_dash(Vector3.RIGHT)).is_true()
	await _physics_frames(20)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)
	# The next punch (~frame 120) finds the player vulnerable.
	await _physics_frames(80)
	assert_float(_player.health.current_health).is_equal_approx(91.0, 0.0001)


func test_ac551_a_hit_right_after_the_dash_deals_damage() -> void:
	# The dash covers frames 10-22; the punch at ~frame 30 goes through (the
	# old 1 s iframes would have blocked it).
	_add_static(TestWorld.make_box(Vector3(1.0, 3.0, 10.0), Vector3(0.9, 1.5, 0.0)))
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	await _physics_frames(10)
	var dash: DashComponent = _player.get_node("DashComponent") as DashComponent
	assert_bool(dash.try_dash(Vector3.RIGHT)).is_true()
	await _physics_frames(15)
	assert_bool(_player.health.is_invulnerable).is_false()
	await _physics_frames(15)
	assert_float(_player.health.current_health).is_equal_approx(91.0, 0.0001)


func _flat_distance_to_player(enemy: Enemy) -> float:
	return Vector2(enemy.global_position.x - _player.global_position.x, enemy.global_position.z - _player.global_position.z).length()


func test_ac36_player_hit_pushes_the_enemy_back() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	await _physics_frames(2)
	var start: float = _flat_distance_to_player(enemy)
	ComboDriver.drive_by_hand(_player)
	ComboDriver.use_unit_combo(_player)
	assert_bool(ComboDriver.strike(_player, 0.99)).is_true()
	var farthest: float = start
	for i: int in 30:
		await get_tree().physics_frame
		farthest = maxf(farthest, _flat_distance_to_player(enemy))
	# Expected push ≈ 5² / (2 · 20) = 0.625 m, straight away from the player.
	assert_float(farthest - start).is_between(0.5, 0.75)
	assert_float(enemy.global_position.x).is_equal_approx(0.0, 0.05)


func test_ac36_pushed_enemy_comes_back_into_range() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	enemy.apply_knockback(Vector3(0.0, 0.0, -1.0), 5.0)
	await _physics_frames(60)
	assert_float(_flat_distance_to_player(enemy)).is_less_equal(2.0)


func test_ac18_enemy_cannot_cross_a_wall() -> void:
	_add_static(TestWorld.make_box(Vector3(10.0, 3.0, 1.0), Vector3(0.0, 1.5, -5.0)))
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -9.0))
	await _physics_frames(120)
	# Wall far face is at z = -5.5 and the capsule radius is 0.4.
	assert_float(enemy.global_position.z).is_less(-5.5)
