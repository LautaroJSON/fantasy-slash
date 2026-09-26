extends GdUnitTestSuite
## Boss health and defense for ~90 s fights (docs/specs/boss-health-tuning.md).

const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const TITAN: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const COLMENA: EnemyStats = preload("res://data/enemies/colmena_stats.tres")
## Reference average hit and effective health for 90 s at wave 4 (level 2).
const AVERAGE_HIT: float = 20.0
const TARGET_WAVE_4: float = 1680.0


func _at(stats: EnemyStats, level: int) -> EnemyStats:
	var out := EnemyStats.new()
	stats.write_scaled(level, out)
	return out


func _assert_row(stats: EnemyStats, level: int, health: float, defense: float) -> void:
	var out: EnemyStats = _at(stats, level)
	assert_float(out.max_health).override_failure_message("%s lv %d health" % [stats.display_name, level]).is_equal_approx(health, 1.0)
	assert_float(out.defense).override_failure_message("%s lv %d defense" % [stats.display_name, level]).is_equal_approx(defense, 0.01)


func test_ac552_health_and_defense_by_level() -> void:
	for row: Array in [[2, 1511.0, 2.25], [4, 1773.0, 2.75], [10, 2560.0, 4.25], [25, 4526.0, 8.0]]:
		_assert_row(VERDUGO, row[0], row[1], row[2])
	for row: Array in [[2, 1007.0, 2.25], [4, 1182.0, 2.75], [10, 1707.0, 4.25], [25, 3018.0, 8.0]]:
		_assert_row(TITAN, row[0], row[1], row[2])
	for row: Array in [[2, 690.0, 2.25], [4, 810.0, 2.75], [10, 1169.0, 4.25], [25, 2066.0, 8.0]]:
		_assert_row(COLMENA, row[0], row[1], row[2])


func test_ac553_every_boss_lasts_about_ninety_seconds_at_wave_4() -> void:
	# Effort multipliers: Verdugo 1, Titán 1.5 (armour), Colmena 2.2 (exposure).
	for pair: Array in [[VERDUGO, 1.0], [TITAN, 1.5], [COLMENA, 2.2]]:
		var out: EnemyStats = _at(pair[0], 2)
		var effective: float = out.max_health / (1.0 - out.defense / AVERAGE_HIT) * float(pair[1])
		assert_float(effective).override_failure_message(pair[0].display_name).is_between(TARGET_WAVE_4 * 0.95, TARGET_WAVE_4 * 1.05)


func test_ac554_other_stats_are_unchanged() -> void:
	assert_float(VERDUGO.damage).is_equal_approx(18.0, 0.0001)
	assert_float(TITAN.damage).is_equal_approx(22.0, 0.0001)
	assert_float(COLMENA.damage).is_equal_approx(14.0, 0.0001)
	assert_float(VERDUGO.move_speed).is_equal_approx(3.0, 0.0001)
	assert_float(TITAN.move_speed).is_equal_approx(1.8, 0.0001)
	assert_float(COLMENA.move_speed).is_equal_approx(2.0, 0.0001)
	assert_float(VERDUGO.body_scale).is_equal_approx(2.0, 0.0001)
	assert_float(TITAN.body_scale).is_equal_approx(3.5, 0.0001)
	assert_float(COLMENA.body_scale).is_equal_approx(2.6, 0.0001)
	assert_float(TITAN.attack_interval).is_equal_approx(1.0, 0.0001)
