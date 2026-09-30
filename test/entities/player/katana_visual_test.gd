extends GdUnitTestSuite
## The generated katana and its sheath (docs/specs/katana-visual-rework.md AC1231–AC1239).
## AC1240 (the hilt never goes through the body) is in class_combat_identity_test.gd
## and the sheathed blade inside its sheath (AC1235) in sheath_grip_test.gd.

const KATANA_SCENE: PackedScene = preload("res://entities/player/weapons/katana.tscn")
const KATANA_SHEATH_SCENE: PackedScene = preload("res://entities/player/weapons/katana_sheath.tscn")
const BLADE_MODEL: Mesh = preload("res://assets/models/weapons/katana/katana_blade.res")
const SHEATH_MODEL: Mesh = preload("res://assets/models/weapons/katana/katana_sheath.res")
const KatanaBuilder := preload("res://assets/models/weapons/katana/tools/build_katana_meshes.gd")
const KatanaParts := preload("res://test/helpers/katana_parts.gd")
const ASSET_DIR: String = "res://assets/models/weapons/katana/"
const MATERIAL_DIR: String = "res://materials/weapons/"
const OVERLAY: Material = preload("res://materials/weapons/katana_empowered_overlay.tres")
const BLADE_MATERIALS: Array[String] = ["katana_steel", "katana_hamon", "katana_iron", "katana_gold", "katana_tsuka", "katana_tsuka_relief"]
const SHEATH_MATERIALS: Array[String] = ["katana_lacquer", "katana_lacquer_red", "katana_gold", "katana_sageo"]
## AC1237: albedo of each material (spec §2.1) and the tolerance.
const COLORS: Dictionary[String, Color] = {
	"katana_steel": Color(0.62, 0.68, 0.75),
	"katana_hamon": Color(0.93, 0.95, 0.97),
	"katana_iron": Color(0.23, 0.24, 0.27),
	"katana_gold": Color(0.79, 0.64, 0.29),
	"katana_tsuka": Color(0.07, 0.07, 0.08),
	"katana_tsuka_relief": Color(0.17, 0.17, 0.20),
	"katana_lacquer": Color(0.09, 0.09, 0.11),
	"katana_lacquer_red": Color(0.48, 0.12, 0.14),
	"katana_sageo": Color(0.61, 0.62, 0.65),
}
const COLOR_TOLERANCE: float = 0.03
const BUILD_TOLERANCE: float = 0.0001
## Slack when picking the vertices of one ring of the blade (weapon z), in meters.
const SLICE_TOLERANCE: float = 0.0002


func _model_of(scene: PackedScene) -> MeshInstance3D:
	var weapon: Node3D = auto_free(scene.instantiate())
	var mesh_count: int = 0
	for child: Node in weapon.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	assert_int(mesh_count).is_equal(1)
	return weapon.get_node("Model") as MeshInstance3D


func _material(material_name: String) -> StandardMaterial3D:
	return load(MATERIAL_DIR + material_name + "_material.tres") as StandardMaterial3D


## Vertices of one surface of a mesh whose z is within the slice tolerance of `z`.
func _slice(points: PackedVector3Array, z: float) -> PackedVector3Array:
	var slice := PackedVector3Array()
	for p: Vector3 in points:
		if absf(p.z - z) <= SLICE_TOLERANCE:
			slice.append(p)
	return slice


func _bounds_of(mesh: Mesh, surface: int) -> AABB:
	return KatanaParts.bounds(KatanaParts.surface_points(mesh, surface))


func _all_points(mesh: Mesh) -> PackedVector3Array:
	var points := PackedVector3Array()
	for surface: int in mesh.get_surface_count():
		points.append_array(KatanaParts.surface_points(mesh, surface))
	return points


func test_ac1231_the_scenes_use_the_generated_meshes_and_flat_materials() -> void:
	var pairs: Array = [[KATANA_SCENE, BLADE_MODEL, BLADE_MATERIALS], [KATANA_SHEATH_SCENE, SHEATH_MODEL, SHEATH_MATERIALS]]
	for pair: Array in pairs:
		var model: MeshInstance3D = _model_of(pair[0])
		var names: Array[String] = pair[2]
		assert_object(model.mesh).is_same(pair[1])
		assert_bool(model.transform.is_equal_approx(Transform3D.IDENTITY)).is_true()
		assert_int(model.mesh.get_surface_count()).is_equal(names.size())
		for surface: int in names.size():
			var material: Material = model.get_surface_override_material(surface)
			assert_object(material).is_same(_material(names[surface]))
			assert_object((material as StandardMaterial3D).albedo_texture).is_null()
	var katana: Node3D = auto_free(KATANA_SCENE.instantiate())
	assert_vector((katana.get_node("TrailBase") as Node3D).position).is_equal_approx(Vector3(0.0, 0.0, -0.2), Vector3.ONE * 0.0001)
	assert_float((katana.get_node("TrailTip") as Node3D).position.z).is_equal_approx(-1.27, 0.03)
	assert_vector((katana.get_node("Hilt") as Node3D).position).is_equal_approx(Vector3(0.0, 0.0, KatanaBuilder.FIST_Z), Vector3.ONE * 0.0001)
	var sheath: Node3D = auto_free(KATANA_SHEATH_SCENE.instantiate())
	assert_vector((sheath.get_node("Grip") as Node3D).position).is_equal_approx(Vector3(0.0, 0.0, -0.3032), Vector3.ONE * 0.0001)


func test_ac1232_the_blade_is_curved_with_a_kissaki_and_a_hamon() -> void:
	var blade := PackedVector3Array()
	for surface: int in [KatanaBuilder.BladeSurface.STEEL, KatanaBuilder.BladeSurface.HAMON]:
		blade.append_array(KatanaParts.surface_points(BLADE_MODEL, surface))
	# Tip.
	var tip: Vector3 = blade[0]
	for p: Vector3 in blade:
		if p.z < tip.z:
			tip = p
	assert_float(tip.z).is_equal_approx(-1.267, 0.01)
	assert_float(tip.x).is_equal_approx(0.096, 0.01)
	# Width and thickness.
	var base: AABB = KatanaParts.bounds(_slice(blade, KatanaBuilder.BLADE_START_Z))
	assert_float(base.size.x).is_between(0.048, 0.052)
	assert_float(base.size.y).is_between(0.008, 0.010)
	var yokote_width: float = KatanaParts.bounds(_slice(blade, KatanaBuilder.yokote_z())).size.x
	assert_float(yokote_width).is_between(0.038, 0.042)
	# Sori: the middle of the blade bows 1.5 to 3 cm toward the edge (-X) from the chord.
	var mid_z: float = lerpf(KatanaBuilder.BLADE_START_Z, KatanaBuilder.yokote_z(), 0.5)
	var mid: AABB = KatanaParts.bounds(_slice(blade, mid_z))
	var s: float = (KatanaBuilder.BLADE_START_Z - mid_z) / (KatanaBuilder.BLADE_START_Z - KatanaBuilder.TIP_Z)
	var deviation: float = mid.get_center().x - KatanaBuilder.TIP_X * s
	assert_float(deviation).is_between(-0.03, -0.015)
	# Kissaki: the last 5 cm narrow to the point.
	var kissaki_mid: float = KatanaParts.bounds(_slice(blade, KatanaBuilder.TIP_Z + KatanaBuilder.KISSAKI_LENGTH * 0.5)).size.x
	var point: float = KatanaParts.bounds(_slice(blade, KatanaBuilder.TIP_Z)).size.x
	assert_float(kissaki_mid).is_less(yokote_width)
	assert_float(point).is_less(kissaki_mid)
	assert_float(point).is_less(0.001)
	# The hamon is on the edge half.
	var hamon: PackedVector3Array = KatanaParts.surface_points(BLADE_MODEL, KatanaBuilder.BladeSurface.HAMON)
	assert_int(hamon.size()).is_greater(0)
	for p: Vector3 in hamon:
		assert_float(p.x).override_failure_message("hamon vertex %s" % p).is_less_equal(KatanaBuilder.axis_x(p.z) + 0.0001)
	# The edge (least X of each ring) is a line: 1 mm thick at most.
	var lowest: Dictionary = {}
	for p: Vector3 in blade:
		var key: int = roundi(p.z * 100000.0)
		if not lowest.has(key) or p.x < (lowest[key] as Vector3).x:
			lowest[key] = p
	for key: int in lowest:
		assert_float(absf((lowest[key] as Vector3).y)).override_failure_message("edge at %s" % lowest[key]).is_less_equal(0.0005)


func test_ac1233_the_tsuba_is_12_cm_with_four_openings() -> void:
	var iron: AABB = _bounds_of(BLADE_MODEL, KatanaBuilder.BladeSurface.IRON)
	assert_float(iron.size.x).is_between(0.115, 0.125)
	assert_float(iron.size.y).is_between(0.115, 0.125)
	assert_float(iron.size.z).is_between(0.006, 0.012)
	assert_float(iron.end.z).is_between(-0.175, -0.165)
	# A ray along Z at 3.6 cm from the center crosses the iron on the axes and goes through the diagonals.
	var plate := ArrayMesh.new()
	plate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BLADE_MODEL.surface_get_arrays(KatanaBuilder.BladeSurface.IRON))
	var triangles: TriangleMesh = plate.generate_triangle_mesh()
	for k: int in 8:
		var angle: float = deg_to_rad(45.0 * float(k))
		var origin := Vector3(cos(angle) * KatanaBuilder.HOLE_CENTER_R, sin(angle) * KatanaBuilder.HOLE_CENTER_R, 0.5)
		var hit: Dictionary = triangles.intersect_ray(origin, Vector3.FORWARD)
		assert_bool(hit.is_empty()).override_failure_message("%d degrees" % (45 * k)).is_equal(k % 2 == 1)


func test_ac1234_the_tsuka_is_black_with_a_braid_and_menuki() -> void:
	var box: AABB = BLADE_MODEL.get_aabb()
	var iron: AABB = _bounds_of(BLADE_MODEL, KatanaBuilder.BladeSurface.IRON)
	assert_float(box.end.z - iron.end.z).is_between(0.29, 0.33)
	assert_float(_bounds_of(BLADE_MODEL, KatanaBuilder.BladeSurface.GOLD).end.z).is_equal_approx(box.end.z, 0.0001)
	var tsuka: AABB = _bounds_of(BLADE_MODEL, KatanaBuilder.BladeSurface.TSUKA)
	assert_bool(tsuka.position.z <= KatanaBuilder.FIST_Z and tsuka.end.z >= KatanaBuilder.FIST_Z).is_true()
	var tsuka_points: PackedVector3Array = KatanaParts.surface_points(BLADE_MODEL, KatanaBuilder.BladeSurface.TSUKA)
	assert_float(KatanaParts.bounds(_slice(tsuka_points, KatanaBuilder.TSUKA_FRONT_Z)).size.x).is_greater_equal(0.045)
	var cloth: Color = _material("katana_tsuka").albedo_color
	var relief: Color = _material("katana_tsuka_relief").albedo_color
	assert_float(cloth.v).is_less_equal(0.12)
	assert_float(relief.v).is_less_equal(0.25)
	assert_float(relief.v).is_greater(cloth.v)
	# Six lozenges on each wide face: four triangles each.
	var lozenge_vertices: int = KatanaBuilder.LOZENGE_COUNT * 2 * 4 * 3
	assert_int(KatanaParts.surface_points(BLADE_MODEL, KatanaBuilder.BladeSurface.RELIEF).size()).is_greater_equal(lozenge_vertices)
	# One gold menuki on each narrow face, at the fist.
	var sides: Array[bool] = [false, false]
	for p: Vector3 in KatanaParts.surface_points(BLADE_MODEL, KatanaBuilder.BladeSurface.GOLD):
		if absf(p.z - KatanaBuilder.FIST_Z) < 0.02 and absf(p.x) > 0.028:
			sides[0 if p.x > 0.0 else 1] = true
	assert_bool(sides[0] and sides[1]).is_true()


func test_ac1235_the_sheath_measures() -> void:
	var box: AABB = SHEATH_MODEL.get_aabb()
	assert_float(box.position.z).is_equal_approx(KatanaBuilder.SHEATH_END_Z, 0.003)
	# The mouth is on the front face of the guard.
	assert_float(box.end.z).is_equal_approx(KatanaBuilder.GUARD_FRONT_Z, 0.001)
	var body := PackedVector3Array()
	var red := PackedVector3Array()
	for surface: int in [KatanaBuilder.SheathSurface.LACQUER, KatanaBuilder.SheathSurface.RED]:
		for p: Vector3 in KatanaParts.surface_points(SHEATH_MODEL, surface):
			if p.z >= -1.15 and p.z <= -0.6:
				body.append(p)
	assert_float(KatanaParts.bounds(body).size.y).is_between(0.022, 0.028)
	# The two narrow sides (edge and back) are the red lacquer.
	for p: Vector3 in KatanaParts.surface_points(SHEATH_MODEL, KatanaBuilder.SheathSurface.RED):
		assert_float(absf(p.y)).override_failure_message("red vertex %s" % p).is_less_equal(0.007)
		assert_float(absf(absf(p.x - KatanaBuilder.axis_x(p.z)) - KatanaBuilder.sheath_dims(p.z).x)).override_failure_message("red vertex %s" % p).is_less_equal(0.001)
	# The end closes in: narrower than the body.
	var end_width: float = KatanaParts.bounds(_slice(_all_points(SHEATH_MODEL), KatanaBuilder.SHEATH_END_Z)).size.x
	assert_float(end_width).is_less(KatanaParts.bounds(_slice(body, KatanaBuilder.SHEATH_BODY_START_Z + (KatanaBuilder.KOJIRI_START_Z - KatanaBuilder.SHEATH_BODY_START_Z) * 0.5)).size.x * 0.5)
	# Gold at the mouth, at the tip and in the kurigata.
	var mouth: bool = false
	var end: bool = false
	var kurigata: bool = false
	var back_x: float = KatanaBuilder.axis_x(KatanaBuilder.KURIGATA_Z) + KatanaBuilder.sheath_dims(KatanaBuilder.KURIGATA_Z).x
	for p: Vector3 in KatanaParts.surface_points(SHEATH_MODEL, KatanaBuilder.SheathSurface.GOLD):
		mouth = mouth or p.z > KatanaBuilder.SHEATH_BODY_START_Z
		end = end or p.z < KatanaBuilder.KOJIRI_START_Z
		kurigata = kurigata or (absf(p.z - KatanaBuilder.KURIGATA_Z) < 0.02 and p.x > back_x + 0.005)
	assert_bool(mouth and end and kurigata).is_true()


func test_ac1236_the_sageo_is_a_grey_cord_hanging_from_the_kurigata() -> void:
	var color: Color = _material("katana_sageo").albedo_color
	assert_float(maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))).is_less_equal(0.05)
	assert_float(color.v).is_between(0.5, 0.7)
	var cord: PackedVector3Array = KatanaParts.surface_points(SHEATH_MODEL, KatanaBuilder.SheathSurface.SAGEO)
	assert_int(cord.size()).is_greater(0)
	var start: Vector3 = KatanaBuilder.sageo_start()
	var nearest: float = INF
	for p: Vector3 in cord:
		nearest = minf(nearest, p.distance_to(start))
	assert_float(nearest).is_less_equal(0.01)
	var box: AABB = KatanaParts.bounds(cord)
	assert_float(box.size.z).is_between(0.05, 0.12)
	var back_x: float = KatanaBuilder.axis_x(KatanaBuilder.KURIGATA_Z) + KatanaBuilder.sheath_dims(KatanaBuilder.KURIGATA_Z).x
	assert_float(box.end.x - back_x).is_less_equal(0.09)


func test_ac1237_the_materials_are_flat_colors_and_the_glow_covers_every_surface() -> void:
	for material_name: String in COLORS:
		var material: StandardMaterial3D = _material(material_name)
		assert_object(material).is_not_null()
		assert_object(material.albedo_texture).is_null()
		var expected: Color = COLORS[material_name]
		assert_float(material.albedo_color.r).override_failure_message(material_name).is_equal_approx(expected.r, COLOR_TOLERANCE)
		assert_float(material.albedo_color.g).override_failure_message(material_name).is_equal_approx(expected.g, COLOR_TOLERANCE)
		assert_float(material.albedo_color.b).override_failure_message(material_name).is_equal_approx(expected.b, COLOR_TOLERANCE)
	# Hosho's glow is an overlay of the Model: it draws over each of the six surfaces.
	var model: MeshInstance3D = _model_of(KATANA_SCENE)
	model.material_overlay = OVERLAY
	assert_object(model.material_overlay).is_same(OVERLAY)
	assert_int(model.mesh.get_surface_count()).is_equal(6)


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


func test_ac1238_the_generator_reproduces_the_meshes() -> void:
	_assert_same_build(KatanaBuilder.build_blade(), BLADE_MODEL)
	_assert_same_build(KatanaBuilder.build_sheath(), SHEATH_MODEL)
	var source: String = FileAccess.get_file_as_string(ASSET_DIR + "SOURCE.md")
	assert_str(source).contains("build_katana_meshes.gd")
	assert_str(source).not_contains("provisto por el usuario")


func test_ac1239_the_third_party_katana_is_gone() -> void:
	for path: String in [
		ASSET_DIR + "katana.glb", ASSET_DIR + "katana.glb.import",
		ASSET_DIR + "katana_palette.png", ASSET_DIR + "katana_palette.png.import",
		MATERIAL_DIR + "katana_material.tres",
	]:
		assert_bool(FileAccess.file_exists(path)).override_failure_message(path).is_false()
