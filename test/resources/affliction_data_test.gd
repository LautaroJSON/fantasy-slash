extends GdUnitTestSuite
## docs/specs/affliction.md: data of the Affliction mechanic.

const CONFIG: AfflictionConfig = preload("res://data/combat/affliction_config.tres")
const CATALOG: AfflictionCatalog = preload("res://data/afflictions/affliction_catalog.tres")
const POISON: AfflictionData = preload("res://data/afflictions/poison.tres")
const BURST: AfflictionData = preload("res://data/afflictions/burst.tres")
const FROST: AfflictionData = preload("res://data/afflictions/frost.tres")
const CORROSION: AfflictionData = preload("res://data/afflictions/corrosion.tres")
const BLEEDING: AfflictionData = preload("res://data/afflictions/bleeding.tres")
const UPGRADE_CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const BUILDUP_CARD: UpgradeData = preload("res://data/upgrades/affliction_buildup.tres")
const ICON_DIR: String = "res://assets/icons/status/"
const NEW_ICONS: Array[String] = ["poison_bottle.svg", "snowflake.svg", "acid_blob.svg"]


func test_ac851_config_values() -> void:
	assert_int(CONFIG.max_types).is_equal(3)
	assert_float(CONFIG.threshold).is_equal(100.0)
	assert_float(CONFIG.max_resistance).is_equal(0.9)
	assert_float(CONFIG.decay_delay).is_equal(5.0)
	assert_float(CONFIG.decay_per_second).is_equal(15.0)
	assert_int(CONFIG.source_names.size()).is_equal(AfflictionUpgradeData.Source.size())


func test_ac852_violet_cards_with_three_levels() -> void:
	# 8 from affliction.md + 2 from affliction-bleed.md.
	assert_int(CATALOG.cards.size()).is_equal(10)
	var seen: Dictionary = {}
	for card: AfflictionUpgradeData in CATALOG.cards:
		var key: String = "%s/%d" % [card.affliction.id, card.source]
		assert_bool(seen.has(key)).override_failure_message(key).is_false()
		seen[key] = true
		assert_int(card.max_level).is_equal(3)
		assert_int(card.level_descriptions.size()).is_equal(3)
		var expected: Array[float] = [20.0, 30.0, 40.0]
		if card.source == AfflictionUpgradeData.Source.ABILITY:
			expected = [35.0, 50.0, 65.0]
		assert_array(card.level_values).is_equal(expected)


func test_ac853_affliction_effects() -> void:
	assert_float(POISON.potency_for(15.0)).is_equal_approx(4.5, 0.0001)
	assert_float(BURST.potency_for(15.0)).is_equal_approx(22.5, 0.0001)
	assert_float(BURST.burst_radius).is_equal(2.5)
	assert_bool(BURST.has_burst()).is_true()
	assert_object(BURST.debuff).is_null()
	assert_float(FROST.potency_for(15.0)).is_equal_approx(1.0, 0.0001)
	assert_float(FROST.potency_for(15.0, true)).is_equal_approx(0.4, 0.0001)
	assert_float(CORROSION.potency_for(15.0)).is_equal_approx(0.25, 0.0001)
	for data: AfflictionData in [POISON, FROST, CORROSION]:
		assert_bool(data.has_burst()).is_false()


func test_ac854_new_statuses() -> void:
	var poison: DebuffData = POISON.debuff
	assert_int(poison.effect).is_equal(DebuffData.Effect.DAMAGE_OVER_TIME)
	assert_int(poison.damage_scaling).is_equal(DebuffData.DamageScaling.FLAT)
	assert_int(poison.stack_mode).is_equal(DebuffData.StackMode.QUEUE)
	assert_float(poison.duration).is_equal(5.0)
	assert_float(poison.tick_interval).is_equal(1.0)
	assert_int(poison.max_stacks).is_equal(3)
	var frost: DebuffData = FROST.debuff
	assert_int(frost.effect).is_equal(DebuffData.Effect.SLOW)
	assert_float(frost.duration).is_equal(1.5)
	assert_int(frost.get_stack_cap()).is_equal(1)
	var corrosion: DebuffData = CORROSION.debuff
	assert_int(corrosion.effect).is_equal(DebuffData.Effect.ARMOR_REDUCTION)
	assert_int(corrosion.stack_mode).is_equal(DebuffData.StackMode.INTENSITY)
	assert_float(corrosion.duration).is_equal(5.0)
	assert_int(corrosion.max_stacks).is_equal(4)
	for data: DebuffData in [poison, frost, corrosion]:
		assert_bool(data.is_beneficial).is_false()
		assert_str(data.icon.resource_path).starts_with(ICON_DIR)


func test_ac855_icon_color_is_the_bar_color() -> void:
	for data: AfflictionData in [POISON, FROST, CORROSION, BLEEDING]:
		assert_object(data.debuff.icon_color).is_equal(data.bar_material.albedo_color)


func test_ac857_every_source_has_an_affliction_scale() -> void:
	var expected: Dictionary = {
		"res://data/classes/warrior/warrior_combo.tres": 1.0,
		"res://data/classes/berserker/berserker_combo.tres": 2.3,
		"res://data/classes/samurai/samurai_combo.tres": 0.8,
		"res://data/classes/berserker/air_slash_config.tres": 2.3,
		"res://data/abilities/shield_charge/shield_charge.tres": 1.5,
		"res://data/abilities/parry/parry.tres": 2.0,
		"res://data/abilities/spin/spin.tres": 0.4,
		"res://data/abilities/sheathe/sheathe.tres": 2.0,
	}
	for path: String in expected:
		var resource: Resource = load(path)
		assert_float(resource.get(&"affliction_scale")).override_failure_message(path).is_equal_approx(expected[path], 0.0001)


func test_ac858_enemy_resistances() -> void:
	var expected: Dictionary = {
		"grunt": 0.0, "charger": 0.0, "leaper": 0.0, "harasser": 0.0,
		"shieldbearer": 0.25, "verdugo": 0.5, "titan": 0.5, "colmena": 0.5,
	}
	for enemy: String in expected:
		var stats: EnemyStats = load("res://data/enemies/%s_stats.tres" % enemy)
		assert_float(stats.affliction_resistance).override_failure_message(enemy).is_equal(expected[enemy])


func test_ac859_buildup_stat_and_card() -> void:
	for player_class: String in ["warrior", "berserker", "samurai"]:
		var stats: PlayerStats = load("res://data/classes/%s/%s_stats.tres" % [player_class, player_class])
		assert_float(stats.get_base(PlayerStats.Stat.AFFLICTION_BUILDUP)).is_equal(0.0)
	assert_int(BUILDUP_CARD.stat).is_equal(PlayerStats.Stat.AFFLICTION_BUILDUP)
	assert_float(BUILDUP_CARD.amount).is_equal(0.1)
	assert_int(BUILDUP_CARD.max_stacks).is_equal(5)
	assert_int(UPGRADE_CATALOG.upgrades.size()).is_equal(11)
	assert_bool(UPGRADE_CATALOG.upgrades.has(BUILDUP_CARD)).is_true()


func test_ac892_new_icons_are_credited_and_have_no_background() -> void:
	var source: String = FileAccess.get_file_as_string(ICON_DIR + "SOURCE.md")
	for file: String in NEW_ICONS:
		assert_str(source).contains("`%s` | Lorc | https://game-icons.net/" % file)
		assert_str(FileAccess.get_file_as_string(ICON_DIR + file)).not_contains("M0 0h512v512H0z")
	assert_str(source).contains("CC BY 3.0")


## docs/specs/affliction-damage-colors.md
func test_ac936_damage_number_colors_match_the_bars() -> void:
	assert_object(POISON.debuff.damage_number_material.albedo_color).is_equal(POISON.bar_material.albedo_color)
	assert_object(BURST.damage_number_material.albedo_color).is_equal(BURST.bar_material.albedo_color)
	for id: String in ["frost", "corrosion", "bleed", "weaken", "rage", "shield"]:
		var data: DebuffData = load("res://data/debuffs/%s.tres" % id)
		assert_object(data.damage_number_material).override_failure_message(id).is_null()


## docs/specs/frost-freeze.md
func test_ac941_bosses_resist_control() -> void:
	var expected: Dictionary = {
		"grunt": false, "charger": false, "leaper": false, "harasser": false,
		"shieldbearer": false, "verdugo": true, "titan": true, "colmena": true,
	}
	for enemy: String in expected:
		var stats: EnemyStats = load("res://data/enemies/%s_stats.tres" % enemy)
		assert_bool(stats.resists_control).override_failure_message(enemy).is_equal(expected[enemy])


func test_ac945_corrosion_is_light_gray_and_burst_orange() -> void:
	var gray := Color(0.7, 0.7, 0.72, 1.0)
	var orange := Color(1.0, 0.55, 0.15, 1.0)
	assert_object(CORROSION.bar_material.albedo_color).is_equal(gray)
	assert_object(CORROSION.debuff.icon_color).is_equal(gray)
	assert_object(BURST.bar_material.albedo_color).is_equal(orange)
	assert_object(BURST.damage_number_material.albedo_color).is_equal(orange)


func test_ac946_both_frost_statuses_look_the_same() -> void:
	var freeze: DebuffData = FROST.debuff_for(false)
	var chill: DebuffData = FROST.debuff_for(true)
	assert_object(chill).is_not_same(freeze)
	assert_str(String(chill.id)).is_equal(String(freeze.id))
	assert_object(chill.icon).is_same(freeze.icon)
	assert_object(chill.icon_color).is_equal(freeze.icon_color)
	assert_int(chill.effect).is_equal(DebuffData.Effect.SLOW)
	assert_float(chill.duration).is_equal(5.0)
	assert_str(chill.icon.resource_path).starts_with(ICON_DIR)


## docs/specs/affliction-name-popup.md
func test_ac954_which_afflictions_deal_damage() -> void:
	assert_bool(POISON.deals_damage()).is_true()
	assert_bool(BURST.deals_damage()).is_true()
	assert_bool(FROST.deals_damage()).is_false()
	assert_bool(CORROSION.deals_damage()).is_false()
	for data: AfflictionData in [POISON, BURST, FROST, CORROSION, BLEEDING]:
		var text: StandardMaterial3D = data.damage_number_material if data.damage_number_material != null else data.debuff.damage_number_material
		assert_object(text.albedo_color).override_failure_message(String(data.id)).is_equal(data.bar_material.albedo_color)


## docs/specs/affliction-bleed.md
func test_ac962_bleeding_data() -> void:
	assert_str(BLEEDING.title).is_equal("Sangrado")
	var crimson := Color(0.75, 0.1, 0.25, 1.0)
	assert_object(BLEEDING.bar_material.albedo_color).is_equal(crimson)
	var status: DebuffData = BLEEDING.debuff
	assert_object(BLEEDING.resisted_debuff).is_same(status)
	assert_float(BLEEDING.potency_for(15.0)).is_equal_approx(0.01, 0.00001)
	assert_float(BLEEDING.potency_for(15.0, true)).is_equal_approx(0.001, 0.00001)
	assert_bool(BLEEDING.deals_damage()).is_true()
	assert_str(String(status.id)).is_equal("bleeding")
	assert_int(status.effect).is_equal(DebuffData.Effect.DAMAGE_OVER_TIME)
	assert_int(status.damage_scaling).is_equal(DebuffData.DamageScaling.MAX_HEALTH)
	assert_int(status.stack_mode).is_equal(DebuffData.StackMode.INTENSITY)
	assert_float(status.duration).is_equal(5.0)
	assert_float(status.tick_interval).is_equal(1.0)
	assert_int(status.max_stacks).is_equal(3)
	assert_array(status.stack_multipliers).is_equal([1.0, 3.0, 6.0])
	assert_str(status.icon.resource_path).is_equal(ICON_DIR + "bleeding_wound.svg")
	assert_object(status.icon_color).is_equal(crimson)
	assert_object(status.damage_number_material.albedo_color).is_equal(crimson)
	var sources: Array[int] = []
	for card: AfflictionUpgradeData in CATALOG.cards:
		if card.affliction == BLEEDING:
			sources.append(card.source)
	assert_array(sources).contains_exactly_in_any_order([AfflictionUpgradeData.Source.BASIC_ATTACK, AfflictionUpgradeData.Source.ABILITY])
