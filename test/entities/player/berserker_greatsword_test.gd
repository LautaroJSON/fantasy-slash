extends GdUnitTestSuite
## The Berserker's knight greatsword (docs/specs/berserker-greatsword.md
## AC1011–AC1013): its wide blade stays out of the body by both edges, the
## reach is kept and the old greatsword model is gone.

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const KnightBuilder := preload("res://assets/models/weapons/knight_set/tools/build_knight_meshes.gd")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const SAMPLE_STEP: float = 1.0 / 30.0
## Points checked along each edge.
const EDGE_SAMPLES: int = 16
## Torso and head volumes of AC653 (class_combat_identity_test), in the
## joints' unscaled space.
const TORSO_BOTTOM: float = -0.16
const TORSO_TOP: float = 0.372
const TORSO_HALF_WIDTH: float = 0.131
const TORSO_HALF_DEPTH: float = 0.08
const HEAD_CENTER: Vector3 = Vector3(0.0, 0.21, 0.0)
const HEAD_RADIUS: float = 0.2
## AC1012: the Berserker's base reach, and AC211's tolerance.
const BERSERKER_RANGE: float = 3.0
const REACH_TOLERANCE: float = 0.05
const TOLERANCE: float = 0.0001

var _player: Player
var _humanoid: LowPolyHumanoid


func before_test() -> void:
	Session.character_class = BERSERKER
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = auto_free(EnemyRegistry.new())
	add_child(_player)
	ComboDriver.drive_by_hand(_player)
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid


func after_test() -> void:
	Session.character_class = null


func _weapon() -> Node3D:
	return _player.get_node("Visual/SwordPivot").get_child(0) as Node3D


## Where a point is inside the torso or the head, or "".
func _inside_body(point: Vector3) -> String:
	var local: Vector3 = _humanoid.get_joint("torso").global_transform.affine_inverse() * point
	var ellipse: float = pow(local.x / TORSO_HALF_WIDTH, 2.0) + pow(local.z / TORSO_HALF_DEPTH, 2.0)
	if local.y >= TORSO_BOTTOM and local.y <= TORSO_TOP and ellipse < 1.0:
		return "torso"
	if (_humanoid.get_joint("neck").global_transform.affine_inverse() * point).distance_to(HEAD_CENTER) < HEAD_RADIUS:
		return "head"
	return ""


func test_ac1011_the_edges_never_go_through_the_body() -> void:
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	var from_z: float = KnightBuilder.gs_guard_front_z()
	var to_z: float = KnightBuilder.GS_TIP_Z + KnightBuilder.GS_POINT_LENGTH
	for clip_name: StringName in _humanoid.anim.get_animation_list():
		var length: float = _humanoid.anim.get_animation(clip_name).length
		var time: float = 0.0
		while time <= length:
			_humanoid.anim.play(clip_name, 0.0)
			_humanoid.anim.seek(time, true)
			mount.update(1.0)
			var weapon: Transform3D = _weapon().global_transform
			for side: float in [1.0, -1.0]:
				for i: int in EDGE_SAMPLES + 1:
					var z: float = lerpf(from_z, to_z, float(i) / EDGE_SAMPLES)
					var inside: String = _inside_body(weapon * Vector3(side * KnightBuilder.GS_BLADE_HALF_WIDTH, 0.0, z))
					assert_str(inside).override_failure_message("%s at %.2f s: the %s edge goes through the %s at z = %.2f" % [clip_name, time, "+X" if side > 0.0 else "-X", inside, z]).is_empty()
			time += SAMPLE_STEP


func test_ac1012_the_reach_is_kept() -> void:
	assert_float(BERSERKER.base_stats.attack_range).is_equal_approx(BERSERKER_RANGE, TOLERANCE)
	var weapon: WeaponData = BERSERKER.weapon
	var model: MeshInstance3D = _weapon().get_node("Model") as MeshInstance3D
	var bounds: AABB = model.transform * model.mesh.get_aabb()
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	var radius: float = ((enemy.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D).radius
	var expected: float = weapon.swing.hilt_offset + absf(bounds.position.z) * cos(weapon.swing.blade_tilt) + radius
	assert_float(BERSERKER.base_stats.attack_range).is_equal_approx(expected, REACH_TOLERANCE)


func test_ac1013_the_old_model_is_gone() -> void:
	var old_name: String = "fal" + "chion"
	assert_bool(DirAccess.dir_exists_absolute("res://assets/models/weapons/" + old_name)).is_false()
	for file: String in DirAccess.get_files_at("res://materials/weapons"):
		assert_bool(file.begins_with(old_name)).override_failure_message(file).is_false()
	var found := PackedStringArray()
	_files("res://", found)
	for path: String in found:
		assert_bool(FileAccess.get_file_as_string(path).contains(old_name)).override_failure_message(path).is_false()
	var constitution: String = FileAccess.get_file_as_string("res://docs/constitution.md")
	assert_bool(constitution.contains("knight_greatsword.res")).is_true()


func _files(dir_path: String, found: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		if not sub.begins_with(".") and sub != "docs" and sub != "addons":
			_files(dir_path.path_join(sub), found)
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() in ["gd", "tscn", "tres"]:
			found.append(dir_path.path_join(file))
