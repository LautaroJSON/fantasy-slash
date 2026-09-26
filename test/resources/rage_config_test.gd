extends GdUnitTestSuite

const RAGE: RageConfig = preload("res://data/enemies/rage/rage_config.tres")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const MAX_LEVEL: int = 25


## Grunt stats at the enemy level cap (232 health, 27.2 damage, 5 defense, 5 speed).
func _grunt_at_cap() -> EnemyStats:
	var out := EnemyStats.new()
	GRUNT_STATS.write_scaled(MAX_LEVEL, out)
	return out


func test_ac333_rage_level_zero_changes_nothing() -> void:
	var base: EnemyStats = _grunt_at_cap()
	var out: EnemyStats = _grunt_at_cap()
	RAGE.write_raged(0, out)
	for i: int in EnemyStats.Stat.size():
		var stat: EnemyStats.Stat = i as EnemyStats.Stat
		assert_float(out.get_stat(stat)).is_equal_approx(base.get_stat(stat), 0.0001)


func test_ac334_rage_level_one_grows_the_four_stats() -> void:
	var base: EnemyStats = _grunt_at_cap()
	var out: EnemyStats = _grunt_at_cap()
	RAGE.write_raged(1, out)
	assert_float(out.max_health).is_equal_approx(base.max_health * 1.15, 0.0001)
	assert_float(out.damage).is_equal_approx(base.damage * 1.08, 0.0001)
	assert_float(out.defense).is_equal_approx(base.defense + 0.5, 0.0001)
	assert_float(out.move_speed).is_equal_approx(base.move_speed + 0.1, 0.0001)
	assert_float(out.attack_interval).is_equal_approx(base.attack_interval, 0.0001)
	assert_float(out.attack_range).is_equal_approx(base.attack_range, 0.0001)
	assert_float(out.knockback_friction).is_equal_approx(base.knockback_friction, 0.0001)


func test_ac335_defense_and_speed_stop_at_their_caps() -> void:
	var out: EnemyStats = _grunt_at_cap()
	RAGE.write_raged(30, out)
	assert_float(out.max_health).is_equal_approx(1276.0, 0.001)
	assert_float(out.damage).is_equal_approx(92.48, 0.001)
	assert_float(out.defense).is_equal_approx(20.0, 0.0001)
	assert_float(out.move_speed).is_equal_approx(5.4, 0.0001)


func test_ac336_rage_never_lowers_a_stat_above_its_cap() -> void:
	var growth := EnemyStatGrowth.new()
	growth.stat = EnemyStats.Stat.DEFENSE
	growth.mode = EnemyStatGrowth.Mode.FLAT
	growth.amount = 1.0
	growth.has_cap = true
	growth.cap = 3.0
	var config := RageConfig.new()
	config.growth.append(growth)
	var out := EnemyStats.new()
	out.defense = 8.0
	config.write_raged(4, out)
	assert_float(out.defense).is_equal_approx(8.0, 0.0001)
