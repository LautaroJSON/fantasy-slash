extends GdUnitTestSuite
## Toon shading and rim light of the player, weapons and enemies
## (docs/specs/stage-lighting-sky.md, AC1386–AC1387).

const PLAYER: String = "res://materials/player_material.tres"
const FALLBACK_ENEMY: String = "res://materials/enemy_material.tres"
const WEAPONS_DIR: String = "res://materials/weapons/"
const ENEMIES_DIR: String = "res://materials/enemies/"


## Lit StandardMaterial3D files of a folder: overlays (unshaded), glows (emissive)
## and ShaderMaterials keep their own look.
func _lit_materials(dir: String) -> Array[StandardMaterial3D]:
	var result: Array[StandardMaterial3D] = []
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".tres") or file.contains("overlay") or file.contains("glow"):
			continue
		var material: StandardMaterial3D = load(dir + file) as StandardMaterial3D
		if material != null:
			result.append(material)
	return result


func _assert_toon_with_rim(material: StandardMaterial3D, specular: BaseMaterial3D.SpecularMode = BaseMaterial3D.SPECULAR_TOON) -> void:
	var name: String = material.resource_path
	assert_int(material.diffuse_mode).override_failure_message(name).is_equal(BaseMaterial3D.DIFFUSE_TOON)
	assert_int(material.specular_mode).override_failure_message(name).is_equal(specular)
	assert_bool(material.rim_enabled).override_failure_message(name).is_true()
	assert_float(material.rim).override_failure_message(name).is_greater(0.0)


func test_ac1386_the_player_weapons_and_enemies_are_toon_with_a_rim_light() -> void:
	# The white body has no specular: with a toon highlight and a white rim it blew out (see the spec, step 6 notes).
	_assert_toon_with_rim(load(PLAYER) as StandardMaterial3D, BaseMaterial3D.SPECULAR_DISABLED)
	_assert_toon_with_rim(load(FALLBACK_ENEMY) as StandardMaterial3D)
	var weapons: Array[StandardMaterial3D] = _lit_materials(WEAPONS_DIR)
	var enemies: Array[StandardMaterial3D] = _lit_materials(ENEMIES_DIR)
	assert_int(weapons.size()).is_greater(10)
	assert_int(enemies.size()).is_greater(15)
	for material: StandardMaterial3D in weapons + enemies:
		_assert_toon_with_rim(material)


func test_ac1386_emissive_and_unshaded_materials_keep_their_look() -> void:
	for file: String in DirAccess.get_files_at(ENEMIES_DIR):
		if file.contains("glow"):
			assert_bool((load(ENEMIES_DIR + file) as StandardMaterial3D).rim_enabled).override_failure_message(file).is_false()
	for file: String in DirAccess.get_files_at(WEAPONS_DIR):
		if file.contains("overlay"):
			assert_int((load(WEAPONS_DIR + file) as StandardMaterial3D).shading_mode).override_failure_message(file).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)


func test_ac1387_no_enemy_rim_light_is_pure_white() -> void:
	var enemies: Array[StandardMaterial3D] = _lit_materials(ENEMIES_DIR)
	enemies.append(load(FALLBACK_ENEMY) as StandardMaterial3D)
	for material: StandardMaterial3D in enemies:
		assert_float(material.rim_tint).override_failure_message(material.resource_path).is_greater(0.0)
