class_name WindCutConfig
extends Resource
## Look and timing of the Sheathe wind cut (visual only): two walls rising from
## the ground along the slash and opening upwards in a V, sparks and dust along
## the slash, and a flash at its tip.

@export_group("Walls")
## Height of the walls at full charge, in meters (scaled by the charge factor).
@export var max_height: float
## Outward tilt of each wall from the vertical, in degrees.
@export var half_angle_degrees: float
## Thickness of each wall, in meters.
@export var wall_thickness: float
## Seconds the walls take to rise from the ground to their height.
@export var grow_duration: float
## Seconds they take to fade out after rising.
@export var fade_duration: float
## Transparency while rising and at the start of the fade (0.5 = alpha 0.5).
@export var start_transparency: float

@export_group("Sparks")
@export var spark_amount: int
## Seconds each spark lives.
@export var spark_lifetime: float
## Initial speed range of the sparks, in m/s.
@export var spark_speed_min: float
@export var spark_speed_max: float
## Spread of the sparks around the vertical, in degrees.
@export var spark_spread_degrees: float
## Downward acceleration of the sparks, in m/s².
@export var spark_gravity: float
## Size of each spark cube, in meters.
@export var spark_size: float

@export_group("Dust")
@export var dust_amount: int
## Seconds each dust puff lives.
@export var dust_lifetime: float
## Rising speed range of the dust, in m/s.
@export var dust_rise_speed_min: float
@export var dust_rise_speed_max: float
## Diameter of each dust puff, in meters.
@export var dust_size: float
## Width of the strip the dust rises from, in meters.
@export var dust_width: float

@export_group("Flash")
## Height of the flash at the tip of the slash, in meters.
@export var flash_height: float
## Radius the flash sphere grows to, in meters.
@export var flash_radius: float
## Seconds the flash (sphere and light) lasts.
@export var flash_duration: float
## Initial energy of the flash light.
@export var flash_energy: float
## Reach of the flash light, in meters.
@export var flash_range: float
