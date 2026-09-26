extends GdUnitTestSuite
## Boss moves that need a hand (docs/specs/boss-titan.md).

const TITAN: TitanConfig = preload("res://data/enemies/configs/titan_boss.tres")
const SLAM: int = 0
const SWEEP: int = 1
const STOMP: int = 2


func test_ac478_without_hands_only_the_stomp_is_chosen() -> void:
	for roll: float in [0.0, 0.3, 0.6, 0.99]:
		assert_int(BossMoveTable.pick(TITAN.moves, 5.0, 1, -1, roll, 0)).is_equal(STOMP)
	# Two hands (the default): every move can come out at 5 m.
	var seen: Array[int] = []
	for i: int in 20:
		var index: int = BossMoveTable.pick(TITAN.moves, 5.0, 1, -1, (float(i) + 0.5) / 20.0)
		if not seen.has(index):
			seen.append(index)
	assert_int(seen.size()).is_equal(3)


func test_ac478_handless_weight_and_hand_helpers() -> void:
	var stomp: BossMoveData = TITAN.moves[STOMP]
	assert_float(stomp.weight_at(5.0, 1, 2)).is_equal_approx(stomp.weight, 0.0001)
	assert_float(stomp.weight_at(5.0, 1, 0)).is_equal_approx(stomp.handless_weight, 0.0001)
	assert_float(TITAN.moves[SLAM].weight_at(5.0, 1, 0)).is_equal_approx(0.0, 0.0001)
	assert_float(TITAN.hand_size_for(1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(TITAN.hand_size_for(0.0)).is_equal_approx(TITAN.damaged_hand_min_scale, 0.0001)
	var slam: HandSlamMoveData = TITAN.moves[SLAM] as HandSlamMoveData
	assert_bool(slam.is_hit(Vector3.ZERO, Vector3(2.9, 0.0, 0.0))).is_true()
	assert_bool(slam.is_hit(Vector3.ZERO, Vector3(3.1, 0.0, 0.0))).is_false()
