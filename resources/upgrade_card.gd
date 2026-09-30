class_name UpgradeCard
extends Resource
## Base of every card offered after a wave (player or ability upgrade).

## Section of the pause menu's upgrade tab (docs/specs/sandbox-arena-control.md).
enum Group {
	OFFENSE,
	DEFENSE,
	ABILITY,
	AFFLICTION,
}

## Name shown on the card.
@export var title: String
## Signed change shown on the card, e.g. "+4 de daño".
@export var description: String


## True when both cards upgrade the same thing, so an offer never repeats it.
func is_same_kind(_other: UpgradeCard) -> bool:
	return false


## Section of the card in the pause menu. Ability and Affliction cards belong
## to their section by type; player stat cards read it from their data.
func get_group() -> Group:
	return Group.ABILITY
