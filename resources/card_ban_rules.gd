class_name CardBanRules
extends Resource
## When the red "ban an upgrade" card is offered, and its text.

## The ban card is offered after every wave that is a multiple of this.
@export var every_waves: int
## Maximum upgrades a run can ban.
@export var max_bans: int
## Title shown on the red card.
@export var title: String
## Text shown on the red card.
@export_multiline var description: String


func is_offered(cleared_wave: int, bans_used: int) -> bool:
	return bans_used < max_bans and cleared_wave % every_waves == 0
