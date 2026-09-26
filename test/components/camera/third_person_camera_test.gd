extends GdUnitTestSuite

const CAMERA_SCENE: PackedScene = preload("res://components/camera/third_person_camera.tscn")
const CAMERA_CONFIG: CameraConfig = preload("res://data/player/camera_config.tres")


func _make_camera() -> ThirdPersonCamera:
	var target: Node3D = auto_free(Node3D.new())
	add_child(target)
	var camera: ThirdPersonCamera = auto_free(CAMERA_SCENE.instantiate())
	camera.target = target
	camera.config = CAMERA_CONFIG
	add_child(camera)
	return camera


func test_ac11_pitch_is_clamped_to_max() -> void:
	var camera: ThirdPersonCamera = _make_camera()
	camera.rotate_camera(0.0, 10.0)
	assert_float(camera.get_pitch()).is_equal_approx(deg_to_rad(CAMERA_CONFIG.max_pitch_deg), 0.0001)


func test_ac11_pitch_is_clamped_to_min() -> void:
	var camera: ThirdPersonCamera = _make_camera()
	camera.rotate_camera(0.0, -10.0)
	assert_float(camera.get_pitch()).is_equal_approx(deg_to_rad(CAMERA_CONFIG.min_pitch_deg), 0.0001)


func test_ac11_forward_input_maps_to_camera_forward() -> void:
	var camera: ThirdPersonCamera = _make_camera()
	var direction: Vector3 = camera.to_world_direction(Vector2(0.0, -1.0))
	assert_vector(direction).is_equal_approx(Vector3(0.0, 0.0, -1.0), Vector3(0.001, 0.001, 0.001))


func test_ac11_direction_follows_yaw_and_keeps_length() -> void:
	var camera: ThirdPersonCamera = _make_camera()
	camera.rotate_camera(PI / 2.0, 0.0)
	var direction: Vector3 = camera.to_world_direction(Vector2(0.0, -0.5))
	assert_vector(direction).is_equal_approx(Vector3(-0.5, 0.0, 0.0), Vector3(0.001, 0.001, 0.001))


func test_ac369_stick_right_turns_the_yaw_by_its_speed() -> void:
	var camera: ThirdPersonCamera = _make_camera()
	camera.apply_stick_look(Vector2(1.0, 0.0), 0.5)
	var expected: float = wrapf(-CAMERA_CONFIG.stick_yaw_speed * 0.5, -PI, PI)
	assert_float(camera.get_yaw()).is_equal_approx(expected, 0.0001)
	assert_float(camera.get_pitch()).is_equal_approx(0.0, 0.0001)


func test_ac369_stick_down_looks_down() -> void:
	var camera: ThirdPersonCamera = _make_camera()
	camera.apply_stick_look(Vector2(0.0, 1.0), 0.1)
	assert_float(camera.get_pitch()).is_equal_approx(-CAMERA_CONFIG.stick_pitch_speed * 0.1, 0.0001)


func test_ac369_invert_y_flips_the_stick_pitch() -> void:
	var camera: ThirdPersonCamera = _make_camera()
	var inverted: CameraConfig = CAMERA_CONFIG.duplicate() as CameraConfig
	inverted.invert_y = true
	camera.config = inverted
	camera.apply_stick_look(Vector2(0.0, 1.0), 0.1)
	assert_float(camera.get_pitch()).is_equal_approx(CAMERA_CONFIG.stick_pitch_speed * 0.1, 0.0001)


func test_ac369_stick_pitch_stays_within_limits() -> void:
	var camera: ThirdPersonCamera = _make_camera()
	camera.apply_stick_look(Vector2(0.0, -1.0), 100.0)
	assert_float(camera.get_pitch()).is_equal_approx(deg_to_rad(CAMERA_CONFIG.max_pitch_deg), 0.0001)
	camera.apply_stick_look(Vector2(0.0, 1.0), 100.0)
	assert_float(camera.get_pitch()).is_equal_approx(deg_to_rad(CAMERA_CONFIG.min_pitch_deg), 0.0001)


func test_ac369_centered_stick_does_not_turn() -> void:
	var camera: ThirdPersonCamera = _make_camera()
	camera.apply_stick_look(Vector2.ZERO, 1.0)
	assert_float(camera.get_yaw()).is_equal(0.0)
	assert_float(camera.get_pitch()).is_equal(0.0)


func test_ac370_stick_speeds_are_set() -> void:
	assert_float(CAMERA_CONFIG.stick_yaw_speed).is_greater(0.0)
	assert_float(CAMERA_CONFIG.stick_pitch_speed).is_greater(0.0)
