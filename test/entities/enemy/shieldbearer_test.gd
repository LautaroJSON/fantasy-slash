extends GdUnitTestSuite
## Escudero (docs/specs/enemy-types.md). A raw hit of 53 minus its 3 defense
## is 50; blocked, 80 % less: 10. The enemy spawns at +Z so its initial
## facing (−Z) already points at the player at the origin.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const STATS: EnemyStats = preload("res://data/enemies/shieldbearer_stats.tres")
const GUARD: GuardConfig = preload("res://data/enemies/configs/shieldbearer_guard.tres")
const RAW_HIT: float = 53.0
const FULL: float = 50.0
const BLOCKED: float = 10.0

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


func test_ac432_front_hits_are_blocked() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, 5.0))
	await _physics_frames(2)
	assert_float(enemy.health.receive_hit(RAW_HIT)).is_equal_approx(BLOCKED, 0.0001)


func test_ac433_hits_from_behind_are_not_blocked() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, 5.0))
	await _physics_frames(2)
	_player.global_position = Vector3(0.0, 0.0, 9.0)
	await _physics_frames(1)
	assert_float(enemy.health.receive_hit(RAW_HIT)).is_equal_approx(FULL, 0.0001)


func test_ac434_front_pushes_are_ignored_back_pushes_move_it() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, 5.0))
	await _physics_frames(2)
	enemy.apply_knockback(Vector3(0.0, 0.0, 1.0), 5.0)
	assert_bool(enemy.is_knocked_back()).is_false()
	_player.global_position = Vector3(0.0, 0.0, 9.0)
	await _physics_frames(1)
	enemy.apply_knockback(Vector3(0.0, 0.0, -1.0), 5.0)
	assert_bool(enemy.is_knocked_back()).is_true()


func test_ac435_guard_is_down_during_the_bash_and_after_it() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, 1.9))
	await _physics_frames(5)
	var behavior: ShieldbearerBehavior = enemy.get_behavior() as ShieldbearerBehavior
	assert_int(behavior.get_phase()).is_equal(MeleeBehavior.Phase.WINDUP)
	assert_float(enemy.health.receive_hit(RAW_HIT)).is_equal_approx(FULL, 0.0001)
	enemy.health.heal(enemy.health.max_health)
	# Windup + active + recovery = 2 s (120 frames); 0.5 s into guard_down_time.
	await _physics_frames(145)
	assert_bool(behavior.is_attacking()).is_false()
	assert_bool(behavior.is_guarding()).is_false()
	assert_float(enemy.health.receive_hit(RAW_HIT)).is_equal_approx(FULL, 0.0001)
	enemy.health.heal(enemy.health.max_health)
	# Past guard_down_time (1.2 s) and still in the cooldown: guard up again.
	await _physics_frames(50)
	assert_bool(behavior.is_guarding()).is_true()
	assert_float(enemy.health.receive_hit(RAW_HIT)).is_equal_approx(BLOCKED, 0.0001)


func test_ac436_turns_slowly_so_it_can_be_flanked() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, 5.0))
	await _physics_frames(2)
	var yaw: float = enemy.rotation.y
	# 90° to its side: in 10 frames it turns ~16.7°, still outside the 70° half-arc.
	_player.global_position = Vector3(5.0, 0.0, 5.0)
	await _physics_frames(10)
	var max_turn: float = deg_to_rad(GUARD.guard_turn_speed) * 11.0 / 60.0
	assert_float(absf(angle_difference(yaw, enemy.rotation.y))).is_less_equal(max_turn)
	assert_float(enemy.health.receive_hit(RAW_HIT)).is_equal_approx(FULL, 0.0001)
