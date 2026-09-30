extends GdUnitTestSuite
## WaveConfig pure helpers (docs/specs/early-power-curve.md).

const CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const ARENA_STAGE: StageData = preload("res://data/stages/arena/arena_stage.tres")
const SEEDS: int = 40


func test_ac1121_the_first_waves_are_shorter() -> void:
	for row: Array in [[1, 4], [2, 5], [3, 6], [4, 7], [9, 7], [11, 7]]:
		assert_int(CONFIG.enemies_for_wave(row[0])).override_failure_message("wave %d" % row[0]).is_equal(row[1])


func test_ac1122_the_first_waves_give_two_picks() -> void:
	for row: Array in [[1, 2], [2, 2], [3, 2], [4, 1], [9, 1], [10, 1]]:
		assert_int(CONFIG.picks_for_wave(row[0], false)).override_failure_message("wave %d" % row[0]).is_equal(row[1])


func test_ac1122_a_boss_wave_always_gives_one_pick() -> void:
	var config: WaveConfig = CONFIG.duplicate() as WaveConfig
	config.early_wave_picks = [2, 2, 2] as Array[int]
	assert_int(config.picks_for_wave(2, true)).is_equal(1)
	assert_int(config.picks_for_wave(3, false)).is_equal(2)


## stages.md: the boss closes each stage after its 10 regular waves (it was every 10th wave).
func test_ac1123_the_boss_comes_after_ten_regular_waves() -> void:
	assert_int(ARENA_STAGE.regular_waves).is_equal(10)
	assert_bool(ARENA_STAGE.is_boss_wave(11)).is_true()
	for stage_wave: int in [10, 12]:
		assert_bool(ARENA_STAGE.is_boss_wave(stage_wave)).is_false()


## The first wave each type can appear in (Bruto 1, Embestidor 4, Saltador 8, Escudero 11, Hostigador 15).
func test_ac1134_annoying_types_come_later() -> void:
	var first_waves: Dictionary = {
		"grunt": 1, "charger": 4, "leaper": 8, "shieldbearer": 11, "harasser": 15,
	}
	for entry: EnemySpawnEntry in ARENA_STAGE.enemy_types:
		var key: String = entry.stats.resource_path.get_file().trim_suffix("_stats.tres")
		assert_int(entry.first_wave).override_failure_message(key).is_equal(first_waves[key])
	var rng := RandomNumberGenerator.new()
	for wave: int in range(1, 15):
		for seed_value: int in SEEDS:
			rng.seed = seed_value
			var counts: Array[int] = []
			counts.resize(ARENA_STAGE.enemy_types.size())
			counts.fill(0)
			for i: int in CONFIG.enemies_for_wave(wave):
				var index: int = EnemySpawnTable.pick(ARENA_STAGE.enemy_types, wave, counts, rng.randf())
				assert_int(ARENA_STAGE.enemy_types[index].first_wave).is_less_equal(wave)
				counts[index] += 1
	# Waves 1-3 only draw Brutos.
	var counts_early: Array[int] = [0, 0, 0, 0, 0]
	for wave: int in range(1, 4):
		for roll: float in [0.0, 0.3, 0.6, 0.99]:
			assert_int(EnemySpawnTable.pick(ARENA_STAGE.enemy_types, wave, counts_early, roll)).is_equal(0)
