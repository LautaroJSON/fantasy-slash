extends GdUnitTestSuite
## The Samurai runs upright with the katana trailing low behind to the right,
## and starts running with a first step out of the guard
## (docs/specs/samurai-run.md, AC737–AC739 and AC741). Measured in the
## Visual's space (-Z where it runs, +X to the character's right).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMPLE_STEP: float = 1.0 / 30.0
## AC737: widest lean and turn of the torso, in degrees; the hand and the blade
## tip, in meters.
const RUN_LEAN: float = 12.0
const RUN_FACING: float = 20.0
const HAND_RIGHT: float = 0.2
const TIP_BEHIND: float = 0.3
const TIP_RIGHT: float = 0.3
const TIP_LOW: float = 0.7
## AC738: widest sideways gap between the ankles, in meters.
const STEP_WIDTH: float = 0.20
## AC739: length of the first step, its push lean, and the joint match.
const START_LENGTH: float = 0.2
const START_PUSH_TIME: float = 0.08
const START_LEAN: float = 8.0
const JOINT_TOLERANCE: float = deg_to_rad(0.01)

var _player: Player


func before_test() -> void:
	Input.action_release(&"move_forward")
	add_child(auto_free(TestWorld.make_floor(60.0)))


func after_test() -> void:
	Session.character_class = null
	Input.action_release(&"move_forward")


func _spawn(character_class: CharacterClassData) -> Player:
	Session.character_class = character_class
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.enemy_registry = auto_free(EnemyRegistry.new())
	add_child(player)
	return player


func _humanoid() -> LowPolyHumanoid:
	return _player.get_node("Visual/Humanoid") as LowPolyHumanoid


## A samurai whose clips are posed by hand.
func _samurai_posed() -> void:
	_player = _spawn(SAMURAI)
	_humanoid().anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	(_player.get_node("PlayerAnimator") as PlayerAnimator).set_physics_process(false)


func _pose(clip: StringName, time: float) -> void:
	_humanoid().anim.play(clip, 0.0)
	_humanoid().anim.seek(time, true)
	(_player.get_node("WeaponMount") as WeaponMount).update(1.0)


func _to_visual() -> Transform3D:
	return (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()


func _point(node: Node3D) -> Vector3:
	return _to_visual() * node.global_position


func _joint_values(clip: StringName, time: float) -> Dictionary:
	_pose(clip, time)
	var values: Dictionary = {}
	for joint: String in ["hips", "torso", "neck", "shoulder_l", "elbow_l", "wrist_l", "shoulder_r", "elbow_r", "wrist_r", "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r"]:
		values[joint] = _humanoid().get_joint(joint).rotation
	values["hips_pos"] = _humanoid().get_joint("hips").position
	return values


func _assert_same_pose(a: Dictionary, b: Dictionary, label: String) -> void:
	for key: String in a:
		assert_vector(a[key]).override_failure_message("%s: %s" % [label, key]).is_equal_approx(b[key], Vector3.ONE * JOINT_TOLERANCE)


func _lean() -> float:
	return rad_to_deg(_humanoid().get_joint("torso").global_basis.y.normalized().angle_to(Vector3.UP))


# --- AC737 / AC738

func test_ac737_ac738_the_run_is_upright_with_the_katana_trailing() -> void:
	_samurai_posed()
	var pivot: Node3D = _player.get_node("Visual/SwordPivot") as Node3D
	var tip_marker: Node3D = pivot.get_child(0).get_node("TrailTip") as Node3D
	var length: float = _humanoid().anim.get_animation(&"run").length
	var time: float = 0.0
	while time < length:
		_pose(&"run", time)
		var label: String = "run at %.2f s" % time
		assert_float(_lean()).override_failure_message(label).is_less_equal(RUN_LEAN)
		var chest: Vector3 = _to_visual().basis * -_humanoid().get_joint("torso").global_basis.z
		assert_float(rad_to_deg(Vector3(chest.x, 0.0, chest.z).angle_to(Vector3.FORWARD))).override_failure_message(label).is_less_equal(RUN_FACING)
		var hips: Vector3 = _point(_humanoid().get_joint("hips"))
		assert_float(_point(pivot).x).override_failure_message(label).is_greater_equal(HAND_RIGHT)
		var tip: Vector3 = _point(tip_marker)
		assert_float(tip.z - hips.z).override_failure_message(label).is_greater_equal(TIP_BEHIND)
		assert_float(tip.x).override_failure_message(label).is_greater_equal(TIP_RIGHT)
		assert_float(tip.y).override_failure_message(label).is_less_equal(TIP_LOW)
		var gap: float = absf(_point(_humanoid().get_joint("ankle_l")).x - _point(_humanoid().get_joint("ankle_r")).x)
		assert_float(gap).override_failure_message(label).is_less_equal(STEP_WIDTH)
		time += SAMPLE_STEP


# --- AC739

func test_ac739_the_first_step_joins_the_guard_and_the_run() -> void:
	_samurai_posed()
	var clip: Animation = _humanoid().anim.get_animation(&"run_start")
	assert_object(clip).is_not_null()
	assert_float(clip.length).is_equal_approx(START_LENGTH, 0.01)
	for track: int in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_VALUE:
			assert_int(clip.track_get_interpolation_type(track)).is_equal(Animation.INTERPOLATION_CUBIC)
	_assert_same_pose(_joint_values(&"run_start", 0.0), _joint_values(&"idle", 0.0), "first frame vs idle")
	_assert_same_pose(_joint_values(&"run_start", clip.length), _joint_values(&"run", 0.0), "last frame vs run")
	_pose(&"run_start", START_PUSH_TIME)
	assert_float(_lean()).is_greater_equal(START_LEAN)


# --- AC741

func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_ac741_starting_to_move_plays_the_first_step_then_the_run() -> void:
	_player = _spawn(SAMURAI)
	await _frames(10)
	var seen: Array[String] = []
	_humanoid().anim.animation_started.connect(func(clip: StringName) -> void: seen.append(String(clip)))
	Input.action_press(&"move_forward")
	await _frames(ceili(START_LENGTH * Engine.physics_ticks_per_second) + 8)
	Input.action_release(&"move_forward")
	assert_array(seen).is_not_empty()
	assert_str(seen[0]).is_equal("run_start")
	assert_array(seen).contains(["run"])
	assert_int(seen.find("run")).is_equal(1)


func test_ac741_other_classes_go_straight_to_run() -> void:
	for character_class: CharacterClassData in [WARRIOR, BERSERKER]:
		_player = _spawn(character_class)
		await _frames(10)
		assert_bool(_humanoid().anim.has_animation(&"run_start")).is_false()
		Input.action_press(&"move_forward")
		await _frames(4)
		Input.action_release(&"move_forward")
		assert_str(String(_humanoid().anim.current_animation)).is_equal("run")
		await _frames(20)
