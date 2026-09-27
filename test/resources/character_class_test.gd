extends GdUnitTestSuite

const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const CLASS_CATALOG: ClassCatalog = preload("res://data/classes/class_catalog.tres")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")


func test_ac176_warrior_uses_the_sword_stats_and_its_ability_pool() -> void:
	assert_object(WARRIOR.base_stats).is_same(PLAYER_STATS)
	assert_array(WARRIOR.abilities.abilities).contains_exactly_in_any_order([SHIELD_CHARGE, PARRY])


func test_ac176_the_catalog_offers_the_warrior() -> void:
	assert_array(CLASS_CATALOG.classes).contains([WARRIOR])
