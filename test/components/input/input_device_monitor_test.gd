extends GdUnitTestSuite

const PROMPTS: InputPromptConfig = preload("res://data/ui/input_prompt_config.tres")

var _monitor: InputDeviceMonitor
var _changes: Array[InputDeviceMonitor.Device] = []


func before_test() -> void:
	_changes.clear()
	_monitor = auto_free(InputDeviceMonitor.new())
	_monitor.config = PROMPTS
	add_child(_monitor)
	_monitor.device_changed.connect(_on_device_changed)


func _on_device_changed(device: InputDeviceMonitor.Device) -> void:
	_changes.append(device)


func _joy_button() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func _joy_motion(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event


func test_ac371_starts_on_keyboard_and_mouse() -> void:
	assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.KEYBOARD_MOUSE)


func test_ac371_a_gamepad_button_switches_to_gamepad_once() -> void:
	_monitor.handle_event(_joy_button())
	_monitor.handle_event(_joy_button())
	assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.GAMEPAD)
	assert_array(_changes).is_equal([InputDeviceMonitor.Device.GAMEPAD])


func test_ac371_stick_drift_below_the_threshold_is_ignored() -> void:
	_monitor.handle_event(_joy_motion(PROMPTS.gamepad_motion_threshold * 0.5))
	_monitor.handle_event(_joy_motion(-PROMPTS.gamepad_motion_threshold * 0.5))
	assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.KEYBOARD_MOUSE)
	assert_array(_changes).is_empty()


func test_ac371_a_stick_past_the_threshold_switches_to_gamepad() -> void:
	_monitor.handle_event(_joy_motion(-PROMPTS.gamepad_motion_threshold))
	assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.GAMEPAD)


func test_ac371_keyboard_and_mouse_events_switch_back() -> void:
	var back_events: Array[InputEvent] = [InputEventKey.new(), InputEventMouseButton.new(), InputEventMouseMotion.new()]
	for event: InputEvent in back_events:
		_monitor.handle_event(_joy_button())
		_monitor.handle_event(event)
		assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.KEYBOARD_MOUSE)
	assert_int(_changes.size()).is_equal(6)


func test_ac372_prompts_per_device() -> void:
	var keyboard: InputDeviceMonitor.Device = InputDeviceMonitor.Device.KEYBOARD_MOUSE
	var gamepad: InputDeviceMonitor.Device = InputDeviceMonitor.Device.GAMEPAD
	assert_str(PROMPTS.get_prompt(&"ability_basic", keyboard)).is_equal("E")
	assert_str(PROMPTS.get_prompt(&"ability_ultimate", keyboard)).is_equal("R")
	assert_str(PROMPTS.get_prompt(&"ability_basic", gamepad)).is_equal("LB")
	assert_str(PROMPTS.get_prompt(&"ability_ultimate", gamepad)).is_equal("RT")
