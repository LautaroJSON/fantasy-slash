extends GdUnitTestSuite
## EnemySpawnTable.pick (docs/specs/enemy-types.md).


func _entry(weight: float, first_wave: int, max_per_wave: int) -> EnemySpawnEntry:
	var entry := EnemySpawnEntry.new()
	entry.weight = weight
	entry.first_wave = first_wave
	entry.max_per_wave = max_per_wave
	return entry


## Bruto (4, wave 1), a type from wave 2 (2) and one from wave 5 (2).
func _table() -> Array[EnemySpawnEntry]:
	return [_entry(4.0, 1, 5), _entry(2.0, 2, 2), _entry(2.0, 5, 2)] as Array[EnemySpawnEntry]


func test_ac412_only_types_already_allowed_in_the_wave() -> void:
	var counts: Array[int] = [0, 0, 0]
	for roll: float in [0.0, 0.3, 0.6, 0.99]:
		assert_int(EnemySpawnTable.pick(_table(), 1, counts, roll)).is_equal(0)
	# Wave 4: entry 2 (first_wave 5) never comes out.
	for roll: float in [0.0, 0.5, 0.7, 0.99]:
		assert_int(EnemySpawnTable.pick(_table(), 4, counts, roll)).is_not_equal(2)


func test_ac413_draw_follows_the_weights() -> void:
	var counts: Array[int] = [0, 0, 0]
	# Wave 5, total weight 8: [0, 4) → 0, [4, 6) → 1, [6, 8) → 2.
	assert_int(EnemySpawnTable.pick(_table(), 5, counts, 0.0)).is_equal(0)
	assert_int(EnemySpawnTable.pick(_table(), 5, counts, 0.49)).is_equal(0)
	assert_int(EnemySpawnTable.pick(_table(), 5, counts, 0.5)).is_equal(1)
	assert_int(EnemySpawnTable.pick(_table(), 5, counts, 0.74)).is_equal(1)
	assert_int(EnemySpawnTable.pick(_table(), 5, counts, 0.75)).is_equal(2)
	assert_int(EnemySpawnTable.pick(_table(), 5, counts, 0.999)).is_equal(2)


func test_ac414_full_types_are_skipped_and_entry_0_is_the_fallback() -> void:
	# Entry 1 at its max: wave 5 only draws 0 and 2 (total 6).
	var counts: Array[int] = [0, 2, 0]
	assert_int(EnemySpawnTable.pick(_table(), 5, counts, 0.6)).is_equal(0)
	assert_int(EnemySpawnTable.pick(_table(), 5, counts, 0.7)).is_equal(2)
	# Every type full: the Bruto comes out anyway.
	var full: Array[int] = [5, 2, 2]
	assert_int(EnemySpawnTable.pick(_table(), 5, full, 0.9)).is_equal(0)
