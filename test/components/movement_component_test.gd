extends GdUnitTestSuite

const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const PLAYER_TUNING: PlayerTuning = preload("res://data/player/player_tuning.tres")
const COMBAT_RULES: CombatRules = preload("res://data/combat/combat_rules.tres")
const STEP: float = 1.0 / 60.0


func _make_movement() -> MovementComponent:
	var movement: MovementComponent = auto_free(MovementComponent.new())
	movement.tuning = PLAYER_TUNING
	return movement


func test_ac12_accelerates_without_exceeding_max_speed() -> void:
	var movement: MovementComponent = _make_movement()
	var velocity := Vector3.ZERO
	var max_speed: float = PLAYER_STATS.move_speed
	for i: int in 120:
		velocity = movement.compute_velocity(velocity, Vector3.RIGHT, STEP, true, max_speed)
		assert_float(velocity.x).is_less_equal(max_speed + 0.0001)
	assert_float(velocity.x).is_equal_approx(max_speed, 0.0001)


func test_ac12_first_step_follows_acceleration() -> void:
	var movement: MovementComponent = _make_movement()
	var velocity: Vector3 = movement.compute_velocity(Vector3.ZERO, Vector3.RIGHT, 0.1, true, PLAYER_STATS.move_speed)
	var expected: float = minf(PLAYER_TUNING.acceleration * 0.1, PLAYER_STATS.move_speed)
	assert_float(velocity.x).is_equal_approx(expected, 0.0001)


func test_ac12_decelerates_to_zero_without_reversing() -> void:
	var movement: MovementComponent = _make_movement()
	var velocity := Vector3(PLAYER_STATS.move_speed, 0.0, 0.0)
	for i: int in 60:
		velocity = movement.compute_velocity(velocity, Vector3.ZERO, STEP, true, PLAYER_STATS.move_speed)
		assert_float(velocity.x).is_greater_equal(0.0)
	assert_float(velocity.x).is_equal_approx(0.0, 0.0001)


func test_ac12_move_speed_upgrade_raises_top_speed() -> void:
	var movement: MovementComponent = _make_movement()
	var stats: StatsComponent = auto_free(StatsComponent.new())
	stats.base_stats = PLAYER_STATS
	stats.rules = COMBAT_RULES
	var upgrade := UpgradeData.new()
	upgrade.stat = PlayerStats.Stat.MOVE_SPEED
	upgrade.amount = 0.5
	stats.add_upgrade(upgrade)
	var max_speed: float = stats.get_stat(PlayerStats.Stat.MOVE_SPEED)
	var velocity := Vector3.ZERO
	for i: int in 120:
		velocity = movement.compute_velocity(velocity, Vector3.RIGHT, STEP, true, max_speed)
	assert_float(velocity.x).is_equal_approx(6.5, 0.0001)


func test_ac12_vertical_input_is_ignored_and_long_input_is_normalized() -> void:
	var movement: MovementComponent = _make_movement()
	var max_speed: float = PLAYER_STATS.move_speed
	var velocity := Vector3.ZERO
	for i: int in 120:
		velocity = movement.compute_velocity(velocity, Vector3(3.0, 5.0, 4.0), STEP, true, max_speed)
	assert_float(Vector2(velocity.x, velocity.z).length()).is_equal_approx(max_speed, 0.0001)
	assert_float(velocity.y).is_equal_approx(0.0, 0.0001)


func test_ac12_gravity_applies_only_in_the_air() -> void:
	var movement: MovementComponent = _make_movement()
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var airborne: Vector3 = movement.compute_velocity(Vector3.ZERO, Vector3.ZERO, 0.1, false, PLAYER_STATS.move_speed)
	assert_float(airborne.y).is_equal_approx(-gravity * 0.1, 0.0001)
	var landed: Vector3 = movement.compute_velocity(Vector3(0.0, -3.0, 0.0), Vector3.ZERO, 0.1, true, PLAYER_STATS.move_speed)
	assert_float(landed.y).is_equal_approx(0.0, 0.0001)
