class_name HitstopConfig
extends Resource
## Local hit lag of the basic attack (docs/specs/bdo-combat-feel.md). How long
## it lasts and how much the camera shakes are per strike (AttackComboStep).

## Sideways shake of the enemies frozen by a hit, in meters.
@export var enemy_shake_amplitude: float
## Frequency of that shake, in hertz.
@export var enemy_shake_frequency: float
