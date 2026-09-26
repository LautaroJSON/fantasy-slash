class_name ChargeAttackData
extends EnemyAttackData
## Embestidor charge: the windup locks a direction and the enemy runs along it.
## active_time is unused: the charge lasts until charge_distance or a wall.
## See docs/specs/enemy-types.md.

## Closer than this the enemy backs off before charging, in meters.
@export var min_trigger_range: float
## Meters per second while charging.
@export var charge_speed: float
## Longest charge, in meters.
@export var charge_distance: float
## Recovery after running into a wall (replaces recovery_time).
@export var wall_stun_time: float
## Hand offset (relative to rest) while stunned in the recovery.
@export var stun_hand_offset: Vector3
