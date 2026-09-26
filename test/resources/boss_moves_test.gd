extends GdUnitTestSuite
## Boss move data and choice (docs/specs/boss-verdugo.md).

const BOSS: BossConfig = preload("res://data/enemies/configs/verdugo_boss.tres")


func _move(min_range: float, max_range: float, weight: float, close_weight: float, phase_one: bool = true, phase_two: bool = true) -> BossMoveData:
	var move := BossMoveData.new()
	move.min_range = min_range
	move.max_range = max_range
	move.weight = weight
	move.close_weight = close_weight
	move.in_phase_one = phase_one
	move.in_phase_two = phase_two
	return move


func test_ac458_choice_respects_range_close_weight_and_phase() -> void:
	# 0: close (0–4), 1: far (3–12, never closer), 2: phase 2 only (0–12).
	var moves: Array[BossMoveData] = [_move(0.0, 4.0, 1.0, 1.0), _move(3.0, 12.0, 1.0, 0.0), _move(0.0, 12.0, 1.0, 1.0, false, true)]
	for roll: float in [0.0, 0.5, 0.99]:
		assert_int(BossMoveTable.pick(moves, 2.0, 1, -1, roll)).is_equal(0)
		assert_int(BossMoveTable.pick(moves, 8.0, 1, -1, roll)).is_equal(1)
	assert_int(BossMoveTable.pick(moves, 8.0, 2, -1, 0.0)).is_equal(1)
	assert_int(BossMoveTable.pick(moves, 8.0, 2, -1, 0.99)).is_equal(2)
	assert_int(BossMoveTable.pick(moves, 20.0, 2, -1, 0.5)).is_equal(-1)


func test_ac458_never_the_same_move_twice_unless_alone() -> void:
	var moves: Array[BossMoveData] = [_move(0.0, 4.0, 1.0, 1.0), _move(0.0, 4.0, 1.0, 1.0)]
	for roll: float in [0.0, 0.5, 0.99]:
		assert_int(BossMoveTable.pick(moves, 2.0, 1, 0, roll)).is_equal(1)
		assert_int(BossMoveTable.pick(moves, 2.0, 1, 1, roll)).is_equal(0)
	# With a single move in reach, it repeats.
	var single: Array[BossMoveData] = [_move(0.0, 4.0, 1.0, 1.0)]
	assert_int(BossMoveTable.pick(single, 2.0, 1, 0, 0.5)).is_equal(0)


func test_ac459_shockwave_band_and_height() -> void:
	var wave := ShockwaveMoveData.new()
	wave.width = 0.8
	wave.clear_height = 0.3
	var center := Vector3(1.0, 0.0, 1.0)
	assert_bool(wave.is_hit(center, 5.0, center + Vector3(5.3, 0.0, 0.0))).is_true()
	assert_bool(wave.is_hit(center, 5.0, center + Vector3(0.0, 0.0, -4.7))).is_true()
	assert_bool(wave.is_hit(center, 5.0, center + Vector3(5.5, 0.0, 0.0))).is_false()
	assert_bool(wave.is_hit(center, 5.0, center + Vector3(4.5, 0.0, 0.0))).is_false()
	assert_bool(wave.is_hit(center, 5.0, center + Vector3(5.0, 0.29, 0.0))).is_true()
	assert_bool(wave.is_hit(center, 5.0, center + Vector3(5.0, 0.3, 0.0))).is_false()


func test_ac460_phase_two_data() -> void:
	var combo: ComboMoveData = BOSS.moves[0] as ComboMoveData
	assert_int(combo.step_count(1)).is_equal(3)
	assert_int(combo.step_count(2)).is_equal(4)
	assert_object(combo.step_at(3)).is_same(combo.steps[0])
	var wave: ShockwaveMoveData = BOSS.moves[1] as ShockwaveMoveData
	assert_int(wave.ring_count(1)).is_equal(1)
	assert_int(wave.ring_count(2)).is_equal(2)
	assert_float(BOSS.phase_two.health_threshold).is_equal_approx(0.5, 0.0001)
	assert_float(BOSS.phase_two.time_scale).is_equal_approx(0.75, 0.0001)
