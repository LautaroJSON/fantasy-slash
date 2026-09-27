extends GdUnitTestSuite
## The Warrior's knight sword and shield, his rest pose and walk, and the
## combo starting from the rest pose (docs/specs/warrior-sword-and-shield.md
## AC747–AC755). Measured in the Visual's space (-Z toward the enemy, +X to the
## character's right).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const KnightBuilder := preload("res://assets/models/weapons/knight_set/tools/build_knight_meshes.gd")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const NO_CRIT_ROLL: float = 0.99
const SAMPLE_STEP: float = 1.0 / 30.0
## AC747: the Warrior's base reach.
const WARRIOR_RANGE: float = 2.0
## AC748: farthest the right hand may be from the sword axis, in meters.
const FIST_AXIS_GAP: float = 0.015
## AC750: hand on the shield grip, in meters.
const GRIP_TOLERANCE: float = 0.001
## AC751: torso capsule radius, least height over the floor and farthest the
## shield center may go behind the back, in meters.
const TORSO_RADIUS: float = 0.16
const FLOOR_GAP: float = 0.03
const BEHIND_BACK: float = 0.15
## AC752: rest pose.
const FACING: float = 15.0
const LEAN: float = 8.0
const HEAD_FACING: float = 12.0
const FEET_GAP_MIN: float = 0.20
const FEET_GAP_MAX: float = 0.35
const LEFT_AHEAD_MAX: float = 0.15
const HAND_RIGHT: float = 0.15
const HAND_LOW: float = 0.7
const HAND_HIGH: float = 1.0
const TIP_RIGHT: float = 0.2
const TIP_FLOOR_GAP: float = 0.05
const BLADE_DOWN_MIN: float = 35.0
const BLADE_DOWN_MAX: float = 50.0
const SHIELD_LEFT: float = -0.25
const SHIELD_TILT: float = 20.0
const SHIELD_TOP_LOW: float = 1.2
const SHIELD_TOP_HIGH: float = 1.5
const SHIELD_FACE: float = 60.0
## AC753: walk.
const WALK_LEAN: float = 10.0
const WALK_BLADE_DOWN: float = 35.0
const WALK_SHIELD_LEFT: float = -0.2
const WALK_SHIELD_TILT: float = 25.0
const WALK_PERIOD: float = 0.6
## AC754: rest pose shared by the clip edges.
const JOINT_DEGREES: float = 0.5
const HIPS_METERS: float = 0.001
const TOLERANCE: float = 0.0001
const SHIELD_MARKERS: Array[String] = ["Center", "Top", "Bottom", "Left", "Right"]

var _player: Player
var _humanoid: LowPolyHumanoid
var _mount: WeaponMount
var _to_visual: Transform3D


func before_test() -> void:
	_spawn(WARRIOR)


func after_test() -> void:
	Session.character_class = null


func _spawn(character_class: CharacterClassData) -> void:
	Session.character_class = character_class
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = auto_free(EnemyRegistry.new())
	add_child(_player)
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	_humanoid.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	(_player.get_node("PlayerAnimator") as PlayerAnimator).set_physics_process(false)
	_mount = _player.get_node("WeaponMount") as WeaponMount
	_to_visual = (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()
	_pose(&"idle", 0.0)


func _pose(clip: StringName, time: float) -> void:
	_humanoid.anim.play(clip, 0.0)
	_humanoid.anim.seek(time, true)
	_mount.update(1.0)


func _point(node: Node3D) -> Vector3:
	return _to_visual * node.global_position


func _basis(node: Node3D) -> Basis:
	return (_to_visual.basis * node.global_basis).orthonormalized()


func _heading_from_front(direction: Vector3) -> float:
	return rad_to_deg(Vector3(direction.x, 0.0, direction.z).angle_to(Vector3.FORWARD))


func _below_horizontal(direction: Vector3) -> float:
	return rad_to_deg(-asin(direction.normalized().y))


func _sword() -> Node3D:
	return _player.get_node("Visual/SwordPivot").get_child(0) as Node3D


func _marker(name: String) -> Vector3:
	return _point(_player.get_shield().get_node(name) as Node3D)


## Distance from a point to the segment a–b.
func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _clip_times(clip_name: StringName) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	var length: float = _humanoid.anim.get_animation(clip_name).length
	var time: float = 0.0
	while time <= length:
		times.append(time)
		time += SAMPLE_STEP
	return times


# --- Reach and grip

func test_ac747_the_warrior_reaches_two_meters() -> void:
	assert_float(WARRIOR.base_stats.attack_range).is_equal_approx(WARRIOR_RANGE, TOLERANCE)

	# Every strike of the combo reaches a Grunt stopped at its own attack range,
	# and the first one really lands (AC212 with the new sword).
	for step: AttackComboStep in WARRIOR.combo.steps:
		assert_float(WARRIOR_RANGE * step.range_multiplier).override_failure_message(String(step.animation)).is_greater_equal(GRUNT_STATS.attack_range)
	var registry: EnemyRegistry = _player.enemy_registry
	add_child(registry)
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = registry
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, -GRUNT_STATS.attack_range), null)
	var health_before: float = enemy.health.current_health
	ComboDriver.drive_by_hand(_player)
	assert_bool(ComboDriver.strike(_player, NO_CRIT_ROLL)).is_true()
	assert_float(enemy.health.current_health).is_less(health_before)


func test_ac748_the_right_hand_holds_the_grip() -> void:
	var grip_front: float = KnightBuilder.FIST_Z - KnightBuilder.GRIP_LENGTH * 0.5
	var grip_back: float = KnightBuilder.FIST_Z + KnightBuilder.GRIP_LENGTH * 0.5
	var poses: Array[Array] = [[&"idle", 0.0]]
	for step: AttackComboStep in WARRIOR.combo.steps:
		poses.append([step.animation, step.hit_start])
	var hand: MeshInstance3D = _humanoid.get_hand_mesh(LowPolyHumanoid.Hand.RIGHT)
	for p: Array in poses:
		_pose(p[0], p[1])
		var local: Vector3 = _sword().global_transform.affine_inverse() * hand.global_position
		var label: String = "%s at %.2f s" % [p[0], p[1]]
		assert_float(Vector2(local.x, local.y).length()).override_failure_message(label).is_less_equal(FIST_AXIS_GAP)
		assert_float(local.z).override_failure_message(label).is_between(grip_front, grip_back)


# --- Shield in the left hand

func test_ac749_the_shield_hangs_from_a_socket_on_the_left_wrist() -> void:
	var weapon: WeaponData = WARRIOR.weapon
	var socket: Node3D = _player.get_shield_socket()
	assert_object(socket).is_not_null()
	assert_object(socket.get_parent()).is_same(_humanoid.get_joint(String(weapon.shield_joint)))
	assert_str(String(weapon.shield_joint)).is_equal("wrist_l")
	assert_object(_player.get_shield().get_parent()).is_same(socket)
	var size: float = _humanoid.global_basis.get_scale().x
	var expected := Transform3D(Basis.from_euler(weapon.shield_rotation), weapon.shield_position)
	var actual: Transform3D = _humanoid.get_joint("wrist_l").global_transform.affine_inverse() * socket.global_transform
	actual = Transform3D(actual.basis.scaled(Vector3.ONE * size), actual.origin * size)
	assert_bool(actual.is_equal_approx(expected)).is_true()
	assert_object(_player.get_sheath()).is_null()
	for other: CharacterClassData in [SAMURAI, BERSERKER]:
		_spawn(other)
		assert_object(_player.get_shield()).override_failure_message(other.title).is_null()
		assert_object(_player.get_shield_socket()).override_failure_message(other.title).is_null()


func test_ac750_the_left_hand_holds_the_shield_in_every_clip() -> void:
	var hand: MeshInstance3D = _humanoid.get_hand_mesh(LowPolyHumanoid.Hand.LEFT)
	var grip: Node3D = _player.get_shield().get_node("Grip") as Node3D
	for clip_name: StringName in _humanoid.anim.get_animation_list():
		for time: float in _clip_times(clip_name):
			_pose(clip_name, time)
			assert_float(_humanoid.left_hand_grip_weight).is_zero()
			var gap: float = hand.global_position.distance_to(grip.global_position)
			assert_float(gap).override_failure_message("%s at %.2f s: %.4f m" % [clip_name, time, gap]).is_less_equal(GRIP_TOLERANCE)


## Also the sword tip stays over the floor (added while implementing, see the spec §11).
func test_ac751_the_shield_stays_out_of_the_body_and_the_floor() -> void:
	for clip_name: StringName in _humanoid.anim.get_animation_list():
		for time: float in _clip_times(clip_name):
			_pose(clip_name, time)
			var hips: Vector3 = _point(_humanoid.get_joint("hips"))
			var neck: Vector3 = _point(_humanoid.get_joint("neck"))
			for marker: String in SHIELD_MARKERS:
				var p: Vector3 = _marker(marker)
				var label: String = "%s at %.2f s, %s" % [clip_name, time, marker]
				assert_float(_segment_distance(p, hips, neck)).override_failure_message(label).is_greater(TORSO_RADIUS)
				assert_float(p.y).override_failure_message(label).is_greater_equal(FLOOR_GAP)
			assert_float(_marker("Center").z).override_failure_message("%s at %.2f s" % [clip_name, time]).is_less_equal(BEHIND_BACK)
			var tip: Vector3 = _point(_sword().get_node("TrailTip") as Node3D)
			assert_float(tip.y).override_failure_message("%s at %.2f s: sword tip" % [clip_name, time]).is_greater_equal(TIP_FLOOR_GAP)


# --- Rest pose and walk

func test_ac752_the_rest_pose_of_the_reference() -> void:
	var torso: Basis = _basis(_humanoid.get_joint("torso"))
	assert_float(_heading_from_front(-torso.z)).is_less_equal(FACING)
	assert_float(rad_to_deg(torso.y.angle_to(Vector3.UP))).is_less_equal(LEAN)
	assert_float(_heading_from_front(-_basis(_humanoid.get_joint("neck")).z)).is_less_equal(HEAD_FACING)
	var ankle_l: Vector3 = _point(_humanoid.get_joint("ankle_l"))
	var ankle_r: Vector3 = _point(_humanoid.get_joint("ankle_r"))
	assert_float(absf(ankle_l.x - ankle_r.x)).is_between(FEET_GAP_MIN, FEET_GAP_MAX)
	assert_float(ankle_r.z - ankle_l.z).is_between(0.0, LEFT_AHEAD_MAX)
	var hand: Vector3 = _point(_humanoid.get_hand_mesh(LowPolyHumanoid.Hand.RIGHT))
	assert_float(hand.x).is_greater_equal(HAND_RIGHT)
	assert_float(hand.y).is_between(HAND_LOW, HAND_HIGH)
	var base: Vector3 = _point(_sword().get_node("TrailBase") as Node3D)
	var tip: Vector3 = _point(_sword().get_node("TrailTip") as Node3D)
	assert_float(_below_horizontal(tip - base)).is_between(BLADE_DOWN_MIN, BLADE_DOWN_MAX)
	assert_float(tip.z).is_less(0.0)
	assert_float(tip.x).is_greater(TIP_RIGHT)
	assert_float(tip.y).is_greater_equal(TIP_FLOOR_GAP)
	assert_float(_marker("Center").x).is_less_equal(SHIELD_LEFT)
	var top: Vector3 = _marker("Top")
	assert_float(rad_to_deg((top - _marker("Bottom")).angle_to(Vector3.UP))).is_less_equal(SHIELD_TILT)
	assert_float(top.y).is_between(SHIELD_TOP_LOW, SHIELD_TOP_HIGH)
	var face: Vector3 = -_basis(_player.get_shield()).z
	assert_float(face.x).is_less(0.0)
	assert_float(face.z).is_less(0.0)
	assert_float(rad_to_deg(face.angle_to(Vector3.FORWARD))).is_less_equal(SHIELD_FACE)


func test_ac753_the_walk_of_the_reference() -> void:
	assert_float(_humanoid.anim.get_animation(&"run").length).is_equal_approx(WALK_PERIOD, TOLERANCE)
	for time: float in _clip_times(&"run"):
		_pose(&"run", time)
		var label: String = "run at %.2f s" % time
		var torso: Basis = _basis(_humanoid.get_joint("torso"))
		assert_float(rad_to_deg(torso.y.angle_to(Vector3.UP))).override_failure_message(label).is_less_equal(WALK_LEAN)
		var base: Vector3 = _point(_sword().get_node("TrailBase") as Node3D)
		var tip: Vector3 = _point(_sword().get_node("TrailTip") as Node3D)
		assert_float(_below_horizontal(tip - base)).override_failure_message(label).is_greater_equal(WALK_BLADE_DOWN)
		assert_float(tip.y).override_failure_message(label).is_greater_equal(TIP_FLOOR_GAP)
		assert_float(_marker("Center").x).override_failure_message(label).is_less_equal(WALK_SHIELD_LEFT)
		var axis: Vector3 = _marker("Top") - _marker("Bottom")
		assert_float(rad_to_deg(axis.angle_to(Vector3.UP))).override_failure_message(label).is_less_equal(WALK_SHIELD_TILT)


# --- Combo from the rest pose

## Joint rotations (degrees) and hips position of the current pose.
func _snapshot() -> Dictionary:
	var shot: Dictionary = {}
	for key: String in ["hips", "torso", "neck", "shoulder_l", "elbow_l", "wrist_l", "shoulder_r", "elbow_r", "wrist_r",
			"hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r"]:
		shot[key] = _humanoid.get_joint(key).rotation_degrees
	shot["hips_pos"] = _humanoid.get_joint("hips").position
	return shot


func _assert_same_pose(shot: Dictionary, rest: Dictionary, label: String) -> void:
	for key: String in rest.keys():
		var delta: Vector3 = shot[key] - rest[key]
		var limit: float = HIPS_METERS if key == "hips_pos" else JOINT_DEGREES
		assert_float(maxf(absf(delta.x), maxf(absf(delta.y), absf(delta.z)))).override_failure_message("%s: %s" % [label, key]).is_less_equal(limit)


func test_ac754_the_combo_starts_and_ends_in_the_rest_pose() -> void:
	_pose(&"idle", 0.0)
	var rest: Dictionary = _snapshot()
	_pose(&"attack_1", 0.0)
	_assert_same_pose(_snapshot(), rest, "attack_1 start")
	var ends: Array[StringName] = [&"run_stop", &"hit", &"jump_land"]
	for step: AttackComboStep in WARRIOR.combo.steps:
		ends.append(step.animation)
	for clip_name: StringName in ends:
		_pose(clip_name, _humanoid.anim.get_animation(clip_name).length)
		_assert_same_pose(_snapshot(), rest, "%s end" % clip_name)


# --- Cleanup

func _files(dir_path: String, found: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		if not sub.begins_with(".") and sub != "docs" and sub != "addons":
			_files(dir_path.path_join(sub), found)
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() in ["gd", "tscn", "tres"]:
			found.append(dir_path.path_join(file))


func test_ac755_the_old_sword_is_gone() -> void:
	var old_name: String = "hop" + "lite"
	var old_scene: String = "weapons/" + "sword.tscn"
	assert_bool(FileAccess.file_exists("res://entities/player/" + old_scene)).is_false()
	assert_bool(DirAccess.dir_exists_absolute("res://assets/models/weapons/%s_sword" % old_name)).is_false()
	for file: String in DirAccess.get_files_at("res://materials/weapons"):
		assert_bool(file.begins_with(old_name)).override_failure_message(file).is_false()
	var found := PackedStringArray()
	_files("res://", found)
	for path: String in found:
		var text: String = FileAccess.get_file_as_string(path)
		assert_bool(text.contains(old_name + "_") or text.contains(old_scene)).override_failure_message(path).is_false()
	var constitution: String = FileAccess.get_file_as_string("res://docs/constitution.md")
	assert_bool(constitution.contains("knight_sword.res") and constitution.contains("knight_shield.res")).is_true()
