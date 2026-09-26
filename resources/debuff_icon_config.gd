class_name DebuffIconConfig
extends Resource
## Layout of the debuff icons shown above an enemy's health bar.

## Icon slots created up front; debuffs beyond this are not shown.
@export var max_icons: int
## Side of each square icon, in meters.
@export var icon_size: float
## Gap between icons, in meters.
@export var spacing: float
## Height of the icon row above the health bar's centre, in meters.
@export var height_above_bar: float
## Remaining seconds written above each icon (TextMesh).
@export var time_font_size: int
## Meters per font pixel of the remaining seconds.
@export var time_pixel_size: float
## Height of the text's centre above the icon's centre, in meters.
@export var time_height_above_icon: float
## Shared white unshaded material of the text (Principle II, v3.6.0).
@export var time_material: StandardMaterial3D
## Stack count in the bottom-right corner of stacking debuffs (TextMesh, same material).
@export var stack_font_size: int
## Meters per font pixel of the stack count.
@export var stack_pixel_size: float
## Position of the stack count from the icon centre, in meters.
@export var stack_offset: Vector2
@export var cooldown_text: CooldownTextConfig
