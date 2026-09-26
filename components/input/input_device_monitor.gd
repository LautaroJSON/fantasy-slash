class_name InputDeviceMonitor
extends Node
## Tracks whether the last input came from keyboard/mouse or from a gamepad, so
## the UI can show the matching prompts. Classifies events by type only, never
## by button, and decides no gameplay (Principle VI exception).

signal device_changed(device: Device)

enum Device { KEYBOARD_MOUSE, GAMEPAD }

@export var config: InputPromptConfig

var _device: Device = Device.KEYBOARD_MOUSE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	handle_event(event)


## Called by _input and by tests.
func handle_event(event: InputEvent) -> void:
	if _is_gamepad_event(event):
		_set_device(Device.GAMEPAD)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_device(Device.KEYBOARD_MOUSE)


func get_device() -> Device:
	return _device


func _is_gamepad_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return true
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	return motion != null and absf(motion.axis_value) >= config.gamepad_motion_threshold


func _set_device(device: Device) -> void:
	if device == _device:
		return
	_device = device
	device_changed.emit(device)
