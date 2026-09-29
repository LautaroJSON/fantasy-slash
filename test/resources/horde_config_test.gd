extends GdUnitTestSuite
## HordeConfig pure functions (docs/specs/fodder-minion.md, AC1148–AC1149, AC1152 data).

const HORDE: HordeConfig = preload("res://data/waves/horde_config.tres")
const FODDER_SPAWN: EnemySpawnEntry = preload("res://data/enemies/spawn/fodder_spawn.tres")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")


func test_ac1148_total_for_grows_by_wave_and_is_capped() -> void:
	assert_int(HORDE.total_for(0, false)).is_equal(0)
	assert_int(HORDE.total_for(1, true)).is_equal(0)
	assert_int(HORDE.total_for(1, false)).is_equal(10)
	assert_int(HORDE.total_for(2, false)).is_equal(12)
	assert_int(HORDE.total_for(20, false)).is_equal(30)


func test_ac1148_group_size_stays_between_min_and_max() -> void:
	assert_int(HORDE.group_size(0.0)).is_equal(4)
	assert_int(HORDE.group_size(0.999)).is_equal(6)


func test_ac1149_members_stay_inside_the_disc_and_apart() -> void:
	for i: int in HORDE.group_size_max:
		assert_float(HORDE.member_offset(i).length()).is_less_equal(HORDE.group_radius)
		for j: int in range(i + 1, HORDE.group_size_max):
			assert_float(HORDE.member_offset(i).distance_to(HORDE.member_offset(j))).is_greater_equal(HORDE.member_separation)


func test_ac1152_the_fodder_pool_covers_max_alive_and_the_fodder_stay_out_of_the_mix() -> void:
	assert_int(FODDER_SPAWN.max_per_wave).is_greater_equal(HORDE.max_alive)
	assert_float(FODDER_SPAWN.weight).is_equal(0.0)
	assert_object(HORDE.entry).is_same(FODDER_SPAWN)
	assert_bool(WAVE_CONFIG.enemy_types.has(FODDER_SPAWN)).is_false()
	assert_object(WAVE_CONFIG.horde).is_same(HORDE)
