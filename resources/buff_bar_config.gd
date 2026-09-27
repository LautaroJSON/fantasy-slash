class_name BuffBarConfig
extends Resource
## Layout of the player's buff icons in the HUD.

## Slots created up front, the "+" overflow slot included.
@export var max_icons: int
## Side of each square icon, in pixels.
@export var icon_size: float
## Gap between icons, in pixels.
@export var spacing: float
## Shared look of the status icons (docs/specs/status-icons.md).
@export var status_icon: StatusIconConfig
