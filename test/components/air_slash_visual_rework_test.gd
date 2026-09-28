extends GdUnitTestSuite
## The air slash's body clips with the weapon in the hands, the body drawing
## back with the charge and the weapon blinking before the slash releases
## itself (docs/specs/air-slash-visual-rework.md AC1014–AC1026). Poses are
## measured in the Visual's space (-Z forward, +X to the right, +Y up).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const CONFIG: AirSlashConfig = preload("res://data/classes/berserker/air_slash_config.tres")
const ANIMATION_CONFIG: PlayerAnimationConfig = preload("res://data/player/player_animation_config.tres")
const TOLERANCE: float = 0.0001
## Height the player is lifted to before each air slash, in meters.
const LIFT: float = 2.0
## AC1015: pivot on the hand pose, in meters.
const GRIP_TOLERANCE: float = 0.001
## AC1018: torso capsule radius (as AC751) and sampling.
const TORSO_RADIUS: float = 0.16
const SAMPLE_STEP: float = 0.05
## AC1024: most opaque the blink overlay may be.
const MAX_BLINK_ALPHA: float = 0.6

var _registry: EnemyRegistry
var _player: Player
var _air: AirSlashComponent
var _humanoid: LowPolyHumanoid


func before_test() -> void:
	for action: StringName in [&"attack", &"dash", &"jump"]:
		Input.action_release(action)
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	Session.character_class = BERSERKER
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_air = _player.air_slash
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	await _physics_frames(20)


func after_test() -> void:
	Session.character_class = null
	for action: StringName in [&"attack", &"dash", &"jump"]:
		Input.action_release(action)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Lifts the player and holds attack until the suspension starts.
func _start_hover() -> void:
	_player.global_position.y += LIFT
	_player.velocity = Vector3.ZERO
	await _physics_frames(2)
	Input.action_press(&"attack")
	await _physics_frames(2)
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.HOVER)


func _clip() -> String:
	return String(_humanoid.anim.current_animation)


func _pivot() -> Node3D:
	return _player.get_node("Visual/SwordPivot") as Node3D


func _mount() -> WeaponMount:
	return _player.get_node("WeaponMount") as WeaponMount


func _blade_model() -> MeshInstance3D:
	return _pivot().get_child(0).get_node("Model") as MeshInstance3D


func _track_pose(animation: Animation, time: float) -> Dictionary:
	var pose: Dictionary = {}
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_VALUE:
			continue
		pose[String(animation.track_get_path(track))] = animation.value_track_interpolate(track, time)
	return pose


## Poses `clip` at `time` by hand and returns the blade base and tip, the hips
## and the neck, in the Visual's space.
func _measure(clip: StringName, time: float) -> Dictionary:
	_humanoid.anim.play(clip, 0.0)
	_humanoid.anim.seek(time, true)
	_mount().update(1.0)
	var to_visual: Transform3D = (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()
	var sword: Node3D = _pivot().get_child(0) as Node3D
	return {
		"base": to_visual * (sword.get_node("TrailBase") as Node3D).global_position,
		"tip": to_visual * (sword.get_node("TrailTip") as Node3D).global_position,
		"hips": to_visual * _humanoid.get_joint("hips").global_position,
		"neck": to_visual * _humanoid.get_joint("neck").global_position,
	}


func _freeze_animation() -> void:
	_humanoid.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	(_player.get_node("PlayerAnimator") as PlayerAnimator).set_physics_process(false)


## Distance from a point to the segment a–b.
func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Body and weapon

func test_ac1014_the_berserker_has_the_air_slash_clips() -> void:
	var library: AnimationLibrary = _humanoid.get_profile_library(&"berserker")
	for clip: StringName in [CONFIG.charge_body_clip, CONFIG.dive_body_clip, CONFIG.land_body_clip]:
		assert_bool(library.has_animation(clip)).override_failure_message(String(clip)).is_true()
		assert_int(library.get_animation(clip).loop_mode).is_equal(Animation.LOOP_NONE)
	for clip: StringName in [CONFIG.charge_body_clip, CONFIG.dive_body_clip]:
		var animation: Animation = library.get_animation(clip)
		var time: float = 0.0
		while time <= animation.length:
			var grip: float = float(_track_pose(animation, time)[".:left_hand_grip_weight"])
			assert_float(grip).override_failure_message("%s at %.2f s" % [clip, time]).is_equal_approx(1.0, TOLERANCE)
			time += SAMPLE_STEP


func test_ac1015_each_phase_plays_its_clip_with_the_weapon_in_hand() -> void:
	var settle: int = int(ceil(ANIMATION_CONFIG.weapon_mount_blend * Engine.physics_ticks_per_second)) + 2
	await _start_hover()
	await _physics_frames(settle)
	assert_str(_clip()).is_equal(String(CONFIG.charge_body_clip))
	assert_bool(_player.is_weapon_in_hand_cast()).is_true()
	await get_tree().process_frame
	assert_float(_pivot().global_position.distance_to(_mount().get_hand_pose().origin)).is_less_equal(GRIP_TOLERANCE)
	Input.action_release(&"attack")
	await _physics_frames(2)
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.DIVE)
	assert_str(_clip()).is_equal(String(CONFIG.dive_body_clip))
	assert_bool(_player.is_weapon_in_hand_cast()).is_true()
	while _air.get_phase() == AirSlashComponent.Phase.DIVE:
		await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.LANDING)
	assert_str(_clip()).is_equal(String(CONFIG.land_body_clip))
	assert_bool(_player.is_weapon_in_hand_cast()).is_true()


## The clip keeps its normal speed (so the blend into it runs) and is put back
## at the charge every step.
func test_ac1016_the_charge_clip_follows_the_charge() -> void:
	await _start_hover()
	var length: float = _humanoid.anim.get_animation(CONFIG.charge_body_clip).length
	var frame: float = 1.0 / Engine.physics_ticks_per_second
	for i: int in 3:
		await _physics_frames(40)
		var expected: float = _air.get_charge_ratio() * length
		assert_float(_humanoid.anim.current_animation_position).is_equal_approx(expected, frame / CONFIG.hover_duration * length + 0.001)


func test_ac1017_the_body_draws_back_with_the_charge() -> void:
	_freeze_animation()
	var length: float = _humanoid.anim.get_animation(CONFIG.charge_body_clip).length
	var start: Dictionary = _measure(CONFIG.charge_body_clip, 0.0)
	var full: Dictionary = _measure(CONFIG.charge_body_clip, length)
	assert_float((full.tip as Vector3).y).is_greater((start.tip as Vector3).y)
	assert_float((full.tip as Vector3).z).is_greater((start.tip as Vector3).z)
	assert_float((full.neck as Vector3).z - (full.hips as Vector3).z).is_greater((start.neck as Vector3).z - (start.hips as Vector3).z)


func test_ac1018_the_blade_stays_clear_of_the_torso() -> void:
	_freeze_animation()
	for clip: StringName in [CONFIG.charge_body_clip, CONFIG.dive_body_clip]:
		var length: float = _humanoid.anim.get_animation(clip).length
		var time: float = 0.0
		while time <= length:
			var m: Dictionary = _measure(clip, time)
			var base: Vector3 = m.base
			var tip: Vector3 = m.tip
			for point: Vector3 in [base, (base + tip) / 2.0, tip]:
				assert_float(_segment_distance(point, m.hips, m.neck)).override_failure_message("%s at %.2f s" % [clip, time]).is_greater(TORSO_RADIUS)
			time += SAMPLE_STEP


func test_ac1019_swordswing_never_moves_the_weapon() -> void:
	var names: PackedStringArray = PackedStringArray()
	for property: Dictionary in CONFIG.get_property_list():
		names.append(property.name)
	for gone: String in ["raise_position", "raise_rotation", "slam_position", "slam_rotation", "slam_duration"]:
		assert_bool(names.has(gone)).override_failure_message(gone).is_false()
	await _start_hover()
	var active: Array[bool] = [false]
	var frames: int = 0
	while frames < 30:
		active[0] = active[0] or _player.sword_swing.is_active()
		frames += 1
		await get_tree().physics_frame
	Input.action_release(&"attack")
	while _air.is_active():
		active[0] = active[0] or _player.sword_swing.is_active()
		await get_tree().physics_frame
	assert_bool(active[0]).is_false()


func test_ac1020_after_landing_the_body_blends_back_to_the_guard() -> void:
	await _start_hover()
	Input.action_release(&"attack")
	var saw_blend: Array[bool] = [false]
	while _air.is_active():
		await get_tree().physics_frame
		saw_blend[0] = saw_blend[0] or bool((_player.get_node("PlayerAnimator") as PlayerAnimator).get("_in_strike_pose"))
	await _physics_frames(10)
	assert_bool(saw_blend[0]).is_true()
	assert_str(_clip()).is_equal("idle")


# --- Blink

func test_ac1021_ac1022_the_weapon_blinks_faster_near_full_charge() -> void:
	await _start_hover()
	var model: MeshInstance3D = _blade_model()
	var frame: float = 1.0 / Engine.physics_ticks_per_second
	var lit_changes: Array[float] = []
	var was_lit: bool = false
	var elapsed: float = 0.0
	while _air.get_phase() == AirSlashComponent.Phase.HOVER:
		var ratio: float = _air.get_charge_ratio()
		var lit: bool = model.material_overlay != null
		if ratio < CONFIG.blink_start_ratio - frame / CONFIG.hover_duration:
			assert_object(model.material_overlay).override_failure_message("lit at %.3f" % ratio).is_null()
		if lit and not was_lit:
			lit_changes.append(elapsed)
		was_lit = lit
		elapsed += frame
		await get_tree().physics_frame
	assert_int(lit_changes.size()).is_greater_equal(3)
	var first_period: float = lit_changes[1] - lit_changes[0]
	var last_period: float = lit_changes[-1] - lit_changes[-2]
	assert_float(first_period).is_equal_approx(CONFIG.blink_period_start, 2.0 * frame + 0.03)
	assert_float(last_period).is_less(first_period)
	assert_float(last_period).is_greater_equal(CONFIG.blink_period_end - 2.0 * frame)


func test_ac1022_the_blink_period_goes_from_start_to_end() -> void:
	var blink: WeaponChargeBlink = _air.get_blink()
	assert_float(blink.get_period(CONFIG.blink_start_ratio)).is_equal_approx(CONFIG.blink_period_start, TOLERANCE)
	assert_float(blink.get_period(1.0)).is_equal_approx(CONFIG.blink_period_end, TOLERANCE)
	var middle: float = (CONFIG.blink_start_ratio + 1.0) / 2.0
	assert_float(blink.get_period(middle)).is_equal_approx((CONFIG.blink_period_start + CONFIG.blink_period_end) / 2.0, TOLERANCE)


func test_ac1023_releasing_or_cancelling_clears_the_blink() -> void:
	await _start_hover()
	while _air.get_charge_ratio() < CONFIG.blink_start_ratio + 0.05:
		await get_tree().physics_frame
	assert_bool(_air.get_blink().is_blinking()).is_true()
	Input.action_release(&"attack")
	await _physics_frames(2)
	assert_bool(_air.get_blink().is_blinking()).is_false()
	assert_object(_blade_model().material_overlay).is_null()
	while _air.is_active():
		await get_tree().physics_frame
	await _start_hover()
	while _air.get_charge_ratio() < CONFIG.blink_start_ratio + 0.05:
		await get_tree().physics_frame
	_air.cancel()
	assert_object(_blade_model().material_overlay).is_null()


func test_ac1023_the_self_release_at_full_charge_clears_the_blink() -> void:
	await _start_hover()
	while _air.get_phase() == AirSlashComponent.Phase.HOVER:
		await get_tree().physics_frame
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.DIVE)
	assert_object(_blade_model().material_overlay).is_null()


func test_ac1024_the_blink_is_a_shared_white_additive_overlay() -> void:
	var overlay: StandardMaterial3D = CONFIG.blink_overlay
	assert_object(Color(overlay.albedo_color, 1.0)).is_equal(Color(1, 1, 1, 1))
	assert_float(overlay.albedo_color.a).is_less_equal(MAX_BLINK_ALPHA + 0.001)
	assert_int(overlay.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_int(overlay.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)
	await _start_hover()
	while _blade_model().material_overlay == null and _air.get_phase() == AirSlashComponent.Phase.HOVER:
		await get_tree().physics_frame
	assert_object(_blade_model().material_overlay).is_same(overlay)


# --- Trail

func test_ac1025_the_trail_follows_the_dive() -> void:
	var trail: WeaponTrail = _player.get_node("WeaponTrail") as WeaponTrail
	await _start_hover()
	await _physics_frames(10)
	assert_bool(trail.is_emitting()).is_false()
	Input.action_release(&"attack")
	await _physics_frames(2)
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.DIVE)
	assert_bool(trail.is_emitting()).is_true()
	while _air.get_phase() == AirSlashComponent.Phase.DIVE:
		await get_tree().physics_frame
	assert_bool(trail.is_emitting()).is_false()
