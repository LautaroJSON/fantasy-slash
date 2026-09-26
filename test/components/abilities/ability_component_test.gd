extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const THRUST_DAMAGE: AbilityUpgradeData = preload("res://data/abilities/thrust/upgrades/damage.tres")
const THRUST_LACERATING: AbilityUniqueUpgradeData = preload("res://data/abilities/thrust/unique/lacerating.tres")
const SWIFT_STRIKE_DAMAGE: AbilityUpgradeData = preload("res://data/abilities/swift_strike/upgrades/damage.tres")
const SWIFT_STRIKE_RESET: AbilityUniqueUpgradeData = preload("res://data/abilities/swift_strike/unique/reset.tres")
const PLAYER_DAMAGE: UpgradeData = preload("res://data/upgrades/damage.tres")
const ENEMY_HEALTH: float = 40.0
## Base thrust hit with the base player DAMAGE (15): 10 + 0.05 x 15.
const BASE_HIT: float = 10.75

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_ability.equip(THRUST)


func after_test() -> void:
	Input.action_release(&"attack")


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _upgrade_ability(stat: AbilityData.Stat, amount: float) -> void:
	var upgrade := AbilityUpgradeData.new()
	upgrade.stat = stat
	upgrade.amount = amount
	_ability.add_upgrade(upgrade)


func _cast_and_finish() -> void:
	assert_bool(_ability.try_cast()).is_true()
	_ability.advance(_ability.get_stat(AbilityData.Stat.CAST_DURATION))


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_ac46_ability_damage_is_base_plus_scaled_attack() -> void:
	assert_float(DamageMath.ability_damage(10.0, 0.05, 15.0)).is_equal_approx(10.75, 0.0001)


func test_ac47_base_stats_come_from_the_ability_data() -> void:
	for i: int in AbilityData.Stat.size():
		var stat: AbilityData.Stat = i as AbilityData.Stat
		assert_float(_ability.get_stat(stat)).is_equal_approx(THRUST.get_base(stat), 0.0001)


func test_ac47_ability_upgrades_add_to_the_hit() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.0))
	_upgrade_ability(AbilityData.Stat.BASE_DAMAGE, 5.0)
	_upgrade_ability(AbilityData.Stat.ATTACK_SCALING, 0.05)
	_cast_and_finish()
	assert_float(enemy.health.current_health).is_equal_approx(ENEMY_HEALTH - 16.5, 0.0001)


func test_ac47_player_upgrades_only_reach_the_ability_through_scaling() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.0))
	var damage := UpgradeData.new()
	damage.stat = PlayerStats.Stat.DAMAGE
	damage.amount = 4.0
	damage.max_stacks = 1
	_player.apply_upgrade(damage)
	for i: int in AbilityData.Stat.size():
		var stat: AbilityData.Stat = i as AbilityData.Stat
		assert_float(_ability.get_stat(stat)).is_equal_approx(THRUST.get_base(stat), 0.0001)
	assert_int(_ability.get_upgrades().size()).is_equal(0)
	_cast_and_finish()
	assert_float(enemy.health.current_health).is_equal_approx(ENEMY_HEALTH - 10.95, 0.0001)


func test_ac47_ability_upgrades_leave_player_stats_untouched() -> void:
	_player.apply_upgrade(THRUST.upgrades[0])
	assert_int(_ability.get_upgrades().size()).is_equal(1)
	assert_int(_player.stats.get_upgrades().size()).is_equal(0)


func test_ac47_no_crit_or_lifesteal_on_the_thrust() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.0))
	_player.health.receive_hit(20.0)
	var health_before: float = _player.health.current_health
	var crit := UpgradeData.new()
	crit.stat = PlayerStats.Stat.CRIT_CHANCE
	crit.amount = 1.0
	crit.max_stacks = 1
	_player.apply_upgrade(crit)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.CRIT_CHANCE)).is_equal_approx(1.0, 0.0001)
	_cast_and_finish()
	assert_float(enemy.health.current_health).is_equal_approx(ENEMY_HEALTH - BASE_HIT, 0.0001)
	assert_float(_player.health.current_health).is_equal_approx(health_before, 0.0001)


func test_ac48_upgrades_never_break_the_floors() -> void:
	for i: int in 10:
		_upgrade_ability(AbilityData.Stat.COOLDOWN, -0.5)
		_upgrade_ability(AbilityData.Stat.CAST_DURATION, -0.05)
	assert_float(_ability.get_stat(AbilityData.Stat.COOLDOWN)).is_equal_approx(THRUST.min_cooldown, 0.0001)
	assert_float(_ability.get_stat(AbilityData.Stat.CAST_DURATION)).is_equal_approx(THRUST.min_cast_duration, 0.0001)


func test_ac49_cooldown_blocks_casts_until_it_ends() -> void:
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	assert_bool(_ability.try_cast()).is_true()
	assert_float(_ability.get_cooldown_ratio()).is_equal_approx(1.0, 0.0001)
	assert_bool(_ability.try_cast()).is_false()
	_ability.advance(THRUST.cast_duration)
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_ability.try_cast()).is_false()
	_ability.advance(THRUST.cooldown)
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	assert_bool(_ability.try_cast()).is_true()


func test_ac49_empty_slot_cannot_cast() -> void:
	assert_bool(_player.ultimate_ability.is_equipped()).is_false()
	assert_bool(_player.ultimate_ability.try_cast()).is_false()
	assert_float(_player.ultimate_ability.get_cooldown_ratio()).is_equal(0.0)


func test_ac50_rectangle_hitbox_and_hit_on_release() -> void:
	var target: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.0))
	var far_in: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -3.0))
	var too_far: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -4.0))
	var beside: Enemy = _spawn_enemy(Vector3(1.2, 0.0, -1.5))
	var behind: Enemy = _spawn_enemy(Vector3(0.0, 0.0, 2.0))
	assert_bool(_ability.try_cast()).is_true()
	assert_float(target.health.current_health).is_equal(ENEMY_HEALTH)
	_ability.advance(THRUST.cast_duration)
	assert_float(target.health.current_health).is_equal_approx(ENEMY_HEALTH - BASE_HIT, 0.0001)
	assert_float(far_in.health.current_health).is_equal_approx(ENEMY_HEALTH - BASE_HIT, 0.0001)
	assert_float(too_far.health.current_health).is_equal(ENEMY_HEALTH)
	assert_float(beside.health.current_health).is_equal(ENEMY_HEALTH)
	assert_float(behind.health.current_health).is_equal(ENEMY_HEALTH)


func test_ac50_rectangle_math() -> void:
	var forward := Vector2(0.0, -1.0)
	assert_bool(HitboxMath.in_rectangle(Vector3.ZERO, forward, Vector3(0.4, 0.0, -3.5), 3.5, 0.5)).is_true()
	assert_bool(HitboxMath.in_rectangle(Vector3.ZERO, forward, Vector3(0.6, 0.0, -1.0), 3.5, 0.5)).is_false()
	assert_bool(HitboxMath.in_rectangle(Vector3.ZERO, forward, Vector3(0.0, 0.0, 0.1), 3.5, 0.5)).is_false()


func test_ac50_hits_emit_enemy_hit() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -2.0))
	var hits: Array[float] = []
	_ability.enemy_hit.connect(func(_e: Enemy, applied: float, _c: bool) -> void: hits.append(applied))
	_cast_and_finish()
	assert_int(hits.size()).is_equal(1)
	assert_float(hits[0]).is_equal_approx(BASE_HIT, 0.0001)


func test_ac51_thrust_turns_the_player_towards_the_nearest_enemy() -> void:
	_spawn_enemy(Vector3(1.5, 0.0, 0.0))
	_ability.try_cast()
	var visual: Node3D = _player.get_node("Visual") as Node3D
	assert_float(visual.rotation.y).is_equal_approx(-PI / 2.0, 0.01)


func test_ac52_player_stands_still_and_cannot_attack_while_casting() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	await _physics_frames(20)
	var swings: Array[int] = [0]
	_player.attack.attacked.connect(func(_h: int, _t: float, _c: bool) -> void: swings[0] += 1)
	_player.velocity = Vector3(6.0, 0.0, 0.0)
	var start: Vector3 = _player.global_position
	assert_bool(_ability.try_cast()).is_true()
	Input.action_press(&"attack")
	await _physics_frames(10)
	assert_bool(_player.is_casting()).is_true()
	assert_float(_player.global_position.x).is_equal_approx(start.x, 0.001)
	assert_float(_player.global_position.z).is_equal_approx(start.z, 0.001)
	assert_int(swings[0]).is_equal(0)
	assert_bool(_player.dash.is_dashing()).is_false()
	await _physics_frames(30)
	assert_bool(_player.is_casting()).is_false()
	assert_int(swings[0]).is_greater(0)


func test_acou1_owns_its_stat_upgrade() -> void:
	assert_bool(_ability.owns_upgrade(THRUST_DAMAGE)).is_true()


func test_acou2_owns_its_unique_upgrade() -> void:
	assert_bool(_ability.owns_upgrade(THRUST_LACERATING)).is_true()


func test_acou3_does_not_own_another_ability_stat_upgrade() -> void:
	assert_bool(_ability.owns_upgrade(SWIFT_STRIKE_DAMAGE)).is_false()


func test_acou4_does_not_own_another_ability_unique_upgrade() -> void:
	assert_bool(_ability.owns_upgrade(SWIFT_STRIKE_RESET)).is_false()


func test_acou5_does_not_own_a_player_upgrade() -> void:
	assert_bool(_ability.owns_upgrade(PLAYER_DAMAGE)).is_false()


func test_acou6_empty_slot_owns_nothing() -> void:
	var empty: AbilityComponent = auto_free(AbilityComponent.new())
	assert_bool(empty.owns_upgrade(THRUST_DAMAGE)).is_false()
	assert_bool(empty.owns_upgrade(THRUST_LACERATING)).is_false()
	assert_bool(empty.owns_upgrade(PLAYER_DAMAGE)).is_false()
