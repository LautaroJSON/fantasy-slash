extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const CONFIG: HitFeedbackConfig = preload("res://data/player/hit_feedback_config.tres")
const CAMERA_CONFIG: CameraConfig = preload("res://data/player/camera_config.tres")
## Raw hit that survives the player's defense (3): 11 - 3 = 8, a grunt hit.
const GRUNT_HIT: float = 11.0
const LETHAL_HIT: float = 100000.0

var _player: Player
var _feedback: HitFeedbackComponent
var _camera: ThirdPersonCamera
var _visual: Node3D


func before_test() -> void:
	_player = auto_free(PLAYER_SCENE.instantiate())
	add_child(_player)
	_feedback = _player.get_node("HitFeedback") as HitFeedbackComponent
	_camera = _player.get_node("CameraRig") as ThirdPersonCamera
	_visual = _player.get_node("Visual") as Node3D


func _process_frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_ac82_damaged_reports_only_applied_damage() -> void:
	var amounts: Array[float] = []
	_player.health.damaged.connect(func(amount: float) -> void: amounts.append(amount))
	_player.health.receive_hit(GRUNT_HIT)
	_player.health.is_invulnerable = true
	_player.health.receive_hit(GRUNT_HIT)
	_player.health.is_invulnerable = false
	_player.health.receive_hit(LETHAL_HIT)
	_player.health.receive_hit(GRUNT_HIT)
	assert_int(amounts.size()).is_equal(2)
	assert_float(amounts[0]).is_equal_approx(8.0, 0.0001)


func test_ac83_a_hit_flickers_the_player_and_ends_visible() -> void:
	_player.health.receive_hit(GRUNT_HIT)
	assert_bool(_feedback.is_flickering()).is_true()
	assert_bool(_visual.visible).is_false()
	await _wait_seconds(CONFIG.flicker_duration + 0.1)
	assert_bool(_feedback.is_flickering()).is_false()
	assert_bool(_visual.visible).is_true()


func test_ac83_the_flicker_toggles_while_running() -> void:
	_player.health.receive_hit(GRUNT_HIT)
	var seen_visible: bool = false
	for i: int in 30:
		await get_tree().process_frame
		seen_visible = seen_visible or (_feedback.is_flickering() and _visual.visible)
	assert_bool(seen_visible).is_true()


func test_ac84_a_hit_shakes_the_camera_then_it_settles() -> void:
	assert_vector(_camera.get_shake_offset()).is_equal(Vector2.ZERO)
	_player.health.receive_hit(GRUNT_HIT)
	await _process_frames(2)
	var offset: Vector2 = _camera.get_shake_offset()
	assert_bool(offset.is_zero_approx()).is_false()
	assert_float(absf(offset.x)).is_less_equal(CAMERA_CONFIG.shake_max_offset)
	assert_float(absf(offset.y)).is_less_equal(CAMERA_CONFIG.shake_max_offset)
	await _wait_seconds(CAMERA_CONFIG.shake_duration + 0.1)
	assert_vector(_camera.get_shake_offset()).is_equal(Vector2.ZERO)


func test_ac85_bigger_hits_shake_harder() -> void:
	assert_float(HitFeedbackComponent.shake_strength(1.0, CONFIG)).is_equal_approx(CONFIG.min_strength, 0.0001)
	assert_float(HitFeedbackComponent.shake_strength(8.0, CONFIG)).is_equal_approx(0.4, 0.0001)
	assert_float(HitFeedbackComponent.shake_strength(20.0, CONFIG)).is_equal_approx(1.0, 0.0001)
	assert_float(HitFeedbackComponent.shake_strength(50.0, CONFIG)).is_equal_approx(1.0, 0.0001)


func test_ac86_hits_absorbed_by_iframes_give_no_feedback() -> void:
	assert_bool(_player.dash.try_dash(Vector3.FORWARD)).is_true()
	_player.health.receive_hit(GRUNT_HIT)
	assert_bool(_feedback.is_flickering()).is_false()
	assert_bool(_visual.visible).is_true()
	await _process_frames(2)
	assert_vector(_camera.get_shake_offset()).is_equal(Vector2.ZERO)


func test_ac87_death_leaves_the_player_visible_and_the_camera_still() -> void:
	_player.health.receive_hit(GRUNT_HIT)
	await _process_frames(2)
	_player.health.receive_hit(LETHAL_HIT)
	assert_bool(_visual.visible).is_true()
	assert_bool(_feedback.is_flickering()).is_false()
	assert_vector(_camera.get_shake_offset()).is_equal(Vector2.ZERO)
