class_name DamageNumberConfig
extends Resource
## Pool size, motion and look of the floating damage numbers. Normal and
## critical hits differ in color, text, scale, opacity, lifetime and rise speed.

@export var pool_size: int
## Seconds a normal number stays on screen.
@export var lifetime: float
## Upward speed of a normal number, in m/s.
@export var rise_speed: float
## Height above the enemy origin where numbers appear, in meters.
@export var spawn_height: float
## Maximum random horizontal offset of the spawn point, in meters.
@export var spread: float
@export var font_size: int
## World size of one font pixel, in meters.
@export var pixel_size: float
## Scale of normal numbers.
@export var normal_scale: float
## Transparency of a normal number before it fades out, in [0, 1].
@export var normal_transparency: float
## Final scale of critical-hit numbers, reached after the pop.
@export var crit_scale: float
## Scale of a critical-hit number when it appears.
@export var crit_pop_scale: float
## Seconds the pop takes to shrink from crit_pop_scale to crit_scale.
@export var crit_pop_duration: float
## Seconds a critical-hit number stays on screen.
@export var crit_lifetime: float
## Upward speed of a critical-hit number, in m/s.
@export var crit_rise_speed: float
## Appended to the amount of a critical hit.
@export var crit_suffix: String
## Fraction of the lifetime after which the number starts fading out.
@export var fade_start: float
## Font of damage-over-time ticks (poison, bleeding): the default font slanted
## into italics (docs/specs/affliction-damage-colors.md).
@export var over_time_font: FontVariation
