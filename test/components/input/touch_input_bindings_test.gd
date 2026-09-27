extends GdUnitTestSuite
## Project settings and InputMap rules for touch play (docs/specs/mobile-touch-controls.md).


func after_test() -> void:
	for action: StringName in [&"attack", &"move_right"]:
		Input.action_release(action)
	Input.flush_buffered_events()


func _mouse_button(index: MouseButton, device: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = true
	event.device = device
	return event


func test_ac698_project_settings_for_android() -> void:
	assert_int(ProjectSettings.get_setting("display/window/handheld/orientation")).is_equal(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	assert_bool(ProjectSettings.get_setting("application/config/quit_on_go_back")).is_false()
	assert_bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")).is_true()
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")).is_equal("mobile")


func test_ac701_emulated_mouse_clicks_do_not_trigger_attack_or_dash() -> void:
	assert_bool(InputMap.event_is_action(_mouse_button(MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION), &"attack")).is_false()
	assert_bool(InputMap.event_is_action(_mouse_button(MOUSE_BUTTON_RIGHT, InputEvent.DEVICE_ID_EMULATION), &"dash")).is_false()


func test_ac701_real_mouse_clicks_still_trigger_attack_and_dash() -> void:
	assert_bool(InputMap.event_is_action(_mouse_button(MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_MOUSE), &"attack")).is_true()
	assert_bool(InputMap.event_is_action(_mouse_button(MOUSE_BUTTON_RIGHT, InputEvent.DEVICE_ID_MOUSE), &"dash")).is_true()


func test_parsed_action_events_set_pressed_state_and_strength() -> void:
	var press := InputEventAction.new()
	press.action = &"move_right"
	press.pressed = true
	press.strength = 0.5
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	assert_bool(Input.is_action_pressed(&"move_right")).is_true()
	assert_float(Input.get_action_strength(&"move_right")).is_equal_approx(0.5, 0.001)
	var release := InputEventAction.new()
	release.action = &"move_right"
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	assert_bool(Input.is_action_pressed(&"move_right")).is_false()


func test_ac725_android_export_preset() -> void:
	var presets := ConfigFile.new()
	assert_int(presets.load("res://export_presets.cfg")).is_equal(OK)
	var section: String = _android_section(presets)
	assert_str(section).is_not_empty()
	assert_str(presets.get_value(section, "exclude_filter")).contains("test/*").contains("addons/gdUnit4/*")
	var options: String = section + ".options"
	assert_str(presets.get_value(options, "package/unique_name")).is_equal("com.fantasyslash.game")
	assert_str(presets.get_value(options, "package/name")).is_equal("Fantasy Slash")
	assert_str(presets.get_value(options, "version/name")).is_equal("0.1.0")
	assert_bool(presets.get_value(options, "gradle_build/use_gradle_build")).is_true()
	assert_bool(presets.get_value(options, "architectures/arm64-v8a")).is_true()
	assert_bool(presets.get_value(options, "architectures/armeabi-v7a")).is_false()
	assert_bool(presets.get_value(options, "architectures/x86_64")).is_false()


func _android_section(presets: ConfigFile) -> String:
	for section: String in presets.get_sections():
		if presets.has_section_key(section, "platform") and presets.get_value(section, "platform") == "Android":
			return section
	return ""
