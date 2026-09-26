class_name PlayerTuning
extends Resource
## Control-feel values of the player. Not upgradeable.

## Horizontal acceleration while there is movement input, in m/s².
@export var acceleration: float
## Horizontal deceleration without movement input, in m/s².
@export var deceleration: float
## Angular interpolation factor per second when turning the visual.
@export var turn_speed: float
## Initial speed of the push applied to enemies hit, in m/s.
## Not upgradeable: justified exception to Principle III (docs/specs/combat-feedback.md §0).
@export var knockback_speed: float
