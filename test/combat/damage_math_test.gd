extends GdUnitTestSuite


func test_ac1_outgoing_without_crit_is_base_damage() -> void:
	assert_float(DamageMath.outgoing(15.0, 0.0, false, 1.0)).is_equal_approx(15.0, 0.0001)


func test_ac1_outgoing_with_crit_adds_the_crit_bonus() -> void:
	assert_float(DamageMath.outgoing(15.0, 0.0, true, 1.0)).is_equal_approx(30.0, 0.0001)


func test_ac1_outgoing_with_bonus_and_crit() -> void:
	assert_float(DamageMath.outgoing(15.0, 0.1, true, 1.0)).is_equal_approx(33.0, 0.0001)


func test_ac2_mitigate_without_defense() -> void:
	assert_float(DamageMath.mitigate(15.0, 0.0, 1.0)).is_equal_approx(15.0, 0.0001)


func test_ac2_mitigate_subtracts_defense() -> void:
	assert_float(DamageMath.mitigate(8.0, 3.0, 1.0)).is_equal_approx(5.0, 0.0001)


func test_ac2_mitigate_never_below_min_damage() -> void:
	assert_float(DamageMath.mitigate(2.0, 5.0, 1.0)).is_equal_approx(1.0, 0.0001)


func test_ac3_roll_below_chance_is_crit() -> void:
	assert_bool(DamageMath.roll_crit(0.15, 0.10)).is_true()


func test_ac3_roll_equal_to_chance_is_not_crit() -> void:
	assert_bool(DamageMath.roll_crit(0.15, 0.15)).is_false()
