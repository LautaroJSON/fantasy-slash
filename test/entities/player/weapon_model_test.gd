extends GdUnitTestSuite

const SWORD_SCENE: PackedScene = preload("res://entities/player/weapons/knight_sword.tscn")
const SHIELD_SCENE: PackedScene = preload("res://entities/player/weapons/knight_shield.tscn")
const GREATSWORD_SCENE: PackedScene = preload("res://entities/player/weapons/greatsword.tscn")
const SPARTAN_SWORD_SCENE: PackedScene = preload("res://entities/player/weapons/spartan_sword.tscn")
const KNIGHT_SWORD_MODEL: Mesh = preload("res://assets/models/weapons/knight_set/knight_sword.res")
const KNIGHT_SHIELD_MODEL: Mesh = preload("res://assets/models/weapons/knight_set/knight_shield.res")
const KnightBuilder := preload("res://assets/models/weapons/knight_set/tools/build_knight_meshes.gd")
const SPARTAN_SWORD_MODEL: Mesh = preload("res://assets/models/weapons/spartan_sword/spartan_sword.obj")
const KNIGHT_GREATSWORD_MODEL: Mesh = preload("res://assets/models/weapons/knight_set/knight_greatsword.res")
const KATANA_SCENE: PackedScene = preload("res://entities/player/weapons/katana.tscn")
const SAMURAI_STATS: PlayerStats = preload("res://data/classes/samurai/samurai_stats.tres")
const KATANA_SWING: SwordSwingConfig = preload("res://data/classes/samurai/katana_swing_config.tres")
const KatanaParts := preload("res://test/helpers/katana_parts.gd")
const KNIGHT_STEEL: Material = preload("res://materials/weapons/knight_steel_material.tres")
const KNIGHT_DARK_STEEL: Material = preload("res://materials/weapons/knight_dark_steel_material.tres")
const KNIGHT_BRASS: Material = preload("res://materials/weapons/knight_brass_material.tres")
const KNIGHT_LEATHER: Material = preload("res://materials/weapons/knight_leather_material.tres")
const KNIGHT_SWORD_MATERIALS: Array[Material] = [KNIGHT_STEEL, KNIGHT_BRASS, KNIGHT_LEATHER]
const KNIGHT_SHIELD_MATERIALS: Array[Material] = [KNIGHT_DARK_STEEL, KNIGHT_BRASS, KNIGHT_LEATHER, KNIGHT_STEEL]
const KNIGHT_GREATSWORD_MATERIALS: Array[Material] = [KNIGHT_DARK_STEEL, KNIGHT_STEEL, KNIGHT_BRASS, KNIGHT_LEATHER]
const SPARTAN_MATERIALS: Array[Material] = [
	preload("res://materials/weapons/spartan_iron_material.tres"),
	preload("res://materials/weapons/spartan_handle_material.tres"),
	preload("res://materials/weapons/spartan_trim_material.tres"),
]
const SWORD_TIP_Z: float = -1.26
const SPARTAN_TIP_Z: float = -1.47
const GREATSWORD_TIP_Z: float = -2.21
const KATANA_TIP_Z: float = -1.27
const TIP_TOLERANCE: float = 0.05
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


func test_ac203_the_sword_is_the_knight_model_with_shared_materials() -> void:
	_assert_model(SWORD_SCENE, KNIGHT_SWORD_MODEL, KNIGHT_SWORD_MATERIALS)


func test_ac204_the_greatsword_is_the_knight_model_with_shared_materials() -> void:
	_assert_model(GREATSWORD_SCENE, KNIGHT_GREATSWORD_MODEL, KNIGHT_GREATSWORD_MATERIALS)


func test_ac205_the_models_keep_the_previous_reach() -> void:
	_assert_tip_and_flat_blade(SWORD_SCENE, SWORD_TIP_Z)
	_assert_tip_and_flat_blade(GREATSWORD_SCENE, GREATSWORD_TIP_Z)


func test_ac206_weapon_materials_are_flat_colors() -> void:
	_assert_flat_materials(SPARTAN_MATERIALS)
	_assert_flat_materials(KNIGHT_GREATSWORD_MATERIALS)


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


func test_ac237_the_katana_tip_and_trail_markers() -> void:
	var mesh_instance: MeshInstance3D = _model_of(KATANA_SCENE)
	var bounds: AABB = mesh_instance.transform * mesh_instance.mesh.get_aabb()
	assert_float(bounds.position.z).is_equal_approx(KATANA_TIP_Z, TIP_TOLERANCE)
	_assert_trail_markers(KATANA_SCENE)


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
	# AC1010: and the greatsword (docs/specs/berserker-greatsword.md).
	_assert_same_build(KnightBuilder.build_greatsword(), KNIGHT_GREATSWORD_MODEL)


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


# --- Knight greatsword (docs/specs/berserker-greatsword.md)

## AC1006: trail and off-hand markers.
const GS_TRAIL_BASE_Z: float = -0.77
const GS_OFF_HAND_Z: float = -0.1
const GS_TIP_TOLERANCE: float = 0.03
const MARKER_TOLERANCE: float = 0.001
## AC1007: forge mark height and its span in front of the guard, in meters.
const GS_MARK_HEIGHT_MIN: float = 0.15
const GS_MARK_HEIGHT_MAX: float = 0.22
const GS_MARK_NEAR: float = 0.03
const GS_MARK_FAR: float = 0.30
## AC1008: blade width, flat thickness, edge thickness, bevel band and the
## least shift of the point, in meters.
const GS_WIDTH_MIN: float = 0.28
const GS_WIDTH_MAX: float = 0.32
const GS_WIDTH_TOLERANCE: float = 0.01
const GS_THICKNESS_MIN: float = 0.025
const GS_THICKNESS_MAX: float = 0.035
const GS_EDGE_MAX: float = 0.002
const GS_BEVEL_MIN: float = 0.03
const GS_BEVEL_MAX: float = 0.05
const GS_POINT_SHIFT: float = 0.04
## AC1009: grip length, right fist, guard width and total length, in meters.
const GS_GRIP_MIN: float = 0.38
const GS_GRIP_MAX: float = 0.46
const GS_RIGHT_FIST_Z: float = 0.133
const GS_GUARD_MIN: float = 0.33
const GS_GUARD_MAX: float = 0.39
const GS_LENGTH_MIN: float = 2.4
const GS_LENGTH_MAX: float = 2.6
## Vertices this close to the blade edge are on the edge.
const EDGE_EPSILON: float = 0.001


func _greatsword_vertices(surface: int) -> PackedVector3Array:
	return _vertices(KNIGHT_GREATSWORD_MODEL, surface)


func test_ac1006_the_greatsword_scene_uses_the_knight_materials_and_markers() -> void:
	_assert_model(GREATSWORD_SCENE, KNIGHT_GREATSWORD_MODEL, KNIGHT_GREATSWORD_MATERIALS)
	var greatsword: Node3D = auto_free(GREATSWORD_SCENE.instantiate())
	assert_float((greatsword.get_node("TrailBase") as Node3D).position.z).is_equal_approx(GS_TRAIL_BASE_Z, MARKER_TOLERANCE)
	assert_float((greatsword.get_node("TrailTip") as Node3D).position.z).is_equal_approx(GREATSWORD_TIP_Z, GS_TIP_TOLERANCE)
	assert_float((greatsword.get_node("OffHand") as Node3D).position.z).is_equal_approx(GS_OFF_HAND_Z, MARKER_TOLERANCE)


func test_ac1007_the_greatsword_bears_the_forge_mark_on_both_flats() -> void:
	var guard_front: float = KnightBuilder.gs_guard_front_z()
	for side: float in [1.0, -1.0]:
		var mark := PackedVector3Array()
		for p: Vector3 in _greatsword_vertices(KnightBuilder.GreatswordSurface.BRASS):
			if p.z < guard_front - EDGE_EPSILON and absf(p.x) < KnightBuilder.GS_FLAT_HALF_WIDTH and p.y * side > KnightBuilder.GS_FLAT_HALF_THICKNESS * 0.5:
				mark.append(p)
		assert_bool(mark.is_empty()).override_failure_message("side %d" % side).is_false()
		if mark.is_empty():
			continue
		var box: AABB = _bounds(mark)
		assert_float(box.size.z).is_between(GS_MARK_HEIGHT_MIN, GS_MARK_HEIGHT_MAX)
		assert_float(guard_front - box.end.z).is_greater_equal(GS_MARK_NEAR)
		assert_float(guard_front - box.position.z).is_less_equal(GS_MARK_FAR)


func test_ac1008_the_greatsword_blade_is_a_wide_bevelled_slab() -> void:
	var shoulder_z: float = GREATSWORD_TIP_Z + KnightBuilder.GS_POINT_LENGTH
	var flat: PackedVector3Array = _greatsword_vertices(KnightBuilder.GreatswordSurface.DARK_STEEL)
	var bevel: PackedVector3Array = _greatsword_vertices(KnightBuilder.GreatswordSurface.STEEL)
	# Width along the straight part (guard to the start of the point).
	var widths: Dictionary = {}
	for p: Vector3 in bevel:
		if p.z >= shoulder_z - EDGE_EPSILON:
			var key: int = roundi(p.z * 1000.0)
			var span: Vector2 = widths.get(key, Vector2(INF, -INF))
			widths[key] = Vector2(minf(span.x, p.x), maxf(span.y, p.x))
	var least: float = INF
	var most: float = -INF
	for span: Vector2 in widths.values():
		least = minf(least, span.y - span.x)
		most = maxf(most, span.y - span.x)
	assert_float(least).is_between(GS_WIDTH_MIN, GS_WIDTH_MAX)
	assert_float(most - least).is_less_equal(GS_WIDTH_TOLERANCE)
	var flat_box: AABB = _bounds(flat)
	assert_float(flat_box.size.y).is_between(GS_THICKNESS_MIN, GS_THICKNESS_MAX)
	var edge_x: float = _bounds(bevel).end.x
	for p: Vector3 in bevel:
		if absf(absf(p.x) - edge_x) < EDGE_EPSILON:
			assert_float(absf(p.y) * 2.0).override_failure_message(str(p)).is_less_equal(GS_EDGE_MAX)
	assert_float(edge_x - flat_box.end.x).is_between(GS_BEVEL_MIN, GS_BEVEL_MAX)
	var tip := Vector3(0, 0, INF)
	for p: Vector3 in bevel:
		if p.z < tip.z:
			tip = p
	assert_float(tip.x).is_less_equal(-GS_POINT_SHIFT)


func test_ac1009_the_greatsword_hilt_fits_both_hands() -> void:
	var grip: AABB = _bounds(_greatsword_vertices(KnightBuilder.GreatswordSurface.LEATHER))
	assert_float(grip.size.z).is_between(GS_GRIP_MIN, GS_GRIP_MAX)
	for z: float in [GS_RIGHT_FIST_Z, GS_OFF_HAND_Z]:
		assert_float(z).is_between(grip.position.z, grip.end.z)
	var guard_front: float = KnightBuilder.gs_guard_front_z()
	var guard := PackedVector3Array()
	var brass: PackedVector3Array = _greatsword_vertices(KnightBuilder.GreatswordSurface.BRASS)
	for p: Vector3 in brass:
		if p.z >= guard_front - EDGE_EPSILON and p.z <= grip.position.z + EDGE_EPSILON:
			guard.append(p)
	assert_float(_bounds(guard).size.x).is_between(GS_GUARD_MIN, GS_GUARD_MAX)
	var rear: float = -INF
	for surface: int in KNIGHT_GREATSWORD_MODEL.get_surface_count():
		if surface != KnightBuilder.GreatswordSurface.BRASS:
			rear = maxf(rear, _bounds(_greatsword_vertices(surface)).end.z)
	assert_float(_bounds(brass).end.z).is_greater(rear)
	assert_float(KNIGHT_GREATSWORD_MODEL.get_aabb().size.z).is_between(GS_LENGTH_MIN, GS_LENGTH_MAX)
