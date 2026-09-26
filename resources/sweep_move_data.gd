class_name SweepMoveData
extends BossMoveData
## Titán: one hand sweeps a wide arc low over the floor; a target whose feet
## are clear_height above the floor jumps over it (docs/specs/boss-titan.md).
## `attack` gives the times, the arc (hit_arc_degrees, hit_range), the hand
## poses and the damage.

@export var attack: EnemyAttackData
@export var clear_height: float


## Pure: whether the sweep of a boss at `origin` facing `facing` hits a target at `point` (feet).
func is_hit(origin: Vector3, facing: Vector3, point: Vector3, padding: float) -> bool:
	if point.y - origin.y >= clear_height:
		return false
	return attack.is_hit(origin, facing, point, padding)
