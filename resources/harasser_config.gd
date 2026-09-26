class_name HarasserConfig
extends Resource
## How the Hostigador circles the player and when it sees an opening
## (docs/specs/enemy-types.md).

## Distance kept while circling, in meters.
@export var orbit_radius: float
## Seconds between changes of the circling direction.
@export var orbit_flip_time: float
## Angle between the player's facing and the direction to the enemy above
## which the player counts as showing its back, in degrees.
@export var back_angle: float
## Seconds after a player attack during which the enemy may strike.
@export var opening_window: float
## Seconds without an opening after which it strikes anyway.
@export var max_patience: float


## Pure: whether a player facing `player_facing` shows its back to an enemy
## lying along `to_enemy` (both flat).
func is_back_turned(player_facing: Vector3, to_enemy: Vector3) -> bool:
	if player_facing.is_zero_approx() or to_enemy.is_zero_approx():
		return false
	return player_facing.angle_to(to_enemy) > deg_to_rad(back_angle)
