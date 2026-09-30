class_name RollConfig
extends Resource
## Quality of a white (player stat) card: each copy offered rolls one of these
## tiers (docs/specs/upgrade-cards-redesign.md). Index 0 = the lowest tier.

## Chance weight of each tier (any scale, they are normalized when rolling).
@export var weights: Array[float]
## Multiplies the shop price of a card of each tier.
@export var price_factors: Array[float]
## Color of the card number at each tier.
@export var colors: Array[Color]
## Name of each tier, shown on the card.
@export var names: Array[String]


func tier_count() -> int:
	return weights.size()


func price_factor(tier: int) -> float:
	if tier < 0 or tier >= price_factors.size():
		return 1.0
	return price_factors[tier]


func color_of(tier: int) -> Color:
	return colors[clampi(tier, 0, colors.size() - 1)]


func name_of(tier: int) -> String:
	return names[clampi(tier, 0, names.size() - 1)]
