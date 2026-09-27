extends GdUnitTestSuite
## Sheathe's release: the body draws, follows through and shakes the blade
## with the katana in the hand (docs/specs/sheathe-release-animation.md,
## AC721–AC726 and AC728–AC730).

const TestWorld := preload("res://test/helpers/test_world.gd")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
const ANIMATION_CONFIG: PlayerAnimationConfig = preload("res://data/player/player_animation_config.tres")
const SAMPLE_STEP: float = 1.0 / 30.0
## AC722: the release cast (the commitment) and the whole clip, in seconds.
const RELEASE_CAST: float = 0.5
const CLIP_LENGTH: float = 0.9
## Pivot on its pose, in meters and radians (AC723).
const POSE_TOLERANCE: float = 0.001
const ANGLE_TOLERANCE: float = 0.01
## AC724: key times of the path and joint match of the first and last frames.
const DRAW_TIME: float = 0.1
const FOLLOW_TIME: float = 0.2
const CHIBURI_TIME: float = 0.66
const JOINT_TOLERANCE: float = deg_to_rad(0.01)
## AC724: where the blade tip must be, in meters (Visual space: -Z to the enemy,
## +X to the character's right), and the least lean of the follow-through.
const TIP_RIGHT: float = 0.3
const TIP_OVER_SHOULDERS: float = 1.4
const TIP_LOW: float = 0.6
const FOLLOW_LEAN: float = 45.0

var _player: Player


func before_test() -> void:
	Input.action_release(&"dash")
	Input.action_release(&"ability_basic")
	add_child(auto_free(TestWorld.make_floor(60.0)))


func after_test() -> void:
	Session.character_class = null
	Input.action_release(&"dash")
	Input.action_release(&"ability_basic")
	Input.action_release(&"move_left")
	Input.action_release(&"attack")


func _spawn(character_class: CharacterClassData) -> Player:
	Session.character_class = character_class
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.enemy_registry = auto_free(EnemyRegistry.new())
	add_child(player)
	return player


## A samurai with Sheathe on its basic slot, driven by hand.
func _samurai_by_hand() -> AbilityComponent:
	_player = _spawn(SAMURAI)
	ComboDriver.drive_by_hand(_player)
	var ability: AbilityComponent = _player.basic_ability
	ability.equip(SHEATHE)
	ability.set_physics_process(false)
	return ability


func _humanoid() -> LowPolyHumanoid:
	return _player.get_node("Visual/Humanoid") as LowPolyHumanoid


func _animator() -> PlayerAnimator:
	return _player.get_node("PlayerAnimator") as PlayerAnimator


func _mount() -> WeaponMount:
	return _player.get_node("WeaponMount") as WeaponMount


func _pivot() -> Node3D:
	return _player.get_node("Visual/SwordPivot") as Node3D


func _tip() -> Node3D:
	return _pivot().get_child(0).get_node("TrailTip") as Node3D


func _to_visual(point: Vector3) -> Vector3:
	return (_player.get_node("Visual") as Node3D).global_transform.affine_inverse() * point


func _pose(clip: StringName, time: float) -> void:
	_humanoid().anim.play(clip, 0.0)
	_humanoid().anim.seek(time, true)
	_mount().update(1.0)


## Every joint rotation (and the hips offset) of a clip at a time.
func _joint_values(clip: StringName, time: float) -> Dictionary:
	var humanoid: LowPolyHumanoid = _humanoid()
	humanoid.anim.play(clip, 0.0)
	humanoid.anim.seek(time, true)
	var values: Dictionary = {}
	for joint: String in ["hips", "torso", "neck", "shoulder_l", "elbow_l", "wrist_l", "shoulder_r", "elbow_r", "wrist_r", "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r"]:
		values[joint] = humanoid.get_joint(joint).rotation
	values["hips_pos"] = humanoid.get_joint("hips").position
	values["left_grip"] = humanoid.left_hand_grip_weight
	values["right_grip"] = humanoid.right_hand_grip_weight
	return values


func _assert_same_pose(a: Dictionary, b: Dictionary, label: String) -> void:
	for key: String in a:
		if a[key] is Vector3:
			assert_vector(a[key]).override_failure_message("%s: %s" % [label, key]).is_equal_approx(b[key], Vector3.ONE * JOINT_TOLERANCE)
		else:
			assert_float(a[key]).override_failure_message("%s: %s" % [label, key]).is_equal_approx(b[key], 0.0001)


# --- AC721

func test_ac721_the_release_plays_its_body_clip() -> void:
	var ability: AbilityComponent = _samurai_by_hand()
	ability.try_cast()
	assert_str(String(_player.get_body_clip())).is_equal(String(SHEATHE_CONFIG.charge_body_clip))
	ability.release_charge()
	assert_bool(ability.is_casting()).is_true()
	assert_str(String(_player.get_body_clip())).is_equal(String(SHEATHE_CONFIG.release_body_clip))
	_animator().update()
	assert_str(String(_humanoid().anim.current_animation)).is_equal(String(SHEATHE_CONFIG.release_body_clip))
	assert_float(_humanoid().anim.current_animation_position).is_equal_approx(0.0, 0.0001)


func test_ac721_other_classes_have_no_release_clip() -> void:
	var humanoid: LowPolyHumanoid = _spawn(WARRIOR).get_node("Visual/Humanoid") as LowPolyHumanoid
	assert_bool(humanoid.anim.has_animation(SHEATHE_CONFIG.release_body_clip)).is_false()


# --- AC722

func test_ac722_the_release_commits_the_player_for_its_cast() -> void:
	assert_float(SHEATHE.cast_duration).is_equal_approx(RELEASE_CAST, 0.0001)
	assert_float(SHEATHE.min_cast_duration).is_equal_approx(RELEASE_CAST, 0.0001)
	assert_bool(SHEATHE.dash_cancels_cast).is_true()
	var ability: AbilityComponent = _samurai_by_hand()
	ability.try_cast()
	ability.release_charge()
	assert_float(ability.get_stat(AbilityData.Stat.CAST_DURATION)).is_equal_approx(RELEASE_CAST, 0.0001)
	ability.advance(RELEASE_CAST - 0.05)
	assert_bool(_player.is_casting()).is_true()
	ability.advance(0.1)
	assert_bool(_player.is_casting()).is_false()


func test_ac722_a_dash_cuts_the_release_and_keeps_the_katana_in_the_hand() -> void:
	_player = _spawn(SAMURAI)
	for i: int in 10:
		await get_tree().physics_frame
	var ability: AbilityComponent = _player.basic_ability
	ability.equip(SHEATHE)
	Input.action_press(&"ability_basic")
	for i: int in 10:
		await get_tree().physics_frame
	Input.action_release(&"ability_basic")
	for i: int in 3:
		await get_tree().physics_frame
	assert_bool(ability.is_casting()).is_true()
	assert_str(String(_humanoid().anim.current_animation)).is_equal(String(SHEATHE_CONFIG.release_body_clip))
	Input.action_press(&"dash")
	for i: int in 2:
		await get_tree().physics_frame
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_bool(ability.is_casting()).is_false()
	assert_str(String(_humanoid().anim.current_animation)).is_not_equal(String(SHEATHE_CONFIG.release_body_clip))
	assert_bool(_mount().is_holding_in_sheath()).is_false()
	assert_bool(_mount().is_hand_free()).is_true()


# --- AC723

func test_ac723_the_katana_leaves_the_sheath_with_the_hand() -> void:
	var ability: AbilityComponent = _samurai_by_hand()
	var mount: WeaponMount = _mount()
	var pivot: Node3D = _pivot()
	var swing: AnimationPlayer = _player.get_node("SwingPlayer") as AnimationPlayer
	ability.try_cast()
	_animator().update()
	var sheathed: Transform3D = mount.get_sheath_pose()
	ability.release_charge()
	# The frame of the release: the pivot is still on the sheath.
	assert_vector(pivot.global_position).is_equal_approx(sheathed.origin, Vector3.ONE * POSE_TOLERANCE)
	assert_bool(_player.is_weapon_in_hand_cast()).is_true()
	_animator().update()
	var anim: AnimationPlayer = _humanoid().anim
	var elapsed: float = 0.0
	while elapsed < CLIP_LENGTH - SAMPLE_STEP:
		anim.advance(SAMPLE_STEP)
		mount.update(SAMPLE_STEP)
		elapsed += SAMPLE_STEP
		assert_bool(swing.is_playing()).is_false()
		if elapsed > ANIMATION_CONFIG.weapon_mount_blend:
			var in_hand: Transform3D = mount.get_hand_pose()
			assert_vector(pivot.global_position).override_failure_message("at %.2f s" % elapsed).is_equal_approx(in_hand.origin, Vector3.ONE * POSE_TOLERANCE)
			assert_float(pivot.global_basis.get_rotation_quaternion().angle_to(in_hand.basis.get_rotation_quaternion())).is_less(ANGLE_TOLERANCE)
	var library: AnimationLibrary = swing.get_animation_library(&"")
	assert_bool(library.has_animation(&"sheathe_slash")).is_false()


# --- AC724

func test_ac724_the_path_follows_the_reference() -> void:
	_samurai_by_hand()
	var release: StringName = SHEATHE_CONFIG.release_body_clip
	_assert_same_pose(_joint_values(release, 0.0), _joint_values(SHEATHE_CONFIG.charge_body_clip, 0.0), "first frame vs charge")
	var length: float = _humanoid().anim.get_animation(release).length
	assert_float(length).is_equal_approx(CLIP_LENGTH, 0.0001)
	_assert_same_pose(_joint_values(release, length), _joint_values(&"idle", 0.0), "last frame vs idle")
	# Draw: up and to the right.
	_pose(release, DRAW_TIME)
	var tip: Vector3 = _to_visual(_tip().global_position)
	assert_float(tip.x).is_greater_equal(TIP_RIGHT)
	assert_float(tip.y).is_greater_equal(TIP_OVER_SHOULDERS)
	# Follow-through: behind the hips and over the shoulders, the body bowed.
	_pose(release, FOLLOW_TIME)
	tip = _to_visual(_tip().global_position)
	var hips: Vector3 = _to_visual(_humanoid().get_joint("hips").global_position)
	assert_float(tip.z).is_greater(hips.z)
	assert_float(tip.y).is_greater_equal(TIP_OVER_SHOULDERS)
	var torso_up: Vector3 = _humanoid().get_joint("torso").global_basis.y.normalized()
	assert_float(rad_to_deg(torso_up.angle_to(Vector3.UP))).is_greater_equal(FOLLOW_LEAN)
	# Chiburi: in front, to the right and low.
	_pose(release, CHIBURI_TIME)
	tip = _to_visual(_tip().global_position)
	assert_float(tip.z).is_less(0.0)
	assert_float(tip.x).is_greater_equal(TIP_RIGHT)
	assert_float(tip.y).is_less_equal(TIP_LOW)


# --- AC726

func test_ac726_data() -> void:
	assert_str(String(SHEATHE_CONFIG.release_body_clip)).is_equal("sheathe_release")
	var sheathe_script: GDScript = load("res://components/abilities/sheathe_ability.gd") as GDScript
	assert_bool(sheathe_script.get_script_constant_map().has("SLASH_ANIMATION")).is_false()
	var behavior := AbilityBehavior.new()
	assert_bool(behavior.holds_weapon_in_hand(null)).is_false()
	behavior.free()


# --- Revision 2 (§10): fluid curve and free recovery

func test_ac728_the_release_clip_is_cubic() -> void:
	_samurai_by_hand()
	var clip: Animation = _humanoid().anim.get_animation(SHEATHE_CONFIG.release_body_clip)
	for track: int in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_VALUE:
			assert_int(clip.value_track_get_update_mode(track)).is_equal(Animation.UPDATE_CONTINUOUS)
			assert_int(clip.track_get_interpolation_type(track)).override_failure_message(String(clip.track_get_path(track))).is_equal(Animation.INTERPOLATION_CUBIC)


## Real physics frames, as in a run.
func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _frames_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


## A samurai on the floor charges Sheathe for a moment and lets go.
func _release_for_real() -> AbilityComponent:
	_player = _spawn(SAMURAI)
	await _frames(10)
	var ability: AbilityComponent = _player.basic_ability
	ability.equip(SHEATHE)
	Input.action_press(&"ability_basic")
	await _frames(10)
	Input.action_release(&"ability_basic")
	await _frames(2)
	assert_bool(ability.is_casting()).is_true()
	return ability


func _current_clip() -> String:
	return String(_humanoid().anim.current_animation)


func test_ac729_without_input_the_release_finishes_as_a_free_recovery() -> void:
	var ability: AbilityComponent = await _release_for_real()
	await _frames(_frames_for(RELEASE_CAST) + 2)
	assert_bool(ability.is_casting()).is_false()
	assert_str(_current_clip()).is_equal(String(SHEATHE_CONFIG.release_body_clip))
	assert_bool(_mount().is_holding_in_sheath()).is_false()
	assert_bool(_mount().is_hand_free()).is_true()
	await _frames(_frames_for(CLIP_LENGTH - RELEASE_CAST) + 4)
	assert_str(_current_clip()).is_equal("idle")


func test_ac730_moving_cuts_the_recovery() -> void:
	await _release_for_real()
	await _frames(_frames_for(RELEASE_CAST) + 2)
	assert_str(_current_clip()).is_equal(String(SHEATHE_CONFIG.release_body_clip))
	Input.action_press(&"move_left")
	await _frames(8)
	Input.action_release(&"move_left")
	# Adapted (samurai-run.md): from the idle recovery the run starts with run_start.
	assert_array(["run_start", "run"]).contains([_current_clip()])


func test_ac730_attacking_cuts_the_recovery() -> void:
	await _release_for_real()
	await _frames(_frames_for(RELEASE_CAST) + 2)
	Input.action_press(&"attack")
	await _frames(2)
	Input.action_release(&"attack")
	assert_str(_current_clip()).is_equal("attack_1")


func test_ac730_the_dash_cuts_the_recovery() -> void:
	await _release_for_real()
	await _frames(_frames_for(RELEASE_CAST) + 2)
	Input.action_press(&"dash")
	await _frames(2)
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_str(_current_clip()).is_not_equal(String(SHEATHE_CONFIG.release_body_clip))


func test_ac730_a_cancelled_charge_does_not_keep_looping() -> void:
	_player = _spawn(SAMURAI)
	await _frames(10)
	var ability: AbilityComponent = _player.basic_ability
	ability.equip(SHEATHE)
	Input.action_press(&"ability_basic")
	await _frames(10)
	assert_str(_current_clip()).is_equal(String(SHEATHE_CONFIG.charge_body_clip))
	ability.cancel_charge()
	Input.action_release(&"ability_basic")
	await _frames(2)
	assert_str(_current_clip()).is_equal("idle")
