class_name ShockwaveMoveData
extends BossMoveData
## The boss slams the floor and rings grow from it; a ring hits a target on
## the ground inside its band once. `attack` gives the windup, the recovery
## and the damage multiplier.

@export var attack: EnemyAttackData
## Radius of a ring when it appears, in meters.
@export var start_radius: float
## A ring disappears at this radius, in meters.
@export var max_radius: float
## Meters per second a ring grows.
@export var speed: float
## Width of a ring's band, in meters.
@export var width: float
## A target whose feet are this high above the slam point is jumping over it.
@export var clear_height: float
@export var rings_phase_one: int
@export var rings_phase_two: int
## Seconds between two rings.
@export var ring_delay: float


## Pure: whether a ring of `radius` around `center` hits a target at `point` (feet).
func is_hit(center: Vector3, radius: float, point: Vector3) -> bool:
	if point.y - center.y >= clear_height:
		return false
	var distance: float = Vector2(point.x - center.x, point.z - center.z).length()
	return absf(distance - radius) <= width * 0.5


## Pure: rings of the slam in boss phase `phase`.
func ring_count(phase: int) -> int:
	return rings_phase_two if phase == 2 else rings_phase_one
