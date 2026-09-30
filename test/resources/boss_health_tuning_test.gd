extends GdUnitTestSuite
## Boss health and defense for a ~60 s first boss at wave 10 (level 5), with the
## DPS measured in class_dps_reference_test (docs/specs/early-power-curve.md §6.2;
## replaces docs/specs/boss-health-tuning.md, AC552-AC553).

const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const TITAN: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const COLMENA: EnemyStats = preload("res://data/enemies/colmena_stats.tres")
const KING: EnemyStats = preload("res://data/enemies/king_stats.tres")
## Average of the measured class DPS (18.732, 13.44, 28.235).
const DPS_REF: float = 20.1357
## Average hit of the first waves (docs/specs/early-power-curve.md §5).
const AVERAGE_HIT: float = 8.0
const GROWTH: float = 0.095
const BASES: Dictionary = {"verdugo": 499.0, "titan": 333.0, "colmena": 227.0, "king": 499.0}


func _at(stats: EnemyStats, level: int) -> EnemyStats:
	var out := EnemyStats.new()
	stats.write_scaled(level, out)
	return out


func test_ac1132_health_grows_from_the_base_and_defense_stays_low() -> void:
	var stats_by_key: Dictionary = {"verdugo": VERDUGO, "titan": TITAN, "colmena": COLMENA, "king": KING}
	for key: String in stats_by_key:
		var stats: EnemyStats = stats_by_key[key]
		for level: int in [5, 10, 15, 25]:
			var expected: float = float(BASES[key]) * (1.0 + GROWTH * float(level - 1))
			assert_float(_at(stats, level).max_health).override_failure_message("%s lv %d health" % [key, level]).is_equal_approx(expected, 1.0)
		assert_float(_at(stats, 1).defense).override_failure_message(key + " lv 1 defense").is_equal_approx(0.0, 0.01)
		assert_float(_at(stats, 5).defense).override_failure_message(key + " lv 5 defense").is_equal_approx(0.4, 0.01)
		assert_float(_at(stats, 25).defense).override_failure_message(key + " lv 25 defense").is_equal_approx(2.0, 0.01)


## Effort multipliers: Verdugo 1, Titán 1.5 (armour), Colmena 2.2 (exposure), Rey 1.
func test_ac1133_every_boss_lasts_about_a_minute_at_wave_10() -> void:
	var target: float = 36.0 * DPS_REF
	for pair: Array in [[VERDUGO, 1.0], [TITAN, 1.5], [COLMENA, 2.2], [KING, 1.0]]:
		var out: EnemyStats = _at(pair[0], 5)
		var effective: float = out.max_health / (1.0 - out.defense / AVERAGE_HIT) * float(pair[1])
		assert_float(effective).override_failure_message(pair[0].display_name).is_between(target * 0.95, target * 1.05)


func test_ac554_other_stats_are_unchanged() -> void:
	assert_float(VERDUGO.damage).is_equal_approx(18.0, 0.0001)
	assert_float(TITAN.damage).is_equal_approx(22.0, 0.0001)
	assert_float(COLMENA.damage).is_equal_approx(14.0, 0.0001)
	assert_float(KING.damage).is_equal_approx(20.0, 0.0001)
	assert_float(VERDUGO.move_speed).is_equal_approx(3.0, 0.0001)
	assert_float(TITAN.move_speed).is_equal_approx(1.8, 0.0001)
	assert_float(COLMENA.move_speed).is_equal_approx(2.0, 0.0001)
	assert_float(VERDUGO.body_scale).is_equal_approx(2.0, 0.0001)
	assert_float(TITAN.body_scale).is_equal_approx(3.5, 0.0001)
	assert_float(COLMENA.body_scale).is_equal_approx(2.6, 0.0001)
	assert_float(TITAN.attack_interval).is_equal_approx(1.0, 0.0001)
