class_name EnemyStatusOverlayConfig
extends Resource
## Layout of the status icon rows drawn in screen space over the common
## enemies' health bars (docs/specs/status-icons.md).

## Rows created up front; enemies beyond this are not shown.
@export var max_rows: int
## Slots that fit over the health bar, the "+" overflow slot included.
@export var icons_per_bar: int
@export var min_icon_size_px: float
@export var max_icon_size_px: float
## Gap between slots, in pixels.
@export var spacing_px: int
## Offset of the row centre from the projected health bar centre, in pixels.
@export var row_offset_px: Vector2
## Resize a row only when its side changes more than this, in pixels.
@export var resize_threshold_px: float
## Same bar config the enemies use: its width sizes the icons.
@export var health_bar: HealthBarConfig
@export var status_icon: StatusIconConfig


## Pure: side of each slot so `icons_per_bar` slots and their gaps span
## `bar_width_px`, clamped to the min and max sizes.
func icon_side(bar_width_px: float) -> float:
	var gaps: float = float((icons_per_bar - 1) * spacing_px)
	return clampf((bar_width_px - gaps) / float(icons_per_bar), min_icon_size_px, max_icon_size_px)
