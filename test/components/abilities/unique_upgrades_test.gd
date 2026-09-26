extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SWIFT_STRIKE: AbilityData = preload("res://data/abilities/swift_strike/swift_strike.tres")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const RESET: AbilityUniqueUpgradeData = preload("res://data/abilities/swift_strike/unique/reset.tres")
const EXECUTE: AbilityUniqueUpgradeData = preload("res://data/abilities/swift_strike/unique/execute.tres")
const LACERATING: AbilityUniqueUpgradeData = preload("res://data/abilities/thrust/unique/lacerating.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const ENEMY_HEALTH: float = 40.0
## Swift Strike slice with base player DAMAGE (15): 12 + 0.10 x 15.
const SLICE: float = 13.5
## Thrust hit with base player DAMAGE (15): 10 + 0.05 x 15.
const THRUST_HIT: float = 10.75
const SPRINT_FRAMES: int = 40

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	await _physics_frames(20)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Idle enemy (no target) whose health is lowered to `health_left` first.
func _spawn_idle_enemy(at: Vector3, health_left: float = ENEMY_HEALTH) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	if health_left < ENEMY_HEALTH:
		enemy.health.receive_hit(ENEMY_HEALTH - health_left)
	return enemy


## Enemy health before a slice so that, after it, `fraction` of max health is left.
func _health_leaving(fraction: float) -> float:
	return fraction * ENEMY_HEALTH + SLICE


func _sprint() -> void:
	assert_bool(_ability.try_cast()).is_true()
	await _physics_frames(SPRINT_FRAMES)


func _thrust_hit() -> void:
	_ability.advance(10.0)
	assert_bool(_ability.try_cast()).is_true()
	_ability.advance(THRUST.cast_duration)


func test_ac95_reset_readies_the_ability_after_a_kill() -> void:
	_ability.equip(SWIFT_STRIKE)
	_player.apply_upgrade(RESET)
	_spawn_idle_enemy(Vector3(0.0, 0.0, -2.0), 5.0)
	await _sprint()
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	assert_bool(_ability.try_cast()).is_true()


func test_ac95_reset_needs_a_kill() -> void:
	_ability.equip(SWIFT_STRIKE)
	_player.apply_upgrade(RESET)
	_spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	await _sprint()
	assert_float(_ability.get_cooldown_ratio()).is_greater(0.0)


func test_ac95_without_reset_a_kill_keeps_the_cooldown() -> void:
	_ability.equip(SWIFT_STRIKE)
	_spawn_idle_enemy(Vector3(0.0, 0.0, -2.0), 5.0)
	await _sprint()
	assert_float(_ability.get_cooldown_ratio()).is_greater(0.0)


func test_ac96_execute_level_one_threshold() -> void:
	_ability.equip(SWIFT_STRIKE)
	_player.apply_upgrade(EXECUTE)
	var low: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0), _health_leaving(0.14))
	var safe: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -4.0), _health_leaving(0.16))
	await _sprint()
	assert_bool(low.health.is_dead()).is_true()
	assert_bool(safe.health.is_dead()).is_false()
	assert_float(safe.health.get_health_ratio()).is_equal_approx(0.16, 0.001)


func test_ac96_execute_level_two_raises_the_threshold() -> void:
	_ability.equip(SWIFT_STRIKE)
	_player.apply_upgrade(EXECUTE)
	_player.apply_upgrade(EXECUTE)
	assert_float(_ability.get_unique_value(&"execute")).is_equal_approx(0.2, 0.0001)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0), _health_leaving(0.19))
	await _sprint()
	assert_bool(enemy.health.is_dead()).is_true()


func test_ac97_an_execution_counts_for_reset() -> void:
	_ability.equip(SWIFT_STRIKE)
	_player.apply_upgrade(RESET)
	_player.apply_upgrade(EXECUTE)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0), _health_leaving(0.14))
	await _sprint()
	assert_bool(enemy.health.is_dead()).is_true()
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)


func test_ac98_lacerating_bleeds_one_percent_per_second_ignoring_defense() -> void:
	_ability.equip(THRUST)
	_player.apply_upgrade(LACERATING)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	_thrust_hit()
	assert_bool(enemy.debuffs.has_debuff(BLEED.id)).is_true()
	enemy.health.defense = 100.0
	var after_hit: float = ENEMY_HEALTH - THRUST_HIT
	for i: int in 5:
		enemy.debuffs.advance(BLEED.tick_interval)
	assert_float(enemy.health.current_health).is_equal_approx(after_hit - 5.0 * 0.01 * ENEMY_HEALTH, 0.0001)
	assert_bool(enemy.debuffs.has_debuff(BLEED.id)).is_false()


func test_ac99_reapplying_refreshes_and_level_three_bleeds_harder() -> void:
	_ability.equip(THRUST)
	for i: int in 3:
		_player.apply_upgrade(LACERATING)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	_thrust_hit()
	var before_tick: float = enemy.health.current_health
	enemy.debuffs.advance(BLEED.tick_interval)
	assert_float(before_tick - enemy.health.current_health).is_equal_approx(0.03 * ENEMY_HEALTH, 0.0001)
	enemy.debuffs.advance(BLEED.tick_interval)
	assert_int(enemy.debuffs.get_ticks_left(BLEED.id)).is_equal(3)
	_thrust_hit()
	assert_int(enemy.debuffs.get_active().size()).is_equal(1)
	assert_int(enemy.debuffs.get_ticks_left(BLEED.id)).is_equal(5)


func test_ac100_different_debuffs_coexist_and_clear_on_recycle() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	var poison := DebuffData.new()
	poison.id = &"test_poison"
	poison.duration = 3.0
	poison.tick_interval = 1.0
	poison.icon_material = BLEED.icon_material
	enemy.debuffs.apply(BLEED, 0.01)
	enemy.debuffs.apply(poison, 0.01)
	enemy.debuffs.apply(BLEED, 0.01)
	assert_int(enemy.debuffs.get_active().size()).is_equal(2)
	enemy.deactivate()
	assert_int(enemy.debuffs.get_active().size()).is_equal(0)


func test_ac101_icon_shows_while_the_debuff_lasts() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	var icons: DebuffIconRow = enemy.get_node("HealthBar/DebuffIcons") as DebuffIconRow
	assert_int(icons.get_visible_icon_count()).is_equal(0)
	enemy.debuffs.apply(BLEED, 0.01)
	assert_int(icons.get_visible_icon_count()).is_equal(1)
	assert_object(icons.get_icon(0).material_override).is_same(BLEED.icon_material)
	for i: int in 5:
		enemy.debuffs.advance(BLEED.tick_interval)
	assert_int(icons.get_visible_icon_count()).is_equal(0)


func test_ac102_every_bleed_tick_is_reported_for_a_damage_number() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	var ticks: Array[float] = []
	_registry.enemy_debuff_ticked.connect(func(_e: Enemy, amount: float) -> void: ticks.append(amount))
	enemy.debuffs.apply(BLEED, 0.01)
	for i: int in 5:
		enemy.debuffs.advance(BLEED.tick_interval)
	assert_int(ticks.size()).is_equal(5)
	assert_float(ticks[0]).is_equal_approx(0.4, 0.0001)


func test_ac105_levels_are_declared_in_data() -> void:
	assert_int(RESET.max_level).is_equal(1)
	for unique: AbilityUniqueUpgradeData in [EXECUTE, LACERATING]:
		assert_int(unique.max_level).is_equal(3)
		assert_int(unique.level_values.size()).is_equal(unique.max_level)
		assert_int(unique.level_descriptions.size()).is_equal(unique.max_level)
	assert_object(LACERATING.debuff).is_same(BLEED)
