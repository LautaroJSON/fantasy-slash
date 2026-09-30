extends GdUnitTestSuite
## The katana sheath is held in the left hand and the hands grip their targets
## (docs/specs/sheath-socket-hand-grip.md AC663–AC670 and
## docs/specs/sheath-in-left-hand.md AC671–AC677; docs/specs/katana-hand-proportions.md
## AC684–AC685; docs/specs/katana-sheath-shape.md AC696; docs/specs/katana-visual-rework.md AC1235)).

const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const KatanaParts := preload("res://test/helpers/katana_parts.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
const SAMPLE_STEP: float = 1.0 / 30.0
## Hand on its target, in meters (AC663, AC670, AC672).
const GRIP_TOLERANCE: float = 0.001
const POSE_TOLERANCE: float = 0.0001
## AC670/AC675: first frame of sheathe_slash vs the socket.
const SLASH_START_DISTANCE: float = 0.02
const SLASH_START_DEGREES: float = 5.0
## AC673: turn of wrist_l X and the matching turn of the sheath axis, in degrees.
const WRIST_TURN: float = 20.0
const WRIST_TURN_TOLERANCE: float = 1.0
## AC674: farthest the sheath mouth may be from the hips, in meters; steepest
## sheath, in degrees; and lowest point of the sheath over the floor, in meters.
const MOUTH_REACH: float = 0.30
const SHEATH_STEEPEST: float = 60.0
const SHEATH_FLOOR_GAP: float = 0.05
## AC670 (revision 5): least drop of the hips, and the lean range of the
## almost upright torso, in meters and degrees.
const CHARGE_DROP: float = 0.20
const CHARGE_LEAN_MIN: float = 10.0
const CHARGE_LEAN_MAX: float = 25.0
## AC670: least reach of each ankle in front of / behind the hips, and widest
## sideways gap between the feet, in meters.
const LUNGE_REACH: float = 0.25
const LUNGE_WIDTH: float = 0.30
## AC670: widest angle of each foot from its heading, and from lying flat, in degrees.
const FOOT_HEADING: float = 20.0
const FOOT_FLAT: float = 10.0
## AC670: the sheath crosses behind to the right: least rightward share of its
## axis and widest angle from the horizontal; and widest angle between the face
## and the enemy (-Z), in degrees.
const SHEATH_RIGHT: float = 0.5
const SHEATH_TILT: float = 20.0
const FACE_ANGLE: float = 25.0
## AC670: farthest the body center may be from the player origin, horizontally,
## in meters; and the head center in the neck joint (low_poly_humanoid.gd).
const CENTER_TOLERANCE: float = 0.07
const HEAD_CENTER: Vector3 = Vector3(0.0, 0.21, 0.0)
## AC684: least the pommel sticks out behind the right hand, in meters.
const POMMEL_OUT: float = 0.05
## AC685: farthest the Hilt may be from the combat grip point, and the sheath
## mouth from the guard front face, in meters.
const HILT_GAP: float = 0.01
const MOUTH_GAP: float = 0.01
## AC696: least gap between the sheathed blade and the sheath surface, in meters.
const BLADE_MARGIN: float = 0.0015

var _player: Player


func after_test() -> void:
	Session.character_class = null


func _spawn_player(character_class: CharacterClassData) -> Player:
	Session.character_class = character_class
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.enemy_registry = auto_free(EnemyRegistry.new())
	add_child(player)
	return player


func _humanoid(player: Player) -> LowPolyHumanoid:
	return player.get_node("Visual/Humanoid") as LowPolyHumanoid


func _samurai_by_hand() -> LowPolyHumanoid:
	_player = _spawn_player(SAMURAI)
	ComboDriver.drive_by_hand(_player)
	return _humanoid(_player)


func _pose(humanoid: LowPolyHumanoid, clip: StringName, time: float) -> void:
	humanoid.anim.play(clip, 0.0)
	humanoid.anim.seek(time, true)


func _grip() -> Node3D:
	return _player.get_sheath().get_node("Grip") as Node3D


func _hilt() -> Node3D:
	return _player.get_node("Visual/SwordPivot").get_child(0).get_node("Hilt") as Node3D


# --- Socket

func test_ac671_the_sheath_hangs_from_a_socket_on_the_left_wrist() -> void:
	_player = _spawn_player(SAMURAI)
	var humanoid: LowPolyHumanoid = _humanoid(_player)
	var socket: Node3D = _player.get_sheath_socket()
	assert_object(socket).is_not_null()
	assert_str(String(SAMURAI.weapon.sheath_joint)).is_equal("wrist_l")
	assert_object(socket.get_parent()).is_same(humanoid.get_joint(String(SAMURAI.weapon.sheath_joint)))
	assert_object(_player.get_sheath().get_parent()).is_same(socket)
	assert_vector(socket.position * humanoid.scale.x).is_equal_approx(SAMURAI.weapon.sheath_position, Vector3.ONE * POSE_TOLERANCE)
	# The scale of the humanoid is compensated: the sheath keeps its size.
	assert_vector(_player.get_sheath().global_basis.get_scale()).is_equal_approx(Vector3.ONE, Vector3.ONE * POSE_TOLERANCE)
	for character_class: CharacterClassData in [WARRIOR, BERSERKER]:
		assert_object(_spawn_player(character_class).get_sheath_socket()).is_null()


## Axis of the sheath, from its mouth to its tip.
func _sheath_axis() -> Vector3:
	return -_player.get_sheath().global_basis.z.normalized()


func test_ac673_the_left_arm_sets_the_sheath_angle() -> void:
	var humanoid: LowPolyHumanoid = _samurai_by_hand()
	var socket: Node3D = _player.get_sheath_socket()
	var wrist: Node3D = humanoid.get_joint("wrist_l")
	for clip_name: StringName in humanoid.anim.get_animation_list():
		var clip: Animation = humanoid.anim.get_animation(clip_name)
		var time: float = 0.0
		while time <= clip.length:
			_pose(humanoid, clip_name, time)
			var expected: Transform3D = wrist.global_transform * socket.transform
			assert_vector(socket.global_position).is_equal_approx(expected.origin, Vector3.ONE * GRIP_TOLERANCE)
			time += SAMPLE_STEP
	# Turning the wrist about X turns the sheath by as much.
	_pose(humanoid, &"idle", 0.0)
	var before: Vector3 = _sheath_axis()
	wrist.rotation.x += deg_to_rad(WRIST_TURN)
	var turn: float = rad_to_deg(before.angle_to(_sheath_axis()))
	assert_float(turn).is_equal_approx(WRIST_TURN, WRIST_TURN_TOLERANCE)


# --- Hand targets

func test_ac663_a_hand_goes_to_its_target_by_weight() -> void:
	var humanoid: LowPolyHumanoid = auto_free(LowPolyHumanoid.new())
	humanoid.has_sword = false
	humanoid.use_hitbox = false
	add_child(humanoid)
	humanoid.anim.stop()
	var marker: Marker3D = auto_free(Marker3D.new())
	add_child(marker)
	marker.global_position = Vector3(0.7, 1.2, -0.4)
	for hand: LowPolyHumanoid.Hand in [LowPolyHumanoid.Hand.LEFT, LowPolyHumanoid.Hand.RIGHT]:
		var mesh: MeshInstance3D = humanoid.get_hand_mesh(hand)
		var rest: Transform3D = mesh.transform
		var animated: Vector3 = mesh.global_position
		for weight: float in [1.0, 0.5, 0.0]:
			humanoid.left_hand_grip_weight = weight
			humanoid.right_hand_grip_weight = weight
			humanoid.set_hand_target(hand, marker)
			var expected: Vector3 = animated.lerp(marker.global_position, weight)
			assert_vector(mesh.global_position).is_equal_approx(expected, Vector3.ONE * GRIP_TOLERANCE)
		assert_that(mesh.transform).is_equal(rest)
		humanoid.left_hand_grip_weight = 1.0
		humanoid.right_hand_grip_weight = 1.0
		humanoid.set_hand_target(hand, marker)
		humanoid.clear_hand_target(hand)
		assert_that(mesh.transform).is_equal(rest)


func test_ac664_the_grip_lands_in_the_same_frame_and_leaves_the_wrist_alone() -> void:
	var humanoid: LowPolyHumanoid = _samurai_by_hand()
	var mesh: MeshInstance3D = humanoid.get_hand_mesh(LowPolyHumanoid.Hand.LEFT)
	humanoid.anim.play(&"attack_1", 0.0)
	humanoid.anim.advance(0.1)
	assert_vector(mesh.global_position).is_equal_approx(_grip().global_position, Vector3.ONE * GRIP_TOLERANCE)
	var clip: Animation = humanoid.anim.get_animation(&"attack_1")
	var path: NodePath = NodePath(String(humanoid.get_path_to(humanoid.get_joint("wrist_l"))) + ":rotation")
	var track: int = clip.find_track(path, Animation.TYPE_VALUE)
	var animated: Vector3 = clip.value_track_interpolate(track, humanoid.anim.current_animation_position)
	assert_vector(humanoid.get_joint("wrist_l").rotation).is_equal_approx(animated, Vector3.ONE * POSE_TOLERANCE)


## Values of a clip's weight track at its keys.
func _weights(humanoid: LowPolyHumanoid, clip: Animation, side: String) -> Array[float]:
	var track: int = clip.find_track(NodePath(".:%s_hand_grip_weight" % side), Animation.TYPE_VALUE)
	var values: Array[float] = []
	for key: int in clip.track_get_key_count(track):
		values.append(clip.track_get_key_value(track, key))
	return values


func test_ac665_every_clip_carries_its_grip_weights() -> void:
	var humanoid: LowPolyHumanoid = _humanoid(_spawn_player(WARRIOR))
	for id: StringName in LowPolyHumanoid.PROFILES:
		var library: AnimationLibrary = humanoid.get_profile_library(id)
		for clip_name: StringName in library.get_animation_list():
			var clip: Animation = library.get_animation(clip_name)
			for side: String in ["left", "right"]:
				assert_int(clip.find_track(NodePath(".:%s_hand_grip_weight" % side), Animation.TYPE_VALUE)).is_greater_equal(0)
			var left: Array[float] = _weights(humanoid, clip, "left")
			var right: Array[float] = _weights(humanoid, clip, "right")
			var label: String = "%s %s" % [id, clip_name]
			if id == SAMURAI.animation_profile:
				# The sheath comes to the hand, so the left hand has no target (AC672).
				assert_bool(left.all(func(w: float) -> bool: return is_zero_approx(w))).override_failure_message(label).is_true()
				# Adapted (sheathe-visual-rework.md): the deeper charge poses grip the hilt too.
				var charging: bool = clip_name == SHEATHE_CONFIG.charge_body_clip or SHEATHE_CONFIG.charge_sink_clips.has(clip_name)
				var right_expected: float = 1.0 if charging else 0.0
				if clip_name == SHEATHE_CONFIG.release_body_clip:
					# The release starts on the hilt and lets go to draw
					# (sheathe-release-animation.md).
					assert_float(right[0]).override_failure_message(label).is_equal_approx(1.0, POSE_TOLERANCE)
					right = right.slice(1)
				assert_bool(right.all(func(w: float) -> bool: return is_equal_approx(w, right_expected))).override_failure_message(label).is_true()
			elif id == BERSERKER.animation_profile:
				# Two-handed greatsword: the left hand grips its OffHand at every impact
				# (class-combat-identity.md §3.2; it lets go at the end of the return
				# sweep); the right hand never has a target weight.
				for step: AttackComboStep in BERSERKER.combo.steps:
					if step.animation == clip_name:
						var track: int = clip.find_track(NodePath(".:left_hand_grip_weight"), Animation.TYPE_VALUE)
						assert_float(clip.value_track_interpolate(track, step.hit_start)).override_failure_message(label).is_equal_approx(1.0, 0.001)
				assert_bool(right.all(func(w: float) -> bool: return is_zero_approx(w))).override_failure_message(label).is_true()
			else:
				assert_bool(left.all(func(w: float) -> bool: return is_zero_approx(w))).override_failure_message(label).is_true()
				assert_bool(right.all(func(w: float) -> bool: return is_zero_approx(w))).override_failure_message(label).is_true()


func test_ac672_the_samurai_left_hand_holds_the_sheath_in_every_clip() -> void:
	var humanoid: LowPolyHumanoid = _samurai_by_hand()
	var mesh: MeshInstance3D = humanoid.get_hand_mesh(LowPolyHumanoid.Hand.LEFT)
	for clip_name: StringName in humanoid.anim.get_animation_list():
		var clip: Animation = humanoid.anim.get_animation(clip_name)
		var time: float = 0.0
		while time <= clip.length:
			_pose(humanoid, clip_name, time)
			assert_float(humanoid.left_hand_grip_weight).is_zero()
			var gap: float = mesh.global_position.distance_to(_grip().global_position)
			assert_float(gap).override_failure_message("%s at %.2f s: the hand is %.3f m from the grip" % [clip_name, time, gap]).is_less_equal(GRIP_TOLERANCE)
			time += SAMPLE_STEP


## Lowest point of the sheath model, in world meters (the floor is y = 0).
func _sheath_lowest() -> float:
	var model: MeshInstance3D = _player.get_sheath().get_node("Model") as MeshInstance3D
	var box: AABB = model.get_aabb()
	var lowest: float = INF
	for corner: int in 8:
		lowest = minf(lowest, (model.global_transform * box.get_endpoint(corner)).y)
	return lowest


func test_ac674_the_sheath_stays_at_the_waist_in_every_clip() -> void:
	var humanoid: LowPolyHumanoid = _samurai_by_hand()
	var to_visual: Transform3D = (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()
	for clip_name: StringName in humanoid.anim.get_animation_list():
		var clip: Animation = humanoid.anim.get_animation(clip_name)
		var time: float = 0.0
		while time <= clip.length:
			_pose(humanoid, clip_name, time)
			var label: String = "%s at %.2f s" % [clip_name, time]
			var hips: Vector3 = to_visual * humanoid.get_joint("hips").global_position
			var mouth: Vector3 = to_visual * _grip().global_position
			assert_float(mouth.distance_to(hips)).override_failure_message(label).is_less_equal(MOUTH_REACH)
			var axis: Vector3 = (to_visual.basis * _sheath_axis()).normalized()
			assert_float(axis.z).override_failure_message(label).is_greater_equal(0.0)
			assert_float(rad_to_deg(absf(asin(axis.y)))).override_failure_message(label).is_less_equal(SHEATH_STEEPEST)
			assert_float(_sheath_lowest()).override_failure_message(label).is_greater_equal(SHEATH_FLOOR_GAP)
			time += SAMPLE_STEP


# --- Sheathe

## Equips Sheathe on the samurai's basic slot and drives it by hand.
func _equip_sheathe() -> AbilityComponent:
	var ability: AbilityComponent = _player.basic_ability
	ability.equip(SHEATHE)
	ability.set_physics_process(false)
	return ability


func test_ac675_the_charging_katana_waits_in_the_socket_and_slashes_from_it() -> void:
	var humanoid: LowPolyHumanoid = _samurai_by_hand()
	var ability: AbilityComponent = _equip_sheathe()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	var pivot: Node3D = _player.get_node("Visual/SwordPivot") as Node3D
	ability.try_cast()
	assert_bool(mount.is_holding_in_sheath()).is_true()
	for clip_name: StringName in [SHEATHE_CONFIG.charge_body_clip, &"run"]:
		_pose(humanoid, clip_name, 0.2)
		assert_vector(pivot.global_position).is_equal_approx(mount.get_sheath_pose().origin, Vector3.ONE * GRIP_TOLERANCE)
	_pose(humanoid, SHEATHE_CONFIG.charge_body_clip, 0.0)
	var sheathed: Transform3D = mount.get_sheath_pose()
	ability.release_charge()
	assert_bool(mount.is_holding_in_sheath()).is_false()
	# Adapted (sheathe-release-animation.md, AC723): no sheathe_slash; the
	# release starts from the sheath itself and the hand draws the cut.
	var swing: AnimationPlayer = _player.get_node("SwingPlayer") as AnimationPlayer
	assert_bool(swing.is_playing()).is_false()
	assert_float(pivot.global_position.distance_to(sheathed.origin)).is_less_equal(SLASH_START_DISTANCE)
	assert_float(pivot.global_basis.get_rotation_quaternion().angle_to(sheathed.basis.get_rotation_quaternion())).is_less_equal(deg_to_rad(SLASH_START_DEGREES))


func test_ac675_cancelling_the_charge_lets_the_katana_go() -> void:
	_samurai_by_hand()
	var ability: AbilityComponent = _equip_sheathe()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	ability.try_cast()
	ability.cancel_charge()
	assert_bool(mount.is_holding_in_sheath()).is_false()


func test_ac668_the_data_moved_to_the_socket_and_markers() -> void:
	assert_bool("sheathed_position" in SHEATHE_CONFIG).is_false()
	assert_bool("sheathed_rotation" in SHEATHE_CONFIG).is_false()
	assert_str(String(SHEATHE_CONFIG.charge_body_clip)).is_equal("sheathe_charge")
	var sheath: Node3D = auto_free(SAMURAI.weapon.sheath.instantiate())
	assert_bool(sheath.has_node("Grip")).is_true()
	var katana: Node3D = auto_free(SAMURAI.weapon.model.instantiate())
	assert_bool(katana.has_node("Hilt")).is_true()
	var humanoid: LowPolyHumanoid = auto_free(LowPolyHumanoid.new())
	assert_bool(humanoid.has_method("pin_left_hand")).is_false()
	assert_bool(humanoid.has_method("with_left_hand_at")).is_false()


func test_ac677_the_sheath_joint_is_data() -> void:
	assert_bool("sheath_joint" in SAMURAI.weapon).is_true()
	var player_script: String = (load("res://entities/player/player.gd") as GDScript).source_code
	assert_bool(player_script.contains("SHEATH_JOINT")).is_false()


## AC676: the charge pose keeps AC670 (revision 5) with the sheath in the left hand.
func test_ac670_charging_sheathe_crouches_in_the_battojutsu_pose() -> void:
	var humanoid: LowPolyHumanoid = _samurai_by_hand()
	var ability: AbilityComponent = _equip_sheathe()
	ability.try_cast()
	assert_str(String(_player.get_body_clip())).is_equal(String(SHEATHE_CONFIG.charge_body_clip))
	var animator: PlayerAnimator = _player.get_node("PlayerAnimator") as PlayerAnimator
	animator.update()
	assert_str(String(humanoid.anim.current_animation)).is_equal(String(SHEATHE_CONFIG.charge_body_clip))
	_pose(humanoid, &"idle", 0.0)
	var standing: float = humanoid.get_joint("hips").global_position.y
	_pose(humanoid, SHEATHE_CONFIG.charge_body_clip, 0.0)
	var crouching: float = humanoid.get_joint("hips").global_position.y
	assert_float(standing - crouching).is_greater_equal(CHARGE_DROP)
	# Revision 5: the responsible's final pose (sheath-socket-hand-grip.md AC670).
	var torso_up: Vector3 = humanoid.get_joint("torso").global_basis.y.normalized()
	var lean: float = rad_to_deg(torso_up.angle_to(Vector3.UP))
	assert_float(lean).is_between(CHARGE_LEAN_MIN, CHARGE_LEAN_MAX)
	# Lunge with the right foot forward, measured in the Visual (-Z toward the
	# enemy, +X to the character's right).
	var visual: Node3D = _player.get_node("Visual") as Node3D
	var to_visual: Transform3D = visual.global_transform.affine_inverse()
	var hips: Vector3 = to_visual * humanoid.get_joint("hips").global_position
	var ankle_l: Vector3 = to_visual * humanoid.get_joint("ankle_l").global_position
	var ankle_r: Vector3 = to_visual * humanoid.get_joint("ankle_r").global_position
	assert_float(hips.z - ankle_r.z).is_greater_equal(LUNGE_REACH)
	assert_float(ankle_l.z - hips.z).is_greater_equal(LUNGE_REACH)
	assert_float(absf(ankle_l.x - ankle_r.x)).is_less_equal(LUNGE_WIDTH)
	# The front foot points at the enemy and the back one sideways, both flat.
	for foot: Array in [["ankle_r", Vector3.FORWARD], ["ankle_l", Vector3.LEFT]]:
		var foot_basis: Basis = (to_visual.basis * humanoid.get_joint(foot[0]).global_basis).orthonormalized()
		var toe: Vector3 = -foot_basis.z
		assert_float(rad_to_deg(Vector3(toe.x, 0.0, toe.z).angle_to(foot[1]))).override_failure_message(foot[0]).is_less_equal(FOOT_HEADING)
		assert_float(rad_to_deg(foot_basis.y.angle_to(Vector3.UP))).override_failure_message(foot[0]).is_less_equal(FOOT_FLAT)
	# The sheath crosses behind the body to the right, about level.
	var sheath: Node3D = _player.get_sheath()
	var axis: Vector3 = (to_visual.basis * -sheath.global_basis.z).normalized()
	assert_float(axis.z).is_greater(0.0)
	assert_float(axis.x).is_greater_equal(SHEATH_RIGHT)
	assert_float(rad_to_deg(absf(asin(axis.y)))).is_less_equal(SHEATH_TILT)
	# The head looks at the enemy over the guard.
	var face: Vector3 = to_visual.basis * -humanoid.get_joint("neck").global_basis.z
	assert_float(rad_to_deg(face.angle_to(Vector3.FORWARD))).is_less_equal(FACE_ANGLE)
	var right: MeshInstance3D = humanoid.get_hand_mesh(LowPolyHumanoid.Hand.RIGHT)
	var left: MeshInstance3D = humanoid.get_hand_mesh(LowPolyHumanoid.Hand.LEFT)
	# Both hands on the sheathed katana, and the body centered over the player:
	# the horizontal average of hips, torso, head and feet stays on its origin.
	assert_vector(right.global_position).is_equal_approx(_hilt().global_position, Vector3.ONE * GRIP_TOLERANCE)
	var center := Vector3.ZERO
	for joint: String in ["hips", "torso", "ankle_l", "ankle_r"]:
		center += humanoid.get_joint(joint).global_position
	center += humanoid.get_joint("neck").global_transform * HEAD_CENTER
	center = visual.global_transform.affine_inverse() * (center / 5.0)
	assert_float(Vector2(center.x, center.z).length()).is_less_equal(CENTER_TOLERANCE)
	assert_vector(left.global_position).is_equal_approx(_grip().global_position, Vector3.ONE * GRIP_TOLERANCE)


func test_ac670_other_classes_keep_idle_while_casting() -> void:
	for character_class: CharacterClassData in [WARRIOR, BERSERKER]:
		var humanoid: LowPolyHumanoid = _humanoid(_spawn_player(character_class))
		assert_bool(humanoid.anim.has_animation(SHEATHE_CONFIG.charge_body_clip)).is_false()


# --- Katana proportions (docs/specs/katana-hand-proportions.md)

func _katana_model() -> MeshInstance3D:
	return _player.get_node("Visual/SwordPivot").get_child(0).get_node("Model") as MeshInstance3D


## Katana guard vertices, in world space.
func _guard_world() -> PackedVector3Array:
	var model: MeshInstance3D = _katana_model()
	var weapon: Transform3D = (model.get_parent() as Node3D).global_transform
	var points: PackedVector3Array = []
	for p: Vector3 in KatanaParts.guard_points(model):
		points.append(weapon * p)
	return points


## Label of the first world point inside the box of a hand mesh, or "".
func _inside_hand(points: PackedVector3Array, hand: MeshInstance3D) -> String:
	var to_hand: Transform3D = hand.global_transform.affine_inverse()
	var box: AABB = hand.get_aabb()
	for p: Vector3 in points:
		if box.has_point(to_hand * p):
			return "guard vertex %s is inside %s" % [p, hand.name]
	return ""


func test_ac684_the_guard_and_the_pommel_show_around_the_right_hand() -> void:
	var humanoid: LowPolyHumanoid = _samurai_by_hand()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	var pivot: Node3D = _player.get_node("Visual/SwordPivot") as Node3D
	_pose(humanoid, &"idle", 0.0)
	mount.update(1.0)
	assert_vector(pivot.global_position).is_equal_approx(mount.get_hand_pose().origin, Vector3.ONE * GRIP_TOLERANCE)
	var hand: MeshInstance3D = humanoid.get_hand_mesh(LowPolyHumanoid.Hand.RIGHT)
	assert_str(_inside_hand(_guard_world(), hand)).is_empty()
	# Behind the fist along the weapon axis (+Z of the weapon is the pommel end).
	var to_weapon: Transform3D = pivot.global_transform.affine_inverse() * hand.global_transform
	var hand_back: float = -INF
	var box: AABB = hand.get_aabb()
	for corner: int in 8:
		hand_back = maxf(hand_back, (to_weapon * box.get_endpoint(corner)).z)
	var model: MeshInstance3D = _katana_model()
	var pommel: float = (model.transform * model.mesh.get_aabb()).end.z
	assert_float(pommel - hand_back).is_greater_equal(POMMEL_OUT)


func test_ac685_sheathed_the_guard_sits_between_the_hands() -> void:
	var humanoid: LowPolyHumanoid = _samurai_by_hand()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	var pivot: Node3D = _player.get_node("Visual/SwordPivot") as Node3D
	# Combat grip point: the right hand center, in weapon space.
	_pose(humanoid, &"idle", 0.0)
	mount.update(1.0)
	var right: MeshInstance3D = humanoid.get_hand_mesh(LowPolyHumanoid.Hand.RIGHT)
	var grip_point: Vector3 = mount.get_hand_pose().affine_inverse() * right.global_position
	assert_float(_hilt().position.distance_to(grip_point)).is_less_equal(HILT_GAP)
	_equip_sheathe().try_cast()
	_pose(humanoid, SHEATHE_CONFIG.charge_body_clip, 0.0)
	mount.update(1.0)
	assert_bool(mount.is_holding_in_sheath()).is_true()
	var guard: PackedVector3Array = _guard_world()
	assert_str(_inside_hand(guard, right)).is_empty()
	assert_str(_inside_hand(guard, humanoid.get_hand_mesh(LowPolyHumanoid.Hand.LEFT))).is_empty()
	# Sheath mouth on the guard front face, and the blade within the sheath.
	var sheath_model: MeshInstance3D = _player.get_sheath().get_node("Model") as MeshInstance3D
	var sheath_box: AABB = sheath_model.transform * sheath_model.mesh.get_aabb()
	var to_sheath: Transform3D = _player.get_sheath().global_transform.affine_inverse()
	var guard_front: float = INF
	for p: Vector3 in guard:
		guard_front = minf(guard_front, (to_sheath * p).z)
	assert_float(absf(guard_front - sheath_box.end.z)).is_less_equal(MOUTH_GAP)
	var katana_model: MeshInstance3D = _katana_model()
	var tip_local: float = (katana_model.transform * katana_model.mesh.get_aabb()).position.z
	var tip: Vector3 = to_sheath * (pivot.global_transform * Vector3(0.0, 0.0, tip_local))
	assert_float(tip.z).is_greater_equal(sheath_box.position.z)


# --- Katana sheath shape (docs/specs/katana-visual-rework.md AC1235)

## Whether a point is inside a closed triangle mesh: a ray along +Y crosses its
## surface an odd number of times.
func _is_inside(triangles: TriangleMesh, point: Vector3) -> bool:
	var origin: Vector3 = point
	var crossings: int = 0
	while true:
		var hit: Dictionary = triangles.intersect_ray(origin, Vector3.UP)
		if hit.is_empty():
			break
		crossings += 1
		origin = (hit["position"] as Vector3) + Vector3.UP * 0.00001
	return crossings % 2 == 1


func test_ac696_the_sheathed_blade_stays_inside_the_sheath() -> void:
	var humanoid: LowPolyHumanoid = _samurai_by_hand()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	_equip_sheathe().try_cast()
	_pose(humanoid, SHEATHE_CONFIG.charge_body_clip, 0.0)
	mount.update(1.0)
	var sheath_model: MeshInstance3D = _player.get_sheath().get_node("Model") as MeshInstance3D
	var triangles: TriangleMesh = sheath_model.mesh.generate_triangle_mesh()
	var katana_model: MeshInstance3D = _katana_model()
	var to_sheath: Transform3D = sheath_model.global_transform.affine_inverse() * katana_model.global_transform
	var offsets: Array[Vector3] = [Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD]
	for p: Vector3 in KatanaParts.blade_points(katana_model):
		var s: Vector3 = to_sheath * p
		for offset: Vector3 in offsets:
			var label: String = "blade vertex %s (offset %s)" % [s, offset]
			assert_bool(_is_inside(triangles, s + offset * BLADE_MARGIN)).override_failure_message(label + " is outside the sheath").is_true()
