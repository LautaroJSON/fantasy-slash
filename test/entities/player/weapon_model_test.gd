extends GdUnitTestSuite

const SWORD_SCENE: PackedScene = preload("res://entities/player/weapons/knight_sword.tscn")
const SHIELD_SCENE: PackedScene = preload("res://entities/player/weapons/knight_shield.tscn")
const GREATSWORD_SCENE: PackedScene = preload("res://entities/player/weapons/greatsword.tscn")
const SPARTAN_SWORD_SCENE: PackedScene = preload("res://entities/player/weapons/spartan_sword.tscn")
const KNIGHT_SWORD_MODEL: Mesh = preload("res://assets/models/weapons/knight_set/knight_sword.res")
const KNIGHT_SHIELD_MODEL: Mesh = preload("res://assets/models/weapons/knight_set/knight_shield.res")
const KnightBuilder := preload("res://assets/models/weapons/knight_set/tools/build_knight_meshes.gd")
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
const KNIGHT_STEEL: Material = preload("res://materials/weapons/knight_steel_material.tres")
const KNIGHT_DARK_STEEL: Material = preload("res://materials/weapons/knight_dark_steel_material.tres")
const KNIGHT_BRASS: Material = preload("res://materials/weapons/knight_brass_material.tres")
const KNIGHT_LEATHER: Material = preload("res://materials/weapons/knight_leather_material.tres")
const KNIGHT_SWORD_MATERIALS: Array[Material] = [KNIGHT_STEEL, KNIGHT_BRASS, KNIGHT_LEATHER]
const KNIGHT_SHIELD_MATERIALS: Array[Material] = [KNIGHT_DARK_STEEL, KNIGHT_BRASS, KNIGHT_LEATHER, KNIGHT_STEEL]
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
const SWORD_TIP_Z: float = -1.26
const SPARTAN_TIP_Z: float = -1.47
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
## AC694: sheath thickness range, the band where it is measured (weapon z), and
## how much its neck rings stand out of the body, in meters.
const SHEATH_THICKNESS_MIN: float = 0.021
const SHEATH_THICKNESS_MAX: float = 0.023
const SHEATH_BODY_FROM_Z: float = -1.15
const SHEATH_BODY_TO_Z: float = -0.60
const SHEATH_RING_FROM_Z: float = -0.53
const SHEATH_RING_TO_Z: float = -0.29
const SHEATH_RING_OUT: float = 0.0081
const SHEATH_WIDTH_TOLERANCE: float = 0.001
## AC695: end of the sheath, radius of its corners, sharpest turn of its end
## outline and width tolerance at the end.
const SHEATH_END_Z: float = -1.282
const SHEATH_END_TOLERANCE: float = 0.002
const SHEATH_CORNER_RADIUS: float = 0.015
const SHEATH_CORNER_TOLERANCE: float = 0.003
const SHEATH_MAX_TURN_DEGREES: float = 45.0
const SHEATH_END_WIDTH_TOLERANCE: float = 0.002


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


func test_ac203_the_sword_is_the_knight_model_with_shared_materials() -> void:
	_assert_model(SWORD_SCENE, KNIGHT_SWORD_MODEL, KNIGHT_SWORD_MATERIALS)


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
	_assert_tip_and_flat_blade(SPARTAN_SWORD_SCENE, SPARTAN_TIP_Z)


func test_ac209_knight_materials_are_flat_colors() -> void:
	_assert_flat_materials(KNIGHT_SHIELD_MATERIALS)


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


# --- Katana sheath shape (docs/specs/katana-sheath-shape.md)

## Saved sheath vertices in the weapon space, with their source vertices of the
## glb (same order: the generator keeps the vertices of the bone in order).
func _sheath_vertices() -> Array[PackedVector3Array]:
	var model: MeshInstance3D = _model_of(KATANA_SHEATH_SCENE)
	var saved: PackedVector3Array = []
	for p: Vector3 in model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		saved.append(model.transform * p)
	var arrays: Array = KatanaBuilder.source_arrays()
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per_vertex: int = bones.size() / positions.size()
	var source: PackedVector3Array = []
	for i: int in positions.size():
		if KatanaBuilder.main_bone(bones, weights, i, per_vertex) == KatanaBuilder.SHEATH_BONE:
			source.append(model.transform * positions[i])
	return [saved, source]


func test_ac694_the_sheath_is_twice_as_thick_and_as_wide() -> void:
	var vertices: Array[PackedVector3Array] = _sheath_vertices()
	var saved: PackedVector3Array = vertices[0]
	var source: PackedVector3Array = vertices[1]
	assert_int(saved.size()).is_equal(source.size())
	var body_half: float = 0.0
	var ring_half: float = 0.0
	var end_start: float = 0.055 - 1.1 * KatanaBuilder.SHEATH_END_REGION_Y
	for i: int in saved.size():
		var p: Vector3 = saved[i]
		if p.z >= SHEATH_BODY_FROM_Z and p.z <= SHEATH_BODY_TO_Z:
			body_half = maxf(body_half, absf(p.y))
		if p.z >= SHEATH_RING_FROM_Z and p.z <= SHEATH_RING_TO_Z:
			ring_half = maxf(ring_half, absf(p.y))
		# Same width: X does not move outside the end.
		if source[i].z > end_start:
			assert_float(p.x).is_equal_approx(source[i].x, SHEATH_WIDTH_TOLERANCE)
	assert_float(body_half * 2.0).is_between(SHEATH_THICKNESS_MIN, SHEATH_THICKNESS_MAX)
	assert_float(ring_half - body_half).is_equal_approx(SHEATH_RING_OUT, SHEATH_WIDTH_TOLERANCE)


## Distinct outline points (weapon X, Z) of the sheath end, from its outer edge
## to its inner edge, framed by the last station of each edge before the end.
func _sheath_end_outline() -> PackedVector2Array:
	var saved: PackedVector3Array = _sheath_vertices()[0]
	var end_start: float = 0.055 - 1.1 * KatanaBuilder.SHEATH_END_REGION_Y
	var points: Array[Vector2] = []
	for p: Vector3 in saved:
		var q := Vector2(p.x, p.z)
		if points.all(func(o: Vector2) -> bool: return o.distance_to(q) > 0.0001):
			points.append(q)
	var end: Array = points.filter(func(q: Vector2) -> bool: return q.y < end_start)
	end.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x > b.x)
	var body: Array = points.filter(func(q: Vector2) -> bool: return q.y >= end_start)
	body.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	var station: Array[Vector2] = [body[0], body[1]]
	station.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x > b.x)
	var outline: PackedVector2Array = [station[0]]
	outline.append_array(PackedVector2Array(end))
	outline.append(station[1])
	return outline


## Center of the circle through three points.
func _circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d: float = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	var ux: float = (a.length_squared() * (b.y - c.y) + b.length_squared() * (c.y - a.y) + c.length_squared() * (a.y - b.y)) / d
	var uy: float = (a.length_squared() * (c.x - b.x) + b.length_squared() * (a.x - c.x) + c.length_squared() * (b.x - a.x)) / d
	return Vector2(ux, uy)


func test_ac695_the_sheath_end_has_rounded_corners() -> void:
	var outline: PackedVector2Array = _sheath_end_outline()
	var end: PackedVector2Array = outline.slice(1, outline.size() - 1)
	var tip: float = INF
	for q: Vector2 in end:
		tip = minf(tip, q.y)
	assert_float(tip).is_equal_approx(SHEATH_END_Z, SHEATH_END_TOLERANCE)
	# Each half of the end outline is a corner arc.
	var half: int = end.size() / 2
	for corner: PackedVector2Array in [end.slice(0, half), end.slice(half)]:
		var center: Vector2 = _circumcenter(corner[0], corner[corner.size() / 2], corner[corner.size() - 1])
		for q: Vector2 in corner:
			assert_float(q.distance_to(center)).is_equal_approx(SHEATH_CORNER_RADIUS, SHEATH_CORNER_TOLERANCE)
	for i: int in range(1, outline.size() - 1):
		var turn: float = rad_to_deg((outline[i] - outline[i - 1]).angle_to(outline[i + 1] - outline[i]))
		assert_float(absf(turn)).override_failure_message("turn of %.1f° at %s" % [turn, outline[i]]).is_less_equal(SHEATH_MAX_TURN_DEGREES)
	# The width where the arcs end is the width of the sheath before its end.
	var station_width: float = outline[0].x - outline[outline.size() - 1].x
	assert_float(end[0].x - end[end.size() - 1].x).is_equal_approx(station_width, SHEATH_END_WIDTH_TOLERANCE)


# --- Knight sword and shield (docs/specs/warrior-sword-and-shield.md)

## AC744: shield height and width, least rise of the peak, bulge of the face,
## thickest plate and least share of the brass, in meters.
const SHIELD_HEIGHT_MIN: float = 0.78
const SHIELD_HEIGHT_MAX: float = 0.82
const SHIELD_WIDTH_MIN: float = 0.56
const SHIELD_WIDTH_MAX: float = 0.60
const SHIELD_PEAK_RISE: float = 0.08
const SHIELD_BULGE_MIN: float = 0.05
const SHIELD_BULGE_MAX: float = 0.07
const SHIELD_PLATE_MAX: float = 0.02
const BRASS_HEIGHT_SHARE: float = 0.70
const BRASS_WIDTH_SHARE: float = 0.65
## Vertices this close to an x are on that column of the shield.
const COLUMN_EPSILON: float = 0.005
## Brass may sit this much deeper than its sunk base (rounding), in meters.
const BRASS_EPSILON: float = 0.0005
## AC745: generated vs saved vertices, in meters.
const BUILD_TOLERANCE: float = 0.0001
## AC746: sword tip, trail base gap, total length, guard width and grip length.
const KNIGHT_TIP_TOLERANCE: float = 0.03
const KNIGHT_BASE_GAP: float = 0.03
const SWORD_LENGTH_MIN: float = 1.15
const SWORD_LENGTH_MAX: float = 1.25
const GUARD_WIDTH_MIN: float = 0.29
const GUARD_WIDTH_MAX: float = 0.33
const GRIP_LENGTH_MIN: float = 0.15
const GRIP_LENGTH_MAX: float = 0.19


func _vertices(mesh: Mesh, surface: int) -> PackedVector3Array:
	return mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]


func _bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	return box


func test_ac743_the_shield_scene_uses_the_shared_materials_and_markers() -> void:
	_assert_model(SHIELD_SCENE, KNIGHT_SHIELD_MODEL, KNIGHT_SHIELD_MATERIALS)
	var shield: Node3D = auto_free(SHIELD_SCENE.instantiate())
	for marker: String in ["Grip", "Center", "Top", "Bottom", "Left", "Right"]:
		assert_object(shield.get_node_or_null(marker)).override_failure_message(marker).is_instanceof(Marker3D)
	_assert_flat_materials(KNIGHT_SHIELD_MATERIALS)


func test_ac744_the_shield_is_a_curved_heater_with_the_cross_outside() -> void:
	var shield: Node3D = auto_free(SHIELD_SCENE.instantiate())
	var top: Vector3 = (shield.get_node("Top") as Node3D).position
	var bottom: Vector3 = (shield.get_node("Bottom") as Node3D).position
	var left: Vector3 = (shield.get_node("Left") as Node3D).position
	var right: Vector3 = (shield.get_node("Right") as Node3D).position
	assert_float(top.distance_to(bottom)).is_between(SHIELD_HEIGHT_MIN, SHIELD_HEIGHT_MAX)
	assert_float(left.distance_to(right)).is_between(SHIELD_WIDTH_MIN, SHIELD_WIDTH_MAX)
	var plate: PackedVector3Array = _vertices(KNIGHT_SHIELD_MODEL, KnightBuilder.ShieldSurface.DARK_STEEL)
	var box: AABB = _bounds(plate)
	var side_top: float = -INF
	var middle_front: float = INF
	var middle_back: float = -INF
	var side_front: float = INF
	for p: Vector3 in plate:
		if absf(absf(p.x) - box.end.x) < COLUMN_EPSILON:
			side_top = maxf(side_top, p.y)
			side_front = minf(side_front, p.z)
		if absf(p.x) < COLUMN_EPSILON:
			middle_front = minf(middle_front, p.z)
			middle_back = maxf(middle_back, p.z)
	assert_float(box.end.y - side_top).is_greater_equal(SHIELD_PEAK_RISE)
	assert_float(side_front - middle_front).is_between(SHIELD_BULGE_MIN, SHIELD_BULGE_MAX)
	assert_float(middle_back - middle_front).is_less_equal(SHIELD_PLATE_MAX)
	var brass: PackedVector3Array = _vertices(KNIGHT_SHIELD_MODEL, KnightBuilder.ShieldSurface.BRASS)
	for p: Vector3 in brass:
		assert_float(p.z).override_failure_message(str(p)).is_less_equal(KnightBuilder.face_z(p.x) + KnightBuilder.RELIEF_SINK + BRASS_EPSILON)
	var brass_box: AABB = _bounds(brass)
	assert_float(brass_box.size.y).is_greater_equal(BRASS_HEIGHT_SHARE * box.size.y)
	assert_float(brass_box.size.x).is_greater_equal(BRASS_WIDTH_SHARE * box.size.x)


func _assert_same_build(built: ArrayMesh, saved: Mesh) -> void:
	assert_int(built.get_surface_count()).is_equal(saved.get_surface_count())
	for surface: int in saved.get_surface_count():
		var a: Array = built.surface_get_arrays(surface)
		var b: Array = saved.surface_get_arrays(surface)
		var va: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var vb: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
		var na: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var nb: PackedVector3Array = b[Mesh.ARRAY_NORMAL]
		assert_int(va.size()).is_equal(vb.size())
		for i: int in mini(va.size(), vb.size()):
			if va[i].distance_to(vb[i]) > BUILD_TOLERANCE or na[i].distance_to(nb[i]) > BUILD_TOLERANCE:
				fail("surface %d vertex %d differs" % [surface, i])
				return


func test_ac745_the_generator_reproduces_the_knight_meshes() -> void:
	_assert_same_build(KnightBuilder.build_sword(), KNIGHT_SWORD_MODEL)
	_assert_same_build(KnightBuilder.build_shield(), KNIGHT_SHIELD_MODEL)


func test_ac746_the_knight_sword_measures() -> void:
	var sword: Node3D = auto_free(SWORD_SCENE.instantiate())
	assert_float((sword.get_node("TrailTip") as Node3D).position.z).is_equal_approx(SWORD_TIP_Z, KNIGHT_TIP_TOLERANCE)
	assert_float(absf((sword.get_node("TrailBase") as Node3D).position.z - KnightBuilder.guard_front_z())).is_less_equal(KNIGHT_BASE_GAP)
	var model: MeshInstance3D = _model_of(SWORD_SCENE)
	var box: AABB = model.transform * model.mesh.get_aabb()
	assert_float(box.size.z).is_between(SWORD_LENGTH_MIN, SWORD_LENGTH_MAX)
	assert_float(box.size.x).is_between(GUARD_WIDTH_MIN, GUARD_WIDTH_MAX)
	var grip: AABB = _bounds(_vertices(KNIGHT_SWORD_MODEL, KnightBuilder.SwordSurface.LEATHER))
	assert_float(grip.size.z).is_between(GRIP_LENGTH_MIN, GRIP_LENGTH_MAX)
