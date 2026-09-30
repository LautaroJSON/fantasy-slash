extends GdUnitTestSuite
## Gold wallet, prices and ascension (docs/specs/gold-system.md, AC1396-AC1425).

const GOLD: GoldConfig = preload("res://data/economy/gold_config.tres")
const SHOP: ShopConfig = preload("res://data/economy/shop_config.tres")
const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const DAMAGE: UpgradeData = preload("res://data/upgrades/damage.tres")
const PICKUP: UpgradeData = preload("res://data/upgrades/pickup_radius.tres")
const WARRIOR: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const BERSERKER: PlayerStats = preload("res://data/classes/berserker/berserker_stats.tres")
const SAMURAI: PlayerStats = preload("res://data/classes/samurai/samurai_stats.tres")
const RULES: CombatRules = preload("res://data/combat/combat_rules.tres")
const EPSILON: float = 0.0001


func _stats_with(cards: Array[UpgradeData]) -> StatsComponent:
	var stats: StatsComponent = auto_free(StatsComponent.new())
	stats.base_stats = WARRIOR
	stats.rules = RULES
	for card: UpgradeData in cards:
		stats.add_upgrade(card)
	return stats


func test_ac1396_coin_value_grows_with_the_wave_and_the_kind() -> void:
	assert_int(GOLD.coin_value(1, 1.0)).is_equal(3)
	assert_int(GOLD.coin_value(21, 1.0)).is_greater(GOLD.coin_value(1, 1.0))
	assert_int(GOLD.coin_value(5, GOLD.boss_multiplier)).is_greater(GOLD.coin_value(5, 1.0))
	assert_int(GOLD.coin_value(5, GOLD.fodder_multiplier)).is_less_equal(GOLD.coin_value(5, 1.0))
	assert_int(GOLD.coin_value(1, 0.0)).is_equal(1)


func test_ac1400_pickup_radius_is_the_same_in_every_class() -> void:
	assert_float(WARRIOR.pickup_radius).is_greater(0.0)
	assert_float(BERSERKER.pickup_radius).is_equal(WARRIOR.pickup_radius)
	assert_float(SAMURAI.pickup_radius).is_equal(WARRIOR.pickup_radius)


func test_ac1401_the_magnet_card_raises_the_radius() -> void:
	assert_bool(CATALOG.upgrades.has(PICKUP)).is_true()
	var cards: Array[UpgradeData] = [PICKUP]
	assert_float(_stats_with(cards).get_stat(PlayerStats.Stat.PICKUP_RADIUS)).is_equal_approx(WARRIOR.pickup_radius + PICKUP.amount, EPSILON)


func test_ac1403_wallet_spends_only_what_it_has() -> void:
	var wallet: GoldWallet = auto_free(GoldWallet.new())
	wallet.add(50)
	assert_bool(wallet.try_spend(60)).is_false()
	assert_int(wallet.get_gold()).is_equal(50)
	assert_bool(wallet.try_spend(20)).is_true()
	assert_int(wallet.get_gold()).is_equal(30)
	wallet.add(0)
	wallet.add(-5)
	assert_int(wallet.get_gold()).is_equal(30)


func test_ac1404_card_price_grows_with_the_wave_and_the_copies() -> void:
	var base: int = ShopPricing.card_price(DAMAGE, 1, 0, SHOP)
	assert_int(base).is_equal(SHOP.card_base_price)
	assert_int(ShopPricing.card_price(DAMAGE, 20, 0, SHOP)).is_greater(base)
	assert_int(ShopPricing.card_price(DAMAGE, 1, 3, SHOP)).is_greater(base)


func test_ac1408_reroll_heal_and_ban_prices_grow_per_use() -> void:
	assert_int(ShopPricing.reroll_price(0, SHOP)).is_equal(SHOP.reroll_base_price)
	assert_int(ShopPricing.reroll_price(2, SHOP)).is_greater(ShopPricing.reroll_price(1, SHOP))
	assert_int(ShopPricing.heal_price(2, SHOP)).is_greater(ShopPricing.heal_price(0, SHOP))
	assert_int(ShopPricing.ban_price(1, SHOP)).is_greater(ShopPricing.ban_price(0, SHOP))


func test_ac1412_a_card_keeps_giving_a_decreasing_bonus_after_its_cap() -> void:
	assert_int(DAMAGE.ascension_levels).is_greater(0)
	var last_regular: float = DAMAGE.amount_for_copy(DAMAGE.max_stacks - 1)
	var first_ascended: float = DAMAGE.amount_for_copy(DAMAGE.max_stacks)
	var second_ascended: float = DAMAGE.amount_for_copy(DAMAGE.max_stacks + 1)
	assert_float(last_regular).is_equal_approx(DAMAGE.amount, EPSILON)
	assert_float(first_ascended).is_less(last_regular)
	assert_float(first_ascended).is_greater(0.0)
	assert_float(second_ascended).is_less(first_ascended)


func test_ac1412_stats_sum_the_ascended_bonus() -> void:
	var cards: Array[UpgradeData] = []
	var expected: float = WARRIOR.damage
	for i: int in DAMAGE.total_copies():
		cards.append(DAMAGE)
		expected += DAMAGE.amount_for_copy(i)
	assert_float(_stats_with(cards).get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(expected, EPSILON)


func test_ac1413_a_card_without_ascension_keeps_its_full_amount() -> void:
	var plain: UpgradeData = UpgradeData.new()
	plain.amount = 4.0
	assert_float(plain.amount_for_copy(0)).is_equal(4.0)
	assert_float(plain.amount_for_copy(7)).is_equal(4.0)
	assert_int(plain.total_copies()).is_equal(0)


func test_ac1412_ascended_price_jumps_past_the_last_regular_copy() -> void:
	var last_regular: int = ShopPricing.card_price(DAMAGE, 1, DAMAGE.max_stacks - 1, SHOP)
	var ascended: int = ShopPricing.card_price(DAMAGE, 1, DAMAGE.max_stacks, SHOP)
	assert_int(ascended).is_greater(last_regular)
