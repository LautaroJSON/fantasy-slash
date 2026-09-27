class_name HitImpactVfxConfig
extends Resource
## Look of the impact shown where the blade crosses an enemy it hits
## (docs/specs/hit-impact-vfx.md): a shard of light along the cut, a flash and
## sparks. Critical hits are bigger and add a crossed shard.

@export_group("Pool")
## Effects created once when the player loads; the oldest one is reused when
## they are all playing.
@export var pool_size: int

@export_group("Timing")
## Seconds the shard and the flash last.
@export var duration: float
## Seconds the shard takes to stretch to its full length.
@export var grow_time: float

@export_group("Shard")
## Length of the shard along the cut, in meters.
@export var shard_length: float
## Width of the shard across the cut, in meters.
@export var shard_width: float
## Thickness of the shard along the enemy's surface normal, in meters.
@export var shard_thickness: float
## Transparency of the shard at full length (0 = opaque).
@export var shard_start_transparency: float
## Width of the halo around the shard, as a multiple of the shard's width.
@export var shard_halo_scale: float
## Transparency of the halo at full length (0 = opaque).
@export var shard_halo_transparency: float

@export_group("Flash")
## Radius the flash sphere grows to, in meters.
@export var flash_radius: float
## Transparency of the flash sphere when it starts (0 = opaque).
@export var flash_start_transparency: float
@export var flash_energy: float
@export var flash_range: float

@export_group("Sparks")
@export var spark_amount: int
## Side of each spark cube, in meters.
@export var spark_size: float
@export var spark_lifetime: float
## Initial spark speed range, in m/s.
@export var spark_speed_min: float
@export var spark_speed_max: float
## Spread of the sparks around the cut direction, in degrees.
@export var spark_spread: float

@export_group("Placement")
## Lowest and highest impact height above the enemy's feet, in meters.
@export var min_height: float
@export var max_height: float
## Tip movement (meters per physics step) below which the cut direction is
## unknown and the shard lies flat, across the player→enemy direction.
@export var min_tip_speed: float

@export_group("Critical")
## Scale of the whole effect on a critical hit.
@export var crit_scale: float
## Angle of the second shard of a critical hit, around the surface normal, in degrees.
@export var crit_cross_angle: float
