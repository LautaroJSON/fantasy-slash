class_name DashSlashVfxConfig
extends Resource
## Look of the effects of the horizontal slash of a dash that cuts the Spin
## short: sparks along the dash path and a flash at its tip. The sweep itself
## is shown by the weapon and its trail.

@export_group("Path")
## Height of the sparks and the flash above the player's feet, in meters.
@export var blade_height: float

@export_group("Sparks")
@export var spark_amount: int
@export var spark_lifetime: float
## Initial spark speed range, in m/s.
@export var spark_speed_min: float
@export var spark_speed_max: float
## Side of each spark cube, in meters.
@export var spark_size: float

@export_group("Flash")
## Radius of the flash sphere at the tip, in meters.
@export var flash_radius: float
## Seconds the flash (sphere and light) lasts.
@export var flash_duration: float
## Transparency of the flash sphere when it starts (0 = opaque).
@export var flash_start_transparency: float
@export var flash_energy: float
@export var flash_range: float
