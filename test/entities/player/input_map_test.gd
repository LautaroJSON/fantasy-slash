extends GdUnitTestSuite

const GAME_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"attack", &"dash", &"jump", &"pause", &"ability_basic", &"ability_ultimate",
	&"sprint",  # sprint-stamina.md
]


func _has_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.physical_keycode == key:
			return true
	return false


func _has_mouse_button(action: StringName, button: MouseButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == button:
			return true
	return false


func _binding_id(event: InputEvent) -> String:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null:
		return "key:%d" % key_event.physical_keycode
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event != null:
		return "mouse:%d" % mouse_event.button_index
	return event.as_text()


func test_ac65_ability_and_dash_bindings() -> void:
	assert_bool(_has_key(&"ability_basic", KEY_E)).is_true()
	assert_bool(_has_key(&"ability_ultimate", KEY_R)).is_true()
	assert_bool(_has_mouse_button(&"dash", MOUSE_BUTTON_RIGHT)).is_true()
	assert_bool(_has_mouse_button(&"ability_basic", MOUSE_BUTTON_RIGHT)).is_false()


func test_ac65_no_two_actions_share_a_binding() -> void:
	var owner: Dictionary[String, StringName] = {}
	for action: StringName in GAME_ACTIONS:
		assert_bool(InputMap.has_action(action)).is_true()
		for event: InputEvent in InputMap.action_get_events(action):
			var id: String = _binding_id(event)
			assert_bool(owner.has(id)).override_failure_message("%s shared by %s and %s" % [id, owner.get(id, &""), action]).is_false()
			owner[id] = action


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
		if joy_event != null and joy_event.button_index == button:
			return true
	return false


func _has_joy_axis(action: StringName, axis: JoyAxis, direction: float) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion != null and motion.axis == axis and signf(motion.axis_value) == direction:
			return true
	return false


func test_ac367_actions_keep_their_keyboard_and_mouse_bindings() -> void:
	assert_bool(_has_key(&"move_forward", KEY_W)).is_true()
	assert_bool(_has_key(&"move_back", KEY_S)).is_true()
	assert_bool(_has_key(&"move_left", KEY_A)).is_true()
	assert_bool(_has_key(&"move_right", KEY_D)).is_true()
	assert_bool(_has_mouse_button(&"attack", MOUSE_BUTTON_LEFT)).is_true()
	assert_bool(_has_mouse_button(&"dash", MOUSE_BUTTON_RIGHT)).is_true()
	assert_bool(_has_key(&"jump", KEY_SPACE)).is_true()
	assert_bool(_has_key(&"ability_basic", KEY_E)).is_true()
	assert_bool(_has_key(&"ability_ultimate", KEY_R)).is_true()
	assert_bool(_has_key(&"pause", KEY_ESCAPE)).is_true()


func test_ac367_actions_have_their_gamepad_binding() -> void:
	assert_bool(_has_joy_axis(&"move_forward", JOY_AXIS_LEFT_Y, -1.0)).is_true()
	assert_bool(_has_joy_axis(&"move_back", JOY_AXIS_LEFT_Y, 1.0)).is_true()
	assert_bool(_has_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)).is_true()
	assert_bool(_has_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)).is_true()
	assert_bool(_has_joy_button(&"attack", JOY_BUTTON_RIGHT_SHOULDER)).is_true()
	assert_bool(_has_joy_button(&"jump", JOY_BUTTON_A)).is_true()
	assert_bool(_has_joy_button(&"dash", JOY_BUTTON_B)).is_true()
	assert_bool(_has_joy_button(&"ability_basic", JOY_BUTTON_LEFT_SHOULDER)).is_true()
	assert_bool(_has_joy_axis(&"ability_ultimate", JOY_AXIS_TRIGGER_RIGHT, 1.0)).is_true()
	assert_bool(_has_joy_button(&"pause", JOY_BUTTON_START)).is_true()


func test_ac367_right_trigger_counts_from_half_travel() -> void:
	assert_float(InputMap.action_get_deadzone(&"ability_ultimate")).is_equal_approx(0.5, 0.0001)


func test_ac368_camera_actions_read_the_right_stick_only() -> void:
	var expected: Dictionary[StringName, Vector2] = {
		&"camera_left": Vector2(JOY_AXIS_RIGHT_X, -1.0),
		&"camera_right": Vector2(JOY_AXIS_RIGHT_X, 1.0),
		&"camera_up": Vector2(JOY_AXIS_RIGHT_Y, -1.0),
		&"camera_down": Vector2(JOY_AXIS_RIGHT_Y, 1.0),
	}
	for action: StringName in expected:
		assert_bool(InputMap.has_action(action)).is_true()
		assert_int(InputMap.action_get_events(action).size()).is_equal(1)
		assert_bool(_has_joy_axis(action, int(expected[action].x) as JoyAxis, expected[action].y)).is_true()
		assert_float(InputMap.action_get_deadzone(action)).is_equal_approx(0.2, 0.0001)
