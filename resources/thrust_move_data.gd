class_name ThrustMoveData
extends BossMoveData
## El Rey: a lunge with the point forward along a line locked at the end of the
## windup (docs/specs/boss-king.md). The blow lands once along the path.
## `attack` gives the times, the arc and reach of the point and the damage.

@export var attack: EnemyAttackData
@export var thrust_speed: float
@export var thrust_distance: float
## The lunge stops this far from the target, in meters.
@export var stop_distance: float
## Width of the warning strip on the floor, in meters.
@export var line_width: float
## Thrusts in phase 2 (the extra ones follow each other after chain_delay).
@export var thrusts_phase_two: int = 1
## Seconds between one thrust and the next of a chain.
@export var chain_delay: float
## Windup of every thrust of a chain after the first, in seconds.
@export var chain_windup_time: float


## Pure: meters the lunge covers towards a target `distance` away.
func lunge_length(distance: float) -> float:
	return clampf(distance - stop_distance, 0.0, thrust_distance)


## Pure: thrusts in the move for boss phase `phase` (1 or 2).
func thrusts(phase: int) -> int:
	return maxi(thrusts_phase_two, 1) if phase == 2 else 1
