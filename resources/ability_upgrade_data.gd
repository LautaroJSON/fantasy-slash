class_name AbilityUpgradeData
extends UpgradeCard
## One ability upgrade card: adds `amount` (may be negative) to a single stat
## of the ability that lists it in AbilityData.upgrades.

@export var stat: AbilityData.Stat
@export var amount: float
## Times this card can be taken in a run.
@export var max_stacks: int


func is_same_kind(other: UpgradeCard) -> bool:
	var upgrade: AbilityUpgradeData = other as AbilityUpgradeData
	return upgrade != null and upgrade.stat == stat
