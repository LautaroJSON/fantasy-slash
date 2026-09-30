class_name ShopPricing
extends RefCounted
## Pure price rules of the shop (docs/specs/gold-system.md).


## Price of one more copy of `card` on `wave`, with `copies` already taken.
## A rolled card costs more or less by its tier (`rolls`, optional).
static func card_price(card: UpgradeCard, wave: int, copies: int, config: ShopConfig, rolls: RollConfig = null) -> int:
	var price: float = float(config.card_base_price)
	price *= pow(config.card_growth_per_wave, float(wave - 1))
	price *= pow(config.card_growth_per_copy, float(copies))
	if card is AbilityUniqueUpgradeData:
		price *= config.unique_price_factor
	if card is UpgradeData and copies >= (card as UpgradeData).max_stacks:
		price *= pow((card as UpgradeData).ascension_price_growth, float(copies - (card as UpgradeData).max_stacks + 1))
	var stat_card: UpgradeData = card as UpgradeData
	if rolls != null and stat_card != null:
		price *= rolls.price_factor(stat_card.roll_tier)
	return maxi(roundi(price), 1)


static func reroll_price(rerolls_done: int, config: ShopConfig) -> int:
	return _grown(config.reroll_base_price, config.reroll_growth, rerolls_done)


static func heal_price(heals_done: int, config: ShopConfig) -> int:
	return _grown(config.heal_base_price, config.heal_growth, heals_done)


static func ban_price(bans_done: int, config: ShopConfig) -> int:
	return _grown(config.ban_base_price, config.ban_growth, bans_done)


static func _grown(base: int, growth: float, count: int) -> int:
	return maxi(roundi(float(base) * pow(growth, float(count))), 1)
