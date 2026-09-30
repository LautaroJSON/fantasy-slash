class_name UiNavMode
extends Node
## Tells if the player is moving through the UI with the keyboard or a gamepad
## (autoload UiNav). Menu buttons draw their focus frame only then: with the
## mouse the first card would look selected for no reason. Classifies events by
## type and by the ui_* navigation actions only (Principle VI exception: it
## decides no gameplay).

signal changed(navigating: bool)

## Actions that move or press the focus.
const NAV_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev", &"ui_accept"]
const FOCUS_STYLE: StringName = &"focus"
## Meta that keeps a button's FocusBinding alive (a Callable does not hold its RefCounted).
const BINDING_META: StringName = &"ui_nav_binding"

var _navigating: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	handle_event(event)


## Called by _input and by tests.
func handle_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenTouch:
		set_navigating(false)
		return
	for action: StringName in NAV_ACTIONS:
		if event.is_action_pressed(action):
			set_navigating(true)
			return


func is_navigating() -> bool:
	return _navigating


func set_navigating(value: bool) -> void:
	if value == _navigating:
		return
	_navigating = value
	changed.emit(value)


## The button keeps its own focus style (or the theme's) only while navigating;
## otherwise its focus frame is empty. Call after its styles are set.
func bind_focus_frame(button: Control) -> void:
	var original: StyleBox = button.get_theme_stylebox(FOCUS_STYLE) if button.has_theme_stylebox_override(FOCUS_STYLE) else null
	var binding: FocusBinding = FocusBinding.new(button, original)
	button.set_meta(BINDING_META, binding)
	changed.connect(binding.apply)
	button.tree_exiting.connect(_forget.bind(binding))
	binding.apply(_navigating)


func _forget(binding: FocusBinding) -> void:
	if changed.is_connected(binding.apply):
		changed.disconnect(binding.apply)


## One button and the focus style it had; its own object so each connection to
## `changed` is distinct.
class FocusBinding extends RefCounted:
	var _button: Control
	var _original: StyleBox

	func _init(button: Control, original: StyleBox) -> void:
		_button = button
		_original = original

	func apply(navigating: bool) -> void:
		if not is_instance_valid(_button):
			return
		if not navigating:
			_button.add_theme_stylebox_override(FOCUS_STYLE, StyleBoxEmpty.new())
		elif _original != null:
			_button.add_theme_stylebox_override(FOCUS_STYLE, _original)
		else:
			_button.remove_theme_stylebox_override(FOCUS_STYLE)
