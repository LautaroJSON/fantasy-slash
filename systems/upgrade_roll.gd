class_name UpgradeRoll
extends RefCounted
## Pure roll of the white cards of an offer (docs/specs/upgrade-cards-redesign.md).


## Tier drawn with the weights of `config`, using the injected RNG (reproducible by seed).
static func roll_tier(config: RollConfig, rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for weight: float in config.weights:
		total += weight
	var point: float = rng.randf() * total
	for tier: int in config.weights.size():
		point -= config.weights[tier]
		if point < 0.0:
			return tier
	return config.weights.size() - 1


## The offer with every card that has rolls replaced by a copy with its roll.
## Other cards, and everything when there is no config, are kept as they are.
static func roll_offer(offer: Array[UpgradeCard], config: RollConfig, rng: RandomNumberGenerator) -> Array[UpgradeCard]:
	var rolled: Array[UpgradeCard] = []
	for card: UpgradeCard in offer:
		var stat_card: UpgradeData = card as UpgradeData
		if config == null or stat_card == null or stat_card.roll_amounts.is_empty():
			rolled.append(card)
		else:
			rolled.append(stat_card.rolled(roll_tier(config, rng)))
	return rolled
