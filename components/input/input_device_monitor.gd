class_name InputDeviceMonitor
extends Node
## Tracks whether the last input came from keyboard/mouse, a gamepad or the
## touch screen, so the UI can show the matching prompts and controls.
## Classifies events by type only, never by button, and decides no gameplay
## (Principle VI exception). Mouse events that Godot emulates from a touch do
## not count as the mouse (docs/specs/mobile-touch-controls.md).

signal device_changed(device: Device)

enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

## Platform feature of phones and tablets (structural name, not a tuning value).
const MOBILE_FEATURE: String = "mobile"

@export var config: InputPromptConfig

var _device: Device = initial_device()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	handle_event(event)


## Touch on phones and tablets, keyboard and mouse elsewhere.
static func initial_device() -> Device:
	return Device.TOUCH if OS.has_feature(MOBILE_FEATURE) else Device.KEYBOARD_MOUSE


## Called by _input and by tests.
func handle_event(event: InputEvent) -> void:
	if _is_gamepad_event(event):
		_set_device(Device.GAMEPAD)
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_device(Device.TOUCH)
	elif _is_keyboard_mouse_event(event):
		_set_device(Device.KEYBOARD_MOUSE)


func get_device() -> Device:
	return _device


func _is_gamepad_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return true
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	return motion != null and absf(motion.axis_value) >= config.gamepad_motion_threshold


func _is_keyboard_mouse_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return true
	var mouse: InputEventMouse = event as InputEventMouse
	return mouse != null and mouse.device != InputEvent.DEVICE_ID_EMULATION


func _set_device(device: Device) -> void:
	if device == _device:
		return
	_device = device
	device_changed.emit(device)
