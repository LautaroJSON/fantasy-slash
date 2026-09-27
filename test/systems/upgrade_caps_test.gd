extends GdUnitTestSuite

const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const RULES: CombatRules = preload("res://data/combat/combat_rules.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const EPSILON: float = 0.0001


func _capped_value(base: float, amount: float, stacks: int) -> float:
	return base + amount * stacks


func _floor_of(ability: AbilityData, stat: AbilityData.Stat) -> float:
	if stat == AbilityData.Stat.COOLDOWN:
		return ability.min_cooldown
	return ability.min_cast_duration


func test_ac119_every_stat_card_declares_a_cap() -> void:
	for upgrade: UpgradeData in CATALOG.upgrades:
		assert_int(upgrade.max_stacks).override_failure_message(upgrade.title).is_greater(0)
	for ability: AbilityData in [SHIELD_CHARGE, PARRY]:
		for upgrade: AbilityUpgradeData in ability.upgrades:
			assert_int(upgrade.max_stacks).override_failure_message(upgrade.title).is_greater(0)


func test_ac119_ability_speed_and_cooldown_caps_land_exactly_on_the_floor() -> void:
	for ability: AbilityData in [SHIELD_CHARGE, PARRY]:
		for upgrade: AbilityUpgradeData in ability.upgrades:
			if upgrade.amount >= 0.0:
				continue
			var capped: float = _capped_value(ability.get_base(upgrade.stat), upgrade.amount, upgrade.max_stacks)
			assert_float(capped).override_failure_message(upgrade.title).is_equal_approx(_floor_of(ability, upgrade.stat), EPSILON)


func test_ac230_crit_chance_cap_lands_exactly_on_100_percent() -> void:
	var crit: UpgradeData = _card_for(PlayerStats.Stat.CRIT_CHANCE)
	var capped: float = _capped_value(PLAYER_STATS.crit_chance, crit.amount, crit.max_stacks)
	assert_float(capped).is_equal_approx(RULES.max_crit_chance, EPSILON)


func test_ac231_crit_damage_cap_is_the_first_copy_to_reach_300_percent() -> void:
	var crit_damage: UpgradeData = _card_for(PlayerStats.Stat.CRIT_DAMAGE)
	var capped: float = _capped_value(PLAYER_STATS.crit_damage, crit_damage.amount, crit_damage.max_stacks)
	var one_less: float = _capped_value(PLAYER_STATS.crit_damage, crit_damage.amount, crit_damage.max_stacks - 1)
	assert_float(capped).is_greater_equal(RULES.max_crit_damage)
	assert_float(one_less).is_less(RULES.max_crit_damage)


func test_ac120_a_capped_card_leaves_the_pool_and_is_not_applied_again() -> void:
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	get_tree().paused = true
	await get_tree().process_frame
	(arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHIELD_CHARGE)
	var player: Player = arena.get_node("Player") as Player
	var wave_manager: WaveManager = arena.get_node("WaveManager") as WaveManager
	for i: int in DAMAGE_UPGRADE.max_stacks:
		player.apply_upgrade(DAMAGE_UPGRADE)
	assert_bool(wave_manager.get_available_pool().has(DAMAGE_UPGRADE)).is_false()
	player.apply_upgrade(DAMAGE_UPGRADE)
	assert_int(player.count_upgrade(DAMAGE_UPGRADE)).is_equal(DAMAGE_UPGRADE.max_stacks)
	assert_float(player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(
		_capped_value(PLAYER_STATS.damage, DAMAGE_UPGRADE.amount, DAMAGE_UPGRADE.max_stacks), EPSILON)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _card_for(stat: PlayerStats.Stat) -> UpgradeData:
	for upgrade: UpgradeData in CATALOG.upgrades:
		if upgrade.stat == stat:
			return upgrade
	return null
