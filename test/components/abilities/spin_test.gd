extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const SPIN_CONFIG: SpinConfig = preload("res://data/abilities/spin/spin_config.tres")
const DURATION_UPGRADE: AbilityUpgradeData = preload("res://data/abilities/spin/upgrades/duration.tres")
const SPEED_UPGRADE: AbilityUpgradeData = preload("res://data/abilities/spin/upgrades/speed.tres")
const RANGE_UPGRADE: AbilityUpgradeData = preload("res://data/abilities/spin/upgrades/range.tres")
const DAMAGE_UPGRADE: AbilityUpgradeData = preload("res://data/abilities/spin/upgrades/damage.tres")
const ENEMY_HEALTH: float = 40.0
const STEP: float = 0.05
const TOLERANCE: float = 0.0001

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _hits: Array[Enemy] = []


func before_test() -> void:
	Session.character_class = BERSERKER
	_add_static(TestWorld.make_floor(60.0))
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_ability.equip(SPIN)
	_hits.clear()
	_ability.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: _hits.append(enemy))
	await _physics_frames(20)


func after_test() -> void:
	Session.character_class = null
	Input.action_release(&"attack")
	Input.action_release(&"dash")
	Input.action_release(&"move_forward")


func _add_static(body: StaticBody3D) -> void:
	auto_free(body)
	add_child(body)


func _spawn_idle_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Drives the cast by hand (the slot's own physics step is off) for determinism.
func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


func _cast_by_hand() -> void:
	_ability.set_physics_process(false)
	assert_bool(_ability.try_cast()).is_true()


func _hit_damage() -> float:
	return _ability.get_stat(AbilityData.Stat.BASE_DAMAGE) \
		+ _ability.get_stat(AbilityData.Stat.ATTACK_SCALING) * _player.stats.get_stat(PlayerStats.Stat.DAMAGE)


func _near(offset: Vector3) -> Vector3:
	return _player.global_position + offset


func test_ac188_three_hits_one_per_completed_turn() -> void:
	var inside: Enemy = _spawn_idle_enemy(_near(Vector3(2.0, 0.0, 0.0)))
	_cast_by_hand()
	_advance(0.9)
	assert_int(_hits.size()).is_equal(0)
	_advance(0.2)
	assert_int(_hits.size()).is_equal(1)
	_advance(1.0)
	assert_int(_hits.size()).is_equal(2)
	_advance(1.0)
	assert_bool(_ability.is_casting()).is_false()
	assert_int(_hits.size()).is_equal(3)
	var expected: float = 8.0 + 0.15 * BERSERKER.base_stats.damage
	assert_float(_hit_damage()).is_equal_approx(expected, TOLERANCE)
	assert_float(inside.health.current_health).is_equal_approx(ENEMY_HEALTH - 3.0 * expected, 0.01)


func test_ac188_enemies_outside_the_radius_are_not_hit() -> void:
	var probe: Enemy = _spawn_idle_enemy(_near(Vector3(0.0, 0.0, 20.0)))
	var outside_at: float = SPIN.hit_range + probe.get_hit_padding() + 0.3
	var outside: Enemy = _spawn_idle_enemy(_near(Vector3(-outside_at, 0.0, 0.0)))
	_cast_by_hand()
	_advance(SPIN.cast_duration)
	assert_float(outside.health.current_health).is_equal(ENEMY_HEALTH)
	assert_int(_hits.size()).is_equal(0)


func test_ac189_one_full_turn_per_tick_and_the_blade_returns_to_rest() -> void:
	var yaw_at_start: float = _player.get_node("Visual").rotation.y
	_cast_by_hand()
	var visual: Node3D = _player.get_node("Visual") as Node3D
	_advance(0.25)
	assert_float(angle_difference(yaw_at_start, visual.rotation.y)).is_equal_approx(PI / 2.0, 0.01)
	_advance(0.75)
	assert_float(angle_difference(yaw_at_start, visual.rotation.y)).is_equal_approx(0.0, 0.01)
	var pivot: Node3D = _player.get_node("Visual/SwordPivot") as Node3D
	assert_vector(pivot.position).is_equal_approx(SPIN_CONFIG.blade_position, Vector3.ONE * 0.001)
	_advance(2.1)
	assert_bool(_ability.is_casting()).is_false()
	_player.sword_swing.advance(BERSERKER.weapon.swing.recover_duration)
	assert_vector(pivot.position).is_equal_approx(BERSERKER.weapon.rest_position, Vector3.ONE * 0.01)
	assert_vector(pivot.rotation).is_equal_approx(BERSERKER.weapon.rest_rotation, Vector3.ONE * 0.01)


func test_ac190_hit_enemies_are_pushed_away_with_the_spin_knockback() -> void:
	var enemy: Enemy = _spawn_idle_enemy(_near(Vector3(2.0, 0.0, 0.0)))
	_cast_by_hand()
	_advance(1.0)
	var push: Vector3 = enemy.get_knockback_velocity()
	assert_float(push.length()).is_equal_approx(SPIN_CONFIG.knockback_speed, TOLERANCE)
	assert_float(push.x).is_greater(0.0)


## Adapted by docs/specs/spin-dash-slash.md: the dash now cuts the spin short
## (AC568), so this test only checks the slowed walk and the blocked attack.
func test_ac191_moves_slowed_while_spinning_and_cannot_attack() -> void:
	var swings: Array[int] = [0]
	_player.attack.attacked.connect(func(_h: int, _t: float, _c: bool) -> void: swings[0] += 1)
	assert_bool(_ability.try_cast()).is_true()
	Input.action_press(&"move_forward")
	Input.action_press(&"attack")
	await _physics_frames(30)
	var velocity: Vector3 = _player.velocity
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var expected: float = BERSERKER.base_stats.move_speed * SPIN_CONFIG.move_speed_factor
	assert_float(speed).is_equal_approx(expected, expected * 0.05)
	assert_int(swings[0]).is_equal(0)
	assert_bool(_ability.is_casting()).is_true()


func test_ac191_without_input_the_player_stays_put_while_spinning() -> void:
	var start: Vector3 = _player.global_position
	_ability.try_cast()
	await _physics_frames(30)
	assert_float(Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()).is_less(0.05)


func test_ac192_duration_upgrade_spins_longer_with_the_same_hits() -> void:
	_spawn_idle_enemy(_near(Vector3(2.0, 0.0, 0.0)))
	_ability.add_upgrade(DURATION_UPGRADE)
	assert_float(_ability.get_stat(AbilityData.Stat.CAST_DURATION)).is_equal_approx(3.5, TOLERANCE)
	_cast_by_hand()
	_advance(3.4)
	assert_bool(_ability.is_casting()).is_true()
	_advance(0.2)
	assert_bool(_ability.is_casting()).is_false()
	assert_int(_hits.size()).is_equal(3)


func test_ac192_faster_turns_hit_more_often_and_never_below_the_floor() -> void:
	_spawn_idle_enemy(_near(Vector3(2.0, 0.0, 0.0)))
	for i: int in 3:
		_ability.add_upgrade(SPEED_UPGRADE)
	assert_float(_ability.get_stat(AbilityData.Stat.TICK_INTERVAL)).is_equal_approx(0.7, TOLERANCE)
	_cast_by_hand()
	_advance(SPIN.cast_duration)
	assert_int(_hits.size()).is_equal(4)
	for i: int in 10:
		_ability.add_upgrade(SPEED_UPGRADE)
	assert_float(_ability.get_stat(AbilityData.Stat.TICK_INTERVAL)).is_equal(SPIN.min_tick_interval)


func test_ac196_turn_speed_goes_from_one_to_two_and_a_half_turns_per_second() -> void:
	assert_float(SPIN.tick_interval).is_equal(1.0)
	assert_float(SPIN.min_tick_interval).is_equal_approx(0.4, TOLERANCE)
	assert_int(SPEED_UPGRADE.max_stacks).is_equal(6)
	for i: int in SPEED_UPGRADE.max_stacks:
		assert_bool(_player.is_maxed(SPEED_UPGRADE)).is_false()
		_player.apply_upgrade(SPEED_UPGRADE)
	assert_float(_ability.get_stat(AbilityData.Stat.TICK_INTERVAL)).is_equal_approx(0.4, TOLERANCE)
	assert_bool(_player.is_maxed(SPEED_UPGRADE)).is_true()
	_player.apply_upgrade(SPEED_UPGRADE)
	assert_int(_player.count_upgrade(SPEED_UPGRADE)).is_equal(6)
	assert_float(_ability.get_stat(AbilityData.Stat.TICK_INTERVAL)).is_greater_equal(SPIN.min_tick_interval)


## Counts strikes, not hits on one enemy: a 40 HP grunt dies on the 4th hit.
func test_ac197_max_speed_hits_seven_times_in_three_seconds() -> void:
	_spawn_idle_enemy(_near(Vector3(2.0, 0.0, 0.0)))
	for i: int in SPEED_UPGRADE.max_stacks:
		_player.apply_upgrade(SPEED_UPGRADE)
	_cast_by_hand()
	_advance(SPIN.cast_duration + 0.1)
	assert_bool(_ability.is_casting()).is_false()
	assert_int((_ability.get_behavior() as SpinAbility).get_turns_done()).is_equal(7)
	assert_bool(_hits.is_empty()).is_false()


func test_ac192_range_and_damage_upgrades() -> void:
	var probe: Enemy = _spawn_idle_enemy(_near(Vector3(0.0, 0.0, 20.0)))
	var at: float = 2.8 + probe.get_hit_padding()
	var far: Enemy = _spawn_idle_enemy(_near(Vector3(at, 0.0, 0.0)))
	_ability.add_upgrade(RANGE_UPGRADE)
	_ability.add_upgrade(DAMAGE_UPGRADE)
	var expected: float = 8.0 + DAMAGE_UPGRADE.amount + 0.15 * BERSERKER.base_stats.damage
	assert_float(_hit_damage()).is_equal_approx(expected, TOLERANCE)
	_cast_by_hand()
	_advance(1.0)
	assert_bool(_hits.has(far)).is_true()
	assert_float(far.health.current_health).is_equal_approx(ENEMY_HEALTH - expected, 0.01)
