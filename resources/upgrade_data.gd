class_name UpgradeData
extends UpgradeCard
## One player upgrade card: adds `amount` (may be negative) to a single stat.
## An offered copy carries a roll (`roll_amounts`, docs/specs/upgrade-cards-redesign.md).

## Category of the white card (its icon).
enum Category {
	DAMAGE,
	DEFENSE,
	UTILITY,
}

@export var stat: PlayerStats.Stat
## Value of the middle roll: what the sandbox and the pause menu use.
@export var amount: float
## Times this card can be taken in a run.
@export var max_stacks: int
## Section of the pause menu (offensive, defensive or Affliction).
@export var group: UpgradeCard.Group
## Category shown on the card: damage, defensive or utility.
@export var category: Category
## Extra copies bought after max_stacks (docs/specs/gold-system.md). 0 = the
## card leaves the pool at its cap.
@export var ascension_levels: int
## Each ascension copy gives this fraction of the previous copy's bonus.
@export var ascension_factor: float
## Price growth per ascension copy, on top of the price of the last regular copy.
@export var ascension_price_growth: float
## Value of each roll tier (index 0 = lowest). Empty = the card never rolls.
@export var roll_amounts: Array[float]
## How the amount is shown on the card ("+3", "+5 %").
@export var value_format: ValueFormat
## What follows the amount on the card ("de daño").
@export var value_label: String

## Tier of a rolled copy, -1 on a catalog card.
var roll_tier: int = -1


func is_same_kind(other: UpgradeCard) -> bool:
	var upgrade: UpgradeData = other as UpgradeData
	return upgrade != null and upgrade.stat == stat


func get_group() -> UpgradeCard.Group:
	return group


## Copies that can be taken in total, ascension included.
func total_copies() -> int:
	return max_stacks + ascension_levels


## Bonus of the copy taken as number `index` (0-based): the full amount up to
## max_stacks, then decreasing by ascension_factor per copy.
func amount_for_copy(index: int) -> float:
	if ascension_levels <= 0 or index < max_stacks:
		return amount
	return amount * pow(ascension_factor, float(index - max_stacks + 1))


## Copy of this card with the value of `tier`; the catalog card is not touched.
func rolled(tier: int) -> UpgradeData:
	var copy: UpgradeData = duplicate() as UpgradeData
	copy.amount = roll_amounts[clampi(tier, 0, roll_amounts.size() - 1)]
	copy.roll_tier = tier
	return copy


## "+3 de daño" style text of `value`.
func describe_value(value: float) -> String:
	if value_format == null:
		return description
	return ("%s %s" % [value_format.format_value(value), value_label]).strip_edges()
