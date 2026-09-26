class_name HealthBarConfig
extends Resource
## Look and timing of the floating enemy health bar.

## Width and height of the bar, in meters.
@export var size: Vector2
## Height of the bar above the entity origin, in meters.
@export var height_offset: float
## Seconds the lost-health trail stays still after a hit.
@export var trail_hold_time: float
## Fraction of the full bar the trail drains per second.
@export var trail_drain_speed: float
## Text of the level label; %d is the level.
@export var level_format: String
@export var level_font_size: int
## World size of one font pixel, in meters.
@export var level_pixel_size: float
## Gap between the label's right edge and the bar's left edge, in meters.
@export var level_gap: float
## A hit removing at least this fraction of max health shakes the bar (critical hits always do).
@export var heavy_hit_fraction: float
## Seconds the bar shakes.
@export var shake_duration: float
## Horizontal amplitude at the start of the shake, in meters; decays linearly to 0.
@export var shake_amplitude: float
## Oscillations per second.
@export var shake_frequency: float
