extends GdUnitTestSuite

const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")


func _growth(mode: EnemyStatGrowth.Mode, amount: float, has_cap: bool, cap: float) -> EnemyStatGrowth:
	var growth := EnemyStatGrowth.new()
	growth.mode = mode
	growth.amount = amount
	growth.has_cap = has_cap
	growth.cap = cap
	return growth


func test_ac127_wave_to_enemy_level() -> void:
	assert_int(WAVE_CONFIG.enemy_level_for(1)).is_equal(1)
	assert_int(WAVE_CONFIG.enemy_level_for(2)).is_equal(1)
	assert_int(WAVE_CONFIG.enemy_level_for(3)).is_equal(2)
	assert_int(WAVE_CONFIG.enemy_level_for(10)).is_equal(5)
	assert_int(WAVE_CONFIG.enemy_level_for(20)).is_equal(10)
	assert_int(WAVE_CONFIG.enemy_level_for(100)).is_equal(25)


func test_ac128_percent_growth_is_linear_over_the_base() -> void:
	var growth: EnemyStatGrowth = _growth(EnemyStatGrowth.Mode.PERCENT, 0.2, false, 0.0)
	assert_float(growth.scale(40.0, 1)).is_equal_approx(40.0, 0.0001)
	assert_float(growth.scale(40.0, 5)).is_equal_approx(72.0, 0.0001)


func test_ac128_flat_growth_stops_at_the_cap() -> void:
	var growth: EnemyStatGrowth = _growth(EnemyStatGrowth.Mode.FLAT, 0.1, true, 5.0)
	assert_float(growth.scale(3.5, 1)).is_equal_approx(3.5, 0.0001)
	assert_float(growth.scale(3.5, 10)).is_equal_approx(4.4, 0.0001)
	assert_float(growth.scale(3.5, 25)).is_equal_approx(5.0, 0.0001)


func test_ac129_grunt_scaled_to_level_10() -> void:
	var out: EnemyStats = GRUNT_STATS.duplicate() as EnemyStats
	GRUNT_STATS.write_scaled(10, out)
	assert_float(out.max_health).is_equal_approx(112.0, 0.0001)
	assert_float(out.damage).is_equal_approx(15.2, 0.0001)
	assert_float(out.defense).is_equal_approx(4.5, 0.0001)
	assert_float(out.move_speed).is_equal_approx(4.4, 0.0001)
	assert_float(out.attack_interval).is_equal_approx(GRUNT_STATS.attack_interval, 0.0001)
	assert_float(out.attack_range).is_equal_approx(GRUNT_STATS.attack_range, 0.0001)
	assert_float(out.knockback_friction).is_equal_approx(GRUNT_STATS.knockback_friction, 0.0001)


func test_ac129_level_1_writes_the_base_stats() -> void:
	var out: EnemyStats = GRUNT_STATS.duplicate() as EnemyStats
	GRUNT_STATS.write_scaled(10, out)
	GRUNT_STATS.write_scaled(1, out)
	for i: int in EnemyStats.Stat.size():
		var stat: EnemyStats.Stat = i as EnemyStats.Stat
		assert_float(out.get_stat(stat)).is_equal_approx(GRUNT_STATS.get_stat(stat), 0.0001)
