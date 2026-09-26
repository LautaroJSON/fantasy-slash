extends GdUnitTestSuite

const ACTIONS: Array[StringName] = [&"jump", &"dash"]

var _guard: HeldInputGuard


func before_test() -> void:
	_release_all()
	_guard = HeldInputGuard.new(ACTIONS)


func after_test() -> void:
	_release_all()


func _release_all() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func test_ac378_consecutive_frames_block_nothing() -> void:
	_guard.update(10)
	Input.action_press(&"jump")
	_guard.update(11)
	assert_bool(_guard.is_blocked(&"jump")).is_false()
	assert_bool(_guard.is_pressed(&"jump")).is_true()
	assert_bool(_guard.is_just_pressed(&"jump")).is_equal(Input.is_action_just_pressed(&"jump"))


func test_ac378_an_action_held_through_a_pause_is_blocked_until_released() -> void:
	_guard.update(10)
	Input.action_press(&"jump")
	_guard.update(20)
	assert_bool(_guard.is_blocked(&"jump")).is_true()
	assert_bool(_guard.is_pressed(&"jump")).is_false()
	assert_bool(_guard.is_just_pressed(&"jump")).is_false()
	_guard.update(21)
	assert_bool(_guard.is_blocked(&"jump")).is_true()
	Input.action_release(&"jump")
	_guard.update(22)
	assert_bool(_guard.is_blocked(&"jump")).is_false()
	Input.action_press(&"jump")
	_guard.update(23)
	assert_bool(_guard.is_pressed(&"jump")).is_true()


func test_ac378_actions_not_held_after_a_pause_are_not_blocked() -> void:
	_guard.update(10)
	Input.action_press(&"jump")
	_guard.update(20)
	assert_bool(_guard.is_blocked(&"jump")).is_true()
	assert_bool(_guard.is_blocked(&"dash")).is_false()


func test_ac378_several_updates_on_one_frame_are_not_a_pause() -> void:
	_guard.update(10)
	Input.action_press(&"jump")
	_guard.update(10)
	_guard.update(11)
	assert_bool(_guard.is_blocked(&"jump")).is_false()


func test_ac378_the_first_update_is_not_a_pause() -> void:
	Input.action_press(&"jump")
	_guard.update(50)
	assert_bool(_guard.is_blocked(&"jump")).is_false()
