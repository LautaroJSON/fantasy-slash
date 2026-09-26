class_name GuardConfig
extends Resource
## Escudero guard: blocks hits and pushes from the front while it is up
## (docs/specs/enemy-types.md). The guard pose is the type's hands rest pose.

## Full width of the blocking arc, centred on the enemy's facing, in degrees.
@export var block_arc: float
## Fraction of a blocked hit removed (after defense).
@export var block_reduction: float
## Degrees per second the enemy turns towards the target while guarding.
@export var guard_turn_speed: float
## Seconds the guard stays down after the recovery of an attack.
@export var guard_down_time: float
## Hand offset (relative to rest) while the guard is down.
@export var guard_down_offset: Vector3


## Pure: whether something lying along `to_attacker` (flat) from an enemy
## facing `facing` is inside the blocking arc.
func blocks(facing: Vector3, to_attacker: Vector3) -> bool:
	if facing.is_zero_approx() or to_attacker.is_zero_approx():
		return false
	return facing.angle_to(to_attacker) <= deg_to_rad(block_arc) * 0.5
