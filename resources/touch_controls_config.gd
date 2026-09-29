class_name TouchControlsConfig
extends Resource
## Layout, sizes and colors of the on-screen touch controls (floating stick,
## action cluster and pause button). Sizes are in base-resolution pixels
## (docs/specs/mobile-touch-controls.md).

@export_group("Stick")
## Left fraction of the screen where a new touch spawns the stick.
@export var stick_zone_width_ratio: float
## Ring radius; the thumb at this distance means full strength.
@export var stick_radius: float
@export var stick_knob_radius: float
## Strength below which the stick sends no movement (fraction of the radius).
@export var stick_dead_zone: float
## Rest center, from the bottom-left corner of the safe area.
@export var stick_rest_position: Vector2
## Floating stick: past the radius the center follows the thumb.
@export var stick_follows_thumb: bool

@export_group("Cluster")
## Attack button center, from the bottom-right corner of the safe area.
@export var cluster_anchor: Vector2
@export var attack_radius: float
## Jump, dash, basic and ultimate buttons.
@export var side_button_radius: float
## Button centers relative to the attack center.
@export var jump_offset: Vector2
@export var dash_offset: Vector2
@export var basic_offset: Vector2
@export var ultimate_offset: Vector2

@export_group("Pause")
@export var pause_radius: float
## Pause button center, from the top-right corner of the safe area.
@export var pause_anchor: Vector2

@export_group("Hit")
## Extra hit radius of every button: a touch just outside still counts.
@export var touch_slop: float

@export_group("Style")
@export var idle_color: Color
@export var pressed_color: Color
@export var stick_color: Color
@export var knob_color: Color
@export var label_color: Color
## Text of the buttons without an ability slot (attack, jump, dash, pause).
@export var label_font_size: int
@export var ring_width: float
@export var arc_point_count: int


## Offset of a cluster button from the attack center, by action.
func get_cluster_offset(action: StringName) -> Vector2:
	match action:
		&"jump":
			return jump_offset
		&"dash":
			return dash_offset
		&"ability_basic":
			return basic_offset
		&"ability_ultimate":
			return ultimate_offset
	return Vector2.ZERO


func get_cluster_radius(action: StringName) -> float:
	return attack_radius if action == &"attack" else side_button_radius
