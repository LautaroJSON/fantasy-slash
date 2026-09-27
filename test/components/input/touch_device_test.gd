extends GdUnitTestSuite
## Touch as a third input device: monitor, prompts and pointer capture
## (docs/specs/mobile-touch-controls.md).

const PROMPTS: InputPromptConfig = preload("res://data/ui/input_prompt_config.tres")
const WRITE_FOLDERS: Array[String] = ["res://components", "res://entities", "res://ui", "res://levels", "res://systems"]
const POINTER_MODE_PATH: String = "res://components/input/pointer_mode.gd"

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


func _touch() -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	return event


func _mouse_events(device: int) -> Array[InputEvent]:
	var button := InputEventMouseButton.new()
	button.device = device
	var motion := InputEventMouseMotion.new()
	motion.device = device
	return [button, motion]


func test_ac700_touch_prompts() -> void:
	var touch: InputDeviceMonitor.Device = InputDeviceMonitor.Device.TOUCH
	assert_str(PROMPTS.get_prompt(&"attack", touch)).is_equal("Atacar")
	assert_str(PROMPTS.get_prompt(&"jump", touch)).is_equal("Saltar")
	assert_str(PROMPTS.get_prompt(&"dash", touch)).is_equal("Dash")
	assert_str(PROMPTS.get_prompt(&"pause", touch)).is_equal("II")
	assert_str(PROMPTS.get_prompt(&"ability_basic", touch)).is_equal("")
	assert_str(PROMPTS.get_prompt(&"ability_ultimate", touch)).is_equal("")


func test_ac702_starts_on_keyboard_and_mouse_on_pc() -> void:
	assert_int(InputDeviceMonitor.initial_device()).is_equal(InputDeviceMonitor.Device.KEYBOARD_MOUSE)
	assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.KEYBOARD_MOUSE)


func test_ac702_touch_and_drag_switch_to_touch_once() -> void:
	_monitor.handle_event(_touch())
	_monitor.handle_event(InputEventScreenDrag.new())
	assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.TOUCH)
	assert_array(_changes).is_equal([InputDeviceMonitor.Device.TOUCH])


func test_ac702_a_drag_alone_switches_to_touch() -> void:
	_monitor.handle_event(InputEventScreenDrag.new())
	assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.TOUCH)


func test_ac702_emulated_mouse_events_keep_touch() -> void:
	_monitor.handle_event(_touch())
	for event: InputEvent in _mouse_events(InputEvent.DEVICE_ID_EMULATION):
		_monitor.handle_event(event)
	assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.TOUCH)
	assert_array(_changes).is_equal([InputDeviceMonitor.Device.TOUCH])


func test_ac702_real_mouse_events_switch_back() -> void:
	for event: InputEvent in _mouse_events(InputEvent.DEVICE_ID_MOUSE):
		_monitor.handle_event(_touch())
		_monitor.handle_event(event)
		assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.KEYBOARD_MOUSE)
	assert_int(_changes.size()).is_equal(4)


func test_ac702_action_events_change_nothing() -> void:
	_monitor.handle_event(_touch())
	var action := InputEventAction.new()
	action.action = &"attack"
	action.pressed = true
	_monitor.handle_event(action)
	assert_int(_monitor.get_device()).is_equal(InputDeviceMonitor.Device.TOUCH)


func test_ac703_capture_is_allowed_on_pc() -> void:
	assert_bool(PointerMode.is_capture_allowed()).is_true()


func test_ac703_only_pointer_mode_writes_the_mouse_mode() -> void:
	var writer := RegEx.create_from_string("mouse_mode[ \t]*=[^=]")
	var offenders: Array[String] = []
	for folder: String in WRITE_FOLDERS:
		_collect_writers(folder, writer, offenders)
	assert_array(offenders).is_empty()


func _collect_writers(folder: String, writer: RegEx, offenders: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(folder):
		var path: String = folder.path_join(file)
		if file.ends_with(".gd") and path != POINTER_MODE_PATH and writer.search(FileAccess.get_file_as_string(path)) != null:
			offenders.append(path)
	for sub: String in DirAccess.get_directories_at(folder):
		_collect_writers(folder.path_join(sub), writer, offenders)
