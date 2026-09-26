class_name CooldownTextConfig
extends Resource
## How remaining seconds are written in the HUD and above enemy debuffs
## (docs/specs/cooldown-timers.md). Rounded up: never "0.0" while time is left.

## Below this many seconds the text shows tenths ("S.S"); from here on, whole seconds.
@export var decimal_below_seconds: float
## Size of one decimal step, in seconds.
@export var decimal_step: float
## Longest time written; anything above shows this value.
@export var max_seconds: int
## Float tolerance so 2.5000001 still shows "2.5".
@export var rounding_epsilon: float
## Outline of the 2D labels, for contrast over any background.
@export var outline_size: int
@export var outline_color: Color


## Tenths steps below the threshold (1 = one decimal_step).
func get_decimal_step_count() -> int:
	return roundi(decimal_below_seconds / decimal_step) - 1


## First whole second shown without decimals.
func get_first_whole_second() -> int:
	return ceili(decimal_below_seconds)
