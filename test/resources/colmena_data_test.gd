extends GdUnitTestSuite
## La Colmena's data (docs/specs/boss-colmena.md).

const COLMENA: ColmenaConfig = preload("res://data/enemies/configs/colmena_boss.tres")


## enemy-level-pace (AC564): exposed 10 s / 7 s (was 6 / 4).
func test_ac527_ac564_batches_windows_distances_and_shield_status() -> void:
	assert_int(COLMENA.summon_for(1).stats.size()).is_equal(4)
	assert_int(COLMENA.summon_for(2).stats.size()).is_equal(5)
	assert_float(COLMENA.exposed_time_for(1)).is_equal_approx(10.0, 0.0001)
	assert_float(COLMENA.exposed_time_for(2)).is_equal_approx(7.0, 0.0001)
	assert_float(COLMENA.keep_min_distance).is_equal_approx(6.0, 0.0001)
	assert_float(COLMENA.keep_max_distance).is_equal_approx(10.0, 0.0001)
	assert_int(COLMENA.shield_status.effect).is_equal(DebuffData.Effect.STATUS)
	assert_bool(COLMENA.shield_status.permanent).is_true()
	assert_int(COLMENA.moves.size()).is_equal(1)
	assert_bool(COLMENA.moves[0] is ShockwaveMoveData).is_true()
