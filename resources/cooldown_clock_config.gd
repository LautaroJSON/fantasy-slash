class_name CooldownClockConfig
extends Resource
## Look of the translucent cooldown "clock" (LoL style) drawn over HUD icons
## (docs/specs/cooldown-clock.md).

## Dark translucent sector covering the time still left.
@export var color: Color
## Edge points per full turn. A multiple of 8, so square corners fall on a point.
@export var steps_per_turn: int
