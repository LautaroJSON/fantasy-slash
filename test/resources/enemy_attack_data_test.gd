extends GdUnitTestSuite
## AC409: EnemyAttackData.is_hit() is a pure arc test (docs/specs/enemy-attack-telegraph.md).


func _attack(hit_range: float, arc_degrees: float) -> EnemyAttackData:
	var attack := EnemyAttackData.new()
	attack.hit_range = hit_range
	attack.hit_arc_degrees = arc_degrees
	return attack


func test_ac409_range_limit_includes_the_padding() -> void:
	var attack: EnemyAttackData = _attack(2.0, 90.0)
	assert_bool(attack.is_hit(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, -2.35), 0.4)).is_true()
	assert_bool(attack.is_hit(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, -2.45), 0.4)).is_false()
	assert_bool(attack.is_hit(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, -2.1), 0.0)).is_false()


func test_ac409_arc_edge() -> void:
	var attack: EnemyAttackData = _attack(5.0, 90.0)
	var inside := Vector3(sin(deg_to_rad(44.0)), 0.0, -cos(deg_to_rad(44.0))) * 2.0
	var outside := Vector3(sin(deg_to_rad(46.0)), 0.0, -cos(deg_to_rad(46.0))) * 2.0
	assert_bool(attack.is_hit(Vector3.ZERO, Vector3.FORWARD, inside, 0.0)).is_true()
	assert_bool(attack.is_hit(Vector3.ZERO, Vector3.FORWARD, outside, 0.0)).is_false()
	assert_bool(attack.is_hit(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, 1.0), 0.0)).is_false()


func test_ac409_height_is_ignored_and_origin_is_used() -> void:
	var attack: EnemyAttackData = _attack(2.0, 90.0)
	var origin := Vector3(10.0, 0.0, 10.0)
	assert_bool(attack.is_hit(origin, Vector3.FORWARD, origin + Vector3(0.0, 3.0, -1.5), 0.0)).is_true()
	assert_bool(attack.is_hit(origin, Vector3.FORWARD, Vector3(0.0, 0.0, -1.5), 0.0)).is_false()


func test_ac409_overlapping_target_is_always_hit() -> void:
	var attack: EnemyAttackData = _attack(2.0, 10.0)
	assert_bool(attack.is_hit(Vector3.ZERO, Vector3.FORWARD, Vector3(0.3, 0.0, 0.0), 0.4)).is_true()


func test_ac409_total_time_is_the_sum_of_the_phases() -> void:
	var attack := EnemyAttackData.new()
	attack.windup_time = 0.5
	attack.active_time = 0.15
	attack.recovery_time = 0.45
	assert_float(attack.get_total_time()).is_equal_approx(1.1, 0.0001)
