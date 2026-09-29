extends GdUnitTestSuite
## Esbirro data (docs/specs/fodder-minion.md, AC1141–AC1142).

const FODDER: EnemyStats = preload("res://data/enemies/fodder_stats.tres")
const CLASSES: Array[CharacterClassData] = [
	preload("res://data/classes/warrior/warrior.tres"),
	preload("res://data/classes/berserker/berserker.tres"),
	preload("res://data/classes/samurai/samurai.tres"),
]


func test_ac1141_the_weakest_combo_hit_of_every_class_kills_a_fodder() -> void:
	for character_class: CharacterClassData in CLASSES:
		var stats: PlayerStats = character_class.base_stats
		var weakest: float = INF
		for step: AttackComboStep in character_class.combo.steps:
			weakest = minf(weakest, step.damage_multiplier * DamageMath.outgoing(stats.damage, stats.damage_bonus, false, stats.crit_damage))
		var applied: float = DamageMath.mitigate(weakest, FODDER.defense, 1.0)
		assert_float(applied).override_failure_message("%s: weakest hit %.2f vs fodder health %.2f" % [character_class.resource_path, applied, FODDER.max_health]).is_greater_equal(FODDER.max_health)


func test_ac1142_health_and_defense_do_not_grow_with_the_level_but_damage_does() -> void:
	var scaled: EnemyStats = FODDER.duplicate() as EnemyStats
	FODDER.write_scaled(25, scaled)
	assert_float(scaled.max_health).is_equal(FODDER.max_health)
	assert_float(scaled.defense).is_equal(FODDER.defense)
	assert_float(scaled.damage).is_equal_approx(6.0 * (1.0 + 0.1 * 24.0), 0.001)
	assert_float(scaled.move_speed).is_less_equal(4.0)
