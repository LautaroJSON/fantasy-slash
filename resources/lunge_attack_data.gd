class_name LungeAttackData
extends EnemyAttackData
## Hostigador lunge: after the windup the enemy darts at the target along a
## locked direction and stops short of it. active_time is unused: the lunge
## lasts until it has covered its distance or hits a wall.
## See docs/specs/enemy-types.md.

## Meters per second while lunging.
@export var lunge_speed: float
## Longest lunge, in meters.
@export var lunge_distance: float
## The lunge stops this far from the target, in meters.
@export var stop_distance: float
