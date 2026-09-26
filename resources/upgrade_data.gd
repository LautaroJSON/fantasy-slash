class_name UpgradeData
extends UpgradeCard
## One player upgrade card: adds `amount` (may be negative) to a single stat.

@export var stat: PlayerStats.Stat
@export var amount: float
## Times this card can be taken in a run.
@export var max_stacks: int


func is_same_kind(other: UpgradeCard) -> bool:
	var upgrade: UpgradeData = other as UpgradeData
	return upgrade != null and upgrade.stat == stat
