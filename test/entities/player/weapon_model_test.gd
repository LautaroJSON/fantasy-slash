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
