class_name AfflictionConfig
extends Resource
## Global rules and look of the Affliction bars (docs/specs/affliction.md).

## Different Afflictions a run can hold; also the bar rows created per enemy.
@export var max_types: int
## Build-up points that fill a bar.
@export var threshold: float
## Highest resistance an enemy's data can give (1 is left for a future immunity).
@export var max_resistance: float
## Seconds a bar waits without build-up before it starts draining.
@export var decay_delay: float
## Points a draining bar loses per second.
@export var decay_per_second: float
## Seconds a bar shows full, with flash_material, after it triggers.
@export var flash_duration: float
## Height of each 3D row under the health bar, in meters.
@export var bar_height: float
## Gap between the health bar and the first row, and between rows, in meters.
@export var bar_gap: float
## Height of each row under a boss HUD bar, in pixels.
@export var hud_bar_height_px: float
## Gap between the boss bar and the first row, and between rows, in pixels.
@export var hud_bar_gap_px: float
## Background of every row (3D).
@export var background_material: StandardMaterial3D
## Fill of a row while it flashes (3D); the boss HUD uses its albedo_color.
@export var flash_material: StandardMaterial3D
## Background color of the boss HUD rows.
@export var hud_background_color: Color
## Pause menu title: held and max Afflictions.
@export var pause_title_format: String
## Pause menu line: Affliction, source and level.
@export var pause_entry_format: String
## Name of each AfflictionUpgradeData.Source, in enum order.
@export var source_names: Array[String]


## Resistance of an enemy's data, clamped to [0, max_resistance].
func clamp_resistance(value: float) -> float:
	return clampf(value, 0.0, max_resistance)
