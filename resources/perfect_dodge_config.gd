class_name PerfectDodgeConfig
extends Resource
## Perfect dodge (docs/specs/perfect-dodge.md): an enemy hit that reaches the
## player during the first moments of a dash slows every enemy for an instant.
## Common to every class.

## Seconds from the start of the dash during which a hit counts; cut to the
## dash invulnerability.
@export var perfect_window: float
## Least seconds between two perfect dodges.
@export var min_interval: float
## Speed of every enemy during the slow time (1 = normal).
@export var enemy_time_scale: float
## Real seconds the slow time lasts.
@export var slow_duration: float
## Degrees the view widens when it happens (negative narrows it) and seconds it
## takes to ease back; a camera kick, like the one of the dash start.
@export var fov_kick_degrees: float
@export var fov_kick_return: float
## Text floated over the player.
@export var popup_text: String
## Height of that text above the player's feet, in meters.
@export var popup_height: float


## Pure: the window in effect for a dash whose invulnerability lasts `invulnerability` seconds.
func effective_window(invulnerability: float) -> float:
	return minf(perfect_window, invulnerability)
