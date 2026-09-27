class_name StrikeFeel
extends Resource
## Impact of one ability strike (docs/specs/warrior-abilities-rework.md §4.4),
## as the combo's AttackComboStep has for the basic attack. Read by
## HitstopComponent when the ability emits AbilityComponent.struck.

## Seconds the player's clip pauses and the enemies hit freeze and shake
## (bosses only shake). 0 = none.
@export var hitlag: float
## Camera shake strength. 0 = none.
@export var shake_strength: float
