extends GdUnitTestSuite
## Stage data: sequence, layout and what every stage declares
## (docs/specs/stages.md, AC1286–AC1288).

const SEQUENCE: StageSequence = preload("res://data/stages/stage_sequence.tres")
const ARENA_STAGE: StageData = preload("res://data/stages/arena/arena_stage.tres")
const TWO_ARENAS: StageSequence = preload("res://test/data/two_arena_sequence.tres")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")


func test_ac1286_is_last_only_for_the_last_index() -> void:
	assert_bool(TWO_ARENAS.is_last(0)).is_false()
	assert_bool(TWO_ARENAS.is_last(1)).is_true()
	assert_int(TWO_ARENAS.count()).is_equal(2)
	assert_object(TWO_ARENAS.get_stage(1)).is_same(ARENA_STAGE)
	assert_object(TWO_ARENAS.get_stage(2)).is_null()
	assert_object(TWO_ARENAS.get_stage(-1)).is_null()


func test_ac1287_contains_and_clamp_inside() -> void:
	var layout := StageLayout.new()
	layout.spawn_polygon = PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(0, 5)])
	assert_bool(layout.contains(Vector2(0, 0))).is_true()
	assert_bool(layout.contains(Vector2(6, 6))).is_false()
	assert_bool(layout.contains(Vector2(-4, 4))).is_false()
	for point: Vector2 in [Vector2(20, 0), Vector2(-9, 9), Vector2(0, -30), Vector2(0, 0)]:
		var inside: Vector2 = layout.clamp_inside(point)
		# On the edge or inside: a hair towards the centroid is inside.
		var nudged: Vector2 = inside.lerp(Vector2(0, -5.0 / 3.0), 0.001)
		assert_bool(layout.contains(nudged)).override_failure_message(str(point)).is_true()
	assert_vector(layout.clamp_inside(Vector2(0, 0))).is_equal(Vector2(0, 0))
	assert_vector(layout.clamp_inside(Vector2(0, -30))).is_equal(Vector2(0, -5))


func test_ac1287_the_arena_square_clamps_like_before() -> void:
	var layout: StageLayout = ARENA_STAGE.layout
	for point: Vector2 in [Vector2(15, 3), Vector2(-20, -20), Vector2(4, 13), Vector2(3, -2)]:
		var expected := Vector2(clampf(point.x, -12.0, 12.0), clampf(point.y, -12.0, 12.0))
		assert_vector(layout.clamp_inside(point)).is_equal_approx(expected, Vector2.ONE * 0.0001)


func test_ac1288_wave_config_lost_the_stage_fields() -> void:
	for field: String in ["enemy_types", "boss_challenges", "boss_wave_interval", "spawn_half_extent"]:
		assert_bool(field in WAVE_CONFIG).override_failure_message(field).is_false()


func test_ac1288_every_stage_declares_its_content() -> void:
	assert_int(SEQUENCE.count()).is_greater(0)
	for data: StageData in SEQUENCE.stages:
		assert_object(data.scene).override_failure_message(data.id).is_not_null()
		assert_int(data.regular_waves).is_greater(0)
		assert_bool(data.enemy_types.is_empty()).is_false()
		assert_bool(data.boss_challenges.is_empty()).is_false()
		assert_object(data.portal).is_not_null()
		assert_object(data.portal.style_scene).is_not_null()
		assert_object(data.layout).is_not_null()
		assert_int(data.layout.spawn_polygon.size()).is_greater_equal(3)
		assert_str(data.display_name).is_not_empty()
