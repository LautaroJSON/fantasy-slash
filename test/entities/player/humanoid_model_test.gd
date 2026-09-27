extends GdUnitTestSuite
## The humanoid asset and its use in the player scene, plus the new data
## (docs/specs/humanoid-player-model.md, AC590-AC592, AC607).

const ASSET_DIR: String = "res://assets/models/characters/low_poly_humanoid/"
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const PLAYER_MATERIAL: Material = preload("res://materials/player_material.tres")
const COMBO: AttackComboConfig = preload("res://data/classes/warrior/warrior_combo.tres")
const ANIMATION: PlayerAnimationConfig = preload("res://data/player/player_animation_config.tres")
const HITSTOP: HitstopConfig = preload("res://data/classes/warrior/warrior_hitstop.tres")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
## Designed height of the humanoid at scale 1, in meters (SOURCE.md).
const HUMANOID_HEIGHT: float = 1.35
const TOLERANCE: float = 0.0001

var _player: Player


func before_test() -> void:
	Session.character_class = WARRIOR
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = auto_free(EnemyRegistry.new())
	add_child(_player)


func after_test() -> void:
	Session.character_class = null


func _humanoid() -> LowPolyHumanoid:
	return _player.get_node("Visual/Humanoid") as LowPolyHumanoid


## Body meshes of the humanoid: what hangs from a joint socket (the Warrior's
## shield, docs/specs/warrior-sword-and-shield.md) is not part of the body.
func _meshes(node: Node, found: Array[MeshInstance3D]) -> void:
	for child: Node in node.get_children():
		if child == _player.get_shield_socket():
			continue
		if child is MeshInstance3D:
			found.append(child as MeshInstance3D)
		_meshes(child, found)


func test_ac590_the_asset_lives_in_its_folder_and_loads() -> void:
	for file: String in ["low_poly_humanoid.gd", "humanoid_demo.gd", "SOURCE.md"]:
		assert_bool(FileAccess.file_exists(ASSET_DIR + file)).is_true()
	assert_bool(FileAccess.file_exists("res://low_poly_humanoid.gd")).is_false()
	assert_bool(FileAccess.file_exists("res://humanoid_demo.gd")).is_false()
	assert_object(load(ASSET_DIR + "low_poly_humanoid.gd")).is_not_null()


func test_ac590_clip_lengths_are_unchanged() -> void:
	# Adapted (class-combat-identity.md): the generic clips became per-class
	# profiles; the default (warrior) profile keeps its designed lengths and
	# each strike lasts its step's end_time.
	var expected: Dictionary[String, float] = {
		"idle": 2.0, "run": 0.6, "run_stop": 0.35, "jump_start": 0.18, "jump_air": 0.6,
		"jump_land": 0.28, "hit": 0.35,
	}
	for step: AttackComboStep in WARRIOR.combo.steps:
		expected[String(step.animation)] = step.end_time
	for clip: String in expected:
		assert_float(_humanoid().get_profile_library(WARRIOR.animation_profile).get_animation(clip).length).is_equal_approx(expected[clip], TOLERANCE)


func test_ac591_the_humanoid_replaces_the_capsule() -> void:
	assert_bool(_player.has_node("Visual/Body")).is_false()
	var humanoid: LowPolyHumanoid = _humanoid()
	assert_object(humanoid).is_not_null()
	assert_bool(humanoid.has_sword).is_false()
	assert_object(humanoid.hitbox).is_null()
	var meshes: Array[MeshInstance3D] = []
	_meshes(humanoid, meshes)
	assert_bool(meshes.is_empty()).is_false()
	for mesh: MeshInstance3D in meshes:
		assert_object(mesh.material_override).is_same(PLAYER_MATERIAL)
	assert_that((PLAYER_MATERIAL as StandardMaterial3D).albedo_color).is_equal(Color(1, 1, 1))


func test_ac592_the_capsule_matches_the_scaled_humanoid() -> void:
	var collision: CollisionShape3D = _player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule: CapsuleShape3D = collision.shape as CapsuleShape3D
	assert_object(capsule).is_not_null()
	assert_float(capsule.radius).is_equal_approx(0.4, TOLERANCE)
	assert_float(capsule.height).is_equal_approx(1.8, TOLERANCE)
	assert_float(collision.position.y).is_equal_approx(capsule.height / 2.0, TOLERANCE)
	var humanoid_height: float = HUMANOID_HEIGHT * _humanoid().scale.y
	assert_float(absf(humanoid_height - capsule.height)).is_less_equal(0.1)


func test_ac607_values_live_in_their_resources() -> void:
	# Adapted (class-combat-identity.md): the shared combo and hitstop became
	# per class; the player scene defaults to the warrior's (class-combat-identity.md §3.1).
	assert_object(_player.attack.combo).is_same(COMBO)
	assert_int(COMBO.steps.size()).is_equal(4)
	var clips: Array[String] = ["attack_1", "attack_2", "attack_3", "attack_4"]
	var damage: Array[float] = [0.28, 0.32, 0.32, 0.52]
	var knockback: Array[float] = [0.4, 0.5, 0.6, 1.6]
	for i: int in clips.size():
		assert_str(String(COMBO.steps[i].animation)).is_equal(clips[i])
		assert_float(COMBO.steps[i].damage_multiplier).is_equal_approx(damage[i], TOLERANCE)
		assert_float(COMBO.steps[i].knockback_multiplier).is_equal_approx(knockback[i], TOLERANCE)
	assert_float(COMBO.reference_attack_speed).is_equal_approx(1.2, TOLERANCE)
	assert_float(COMBO.input_buffer).is_equal_approx(0.15, TOLERANCE)
	assert_float(ANIMATION.run_speed_threshold).is_equal_approx(0.5, TOLERANCE)
	assert_float(ANIMATION.weapon_mount_blend).is_equal_approx(0.1, TOLERANCE)
	# Hit lag values live in the combo steps (docs/specs/bdo-combat-feel.md).
	var hitlag: Array[float] = [0.05, 0.06, 0.06, 0.11]
	var shake: Array[float] = [0.15, 0.2, 0.2, 0.35]
	for i: int in clips.size():
		assert_float(COMBO.steps[i].hitlag).is_equal_approx(hitlag[i], TOLERANCE)
		assert_float(COMBO.steps[i].shake_strength).is_equal_approx(shake[i], TOLERANCE)
	assert_float(HITSTOP.enemy_shake_amplitude).is_equal_approx(0.06, TOLERANCE)
