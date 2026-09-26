class_name BuffBarConfig
extends Resource
## Layout of the player's buff icons in the HUD.

## Icon slots created up front; buffs beyond this are not shown.
@export var max_icons: int
## Side of each square icon, in pixels.
@export var icon_size: float
## Gap between icons, in pixels.
@export var spacing: float
## Remaining seconds of the current stack, centred on the icon.
@export var time_font_size: int
## Stack count, in the bottom-right corner of the icon.
@export var stack_font_size: int
## Translucent sector over each icon covering the time still left.
@export var clock: CooldownClockConfig
@export var cooldown_text: CooldownTextConfig
