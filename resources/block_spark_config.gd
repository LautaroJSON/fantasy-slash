class_name BlockSparkConfig
extends Resource
## Look of the sparks on the shield when it blocks a hit
## (docs/specs/warrior-abilities-rework.md §3.2): white, additive, gone in
## tenths of a second (Principle II). Pooled: created once.

## Spark bursts that can play at once; the oldest is reused when all play.
@export var pool_size: int
@export var spark_amount: int
## Size of each spark, in meters.
@export var spark_size: float
@export var spark_lifetime: float
@export var spark_speed_min: float
@export var spark_speed_max: float
## How far the sparks open from the direction of the attacker, in degrees.
@export var spark_spread_degrees: float
## Height of the burst above the player's feet, in meters.
@export var height: float
## Meters in front of the player (towards the attacker) the burst plays.
@export var forward_offset: float
