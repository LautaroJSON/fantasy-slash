extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SWIFT_STRIKE: AbilityData = preload("res://data/abilities/swift_strike/swift_strike.tres")
const INDICATOR_CONFIG: AbilityIndicatorConfig = preload("res://data/abilities/swift_strike/swift_strike_indicator_config.tres")
const ENEMY_HEALTH: float = 40.0
## Base slice with the base player DAMAGE (15): 12 + 0.10 x 15.
const BASE_HIT: float = 13.5
## Physics frames that comfortably cover the whole sprint.
const SPRINT_FRAMES: int = 40
const DISTANCE_TOLERANCE: float = 0.1

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent


func before_test() -> void:
	_add_static(TestWorld.make_floor(60.0))
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_ability.equip(SWIFT_STRIKE)
	await _physics_frames(20)


func after_test() -> void:
	Input.action_release(&"attack")


func _add_static(body: StaticBody3D) -> void:
	auto_free(body)
	add_child(body)


## Enemies without a target stand still, so only the sprint moves things.
func _spawn_idle_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_ac75_sprints_its_range_towards_the_nearest_enemy_then_stops() -> void:
	_spawn_idle_enemy(Vector3(9.0, 0.0, 0.0))
	var start: Vector3 = _player.global_position
	assert_bool(_ability.try_cast()).is_true()
	await _physics_frames(SPRINT_FRAMES)
	assert_bool(_ability.is_casting()).is_false()
	assert_float(_player.global_position.x - start.x).is_equal_approx(SWIFT_STRIKE.hit_range, DISTANCE_TOLERANCE)
	assert_float(_player.global_position.z - start.z).is_equal_approx(0.0, DISTANCE_TOLERANCE)
	var stopped_at: Vector3 = _player.global_position
	await _physics_frames(10)
	assert_float(_flat_distance(_player.global_position, stopped_at)).is_less(0.01)


func test_ac75_without_enemies_sprints_where_the_player_faces() -> void:
	var start: Vector3 = _player.global_position
	_ability.try_cast()
	await _physics_frames(SPRINT_FRAMES)
	assert_float(start.z - _player.global_position.z).is_equal_approx(SWIFT_STRIKE.hit_range, DISTANCE_TOLERANCE)
	assert_float(_player.global_position.x - start.x).is_equal_approx(0.0, DISTANCE_TOLERANCE)


func test_ac76_slices_every_enemy_on_the_path_once() -> void:
	var first: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	var near_edge: Enemy = _spawn_idle_enemy(Vector3(0.4, 0.0, -4.0))
	var outside: Enemy = _spawn_idle_enemy(Vector3(1.0, 0.0, -3.0))
	var beyond: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -7.5))
	var hits: Array[int] = [0]
	_ability.enemy_hit.connect(func(_e: Enemy, _a: float, _c: bool) -> void: hits[0] += 1)
	_ability.try_cast()
	await _physics_frames(SPRINT_FRAMES)
	assert_float(first.health.current_health).is_equal_approx(ENEMY_HEALTH - BASE_HIT, 0.0001)
	assert_float(near_edge.health.current_health).is_equal_approx(ENEMY_HEALTH - BASE_HIT, 0.0001)
	assert_float(outside.health.current_health).is_equal(ENEMY_HEALTH)
	assert_float(beyond.health.current_health).is_equal(ENEMY_HEALTH)
	assert_int(hits[0]).is_equal(2)


func test_ac77_a_wall_cuts_the_sprint() -> void:
	_add_static(TestWorld.make_box(Vector3(10.0, 3.0, 1.0), Vector3(0.0, 1.5, -3.0)))
	_ability.try_cast()
	await _physics_frames(SPRINT_FRAMES)
	assert_float(_player.global_position.z).is_greater(-2.5)


func test_ac78_no_invulnerability_and_no_other_actions_while_sprinting() -> void:
	var swings: Array[int] = [0]
	_player.attack.attacked.connect(func(_h: int, _t: float, _c: bool) -> void: swings[0] += 1)
	_ability.try_cast()
	Input.action_press(&"attack")
	await _physics_frames(5)
	assert_bool(_player.is_casting()).is_true()
	assert_bool(_player.health.is_invulnerable).is_false()
	assert_bool(_player.dash.is_dashing()).is_false()
	assert_int(swings[0]).is_equal(0)
	await _physics_frames(SPRINT_FRAMES)
	# Each tap is one strike (humanoid-player-model.md): tap again after the cast.
	Input.action_release(&"attack")
	await _physics_frames(1)
	Input.action_press(&"attack")
	await _physics_frames(30)
	assert_int(swings[0]).is_greater(0)


func test_ac79_range_upgrade_lengthens_sprint_and_indicator() -> void:
	var upgrade: AbilityUpgradeData = SWIFT_STRIKE.upgrades[AbilityData.Stat.HIT_RANGE]
	_player.apply_upgrade(upgrade)
	var start: Vector3 = _player.global_position
	_ability.try_cast()
	var indicator: AbilityRectIndicator = (_ability.get_behavior() as SwiftStrikeAbility).get_indicator()
	assert_bool(indicator.is_showing()).is_true()
	# Adapted (docs/specs/spin-visual-rework.md §2.6): one fill instead of the outline.
	assert_float(indicator.get_length()).is_equal_approx(7.5, 0.01)
	assert_float(indicator.get_width()).is_equal_approx(SWIFT_STRIKE.hit_width, 0.01)
	await _physics_frames(SPRINT_FRAMES)
	assert_float(start.z - _player.global_position.z).is_equal_approx(7.5, DISTANCE_TOLERANCE)
