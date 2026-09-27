class_name AbilitySlotView
extends Control
## HUD circle of one ability slot, drawn with draw_circle/draw_arc (no textures).
## Grey when the slot has no ability; a translucent clock (LoL style) covers
## the cooldown still left, and a ring shows the charge reached while a
## charged ability is held down.
## During the cooldown the remaining seconds replace the key label, and when it
## ends the circle pulses (docs/specs/cooldown-timers.md).
## Only redraws when the cooldown ratio, the charge or the equipped state changes.
## It shows an ability or the dash (a SlotSource, docs/specs/dash-button.md);
## with a `touch_action`, touching the circle presses that InputMap action.

@export var config: AbilitySlotViewConfig
## Key or button hint ("E", "LB"...), hidden while the remaining seconds are shown.
@export var key_label: Label
## Action whose prompt the key label shows (written by the HUD per input device).
@export var prompt_action: StringName
## InputMap action a touch on the circle presses (constitution VI, HUD touch
## buttons); &"" = not touchable. Mouse events are ignored.
@export var touch_action: StringName

var _source: SlotSource = null
var _drawn_ratio: float = -1.0
var _drawn_charge: float = 0.0
var _drawn_charging: bool = false
var _drawn_equipped: bool = false
var _drawn_empowered: bool = false
var _time_label: Label = null
var _shown_step: int = 0
var _pulse_left: float = 0.0
## Touch index holding the button, -1 = none.
var _touch_index: int = -1
## Reused polygon of the cooldown clock.
var _clock_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	_draw_slot()


func _gui_input(event: InputEvent) -> void:
	_handle_touch(event as InputEventScreenTouch)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_EXIT_TREE:
		_release_touch()


func setup(ability: AbilityComponent) -> void:
	_setup_source(AbilitySlotSource.new(ability))


## The dash as a button (docs/specs/dash-button.md): its cooldown only.
func setup_dash(dash: DashComponent) -> void:
	_setup_source(DashSlotSource.new(dash))


func _setup_source(source: SlotSource) -> void:
	_source = source
	var diameter: float = get_radius() * 2.0
	custom_minimum_size = Vector2(diameter, diameter)
	pivot_offset = Vector2(get_radius(), get_radius())
	_create_time_label()
	set_process(true)
	_refresh_if_changed()


## Called by _process and by tests.
func advance(delta: float) -> void:
	_refresh_if_changed()
	_update_time_text()
	_advance_pulse(delta)


func get_radius() -> float:
	return config.get_radius(_slot_kind())


## True while a finger holds the button down.
func is_touch_held() -> bool:
	return _touch_index >= 0


func is_locked() -> bool:
	return not _drawn_equipped


## Cooldown ratio shown on the last draw (1 = just used, 0 = ready).
func get_shown_ratio() -> float:
	return _drawn_ratio


## True when the last draw showed a charge in progress.
## True when the last draw showed the empowered (gold) frame.
func is_showing_empowered() -> bool:
	return _drawn_empowered


func is_showing_charge() -> bool:
	return _drawn_charging


## Charge ratio shown on the last draw (0 when not charging).
func get_shown_charge() -> float:
	return _drawn_charge


func get_time_text() -> String:
	return _time_label.text


func is_key_visible() -> bool:
	return key_label.visible


## Writes the key hint; its visibility still follows the cooldown.
func set_prompt(text: String) -> void:
	key_label.text = text


func get_prompt_text() -> String:
	return key_label.text


func is_pulsing() -> bool:
	return _pulse_left > 0.0


## Fraction covered by the cooldown clock on the last draw (0 when ready or charging).
func get_clock_fraction() -> float:
	if not _drawn_equipped or _drawn_charging:
		return 0.0
	return maxf(_drawn_ratio, 0.0)


## Charge ring radius: just inside the frame.
func get_charge_ring_radius() -> float:
	return get_radius() - config.frame_width - config.ring_width / 2.0


func _refresh_if_changed() -> void:
	var ratio: float = _source.get_cooldown_ratio()
	var equipped: bool = _source.is_equipped()
	var charging: bool = _source.is_charging()
	var charge: float = _source.get_charge_ratio()
	var empowered: bool = _source.is_empowered()
	if ratio == _drawn_ratio and equipped == _drawn_equipped and charging == _drawn_charging and charge == _drawn_charge and empowered == _drawn_empowered:
		return
	if _drawn_ratio > 0.0 and ratio <= 0.0 and equipped:
		_start_pulse()
	_drawn_ratio = ratio
	_drawn_equipped = equipped
	_drawn_charging = charging
	_drawn_charge = charge
	_drawn_empowered = empowered
	queue_redraw()


## Writes the label only when the shown step changes (strings come from a table).
func _update_time_text() -> void:
	var step: int = CooldownText.to_step(_source.get_cooldown_remaining(), config.cooldown_text)
	if step == _shown_step:
		return
	_shown_step = step
	_time_label.text = CooldownText.text_for_step(step, config.cooldown_text)
	key_label.visible = step == 0


func _start_pulse() -> void:
	_pulse_left = config.ready_pulse_duration
	scale = Vector2.ONE * config.ready_pulse_scale


## Shrinks linearly from ready_pulse_scale back to 1.
func _advance_pulse(delta: float) -> void:
	if _pulse_left <= 0.0:
		return
	_pulse_left = maxf(_pulse_left - delta, 0.0)
	var progress: float = _pulse_left / config.ready_pulse_duration
	scale = Vector2.ONE * lerpf(1.0, config.ready_pulse_scale, progress)


func _create_time_label() -> void:
	if _time_label != null:
		return
	_time_label = Label.new()
	_time_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CooldownText.style_label(_time_label, config.get_cooldown_font_size(_slot_kind()), config.cooldown_text)
	add_child(_time_label)


## Body of the current state, then the frame on top of every state.
func _draw_slot() -> void:
	if _source == null:
		return
	var radius: float = get_radius()
	var center := Vector2(radius, radius)
	# The body ends in the middle of the frame, so no edge of it reaches past the frame.
	_draw_body(center, radius - config.frame_width / 2.0)
	_draw_frame(center, radius)


func _draw_body(center: Vector2, radius: float) -> void:
	if not _drawn_equipped:
		draw_circle(center, radius, config.locked_color)
		return
	if _drawn_charging:
		draw_circle(center, radius, config.cooldown_color)
		_draw_ring(center, _drawn_charge, config.charge_ring_color)
		return
	draw_circle(center, radius, config.ready_color)
	_draw_clock(center, radius)


## Opaque antialiased ring over the outer edge; hides where the circle and the
## clock polygon do not match exactly (docs/specs/ability-slot-frame.md). Gold
## while the ability holds an empowered cast (docs/specs/tsubame-gaeshi.md).
func _draw_frame(center: Vector2, radius: float) -> void:
	var color: Color = config.empowered_frame_color if _drawn_empowered else config.frame_color
	draw_arc(center, radius - config.frame_width / 2.0, 0.0, TAU, config.arc_point_count, color, config.frame_width, true)

## Cooldown clock: dark translucent sector over the cooldown still left.
func _draw_clock(center: Vector2, radius: float) -> void:
	CooldownClock.build_sector(_clock_points, center, radius, get_clock_fraction(), CooldownClock.Shape.CIRCLE, config.clock.steps_per_turn)
	if _clock_points.size() >= 3:
		draw_colored_polygon(_clock_points, config.clock.color)


## Clockwise from the top, covering `fraction` of the circle, inside the frame.
func _draw_ring(center: Vector2, fraction: float, color: Color) -> void:
	if fraction <= 0.0:
		return
	var start: float = -PI / 2.0
	draw_arc(center, get_charge_ring_radius(), start, start + TAU * fraction, config.arc_point_count, color, config.ring_width, true)


## Size and font of the shown source: the ultimate's or the basic one's.
func _slot_kind() -> AbilityData.Slot:
	return AbilityData.Slot.ULTIMATE if _source.is_ultimate() else AbilityData.Slot.BASIC


## A touch inside the circle presses `touch_action` until that finger lifts.
func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch == null or touch_action == &"" or _source == null:
		return
	if touch.pressed and _touch_index < 0 and _is_inside(touch.position):
		_touch_index = touch.index
		Input.action_press(touch_action)
		accept_event()
	elif not touch.pressed and touch.index == _touch_index:
		_release_touch()
		accept_event()


func _is_inside(point: Vector2) -> bool:
	var radius: float = get_radius()
	return point.distance_to(Vector2(radius, radius)) <= radius


func _release_touch() -> void:
	if _touch_index < 0:
		return
	_touch_index = -1
	Input.action_release(touch_action)
