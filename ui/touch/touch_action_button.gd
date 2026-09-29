class_name TouchActionButton
extends Control
## Round on-screen button of one InputMap action, drawn with draw_circle and
## draw_arc (no textures). It reads no events: TouchControls routes each
## finger and calls press()/release(). Buttons with an ability slot child
## skip their own fill and text; the dash button also shows its cooldown clock
## and remaining seconds (docs/specs/mobile-touch-controls.md).
## Redraws only when the pressed state changes.

const NO_FINGER: int = -1

@export var action: StringName
@export var config: TouchControlsConfig
## True for the ability buttons: the AbilitySlotView child draws the circle.
@export var draws_slot: bool

var _radius: float = 0.0
var _finger: int = NO_FINGER
var _label: Label = null
var _clock: CooldownClock = null
var _time_label: Label = null
var _cooldown_text: CooldownTextConfig = null
var _shown_step: int = 0


func _draw() -> void:
	_draw_button()


## Places the button centered on `center` (parent space) with `radius`.
func layout(center: Vector2, radius: float) -> void:
	_radius = radius
	size = Vector2(radius, radius) * 2.0
	position = center - Vector2(radius, radius)
	pivot_offset = Vector2(radius, radius)
	queue_redraw()


func set_text(text: String) -> void:
	_ensure_label()
	_label.text = text


## Adds the cooldown clock and the remaining-seconds text (dash button).
func show_cooldown(clock_config: CooldownClockConfig, text_config: CooldownTextConfig, font_size: int) -> void:
	if _clock != null:
		return
	_cooldown_text = text_config
	_clock = CooldownClock.create(clock_config, CooldownClock.Shape.CIRCLE)
	add_child(_clock)
	# Under the text, so the name and the seconds stay readable over the clock.
	move_child(_clock, 0)
	_time_label = _create_centered_label()
	CooldownText.style_label(_time_label, font_size, text_config)


## ratio: 1 = just used, 0 = ready. Text written only when its step changes.
func set_cooldown(ratio: float, remaining: float) -> void:
	_clock.set_fraction(ratio)
	var step: int = CooldownText.to_step(remaining, _cooldown_text)
	if step == _shown_step:
		return
	_shown_step = step
	_time_label.text = CooldownText.text_for_step(step, _cooldown_text)
	if _label != null:
		_label.visible = step == 0


func get_cooldown_fraction() -> float:
	return _clock.get_fraction()


func get_time_text() -> String:
	return _time_label.text


func get_text() -> String:
	return _label.text if _label != null else ""


func get_radius() -> float:
	return _radius


func get_global_center() -> Vector2:
	return get_global_rect().get_center()


func contains_point(global_point: Vector2, slop: float) -> bool:
	return global_point.distance_to(get_global_center()) <= _radius + slop


func press(finger: int) -> void:
	_finger = finger
	queue_redraw()


func release() -> void:
	_finger = NO_FINGER
	queue_redraw()


func is_pressed() -> bool:
	return _finger != NO_FINGER


func get_finger() -> int:
	return _finger


func _ensure_label() -> void:
	if _label != null:
		return
	_label = _create_centered_label()
	_label.add_theme_font_size_override(&"font_size", config.label_font_size)
	_label.add_theme_color_override(&"font_color", config.label_color)


func _create_centered_label() -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## Slot buttons only draw the pressed ring over the slot.
func _draw_button() -> void:
	var center := Vector2(_radius, _radius)
	var color: Color = config.pressed_color if is_pressed() else config.idle_color
	if not draws_slot:
		draw_circle(center, _radius, color)
	if is_pressed() or not draws_slot:
		draw_arc(center, _radius - config.ring_width / 2.0, 0.0, TAU, config.arc_point_count, color, config.ring_width, true)
