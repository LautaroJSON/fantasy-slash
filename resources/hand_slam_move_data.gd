class_name HandSlamMoveData
extends BossMoveData
## Titán: one hand rises, locks the impact point on the target at lock_fraction
## of the windup and crashes there, hitting a circle once; it then rests on the
## floor for hand_rest_time as a weak point (docs/specs/boss-titan.md).
## `attack` gives the windup, active and recovery times and the damage.

@export var attack: EnemyAttackData
## Fraction of the windup after which the impact point stops following the target.
@export var lock_fraction: float
## Radius of the impact circle, in meters.
@export var impact_radius: float
## Seconds the hand rests on the floor after the impact.
@export var hand_rest_time: float
## Hand position (relative to its rest pose, right-hand space) at the top of the windup.
@export var raise_offset: Vector3


## Pure: whether a target at `point` (feet) is inside the impact circle.
func is_hit(impact: Vector3, point: Vector3) -> bool:
	return Vector2(point.x - impact.x, point.z - impact.z).length() <= impact_radius
