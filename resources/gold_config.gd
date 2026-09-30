class_name GoldConfig
extends Resource
## Gold dropped by enemies and how coins move (docs/specs/gold-system.md).

## Value of a coin dropped by a regular enemy on wave 1.
@export var coin_value_base: float
## Extra value per wave.
@export var coin_value_per_wave: float
## Multiplies the value of a coin dropped by fodder.
@export var fodder_multiplier: float
## Multiplies the value of a coin dropped by a boss (HUD bar enemies).
@export var boss_multiplier: float
## Coins lying on the floor at once; a drop past the cap adds its value to the
## nearest coin instead of creating a new one.
@export var max_coins_on_floor: int
## Speed of a coin once the player is inside the pickup radius, in m/s.
@export var magnet_speed: float
## Extra speed per second while the coin is being pulled, in m/s².
@export var magnet_acceleration: float
## Distance to the player at which the coin is collected, in meters.
@export var collect_distance: float
## Height of a resting coin above the floor, in meters.
@export var rest_height: float
## Spin of a resting coin, in radians per second.
@export var spin_speed: float
## True: the coins left on the floor are collected when the run changes stage.
@export var stage_change_auto_collect: bool


## Value of the coin an enemy drops on `wave`. `multiplier` comes from the enemy kind.
func coin_value(wave: int, multiplier: float) -> int:
	return maxi(roundi((coin_value_base + coin_value_per_wave * float(wave - 1)) * multiplier), 1)
