class_name SpinVortexConfig
extends Resource
## Look of the Spin's vortex (docs/specs/spin-visual-rework.md §2.4): the white
## area on the ground that shows where the turns hit, its pulse on each turn,
## and the dust kicked up under the blade.

@export_group("Area")
## Opacity of the area while spinning (at most 0.3, Principle II).
@export var area_alpha: float
## Vertical thickness of the flat disc, in meters.
@export var area_height: float
## Height above the player's feet, in meters (avoids z-fighting with the floor).
@export var ground_offset: float
## Seconds the area takes to appear.
@export var area_fade_in: float
## Seconds the area takes to fade out when the spin ends.
@export var area_fade_out: float

@export_group("Pulse")
## Opacity the area jumps to when a turn completes (at most 0.5, Principle II).
@export var pulse_alpha: float
## Scale of the area when the pulse starts; it grows back to 1.
@export var pulse_start_scale: float
## Seconds the pulse takes to return to the resting opacity and scale.
@export var pulse_duration: float

@export_group("Dust")
## Where the dust rises from, in the player's facing space (-Z forward, +X
## right): on the ground under the blade.
@export var dust_offset: Vector3
@export var dust_amount: int
@export var dust_lifetime: float
## Diameter of each dust puff, in meters.
@export var dust_size: float
## Upward speed of the dust, in m/s.
@export var dust_rise_speed: float
