extends GdUnitTestSuite

const SWORD_SCENE: PackedScene = preload("res://entities/player/weapons/sword.tscn")
const GREATSWORD_SCENE: PackedScene = preload("res://entities/player/weapons/greatsword.tscn")
const SPARTAN_SWORD_SCENE: PackedScene = preload("res://entities/player/weapons/spartan_sword.tscn")
const HOPLITE_SWORD_MODEL: Mesh = preload("res://assets/models/weapons/hoplite_sword/hoplite_sword.obj")
const SPARTAN_SWORD_MODEL: Mesh = preload("res://assets/models/weapons/spartan_sword/spartan_sword.obj")
const FALCHION_MODEL: Mesh = preload("res://assets/models/weapons/falchion/falchion.obj")
const KATANA_SCENE: PackedScene = preload("res://entities/player/weapons/katana.tscn")
const KATANA_SHEATH_SCENE: PackedScene = preload("res://entities/player/weapons/katana_sheath.tscn")
const KATANA_BLADE_MODEL: Mesh = preload("res://assets/models/weapons/katana/katana_blade.res")
const KATANA_SHEATH_MODEL: Mesh = preload("res://assets/models/weapons/katana/katana_sheath.res")
const KATANA_MATERIAL: StandardMaterial3D = preload("res://materials/weapons/katana_material.tres")
const KATANA_ASSET_DIR: String = "res://assets/models/weapons/katana/"
const KatanaBuilder := preload("res://assets/models/weapons/katana/tools/build_katana_meshes.gd")
const SAMURAI_STATS: PlayerStats = preload("res://data/classes/samurai/samurai_stats.tres")
const KATANA_SWING: SwordSwingConfig = preload("res://data/classes/samurai/katana_swing_config.tres")
const KatanaParts := preload("res://test/helpers/katana_parts.gd")
const HOPLITE_MATERIALS: Array[Material] = [
	preload("res://materials/weapons/hoplite_iron_material.tres"),
	preload("res://materials/weapons/hoplite_handle_material.tres"),
	preload("res://materials/weapons/hoplite_trim_material.tres"),
]
const SPARTAN_MATERIALS: Array[Material] = [
	preload("res://materials/weapons/spartan_iron_material.tres"),
	preload("res://materials/weapons/spartan_handle_material.tres"),
	preload("res://materials/weapons/spartan_trim_material.tres"),
]
const FALCHION_MATERIALS: Array[Material] = [
	preload("res://materials/weapons/falchion_iron_material.tres"),
	preload("res://materials/weapons/falchion_handle_material.tres"),
	preload("res://materials/weapons/falchion_trim_material.tres"),
]
const SWORD_TIP_Z: float = -1.47
const GREATSWORD_TIP_Z: float = -2.21
const KATANA_TIP_Z: float = -1.27
const TIP_TOLERANCE: float = 0.05
## AC683: handle length and least section, guard diameter and greatest
## thickness, in meters.
const HANDLE_LENGTH_MIN: float = 0.29
const HANDLE_LENGTH_MAX: float = 0.33
const HANDLE_SECTION_MIN: float = 0.045
const GUARD_DIAMETER_MIN: float = 0.16
const GUARD_DIAMETER_MAX: float = 0.185
const GUARD_THICKNESS_MAX: float = 0.035
## AC686: attack reach kept, and farthest the trail base may be from the guard.
const SAMURAI_ATTACK_RANGE: float = 2.3
const KATANA_HILT_OFFSET: float = 0.35
const TRAIL_BASE_GAP: float = 0.05


func _model_of(scene: PackedScene) -> MeshInstance3D:
	var weapon: Node3D = auto_free(scene.instantiate())
	var mesh_count: int = 0
	for child: Node in weapon.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	assert_int(mesh_count).is_equal(1)
	return weapon.get_node("Model") as MeshInstance3D


func _assert_model(scene: PackedScene, model: Mesh, materials: Array[Material]) -> void:
	var mesh_instance: MeshInstance3D = _model_of(scene)
	assert_object(mesh_instance.mesh).is_same(model)
	assert_int(mesh_instance.mesh.get_surface_count()).is_equal(materials.size())
	for surface: int in materials.size():
		assert_object(mesh_instance.get_surface_override_material(surface)).is_same(materials[surface])


func _assert_tip_and_flat_blade(scene: PackedScene, tip_z: float) -> void:
	var mesh_instance: MeshInstance3D = _model_of(scene)
	var bounds: AABB = mesh_instance.transform * mesh_instance.mesh.get_aabb()
	assert_float(bounds.position.z).is_equal_approx(tip_z, TIP_TOLERANCE)
	assert_float(bounds.size.x).is_greater(bounds.size.y)


func _assert_flat_materials(materials: Array[Material]) -> void:
	for material: Material in materials:
		assert_object(material).is_instanceof(StandardMaterial3D)
		assert_object((material as StandardMaterial3D).albedo_texture).is_null()


func test_ac203_the_sword_is_the_hoplite_model_with_shared_materials() -> void:
	_assert_model(SWORD_SCENE, HOPLITE_SWORD_MODEL, HOPLITE_MATERIALS)


func test_ac204_the_greatsword_is_the_falchion_model_with_shared_materials() -> void:
	_assert_model(GREATSWORD_SCENE, FALCHION_MODEL, FALCHION_MATERIALS)


func test_ac205_the_models_keep_the_previous_reach() -> void:
	_assert_tip_and_flat_blade(SWORD_SCENE, SWORD_TIP_Z)
	_assert_tip_and_flat_blade(GREATSWORD_SCENE, GREATSWORD_TIP_Z)


func test_ac206_weapon_materials_are_flat_colors() -> void:
	_assert_flat_materials(SPARTAN_MATERIALS)
	_assert_flat_materials(FALCHION_MATERIALS)


func test_ac208_the_spartan_sword_stays_available_as_its_own_scene() -> void:
	_assert_model(SPARTAN_SWORD_SCENE, SPARTAN_SWORD_MODEL, SPARTAN_MATERIALS)
	_assert_tip_and_flat_blade(SPARTAN_SWORD_SCENE, SWORD_TIP_Z)


func test_ac209_hoplite_materials_are_flat_colors() -> void:
	_assert_flat_materials(HOPLITE_MATERIALS)


func _assert_trail_markers(scene: PackedScene) -> void:
	var weapon: Node3D = auto_free(scene.instantiate())
	var mesh_instance: MeshInstance3D = weapon.get_node("Model") as MeshInstance3D
	var base: Marker3D = weapon.get_node("TrailBase") as Marker3D
	var tip: Marker3D = weapon.get_node("TrailTip") as Marker3D
	assert_object(base).is_not_null()
	assert_object(tip).is_not_null()
	var bounds: AABB = mesh_instance.transform * mesh_instance.mesh.get_aabb()
	assert_float(tip.position.z).is_equal_approx(bounds.position.z, TIP_TOLERANCE)
	assert_float(base.position.z).is_greater(tip.position.z)


func test_ac214_every_weapon_has_blade_markers_for_the_trail() -> void:
	_assert_trail_markers(SWORD_SCENE)
	_assert_trail_markers(SPARTAN_SWORD_SCENE)
	_assert_trail_markers(GREATSWORD_SCENE)


func test_ac237_the_katana_and_its_sheath_use_the_textured_katana_material() -> void:
	var material: Array[Material] = [KATANA_MATERIAL]
	_assert_model(KATANA_SCENE, KATANA_BLADE_MODEL, material)
	_assert_model(KATANA_SHEATH_SCENE, KATANA_SHEATH_MODEL, material)
	assert_object(KATANA_MATERIAL.albedo_texture).is_not_null()
	assert_str(KATANA_MATERIAL.albedo_texture.resource_path).starts_with(KATANA_ASSET_DIR)


func test_ac237_the_katana_tip_and_trail_markers() -> void:
	var mesh_instance: MeshInstance3D = _model_of(KATANA_SCENE)
	var bounds: AABB = mesh_instance.transform * mesh_instance.mesh.get_aabb()
	assert_float(bounds.position.z).is_equal_approx(KATANA_TIP_Z, TIP_TOLERANCE)
	_assert_trail_markers(KATANA_SCENE)


# --- Katana proportions (docs/specs/katana-hand-proportions.md)

func test_ac683_the_katana_handle_and_guard_match_the_hand() -> void:
	var model: MeshInstance3D = _model_of(KATANA_SCENE)
	var guard: AABB = KatanaParts.bounds(KatanaParts.guard_points(model))
	var handle: AABB = KatanaParts.bounds(KatanaParts.handle_points(model))
	# From the back face of the guard to the pommel end.
	var handle_length: float = handle.end.z - guard.end.z
	assert_float(handle_length).is_between(HANDLE_LENGTH_MIN, HANDLE_LENGTH_MAX)
	assert_float(handle.size.x).is_greater_equal(HANDLE_SECTION_MIN)
	assert_float(guard.size.x).is_between(GUARD_DIAMETER_MIN, GUARD_DIAMETER_MAX)
	assert_float(guard.size.y).is_between(GUARD_DIAMETER_MIN, GUARD_DIAMETER_MAX)
	assert_float(guard.size.z).is_less_equal(GUARD_THICKNESS_MAX)
	var bounds: AABB = model.transform * model.mesh.get_aabb()
	assert_float(bounds.position.z).is_equal_approx(KATANA_TIP_Z, TIP_TOLERANCE)


func test_ac686_the_katana_keeps_its_reach_and_the_trail_starts_at_the_guard() -> void:
	assert_float(SAMURAI_STATS.attack_range).is_equal_approx(SAMURAI_ATTACK_RANGE, 0.0001)
	assert_float(KATANA_SWING.hilt_offset).is_equal_approx(KATANA_HILT_OFFSET, 0.0001)
	var weapon: Node3D = auto_free(KATANA_SCENE.instantiate())
	var guard: AABB = KatanaParts.bounds(KatanaParts.guard_points(weapon.get_node("Model") as MeshInstance3D))
	var base: float = (weapon.get_node("TrailBase") as Node3D).position.z
	# In front of the guard (toward the tip, -Z), close to its front face.
	assert_float(base).is_less(guard.position.z)
	assert_float(guard.position.z - base).is_less_equal(TRAIL_BASE_GAP)
	_assert_trail_markers(KATANA_SCENE)


## Source vertices of one bone of katana.glb, in their original order.
func _source_part(bone: int) -> Dictionary:
	var arrays: Array = KatanaBuilder.source_arrays()
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per_vertex: int = bones.size() / positions.size()
	var part_uvs: PackedVector2Array = []
	var in_part: Array[bool] = []
	for i: int in positions.size():
		in_part.append(KatanaBuilder.main_bone(bones, weights, i, per_vertex) == bone)
		if in_part[i]:
			part_uvs.append(uvs[i])
	var index_count: int = 0
	for t: int in indices.size() / 3:
		if in_part[indices[t * 3]] and in_part[indices[t * 3 + 1]] and in_part[indices[t * 3 + 2]]:
			index_count += 3
	return {"uvs": part_uvs, "index_count": index_count}


func _assert_same_mesh(built: ArrayMesh, saved: Mesh) -> void:
	var a: Array = built.surface_get_arrays(0)
	var b: Array = saved.surface_get_arrays(0)
	assert_array(b[Mesh.ARRAY_INDEX]).is_equal(a[Mesh.ARRAY_INDEX])
	var pa: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var pb: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	assert_int(pb.size()).is_equal(pa.size())
	for i: int in pa.size():
		assert_vector(pb[i]).is_equal_approx(pa[i], Vector3.ONE * 0.00001)


func test_ac688_the_derived_katana_meshes_keep_the_source_topology_and_are_reproducible() -> void:
	var parts: Array = [[KatanaBuilder.BLADE_BONE, KATANA_BLADE_MODEL], [KatanaBuilder.SHEATH_BONE, KATANA_SHEATH_MODEL]]
	for part: Array in parts:
		var source: Dictionary = _source_part(part[0])
		var mesh: Mesh = part[1]
		var arrays: Array = mesh.surface_get_arrays(0)
		assert_array(arrays[Mesh.ARRAY_TEX_UV]).is_equal(source["uvs"])
		assert_int((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()).is_equal(source["index_count"])
		_assert_same_mesh(KatanaBuilder.build(part[0]), mesh)
	var source_md: String = FileAccess.get_file_as_string(KATANA_ASSET_DIR + "SOURCE.md")
	assert_str(source_md).contains("build_katana_meshes.gd")
