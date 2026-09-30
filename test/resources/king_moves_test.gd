extends GdUnitTestSuite
## Pure data of the King (docs/specs/boss-king.md): AC1241-AC1243.

const BOSS: BossConfig = preload("res://data/enemies/configs/king_boss.tres")
const SLASH: int = 0
const THRUST: int = 1
const SPIN: int = 2
const OATH: int = 3
const JUDGMENT: int = 4
const ROLLS: Array[float] = [0.0, 0.2, 0.4, 0.6, 0.8, 0.99]


func _picks(distance: float, phase: int) -> Array[int]:
	var picked: Array[int] = []
	for roll: float in ROLLS:
		var index: int = BossMoveTable.pick(BOSS.moves, distance, phase, -1, roll)
		if not picked.has(index):
			picked.append(index)
	return picked


func test_ac1241_the_thrust_length_respects_the_stop_distance_and_the_limit() -> void:
	var thrust: ThrustMoveData = BOSS.moves[THRUST] as ThrustMoveData
	assert_float(thrust.lunge_length(6.0)).is_equal_approx(6.0 - thrust.stop_distance, 0.0001)
	assert_float(thrust.lunge_length(1.0)).is_equal_approx(0.0, 0.0001)
	assert_float(thrust.lunge_length(30.0)).is_equal_approx(thrust.thrust_distance, 0.0001)
	assert_int(thrust.thrusts(1)).is_equal(1)
	assert_int(thrust.thrusts(2)).is_equal(2)


func test_ac1242_the_spin_hits_all_around_and_cannot_be_jumped() -> void:
	var spin: SweepMoveData = BOSS.moves[SPIN] as SweepMoveData
	var origin: Vector3 = Vector3.ZERO
	var facing: Vector3 = Vector3.FORWARD
	for point: Vector3 in [Vector3(0, 0, -3), Vector3(0, 0, 3), Vector3(3, 0, 0), Vector3(-3, 0, 0)]:
		assert_bool(spin.is_hit(origin, facing, point, 0.0)).override_failure_message(str(point)).is_true()
	assert_bool(spin.is_hit(origin, facing, Vector3(0, 1.5, 3), 0.0)).is_true()
	assert_bool(spin.is_hit(origin, facing, Vector3(0, 0, spin.attack.hit_range + 1.0), 0.0)).is_false()


func test_ac1243_the_choice_follows_distance_and_phase() -> void:
	# 10 m: only the thrust and the oath reach.
	for index: int in _picks(10.0, 1):
		assert_bool(index == THRUST or index == OATH).override_failure_message("phase 1, 10 m: %d" % index).is_true()
	# 2 m: slash, spin and (rarely) the oath; the thrust does not start that close.
	var close: Array[int] = _picks(2.0, 1)
	assert_bool(close.has(SLASH) and close.has(SPIN)).is_true()
	assert_bool(close.has(THRUST) or close.has(JUDGMENT)).is_false()
	# The Judgment is phase 2 only.
	assert_bool(_picks(2.0, 2).has(JUDGMENT)).is_true()
	assert_bool(_picks(5.0, 1).has(JUDGMENT)).is_false()
	assert_int(BossMoveTable.pick(BOSS.moves, 20.0, 2, -1, 0.5)).is_equal(-1)
