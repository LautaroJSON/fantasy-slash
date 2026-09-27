extends GdUnitTestSuite

const RULES: CardBanRules = preload("res://data/upgrades/card_ban_rules.tres")
const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")


func test_ac67_ban_card_every_three_waves_until_the_cap() -> void:
	var offered_waves: Array[int] = []
	for wave: int in range(1, 10):
		if RULES.is_offered(wave, 0):
			offered_waves.append(wave)
	assert_array(offered_waves).is_equal([3, 6, 9])
	for wave: int in range(1, 10):
		assert_bool(RULES.is_offered(wave, RULES.max_bans)).is_false()
	assert_bool(RULES.is_offered(3, RULES.max_bans - 1)).is_true()


func test_ac68_banned_cards_are_never_offered() -> void:
	var pool: Array[UpgradeCard] = UpgradeOffer.build_pool(CATALOG, SHIELD_CHARGE.upgrades)
	var banned: Array[UpgradeCard] = []
	for i: int in RULES.max_bans:
		banned.append(pool[i])
	var available: Array[UpgradeCard] = UpgradeOffer.without(pool, banned)
	assert_int(available.size()).is_equal(pool.size() - RULES.max_bans)
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 500:
		rng.seed = seed_value
		var offer: Array[UpgradeCard] = UpgradeOffer.pick(available, 3, rng)
		assert_int(offer.size()).is_equal(3)
		for card: UpgradeCard in offer:
			assert_bool(banned.has(card)).is_false()
		assert_bool(offer[0].is_same_kind(offer[1]) or offer[0].is_same_kind(offer[2]) or offer[1].is_same_kind(offer[2])).is_false()
