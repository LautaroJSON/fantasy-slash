class_name TelegraphConfig
extends Resource
## Look and timing of the enemy attack warnings on the floor
## (docs/specs/enemy-ground-telegraph.md).

## Height of the zone above the floor, in meters (avoids z-fighting).
@export var ground_offset: float
## Extra height of the fill over the zone, in meters.
@export var fill_lift: float
## Vertical thickness of the zone and the fill, in meters.
@export var thickness: float
## Transparency of the whole zone (0 = the material's alpha, 1 = invisible).
@export var base_transparency: float
@export var fill_transparency: float
## Transparency of the fill during the flash of the hit.
@export var flash_transparency: float
## Seconds the flash holds before fading.
@export var flash_time: float
## Seconds the zone takes to fade out after the flash.
@export var fade_time: float
## Triangles of a full-circle sector (an arc uses its share, at least 2).
@export var sector_segments: int
## Dust puffs of a floor hit.
@export var dust_amount: int
## Seconds each dust puff lives.
@export var dust_lifetime: float
## Diameter of each dust puff, in meters.
@export var dust_size: float
## Rising speed range of the dust, in m/s.
@export var dust_rise_speed_min: float
@export var dust_rise_speed_max: float
## Fraction of the zone's radius the dust spreads over.
@export var dust_spread: float
## Half-angle of the cone the dust rises in, in degrees.
@export var dust_cone_degrees: float
