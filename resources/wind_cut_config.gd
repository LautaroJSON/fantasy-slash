class_name WindCutConfig
extends Resource
## Look and timing of the Sheathe wind cut (visual only, docs/specs/
## sheathe-visual-rework.md): on the release a thin line marks the slash on
## the ground; on the burst, segmented walls rise in a wave along it opening
## upwards in a V and thin out as they fade, a crescent and its echo fly
## forwards at chest height, a crack opens on the ground, sparks and dust
## rise along the slash and a flash bursts at its tip.

@export_group("Line")
## Width of the line marking the slash on the ground, in meters.
@export var line_width: float
## Seconds the line takes to grow from the player to the tip.
@export var line_grow_duration: float
## Transparency of the line (0 = opaque).
@export var line_transparency: float

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
## Segments of each wall along the slash.
@export var segment_count: int
## Share of its slot each segment fills (the rest is a thin gap).
@export var segment_fill: float
## Height of the end segments relative to the middle one (sine profile).
@export var edge_height_ratio: float
## Seconds between the start of the rise of one segment and the next,
## from the player towards the tip.
@export var wave_step: float
## Share of its height a segment keeps at the end of its fade.
@export var fade_height_ratio: float
## Share of its thickness a segment keeps at the end of its fade (0 = it thins
## out to nothing).
@export var fade_thickness_ratio: float
## Extra delay of the fade of the middle segment over the end ones, in
## seconds: the cut closes from the edges inwards.
@export var fade_stagger: float

@export_group("Crescent")
## Angle the crescent spans, in degrees.
@export var crescent_arc_degrees: float
## Outer radius of the crescent, in meters.
@export var crescent_radius: float
## Radial width of the crescent at its middle, in meters (0 at the tips).
@export var crescent_width: float
## Divisions of the arc (built once).
@export var crescent_segments: int
## Height of the crescent over the ground, in meters.
@export var crescent_height: float
## Tilt of the crescent around the slash, in degrees (positive raises its
## right side, like the rising draw).
@export var crescent_roll_degrees: float
## Distance in front of the player where the crescent is born, in meters.
@export var crescent_start: float
## Seconds it takes to fly to the tip of the slash (ease-out).
@export var crescent_travel: float
## Seconds it keeps fading once at the tip.
@export var crescent_fade: float
## Scale of the crescent when born (it grows to 1 over the travel).
@export var crescent_start_scale: float
## Smallest final scale: the final scale is the charge factor, not below this.
@export var crescent_min_scale: float
## Transparency of the crescent when born (it fades to 1).
@export var crescent_start_transparency: float
## Seconds the echo leaves after the crescent.
@export var echo_delay: float
## Size of the echo relative to the crescent.
@export var echo_scale: float
## Transparency of the echo when born (it fades to 1).
@export var echo_start_transparency: float

@export_group("Crack")
## Pieces of the crack along the slash.
@export var crack_count: int
## Width of each piece, in meters.
@export var crack_width: float
## Largest random turn of each piece, in degrees.
@export var crack_jitter_degrees: float
## Largest random sideways shift of each piece, in meters.
@export var crack_offset: float
## Seconds between one piece opening and the next, from the player.
@export var crack_open_step: float
## Seconds the crack stays after the burst before fading.
@export var crack_duration: float
## Seconds it takes to fade out.
@export var crack_fade: float

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
