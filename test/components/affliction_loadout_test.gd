extends GdUnitTestSuite
## docs/specs/affliction.md: the player's Afflictions (AfflictionLoadout):
## build-up per source, triggers, burst and cards.

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const POISON_BASIC: AfflictionUpgradeData = preload("res://data/afflictions/cards/poison_basic_attack.tres")
const POISON_ABILITY: AfflictionUpgradeData = preload("res://data/afflictions/cards/poison_ability.tres")
const BURST_BASIC: AfflictionUpgradeData = preload("res://data/afflictions/cards/burst_basic_attack.tres")
const FROST_BASIC: AfflictionUpgradeData = preload("res://data/afflictions/cards/frost_basic_attack.tres")
const FROST_ABILITY: AfflictionUpgradeData = preload("res://data/afflictions/cards/frost_ability.tres")
const CORROSION_BASIC: AfflictionUpgradeData = preload("res://data/afflictions/cards/corrosion_basic_attack.tres")
const POISON_STATUS: DebuffData = preload("res://data/debuffs/poison.tres")
const FROST_STATUS: DebuffData = preload("res://data/debuffs/frost.tres")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const StatusOverlayProbe := preload("res://test/helpers/status_overlay_probe.gd")
const NO_CRIT_ROLL: float = 0.99

var _registry: EnemyRegistry
var _player: Player


func after_test() -> void:
	Session.character_class = null


func _spawn_player(character_class: CharacterClassData) -> void:
	Session.character_class = character_class
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _combo_hit(enemy: Enemy) -> void:
	_player.attack.enemy_hit.emit(enemy, 5.0, false)


func _ability_hit(enemy: Enemy) -> void:
	_player.basic_ability.enemy_hit.emit(enemy, 5.0, false)


## Combo hits until the first trigger of `status`; 0 if none within 20 hits.
func _hits_to_trigger(enemy: Enemy, status: DebuffData) -> int:
	for hit: int in range(1, 21):
		_combo_hit(enemy)
		if enemy.debuffs.has_debuff(status.id):
			return hit
	return 0


func test_ac862_five_real_warrior_strikes_poison_a_grunt() -> void:
	_spawn_player(WARRIOR)
	ComboDriver.drive_by_hand(_player)
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.0))
	enemy.health.setup(10000.0, 0.0)
	_player.apply_upgrade(POISON_BASIC)
	for strike: int in 4:
		ComboDriver.strike_and_finish(_player, NO_CRIT_ROLL)
		assert_float(enemy.afflictions.get_buildup(0)).is_equal_approx(20.0 * (strike + 1), 0.001)
	assert_bool(enemy.debuffs.has_debuff(POISON_STATUS.id)).is_false()
	ComboDriver.strike_and_finish(_player, NO_CRIT_ROLL)
	assert_bool(enemy.debuffs.has_debuff(POISON_STATUS.id)).is_true()
	assert_float(enemy.afflictions.get_buildup(0)).is_equal(0.0)


func test_ac864_each_card_only_takes_its_source() -> void:
	_spawn_player(WARRIOR)
	var enemy: Enemy = _spawn_enemy(Vector3.ZERO)
	_player.apply_upgrade(POISON_BASIC)
	_ability_hit(enemy)
	_player.ultimate_ability.enemy_hit.emit(enemy, 5.0, false)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal(0.0)
	_player.reset_upgrades()
	_player.apply_upgrade(FROST_ABILITY)
	_combo_hit(enemy)
	_player.air_slash.enemy_hit.emit(enemy, 5.0, false)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal(0.0)


func test_ac865_one_affliction_two_sources_one_bar() -> void:
	_spawn_player(WARRIOR)
	_player.basic_ability.equip(THRUST)
	var enemy: Enemy = _spawn_enemy(Vector3.ZERO)
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(POISON_ABILITY)
	assert_int(_player.afflictions.get_type_count()).is_equal(1)
	_combo_hit(enemy)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal_approx(20.0, 0.001)
	_ability_hit(enemy)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal_approx(55.0, 0.001)


func test_ac866_a_hit_fills_only_the_bars_of_its_source() -> void:
	_spawn_player(WARRIOR)
	var enemy: Enemy = _spawn_enemy(Vector3.ZERO)
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(BURST_BASIC)
	_player.apply_upgrade(FROST_ABILITY)
	_combo_hit(enemy)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal_approx(20.0, 0.001)
	assert_float(enemy.afflictions.get_buildup(1)).is_equal_approx(20.0, 0.001)
	assert_float(enemy.afflictions.get_buildup(2)).is_equal(0.0)


func test_ac867_no_buildup_without_damage_nor_from_ticks_or_bursts() -> void:
	_spawn_player(WARRIOR)
	var enemy: Enemy = _spawn_enemy(Vector3.ZERO)
	_player.apply_upgrade(POISON_BASIC)
	_player.attack.enemy_hit.emit(enemy, 0.0, false)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal(0.0)
	enemy.debuffs.apply(POISON_STATUS, 4.5)
	enemy.debuffs.advance(1.0)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal(0.0)


func test_ac868_resistance_and_player_bonus() -> void:
	_spawn_player(WARRIOR)
	var enemy: Enemy = _spawn_enemy(Vector3.ZERO)
	enemy.afflictions.setup(VERDUGO)
	_player.apply_upgrade(POISON_BASIC)
	_combo_hit(enemy)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal_approx(10.0, 0.001)
	var bonus := UpgradeData.new()
	bonus.stat = PlayerStats.Stat.AFFLICTION_BUILDUP
	bonus.amount = 0.3
	bonus.max_stacks = 1
	_player.stats.add_upgrade(bonus)
	_combo_hit(enemy)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal_approx(23.0, 0.001)


func test_ac871_poison_potency_comes_from_player_damage() -> void:
	_spawn_player(WARRIOR)
	var enemy: Enemy = _spawn_enemy(Vector3.ZERO)
	enemy.health.setup(1000.0, 0.0)
	_player.apply_upgrade(POISON_BASIC)
	assert_int(_hits_to_trigger(enemy, POISON_STATUS)).is_equal(5)
	var damage: float = _player.stats.get_stat(PlayerStats.Stat.DAMAGE)
	enemy.debuffs.advance(1.0)
	assert_float(enemy.health.current_health).is_equal_approx(1000.0 - 0.3 * damage, 0.001)


func test_ac875_burst_hits_enemies_in_range_without_being_a_hit() -> void:
	_spawn_player(WARRIOR)
	var center: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -5.0))
	var near: Enemy = _spawn_enemy(Vector3(2.0, 0.0, -5.0))
	var far: Enemy = _spawn_enemy(Vector3(6.0, 0.0, -5.0))
	for enemy: Enemy in [center, near, far]:
		enemy.health.setup(1000.0, 0.0)
	_player.apply_upgrade(BURST_BASIC)
	var bursts: Array[Enemy] = []
	_player.afflictions.burst_hit.connect(func(enemy: Enemy, _applied: float, _type: AfflictionData) -> void: bursts.append(enemy))
	var hits: Array[int] = [0]
	_player.attack.enemy_hit.connect(func(_e: Enemy, _a: float, _c: bool) -> void: hits[0] += 1)
	var healed_from: float = _player.health.current_health
	for hit: int in 7:
		_combo_hit(center)
	assert_int(hits[0]).is_equal(7)
	var damage: float = 1.5 * _player.stats.get_stat(PlayerStats.Stat.DAMAGE)
	assert_float(center.health.current_health).is_equal_approx(1000.0 - damage, 0.001)
	assert_float(near.health.current_health).is_equal_approx(1000.0 - damage, 0.001)
	assert_float(far.health.current_health).is_equal(1000.0)
	assert_array(bursts).contains_exactly_in_any_order([center, near])
	assert_float(_player.health.current_health).is_equal(healed_from)
	assert_float(near.afflictions.get_buildup(0)).is_equal(0.0)


func test_ac877_a_card_levels_up_in_its_slot() -> void:
	_spawn_player(WARRIOR)
	var enemy: Enemy = _spawn_enemy(Vector3.ZERO)
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(POISON_BASIC)
	assert_int(_player.count_upgrade(POISON_BASIC)).is_equal(2)
	assert_int(_player.afflictions.get_type_count()).is_equal(1)
	_combo_hit(enemy)
	assert_float(enemy.afflictions.get_buildup(0)).is_equal_approx(30.0, 0.001)


func test_ac878_the_fourth_affliction_is_capped() -> void:
	_spawn_player(WARRIOR)
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(BURST_BASIC)
	_player.apply_upgrade(FROST_BASIC)
	assert_bool(_player.is_maxed(CORROSION_BASIC)).is_true()
	assert_bool(_player.is_maxed(POISON_ABILITY)).is_false()
	assert_bool(_player.is_maxed(FROST_ABILITY)).is_false()
	_player.apply_upgrade(CORROSION_BASIC)
	assert_int(_player.afflictions.get_type_count()).is_equal(3)


func test_ac879_a_card_at_level_three_is_maxed() -> void:
	_spawn_player(WARRIOR)
	for i: int in 3:
		assert_bool(_player.is_maxed(POISON_BASIC)).is_false()
		_player.apply_upgrade(POISON_BASIC)
	assert_bool(_player.is_maxed(POISON_BASIC)).is_true()
	_player.apply_upgrade(POISON_BASIC)
	assert_int(_player.count_upgrade(POISON_BASIC)).is_equal(3)


func test_ac882_reset_and_remove() -> void:
	_spawn_player(WARRIOR)
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(FROST_BASIC)
	_player.remove_upgrade(POISON_BASIC)
	assert_int(_player.count_upgrade(POISON_BASIC)).is_equal(1)
	_player.remove_upgrade(POISON_BASIC)
	assert_int(_player.afflictions.get_type_count()).is_equal(1)
	assert_str(String(_player.afflictions.get_type(0).id)).is_equal("frost")
	_player.reset_upgrades()
	assert_int(_player.afflictions.get_type_count()).is_equal(0)


func test_ac896_classes_trigger_after_similar_combos() -> void:
	var expected: Dictionary = {WARRIOR: 5, SAMURAI: 7, BERSERKER: 3}
	for character_class: CharacterClassData in expected:
		_spawn_player(character_class)
		var enemy: Enemy = _spawn_enemy(Vector3.ZERO)
		_player.apply_upgrade(POISON_BASIC)
		assert_int(_hits_to_trigger(enemy, POISON_STATUS)).override_failure_message(character_class.resource_path).is_equal(expected[character_class])


func test_ac889_the_triggered_status_shows_in_the_overlay() -> void:
	_spawn_player(WARRIOR)
	var enemy: Enemy = _spawn_enemy(Vector3.ZERO)
	_player.apply_upgrade(POISON_BASIC)
	var probe: StatusOverlayProbe = auto_free(StatusOverlayProbe.new())
	add_child(probe)
	probe.watch(enemy)
	for hit: int in 5:
		_combo_hit(enemy)
	var row: StatusIconRow = probe.row()
	assert_int(row.get_visible_icon_count()).is_equal(1)
	assert_object(row.icon(0).get_glyph_texture()).is_same(POISON_STATUS.icon)
	assert_object(row.icon(0).get_border_color()).is_equal(StatusOverlayProbe.CONFIG.status_icon.debuff_border_color)
	assert_float(row.icon(0).get_clock().get_fraction()).is_equal_approx(1.0, 0.0001)
	assert_str(row.icon(0).get_stack_text()).is_equal("1")
	for hit: int in 10:
		_combo_hit(enemy)
	assert_str(probe.row().icon(0).get_stack_text()).is_equal("3")
