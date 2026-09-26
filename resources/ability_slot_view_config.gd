class_name AbilitySlotViewConfig
extends Resource
## Look of the ability circles in the HUD.

## Radius of the basic ability circle, in pixels.
@export var basic_radius: float
## Radius of the ultimate circle, in pixels.
@export var ultimate_radius: float
## Width of the charge ring, in pixels.
@export var ring_width: float
## Points used to draw the charge ring.
@export var arc_point_count: int
## Fill when the ability is ready.
@export var ready_color: Color
## Fill behind the charge ring while a charged ability is held down.
@export var cooldown_color: Color
## Ring showing the charge of an ability held down (drawn over cooldown_color).
@export var charge_ring_color: Color
## Fill of a slot without an ability.
@export var locked_color: Color
## Width of the frame drawn over the outer edge in every state, in pixels.
@export var frame_width: float
## Opaque color of the frame.
@export var frame_color: Color
## Frame color while the ability holds an empowered cast (e.g. Tsubame Gaeshi).
@export var empowered_frame_color: Color
## Font size of the remaining cooldown, basic ability.
@export var cooldown_font_size: int
## Font size of the remaining cooldown, ultimate.
@export var ultimate_cooldown_font_size: int
## Scale the circle jumps to when the cooldown ends (then back to 1).
@export var ready_pulse_scale: float
## Seconds the ready pulse takes to shrink back to 1.
@export var ready_pulse_duration: float
## Translucent sector over the circle covering the cooldown still left.
@export var clock: CooldownClockConfig
@export var cooldown_text: CooldownTextConfig


func get_radius(slot: AbilityData.Slot) -> float:
	if slot == AbilityData.Slot.ULTIMATE:
		return ultimate_radius
	return basic_radius


func get_cooldown_font_size(slot: AbilityData.Slot) -> int:
	if slot == AbilityData.Slot.ULTIMATE:
		return ultimate_cooldown_font_size
	return cooldown_font_size
