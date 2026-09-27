extends GdUnitTestSuite
## docs/specs/affliction.md: SLOW, upgradable (INTENSITY) and stackable (QUEUE)
## stacks, and flat damage-over-time ticks.

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const POISON: DebuffData = preload("res://data/debuffs/poison.tres")
const FROST: DebuffData = preload("res://data/debuffs/frost.tres")
const FROST_CHILL: DebuffData = preload("res://data/debuffs/frost_chill.tres")
const CORROSION: DebuffData = preload("res://data/debuffs/corrosion.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const WEAKEN: DebuffData = preload("res://data/debuffs/weaken.tres")
const RAGE: DebuffData = preload("res://data/debuffs/rage.tres")
const SHIELD: DebuffData = preload("res://data/debuffs/shield.tres")
const BLEEDING: DebuffData = preload("res://data/debuffs/bleeding.tres")


## Adds up the delta its enemy hands it every frame.
class DeltaProbe:
	extends EnemyBehavior
	var total: float = 0.0

	func physics_update(delta: float) -> void:
		total += delta


func _spawn_enemy() -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	add_child(enemy)
	enemy.activate(Vector3.ZERO, null)
	enemy.health.setup(1000.0, 6.0)
	return enemy


func test_ac856_existing_statuses_keep_their_stack_and_damage_modes() -> void:
	for data: DebuffData in [BLEED, WEAKEN, RAGE, SHIELD]:
		assert_int(data.stack_mode).override_failure_message(String(data.id)).is_equal(DebuffData.StackMode.INTENSITY)
		assert_int(data.damage_scaling).override_failure_message(String(data.id)).is_equal(DebuffData.DamageScaling.MAX_HEALTH)


func test_ac871_poison_ticks_remove_a_flat_amount() -> void:
	var enemy: Enemy = _spawn_enemy()
	enemy.debuffs.apply(POISON, 4.5)
	enemy.debuffs.advance(1.0)
	assert_float(enemy.health.current_health).is_equal_approx(995.5, 0.001)


func test_ac872_stackable_poison_queues_instances_without_more_damage() -> void:
	var enemy: Enemy = _spawn_enemy()
	for i: int in 3:
		enemy.debuffs.apply(POISON, 4.5)
	assert_int(enemy.debuffs.get_stacks(POISON.id)).is_equal(3)
	enemy.debuffs.advance(1.0)
	assert_float(enemy.health.current_health).is_equal_approx(995.5, 0.001)
	for i: int in 4:
		enemy.debuffs.advance(1.0)
	assert_int(enemy.debuffs.get_stacks(POISON.id)).is_equal(2)
	for i: int in 10:
		enemy.debuffs.advance(1.0)
	assert_bool(enemy.debuffs.has_debuff(POISON.id)).is_false()
	assert_float(enemy.health.current_health).is_equal_approx(1000.0 - 15.0 * 4.5, 0.001)


func test_ac872_a_full_queue_restarts_the_running_instance() -> void:
	var enemy: Enemy = _spawn_enemy()
	for i: int in 3:
		enemy.debuffs.apply(POISON, 4.5)
	enemy.debuffs.advance(1.0)
	enemy.debuffs.advance(1.0)
	assert_float(enemy.debuffs.get_remaining_seconds(POISON.id)).is_equal_approx(3.0, 0.001)
	enemy.debuffs.apply(POISON, 4.5)
	assert_int(enemy.debuffs.get_stacks(POISON.id)).is_equal(3)
	assert_float(enemy.debuffs.get_remaining_seconds(POISON.id)).is_equal_approx(5.0, 0.001)


func test_ac873_upgradable_corrosion_grows_and_restarts() -> void:
	var enemy: Enemy = _spawn_enemy()
	enemy.debuffs.apply(CORROSION, 0.25)
	assert_float(enemy.health.get_effective_defense()).is_equal_approx(4.5, 0.001)
	enemy.debuffs.advance(3.0)
	enemy.debuffs.apply(CORROSION, 0.25)
	assert_float(enemy.health.get_effective_defense()).is_equal_approx(3.0, 0.001)
	assert_float(enemy.debuffs.get_remaining_seconds(CORROSION.id)).is_equal_approx(5.0, 0.001)
	enemy.debuffs.apply(CORROSION, 0.25)
	enemy.debuffs.apply(CORROSION, 0.25)
	assert_float(enemy.health.get_effective_defense()).is_equal_approx(0.0, 0.001)
	enemy.debuffs.apply(CORROSION, 0.25)
	assert_int(enemy.debuffs.get_stacks(CORROSION.id)).is_equal(4)


func test_ac874_a_slow_status_slows_walking_and_the_behavior_clock() -> void:
	var enemy: Enemy = _spawn_enemy()
	var probe: DeltaProbe = auto_free(DeltaProbe.new())
	enemy._behavior = probe
	enemy.debuffs.apply(FROST_CHILL, 0.4)
	assert_float(enemy.debuffs.get_speed_scale()).is_equal_approx(0.6, 0.001)
	var frames: int = 0
	while probe.total < 1.0 and frames < 1000:
		enemy._update_behaviour(1.0 / 60.0)
		frames += 1
	assert_float(frames / 60.0).is_equal_approx(1.0 / 0.6, 0.02)
	enemy.walk(Vector3.FORWARD, 1.0 / 60.0)
	assert_float(enemy.velocity.z).is_equal_approx(-enemy.get_scaled_stats().move_speed * 0.6, 0.001)


## docs/specs/frost-freeze.md: a frozen common enemy stands still for 1.5 s.
func test_ac942_frost_freezes_a_common_enemy() -> void:
	var enemy: Enemy = _spawn_enemy()
	var probe: DeltaProbe = auto_free(DeltaProbe.new())
	enemy._behavior = probe
	enemy.debuffs.apply(FROST, 1.0)
	assert_float(enemy.debuffs.get_speed_scale()).is_equal(0.0)
	for i: int in 60:
		enemy._update_behaviour(1.0 / 60.0)
	assert_float(probe.total).is_equal(0.0)
	assert_float(enemy.velocity.x).is_equal(0.0)
	assert_float(enemy.velocity.z).is_equal(0.0)
	enemy.debuffs.advance(1.4)
	assert_float(enemy.debuffs.get_speed_scale()).is_equal(0.0)
	enemy.debuffs.advance(0.2)
	assert_float(enemy.debuffs.get_speed_scale()).is_equal(1.0)


func test_ac944_a_frozen_enemy_still_takes_damage_and_pushes() -> void:
	var enemy: Enemy = _spawn_enemy()
	enemy.debuffs.apply(FROST, 1.0)
	enemy.health.receive_hit(20.0)
	assert_float(enemy.health.current_health).is_less(1000.0)
	enemy.apply_knockback(Vector3.FORWARD, 5.0)
	assert_bool(enemy.is_knocked_back()).is_true()


func test_ac943_boss_chill_lasts_five_seconds() -> void:
	var enemy: Enemy = _spawn_enemy()
	enemy.debuffs.apply(FROST_CHILL, 0.4)
	enemy.debuffs.advance(4.9)
	assert_float(enemy.debuffs.get_speed_scale()).is_equal_approx(0.6, 0.001)
	enemy.debuffs.apply(FROST_CHILL, 0.4)
	assert_float(enemy.debuffs.get_speed_scale()).is_equal_approx(0.6, 0.001)
	assert_float(enemy.debuffs.get_remaining_seconds(FROST_CHILL.id)).is_equal_approx(5.0, 0.001)
	enemy.debuffs.advance(5.1)
	assert_float(enemy.debuffs.get_speed_scale()).is_equal(1.0)

func test_ac876_bleed_still_removes_a_fraction_of_max_health() -> void:
	var enemy: Enemy = _spawn_enemy()
	enemy.debuffs.apply(BLEED, 0.01)
	enemy.debuffs.apply(BLEED, 0.01)
	assert_int(enemy.debuffs.get_stacks(BLEED.id)).is_equal(1)
	enemy.debuffs.advance(1.0)
	assert_float(enemy.health.current_health).is_equal_approx(990.0, 0.001)


func test_ac894_slow_is_the_last_effect_value() -> void:
	assert_int(DebuffData.Effect.SLOW).is_equal(4)


## docs/specs/affliction-damage-colors.md
func test_ac938_ticks_report_their_status() -> void:
	var enemy: Enemy = _spawn_enemy()
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	registry.register(enemy)
	var seen: Array[DebuffData] = []
	registry.enemy_debuff_ticked.connect(func(_e: Enemy, _a: float, data: DebuffData) -> void: seen.append(data))
	enemy.debuffs.apply(POISON, 4.5)
	enemy.debuffs.apply(BLEED, 0.01)
	enemy.debuffs.advance(1.0)
	assert_array(seen).contains_exactly_in_any_order([POISON, BLEED])


## docs/specs/affliction-bleed.md
func test_ac961_stack_multipliers_shape_the_strength() -> void:
	assert_float(BLEEDING.stack_multiplier(1)).is_equal(1.0)
	assert_float(BLEEDING.stack_multiplier(2)).is_equal(3.0)
	assert_float(BLEEDING.stack_multiplier(3)).is_equal(6.0)
	assert_float(CORROSION.stack_multiplier(3)).is_equal(3.0)
	assert_float(WEAKEN.stack_multiplier(2)).is_equal(2.0)


func test_ac963_bleeding_ticks_grow_with_stacks() -> void:
	var enemy: Enemy = _spawn_enemy()
	var expected: Array[float] = [10.0, 30.0, 60.0, 60.0]
	for i: int in expected.size():
		enemy.debuffs.apply(BLEEDING, 0.01)
		assert_float(enemy.debuffs.get_remaining_seconds(BLEEDING.id)).is_equal_approx(5.0, 0.001)
		var before: float = enemy.health.current_health
		enemy.debuffs.advance(1.0)
		assert_float(before - enemy.health.current_health).is_equal_approx(expected[i], 0.001)


func test_ac964_bosses_bleed_a_tenth() -> void:
	var enemy: Enemy = _spawn_enemy()
	var expected: Array[float] = [1.0, 3.0, 6.0]
	for i: int in expected.size():
		enemy.debuffs.apply(BLEEDING, 0.001)
		var before: float = enemy.health.current_health
		enemy.debuffs.advance(1.0)
		assert_float(before - enemy.health.current_health).is_equal_approx(expected[i], 0.001)


func test_ac966_lacerante_bleed_is_unchanged_and_separate() -> void:
	var enemy: Enemy = _spawn_enemy()
	enemy.debuffs.apply(BLEED, 0.01)
	enemy.debuffs.apply(BLEEDING, 0.01)
	enemy.debuffs.apply(BLEEDING, 0.01)
	assert_int(enemy.debuffs.get_stacks(BLEED.id)).is_equal(1)
	assert_int(enemy.debuffs.get_stacks(BLEEDING.id)).is_equal(2)
	assert_array(BLEED.stack_multipliers).is_empty()
	assert_int(BLEED.get_stack_cap()).is_equal(1)
