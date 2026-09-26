class_name HitFeedbackConfig
extends Resource
## How the player reacts when it takes damage: camera shake and body flicker.

## Damage that produces a full-strength shake; smaller hits shake less.
@export var damage_for_full_shake: float
## Weakest shake strength of any damaging hit, in [0, 1].
@export var min_strength: float
## Seconds the player flickers after a hit.
@export var flicker_duration: float
## Seconds between visibility toggles while flickering.
@export var flicker_interval: float
