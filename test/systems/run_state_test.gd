extends GdUnitTestSuite


func _run_at(wave: int) -> RunState:
	var run: RunState = auto_free(RunState.new())
	for i: int in wave - 1:
		run.next_wave()
	return run


func test_ac337_no_rage_until_it_starts() -> void:
	var run: RunState = _run_at(120)
	assert_int(run.get_rage_level()).is_equal(0)


func test_ac338_rage_level_counts_waves_from_the_next_one() -> void:
	var run: RunState = _run_at(114)
	run.start_rage()
	assert_int(run.get_rage_level()).is_equal(0)
	run.next_wave()
	assert_int(run.get_rage_level()).is_equal(1)
	run.next_wave()
	run.start_rage()
	run.next_wave()
	assert_int(run.wave).is_equal(117)
	assert_int(run.get_rage_level()).is_equal(3)
