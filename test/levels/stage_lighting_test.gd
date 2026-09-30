extends GdUnitTestSuite
## Light of the stages and the panorama sky (docs/specs/stage-lighting-sky.md, AC1376–AC1383).

const ARENA: StageData = preload("res://data/stages/arena/arena_stage.tres")
const MAR_DE_FLORES: StageData = preload("res://data/stages/mar_de_flores/mar_de_flores_stage.tres")
const ARENA_LIGHTING: StageLighting = preload("res://data/stages/arena/arena_lighting.tres")
const MAR_LIGHTING: StageLighting = preload("res://data/stages/mar_de_flores/mar_de_flores_lighting.tres")
const SKY_DIR: String = "res://assets/skies/sbs_cloudy_sky_04"
const BUILDER_DIR: String = "res://assets/models/environment/mar_de_flores"
const ANGLE_TOLERANCE: float = 0.0001


func _stage(data: StageData, lighting: StageLighting = null) -> StageMap:
	var stage: StageMap = auto_free(data.scene.instantiate()) as StageMap
	stage.setup(data)
	if lighting != null:
		stage.lighting = lighting
	add_child(stage)
	return stage


func _custom_lighting(speed: float, offset: float) -> StageLighting:
	var lighting := StageLighting.new()
	lighting.environment = Environment.new()
	lighting.environment.background_mode = Environment.BG_SKY
	lighting.sky_rotation_speed_deg = speed
	lighting.sky_yaw_offset_deg = offset
	return lighting


# --- light in data -----------------------------------------------------------

func test_ac1376_the_stage_applies_its_lighting_to_the_environment_and_the_sun() -> void:
	for data: StageData in [ARENA, MAR_DE_FLORES]:
		var stage: StageMap = _stage(data)
		var lighting: StageLighting = stage.lighting
		assert_object(lighting).override_failure_message(data.display_name).is_not_null()
		assert_int(stage.world_environment.environment.background_mode).is_equal(lighting.environment.background_mode)
		assert_float(stage.world_environment.environment.ambient_light_energy).is_equal_approx(lighting.environment.ambient_light_energy, 0.0001)
		assert_object(stage.sun.light_color).is_equal(lighting.sun_color)
		assert_float(stage.sun.light_energy).is_equal_approx(lighting.sun_energy, 0.0001)
		assert_bool(stage.sun.shadow_enabled).is_equal(lighting.sun_shadows)
		assert_float(stage.sun.shadow_blur).is_equal_approx(lighting.sun_shadow_blur, 0.0001)
		assert_float(stage.sun.directional_shadow_max_distance).is_equal_approx(lighting.sun_shadow_max_distance, 0.0001)
		assert_float(stage.sun.rotation.x).is_equal_approx(deg_to_rad(lighting.sun_pitch_deg), ANGLE_TOLERANCE)
		assert_float(stage.sun.rotation.y).is_equal_approx(deg_to_rad(lighting.sun_yaw_deg), ANGLE_TOLERANCE)


func test_ac1377_the_applied_environment_is_a_copy() -> void:
	var stage: StageMap = _stage(MAR_DE_FLORES, _custom_lighting(6.0, 0.0))
	var shared: Environment = stage.lighting.environment
	assert_object(stage.world_environment.environment).is_not_same(shared)
	stage._process(60.0)
	assert_float(shared.sky_rotation.y).is_equal(0.0)
	assert_float(MAR_LIGHTING.environment.sky_rotation.y).is_equal(0.0)


func test_ac1378_the_sky_turns_at_the_speed_of_the_lighting() -> void:
	var turning: StageMap = _stage(MAR_DE_FLORES, _custom_lighting(6.0, 10.0))
	var sky: Environment = turning.world_environment.environment
	assert_float(sky.sky_rotation.y).is_equal_approx(deg_to_rad(10.0), ANGLE_TOLERANCE)
	turning._process(60.0)
	assert_float(sky.sky_rotation.y).is_equal_approx(deg_to_rad(16.0), ANGLE_TOLERANCE)
	turning._process(30.0)
	assert_float(sky.sky_rotation.y).is_equal_approx(deg_to_rad(19.0), ANGLE_TOLERANCE)
	var still: StageMap = _stage(MAR_DE_FLORES, _custom_lighting(0.0, 10.0))
	assert_bool(still.is_processing()).is_false()
	assert_float(still.world_environment.environment.sky_rotation.y).is_equal_approx(deg_to_rad(10.0), ANGLE_TOLERANCE)


func test_ac1379_the_builder_no_longer_writes_the_environment_or_the_sun() -> void:
	var builder: String = FileAccess.get_file_as_string(BUILDER_DIR + "/tools/build_mar_de_flores.gd")
	for forbidden: String in ["var environment := Environment.new()", "ProceduralSkyMaterial", "SUN_", "FOG_", "light_energy", "_save_environment"]:
		assert_bool(builder.contains(forbidden)).override_failure_message(forbidden).is_false()
	assert_bool(FileAccess.file_exists("res://levels/stages/mar_de_flores/mar_de_flores_environment.tres")).is_false()
	var stage: StageMap = _stage(MAR_DE_FLORES)
	assert_object(stage.lighting).is_same(MAR_LIGHTING)
	assert_str(stage.lighting.resource_path).is_equal("res://data/stages/mar_de_flores/mar_de_flores_lighting.tres")


func test_ac1380_the_arena_keeps_the_light_it_had() -> void:
	var environment: Environment = ARENA_LIGHTING.environment
	assert_int(environment.background_mode).is_equal(Environment.BG_COLOR)
	assert_object(environment.background_color).is_equal(Color(0.42, 0.56, 0.74))
	assert_int(environment.ambient_light_source).is_equal(Environment.AMBIENT_SOURCE_COLOR)
	assert_object(environment.ambient_light_color).is_equal(Color(0.62, 0.66, 0.72))
	assert_float(environment.ambient_light_energy).is_equal_approx(0.6, 0.0001)
	assert_object(ARENA_LIGHTING.sun_color).is_equal(Color.WHITE)
	assert_float(ARENA_LIGHTING.sun_energy).is_equal(1.0)
	assert_bool(ARENA_LIGHTING.sun_shadows).is_false()
	# Direction of the sun the Arena scene had: -Z axis of its old transform (the
	# .tscn writes the basis by rows). It pointed up, so the floor was never lit;
	# kept as it was on purpose (AC1393).
	var old_basis := Basis(Vector3(0.866025, -0.391667, 0.310806), Vector3(0.0, 0.62161, 0.78333), Vector3(-0.5, -0.678383, 0.538332))
	var direction: Vector3 = -Basis.from_euler(Vector3(deg_to_rad(ARENA_LIGHTING.sun_pitch_deg), deg_to_rad(ARENA_LIGHTING.sun_yaw_deg), 0.0)).z
	assert_vector(direction).is_equal_approx(-old_basis.z, Vector3.ONE * 0.005)


# --- sky ---------------------------------------------------------------------

func test_ac1381_the_mar_de_flores_uses_the_panorama_and_takes_its_ambient_from_it() -> void:
	var environment: Environment = MAR_LIGHTING.environment
	assert_int(environment.background_mode).is_equal(Environment.BG_SKY)
	assert_int(environment.ambient_light_source).is_equal(Environment.AMBIENT_SOURCE_SKY)
	var material: PanoramaSkyMaterial = environment.sky.sky_material as PanoramaSkyMaterial
	assert_object(material).is_not_null()
	assert_str(material.panorama.resource_path).starts_with(SKY_DIR + "/")


func test_ac1382_the_panorama_is_equirectangular_and_documents_its_source() -> void:
	var material: PanoramaSkyMaterial = MAR_LIGHTING.environment.sky.sky_material as PanoramaSkyMaterial
	assert_int(material.panorama.get_width()).is_equal(material.panorama.get_height() * 2)
	var source: String = FileAccess.get_file_as_string(SKY_DIR + "/SOURCE.md")
	for field: String in ["Origen", "Licencia", "2026-09-29"]:
		assert_bool(source.contains(field)).override_failure_message(field).is_true()


func test_ac1383_no_3d_clouds_are_left() -> void:
	var stage: StageMap = _stage(MAR_DE_FLORES)
	assert_object(stage.find_child("Clouds", true, false)).is_null()
	for path: String in [BUILDER_DIR + "/scatter/clouds.res", BUILDER_DIR + "/cloud_puff.tres", "res://materials/environment/cloud_material.tres"]:
		assert_bool(FileAccess.file_exists(path)).override_failure_message(path).is_false()
	assert_bool(MarDeFloresBuilder.new().has_method("clouds")).is_false()


# --- look --------------------------------------------------------------------

func test_ac1384_the_mar_de_flores_uses_agx_glow_and_saturated_colour() -> void:
	var environment: Environment = MAR_LIGHTING.environment
	assert_int(environment.tonemap_mode).is_equal(Environment.TONE_MAPPER_AGX)
	assert_bool(environment.glow_enabled).is_true()
	assert_bool(environment.adjustment_enabled).is_true()
	assert_float(environment.adjustment_saturation).is_greater(1.0)


func test_ac1385_the_scenery_materials_are_toon_and_matte_except_the_water() -> void:
	var dir: DirAccess = DirAccess.open("res://materials/environment")
	var checked: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var material: StandardMaterial3D = load("res://materials/environment/" + file) as StandardMaterial3D
		if file == "water_material.tres":
			assert_int(material.specular_mode).override_failure_message(file).is_equal(BaseMaterial3D.SPECULAR_SCHLICK_GGX)
			continue
		assert_int(material.diffuse_mode).override_failure_message(file).is_equal(BaseMaterial3D.DIFFUSE_TOON)
		assert_int(material.specular_mode).override_failure_message(file).is_equal(BaseMaterial3D.SPECULAR_DISABLED)
		checked += 1
	assert_int(checked).is_greater(10)


func test_ac1388_the_greens_of_the_ground_are_darker_and_not_less_saturated() -> void:
	# Values before this spec (docs/specs/stage-lighting-sky.md §3.3).
	var pairs: Array = [
		[MarDeFloresBuilder.MEADOW, Color(0.47, 0.68, 0.31)],
		[MarDeFloresBuilder.OUTSIDE, Color(0.4, 0.6, 0.28)],
		[(load("res://materials/environment/grass_material.tres") as StandardMaterial3D).albedo_color, Color(0.62, 0.86, 0.4)],
		[(load("res://materials/environment/far_ground_material.tres") as StandardMaterial3D).albedo_color, Color(0.42, 0.6, 0.3)],
	]
	for pair: Array in pairs:
		var now: Color = pair[0]
		var before: Color = pair[1]
		assert_float(now.v).override_failure_message(str(now)).is_less(before.v)
		assert_float(now.s).override_failure_message(str(now)).is_greater_equal(before.s)
