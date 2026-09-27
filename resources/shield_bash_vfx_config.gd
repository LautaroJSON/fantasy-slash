class_name ShieldBashVfxConfig
extends Resource
## Look of the Shield Charge's dust (docs/specs/warrior-abilities-rework.md §3.1):
## puffs kicked up at the player's feet while charging, and a flat dust ring
## that opens where the shield bash lands.

## Height above the ground, in meters.
@export var ground_offset: float
@export var dust_amount: int
@export var dust_lifetime: float
## Diameter of each dust puff, in meters.
@export var dust_size: float
## Speed of the puffs as they leave the feet, in m/s.
@export var dust_speed: float
## How far the puffs open from straight up, in degrees.
@export var dust_spread_degrees: float
## Meters in front of the player the bash ring opens.
@export var ring_forward_offset: float
## Radius the ring reaches, in meters (× empowered_ring_scale when empowered).
@export var ring_radius: float
## Thickness of the ring, in meters.
@export var ring_thickness: float
## Seconds the ring takes to open and fade.
@export var ring_duration: float
## Transparency of the ring when it starts (0 = opaque); it fades to 1.
@export var ring_start_transparency: float
