class_name LeapAttackData
extends EnemyAttackData
## Saltador leap: the windup locks the landing point, the jump follows a
## parabola and the slam hits a circle (hit_range, hit_arc_degrees 360) where
## it lands. active_time is how long the hands stay down after the slam.
## See docs/specs/enemy-types.md.

## Closer than this the enemy backs off before leaping, in meters.
@export var min_trigger_range: float
## Longest leap, in meters (the landing point is clamped to it).
@export var max_leap_distance: float
## Seconds in the air.
@export var leap_time: float
## Highest point of the jump above the take-off, in meters.
@export var leap_height: float
## Hand offset (relative to rest) while in the air.
@export var air_hand_offset: Vector3


## Pure: upward speed that peaks at leap_height and lands after leap_time.
func get_launch_speed() -> float:
	return 4.0 * leap_height / leap_time


## Pure: gravity (m/s²) of that parabola.
func get_leap_gravity() -> float:
	return 8.0 * leap_height / (leap_time * leap_time)
