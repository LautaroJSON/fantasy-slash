class_name BossBarConfig
extends Resource
## Look of the boss health bars fixed at the top centre of the HUD. Trail,
## shake threshold, duration and frequency come from health_bar_config, so
## they behave exactly like the floating 3D bars.

## Bars created up front (the biggest boss challenge count).
@export var max_bars: int
## Width and height of each bar, in pixels.
@export var bar_size: Vector2
## Vertical gap between stacked bars, in pixels.
@export var spacing: int
## Title: display name and level.
@export var title_format: String
## Current and maximum health, rounded up.
@export var health_format: String
@export var fill_color: Color
@export var trail_color: Color
@export var background_color: Color
## Horizontal shake amplitude at the start of a shake, in pixels.
@export var shake_amplitude_px: float
@export var debuff_icon_size_px: float
@export var debuff_spacing_px: int
## Icon slots created up front, the "+" overflow slot included.
@export var max_debuff_icons: int
## Shared look of the status icons (docs/specs/status-icons.md).
@export var status_icon: StatusIconConfig
@export var health_bar_config: HealthBarConfig
