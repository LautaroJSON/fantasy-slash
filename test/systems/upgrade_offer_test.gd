extends GdUnitTestSuite

const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
## Stats with a card: all but the five fixed by design (docs/specs/stats-rework.md),
## plus AFFLICTION_BUILDUP (docs/specs/affliction.md).
const UPGRADEABLE_STAT_COUNT: int = 11


func _player_pool() -> Array[UpgradeCard]:
	var no_ability_upgrades: Array[AbilityUpgradeData] = []
	return UpgradeOffer.build_pool(CATALOG, no_ability_upgrades)


func _count_distinct_kinds(offer: Array[UpgradeCard]) -> int:
	var distinct: Array[UpgradeCard] = []
	for card: UpgradeCard in offer:
		var repeated: bool = false
		for seen: UpgradeCard in distinct:
			repeated = repeated or seen.is_same_kind(card)
		if not repeated:
			distinct.append(card)
	return distinct.size()


func test_ac21_catalog_has_one_upgrade_per_upgradeable_stat() -> void:
	assert_int(CATALOG.upgrades.size()).is_equal(UPGRADEABLE_STAT_COUNT)
	var seen: Dictionary[int, bool] = {}
	for upgrade: UpgradeData in CATALOG.upgrades:
		seen[upgrade.stat] = true
	assert_int(seen.size()).is_equal(UPGRADEABLE_STAT_COUNT)


func test_ac21_pick_returns_three_distinct_stats_every_time() -> void:
	var rng := RandomNumberGenerator.new()
	var pool: Array[UpgradeCard] = _player_pool()
	for seed_value: int in 1000:
		rng.seed = seed_value
		var offer: Array[UpgradeCard] = UpgradeOffer.pick(pool, 3, rng)
		assert_int(offer.size()).is_equal(3)
		assert_int(_count_distinct_kinds(offer)).is_equal(3)


func test_ac21_pick_eventually_offers_every_stat() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pool: Array[UpgradeCard] = _player_pool()
	var offered: Dictionary[int, bool] = {}
	for i: int in 200:
		for card: UpgradeCard in UpgradeOffer.pick(pool, 3, rng):
			offered[(card as UpgradeData).stat] = true
	assert_int(offered.size()).is_equal(UPGRADEABLE_STAT_COUNT)


func test_ac54_pool_holds_player_and_ability_upgrades() -> void:
	var pool: Array[UpgradeCard] = UpgradeOffer.build_pool(CATALOG, SHIELD_CHARGE.upgrades)
	assert_int(pool.size()).is_equal(CATALOG.upgrades.size() + SHIELD_CHARGE.upgrades.size())
	for upgrade: AbilityUpgradeData in SHIELD_CHARGE.upgrades:
		assert_bool(pool.has(upgrade)).is_true()


## TICK_INTERVAL only applies to channelled abilities (berserker.md) and
## CHARGE_TIME to charged ones (samurai.md), not to the Shield Charge; each of
## its cards upgrades a different stat (warrior-abilities-rework.md §3.1).
func test_ac54_shield_charge_has_one_upgrade_per_stat_it_uses() -> void:
	var seen: Dictionary[int, bool] = {}
	for upgrade: AbilityUpgradeData in SHIELD_CHARGE.upgrades:
		seen[upgrade.stat] = true
	assert_int(seen.size()).is_equal(SHIELD_CHARGE.upgrades.size())
	assert_bool(seen.has(AbilityData.Stat.TICK_INTERVAL)).is_false()
	assert_bool(seen.has(AbilityData.Stat.CHARGE_TIME)).is_false()


func test_ac54_mixed_offers_never_repeat_a_kind_and_reach_every_ability_upgrade() -> void:
	var rng := RandomNumberGenerator.new()
	var pool: Array[UpgradeCard] = UpgradeOffer.build_pool(CATALOG, SHIELD_CHARGE.upgrades)
	var offered_ability: Dictionary[int, bool] = {}
	for seed_value: int in 500:
		rng.seed = seed_value
		var offer: Array[UpgradeCard] = UpgradeOffer.pick(pool, 3, rng)
		assert_int(_count_distinct_kinds(offer)).is_equal(3)
		for card: UpgradeCard in offer:
			if card is AbilityUpgradeData:
				offered_ability[(card as AbilityUpgradeData).stat] = true
	assert_int(offered_ability.size()).is_equal(SHIELD_CHARGE.upgrades.size())


func test_ac54_player_and_ability_cards_are_different_kinds() -> void:
	var player_card: UpgradeData = CATALOG.upgrades[0]
	var ability_card: AbilityUpgradeData = SHIELD_CHARGE.upgrades[0]
	assert_int(player_card.stat).is_equal(ability_card.stat)
	assert_bool(player_card.is_same_kind(ability_card)).is_false()
	assert_bool(ability_card.is_same_kind(player_card)).is_false()
