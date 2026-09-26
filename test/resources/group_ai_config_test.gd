extends GdUnitTestSuite
## GroupAIConfig pure helpers (docs/specs/enemy-group-ai.md).

const CONFIG: GroupAIConfig = preload("res://data/enemies/group_ai_config.tres")


## enemy-pace (AC517, replaces AC444): attackers grow with the Rage level, not the wave.
func test_ac517_attackers_grow_with_the_rage_up_to_the_cap() -> void:
	assert_int(CONFIG.max_attackers_for(0)).is_equal(2)
	assert_int(CONFIG.max_attackers_for(1)).is_equal(2)
	assert_int(CONFIG.max_attackers_for(2)).is_equal(2)
	assert_int(CONFIG.max_attackers_for(3)).is_equal(3)
	assert_int(CONFIG.max_attackers_for(6)).is_equal(4)
	assert_int(CONFIG.max_attackers_for(20)).is_equal(4)


func test_ac444_slots_are_spread_evenly_around() -> void:
	assert_vector(CONFIG.slot_direction(0)).is_equal_approx(Vector3(0.0, 0.0, 1.0), Vector3(0.0001, 0.0001, 0.0001))
	var step: float = TAU / CONFIG.slot_count
	for i: int in CONFIG.slot_count:
		var next: int = (i + 1) % CONFIG.slot_count
		assert_float(CONFIG.slot_direction(i).angle_to(CONFIG.slot_direction(next))).is_equal_approx(step, 0.0001)
		assert_float(CONFIG.slot_direction(i).length()).is_equal_approx(1.0, 0.0001)


func test_ac557_rest_between_turns_by_level_and_rage() -> void:
	assert_float(CONFIG.rest_for(1, 0)).is_equal_approx(1.5, 0.0001)
	assert_float(CONFIG.rest_for(10, 0)).is_equal_approx(1.125, 0.0001)
	assert_float(CONFIG.rest_for(25, 0)).is_equal_approx(0.5, 0.0001)
	assert_float(CONFIG.rest_for(25, 5)).is_equal_approx(0.3, 0.0001)
