extends GdUnitTestSuite
## EnemyPaceConfig (docs/specs/enemy-pace.md, docs/specs/enemy-level-pace.md).

const PACE: EnemyPaceConfig = preload("res://data/enemies/enemy_pace_config.tres")


## enemy-level-pace (AC556, replaces AC516): the level ramps the pace, Rage speeds it up further.
func test_ac556_scales_by_level_and_rage() -> void:
	assert_float(PACE.windup_scale_for(1, 0)).is_equal_approx(2.2, 0.0001)
	assert_float(PACE.windup_scale_for(10, 0)).is_equal_approx(1.825, 0.0001)
	assert_float(PACE.windup_scale_for(25, 0)).is_equal_approx(1.2, 0.0001)
	assert_float(PACE.windup_scale_for(25, 2)).is_equal_approx(1.0, 0.0001)
	assert_float(PACE.windup_scale_for(25, 9)).is_equal_approx(1.0, 0.0001)
	assert_float(PACE.interval_scale_for(1, 0)).is_equal_approx(3.0, 0.0001)
	assert_float(PACE.interval_scale_for(10, 0)).is_equal_approx(2.4, 0.0001)
	assert_float(PACE.interval_scale_for(25, 0)).is_equal_approx(1.4, 0.0001)
	assert_float(PACE.interval_scale_for(25, 2)).is_equal_approx(1.0, 0.0001)
	assert_float(PACE.interval_scale_for(40, 0)).is_equal_approx(1.4, 0.0001)
