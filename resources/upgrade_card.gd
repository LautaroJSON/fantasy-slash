class_name UpgradeCard
extends Resource
## Base of every card offered after a wave (player or ability upgrade).

## Name shown on the card.
@export var title: String
## Signed change shown on the card, e.g. "+4 de daño".
@export var description: String


## True when both cards upgrade the same thing, so an offer never repeats it.
func is_same_kind(_other: UpgradeCard) -> bool:
	return false
