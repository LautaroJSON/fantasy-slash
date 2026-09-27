class_name SpinDustConfig
extends Resource
## Look of the Spin's dust (docs/specs/spin-visual-rework.md §12): puffs kicked
## up from a small ring around the player's feet, the center of the spin,
## rising and opening outwards while the spin lasts.

## Radius of the ring around the feet the dust rises from, in meters.
@export var dust_ring_radius: float
## How far the puffs open outwards from straight up, in degrees.
@export var dust_spread_degrees: float
## Height above the player's feet, in meters.
@export var ground_offset: float
@export var dust_amount: int
@export var dust_lifetime: float
## Diameter of each dust puff, in meters.
@export var dust_size: float
## Speed of the dust as it leaves the ring, in m/s.
@export var dust_rise_speed: float
