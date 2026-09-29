extends GdUnitTestSuite
## docs/specs/mobile-touch-controls.md: stick, buttons, camera drag and finger
## routing of the on-screen touch controls.

const SCENE: PackedScene = preload("res://ui/touch/touch_controls.tscn")
const CONFIG: TouchControlsConfig = preload("res://data/ui/touch_controls_config.tres")
const CAMERA_SCENE: PackedScene = preload("res://components/camera/third_person_camera.tscn")
const CAMERA_CONFIG: CameraConfig = preload("res://data/player/camera_config.tres")
const CANVAS: Vector2 = Vector2(1152.0, 648.0)
const BUTTON_ACTIONS: Array[StringName] = [&"attack", &"jump", &"dash", &"ability_basic", &"ability_ultimate", &"pause"]
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_forward", &"move_back"]
const CLUSTER_ACTIONS: Array[StringName] = [&"attack", &"jump", &"dash", &"ability_basic", &"ability_ultimate"]

var _root: Control
var _touch: TouchControls
var _camera: ThirdPersonCamera


func before_test() -> void:
	_root = auto_free(Control.new())
	_root.size = CANVAS
	add_child(_root)
	var target: Node3D = auto_free(Node3D.new())
	add_child(target)
	_camera = auto_free(CAMERA_SCENE.instantiate())
	_camera.target = target
	_camera.config = CAMERA_CONFIG
	add_child(_camera)
	_touch = SCENE.instantiate() as TouchControls
	_touch.camera = _camera
	_root.add_child(_touch)
	_touch.set_active(true)


func after_test() -> void:
	get_tree().paused = false
	_touch.release_all()
	for action: StringName in BUTTON_ACTIONS + MOVE_ACTIONS:
		Input.action_release(action)
	Input.flush_buffered_events()


func _down(finger: int, point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = point
	event.pressed = true
	_touch.handle_event(event)
	Input.flush_buffered_events()


func _up(finger: int, point: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = point
	event.pressed = false
	_touch.handle_event(event)
	Input.flush_buffered_events()


func _drag(finger: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = point
	event.relative = relative
	_touch.handle_event(event)
	Input.flush_buffered_events()


func _center_of(action: StringName) -> Vector2:
	return _touch.get_button(action).get_global_center()


## A point on the left half, away from every button.
func _left_point() -> Vector2:
	return Vector2(300.0, 300.0)


## A point on the right half, away from every button.
func _right_point() -> Vector2:
	return Vector2(800.0, 200.0)


func test_ac1092_config_values_and_cluster_without_overlaps() -> void:
	for value: float in [CONFIG.stick_zone_width_ratio, CONFIG.stick_radius, CONFIG.stick_knob_radius, CONFIG.stick_dead_zone,
			CONFIG.attack_radius, CONFIG.side_button_radius, CONFIG.pause_radius, CONFIG.touch_slop, CONFIG.ring_width]:
		assert_float(value).is_greater(0.0)
	assert_int(CONFIG.label_font_size).is_greater(0)
	assert_int(CONFIG.arc_point_count).is_greater(0)
	for point: Vector2 in [CONFIG.stick_rest_position, CONFIG.cluster_anchor, CONFIG.pause_anchor,
			CONFIG.jump_offset, CONFIG.dash_offset, CONFIG.basic_offset, CONFIG.ultimate_offset]:
		assert_vector(point).is_not_equal(Vector2.ZERO)
	assert_float(CONFIG.attack_radius).is_greater(CONFIG.side_button_radius)
	assert_float(CAMERA_CONFIG.touch_look_sensitivity).is_greater(0.0)
	for a: StringName in CLUSTER_ACTIONS:
		for b: StringName in CLUSTER_ACTIONS:
			if a == b:
				continue
			var distance: float = CONFIG.get_cluster_offset(a).distance_to(CONFIG.get_cluster_offset(b))
			assert_float(distance).is_greater_equal(CONFIG.get_cluster_radius(a) + CONFIG.get_cluster_radius(b))


func test_ac1097_each_button_presses_and_releases_its_action() -> void:
	for i: int in BUTTON_ACTIONS.size():
		var action: StringName = BUTTON_ACTIONS[i]
		_down(i, _center_of(action))
		assert_bool(Input.is_action_pressed(action)).override_failure_message("%s not pressed" % action).is_true()
		assert_bool(Input.is_action_just_pressed(action)).override_failure_message("%s not just pressed" % action).is_true()
		assert_bool(_touch.get_button(action).is_pressed()).is_true()
		_up(i)
		assert_bool(Input.is_action_pressed(action)).override_failure_message("%s still pressed" % action).is_false()
		assert_bool(_touch.get_button(action).is_pressed()).is_false()


func test_ac1098_touch_slop_around_a_button() -> void:
	var jump: TouchActionButton = _touch.get_button(&"jump")
	var outward := Vector2(1.0, 0.0)
	_down(0, jump.get_global_center() + outward * (jump.get_radius() + CONFIG.touch_slop - 1.0))
	assert_bool(Input.is_action_pressed(&"jump")).is_true()
	_up(0)
	_down(1, jump.get_global_center() + outward * (jump.get_radius() + CONFIG.touch_slop + 2.0))
	assert_bool(Input.is_action_pressed(&"jump")).is_false()


func test_ac1099_fingers_are_routed_independently() -> void:
	_down(0, _left_point())
	_drag(0, _left_point() + Vector2(CONFIG.stick_radius, 0.0), Vector2(CONFIG.stick_radius, 0.0))
	_down(1, _center_of(&"attack"))
	_up(0)
	assert_bool(Input.is_action_pressed(&"attack")).is_true()
	_down(0, _left_point())
	_drag(0, _left_point() + Vector2(CONFIG.stick_radius, 0.0), Vector2(CONFIG.stick_radius, 0.0))
	_up(1)
	assert_float(Input.get_action_strength(&"move_right")).is_equal_approx(1.0, 0.001)


func test_ac1099_a_second_finger_on_a_pressed_button_is_ignored() -> void:
	_down(0, _center_of(&"attack"))
	_down(1, _center_of(&"attack"))
	_up(1)
	assert_bool(Input.is_action_pressed(&"attack")).is_true()
	_up(0)
	assert_bool(Input.is_action_pressed(&"attack")).is_false()


func test_ac1100_floating_stick_sends_move_strengths() -> void:
	_down(0, _left_point())
	assert_vector(_touch.get_stick().get_center()).is_equal(_left_point())
	_drag(0, _left_point() + Vector2(CONFIG.stick_radius, 0.0), Vector2(CONFIG.stick_radius, 0.0))
	assert_vector(_touch.get_stick_vector()).is_equal_approx(Vector2(1.0, 0.0), Vector2(0.001, 0.001))
	assert_float(Input.get_action_strength(&"move_right")).is_equal_approx(1.0, 0.001)
	assert_float(Input.get_action_strength(&"move_left")).is_equal(0.0)
	_drag(0, _left_point() + Vector2(0.0, -CONFIG.stick_radius / 2.0), Vector2.ZERO)
	assert_float(Input.get_action_strength(&"move_forward")).is_equal_approx(0.5, 0.001)
	assert_bool(Input.is_action_pressed(&"move_right")).is_false()


func test_ac1101_dead_zone_sends_nothing() -> void:
	_down(0, _left_point())
	var small: float = CONFIG.stick_dead_zone * CONFIG.stick_radius * 0.5
	_drag(0, _left_point() + Vector2(small, 0.0), Vector2(small, 0.0))
	assert_vector(_touch.get_stick_vector()).is_equal(Vector2.ZERO)
	for action: StringName in MOVE_ACTIONS:
		assert_bool(Input.is_action_pressed(action)).is_false()


func test_ac1102_the_center_follows_the_thumb_and_rests_on_release() -> void:
	_down(0, _left_point())
	var far: Vector2 = _left_point() + Vector2(CONFIG.stick_radius * 2.0, 0.0)
	_drag(0, far, Vector2(CONFIG.stick_radius * 2.0, 0.0))
	assert_float(_touch.get_stick_vector().length()).is_equal_approx(1.0, 0.001)
	assert_float(_touch.get_stick().get_center().distance_to(far)).is_equal_approx(CONFIG.stick_radius, 0.001)
	_up(0)
	assert_vector(_touch.get_stick().get_center()).is_equal(_touch.get_stick().get_rest_center())
	for action: StringName in MOVE_ACTIONS:
		assert_bool(Input.is_action_pressed(action)).is_false()


func test_ac1103_a_drag_on_the_right_half_turns_the_camera() -> void:
	_down(0, _right_point())
	_drag(0, _right_point() + Vector2(20.0, 0.0), Vector2(20.0, 0.0))
	assert_float(_camera.get_yaw()).is_equal_approx(-20.0 * CAMERA_CONFIG.touch_look_sensitivity, 0.0001)


func test_ac1103_the_left_half_and_button_fingers_never_turn_the_camera() -> void:
	_down(0, _left_point())
	_drag(0, _left_point() + Vector2(20.0, 0.0), Vector2(20.0, 0.0))
	_down(1, _center_of(&"attack"))
	_drag(1, _center_of(&"attack") + Vector2(-200.0, 0.0), Vector2(-200.0, 0.0))
	assert_float(_camera.get_yaw()).is_equal(0.0)
	assert_float(_camera.get_pitch()).is_equal(0.0)


func test_ac1103_a_second_finger_on_the_left_half_does_not_look() -> void:
	_down(0, _left_point())
	_down(1, _left_point() + Vector2(50.0, 0.0))
	_drag(1, _left_point() + Vector2(90.0, 0.0), Vector2(40.0, 0.0))
	assert_float(_camera.get_yaw()).is_equal(0.0)


func test_ac1104_only_one_finger_looks() -> void:
	_down(0, _right_point())
	_down(1, _right_point() + Vector2(0.0, 100.0))
	_drag(1, _right_point() + Vector2(30.0, 100.0), Vector2(30.0, 0.0))
	assert_float(_camera.get_yaw()).is_equal(0.0)
	assert_int(_touch.get_look_finger()).is_equal(0)


func test_ac1105_release_all_and_deactivating_release_every_action() -> void:
	_down(0, _center_of(&"attack"))
	_down(1, _left_point())
	_drag(1, _left_point() + Vector2(0.0, -CONFIG.stick_radius), Vector2(0.0, -CONFIG.stick_radius))
	assert_bool(Input.is_action_pressed(&"move_forward")).is_true()
	_touch.set_active(false)
	Input.flush_buffered_events()
	assert_bool(Input.is_action_pressed(&"attack")).is_false()
	assert_bool(Input.is_action_pressed(&"move_forward")).is_false()
	assert_bool(_touch.visible).is_false()


func test_ac1105_pausing_the_tree_releases_every_action() -> void:
	_down(0, _center_of(&"attack"))
	_down(1, _left_point())
	_drag(1, _left_point() + Vector2(0.0, -CONFIG.stick_radius), Vector2(0.0, -CONFIG.stick_radius))
	get_tree().paused = true
	await get_tree().process_frame
	Input.flush_buffered_events()
	assert_bool(Input.is_action_pressed(&"attack")).is_false()
	assert_bool(Input.is_action_pressed(&"move_forward")).is_false()
	assert_bool(_touch.visible).is_false()
	get_tree().paused = false
	await get_tree().process_frame
	assert_bool(_touch.visible).is_true()


func test_ac1106_while_paused_new_touches_are_ignored_but_releases_run() -> void:
	_down(0, _center_of(&"attack"))
	get_tree().paused = true
	_down(1, _center_of(&"jump"))
	assert_bool(Input.is_action_pressed(&"jump")).is_false()
	_up(0)
	assert_bool(Input.is_action_pressed(&"attack")).is_false()


func test_ac1112_layout_from_the_corners() -> void:
	var attack_center: Vector2 = CANVAS + CONFIG.cluster_anchor
	assert_vector(_center_of(&"attack")).is_equal_approx(attack_center, Vector2(0.01, 0.01))
	for action: StringName in [&"jump", &"dash", &"ability_basic", &"ability_ultimate"]:
		assert_vector(_center_of(action)).is_equal_approx(attack_center + CONFIG.get_cluster_offset(action), Vector2(0.01, 0.01))
		assert_float(_touch.get_button(action).get_radius()).is_equal(CONFIG.side_button_radius)
	assert_float(_touch.get_button(&"attack").get_radius()).is_equal(CONFIG.attack_radius)
	assert_vector(_center_of(&"pause")).is_equal_approx(Vector2(CANVAS.x, 0.0) + CONFIG.pause_anchor, Vector2(0.01, 0.01))
	assert_vector(_touch.get_stick().get_rest_center()).is_equal_approx(Vector2(0.0, CANVAS.y) + CONFIG.stick_rest_position, Vector2(0.01, 0.01))


func test_ac1112_jump_is_top_right_dash_bottom_right_basic_bottom_left_ultimate_top_left() -> void:
	var attack_center: Vector2 = _center_of(&"attack")
	assert_bool(_center_of(&"jump").x > attack_center.x and _center_of(&"jump").y < attack_center.y).is_true()
	assert_bool(_center_of(&"dash").x > attack_center.x and _center_of(&"dash").y > attack_center.y).is_true()
	assert_bool(_center_of(&"ability_basic").x < attack_center.x and _center_of(&"ability_basic").y > attack_center.y).is_true()
	assert_bool(_center_of(&"ability_ultimate").x < attack_center.x and _center_of(&"ability_ultimate").y < attack_center.y).is_true()


func test_ac1113_safe_area_to_canvas() -> void:
	var window := Rect2(Vector2(100.0, 50.0), CANVAS * 2.0)
	var screen_safe := Rect2(Vector2(220.0, 50.0), Vector2(CANVAS.x * 2.0 - 200.0, CANVAS.y * 2.0))
	var safe: Rect2 = SafeArea.to_canvas(screen_safe, window, CANVAS)
	assert_vector(safe.position).is_equal_approx(Vector2(60.0, 0.0), Vector2(0.01, 0.01))
	assert_vector(safe.end).is_equal_approx(Vector2(CANVAS.x - 40.0, CANVAS.y), Vector2(0.01, 0.01))
	assert_that(SafeArea.to_canvas(Rect2(), window, CANVAS)).is_equal(Rect2(Vector2.ZERO, CANVAS))


func test_ac1113_the_controls_stay_inside_the_safe_area() -> void:
	var before_attack: Vector2 = _center_of(&"attack")
	var before_pause: Vector2 = _center_of(&"pause")
	var before_rest: Vector2 = _touch.get_stick().get_rest_center() + _touch.get_global_rect().position
	var safe := Rect2(Vector2(60.0, 0.0), Vector2(CANVAS.x - 100.0, CANVAS.y))
	SafeArea.inset(_touch, safe, CANVAS)
	assert_vector(_center_of(&"attack")).is_equal_approx(before_attack - Vector2(40.0, 0.0), Vector2(0.01, 0.01))
	assert_vector(_center_of(&"pause")).is_equal_approx(before_pause - Vector2(40.0, 0.0), Vector2(0.01, 0.01))
	var rest: Vector2 = _touch.get_stick().get_rest_center() + _touch.get_global_rect().position
	assert_vector(rest).is_equal_approx(before_rest + Vector2(60.0, 0.0), Vector2(0.01, 0.01))
	for action: StringName in BUTTON_ACTIONS:
		var button: TouchActionButton = _touch.get_button(action)
		assert_bool(safe.encloses(button.get_global_rect())).override_failure_message("%s outside" % action).is_true()
