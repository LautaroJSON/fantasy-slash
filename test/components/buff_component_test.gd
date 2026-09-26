extends GdUnitTestSuite

const CONCUSSION: BuffData = preload("res://data/buffs/concussion.tres")
const TOLERANCE: float = 0.0001

var _buffs: BuffComponent


func before_test() -> void:
	_buffs = auto_free(BuffComponent.new())
	add_child(_buffs)


func test_ac285_ac298_concussion_data() -> void:
	assert_that(CONCUSSION.id).is_equal(&"concussion")
	assert_int(CONCUSSION.max_stacks).is_equal(10)
	assert_float(CONCUSSION.stack_duration).is_equal_approx(2.5, TOLERANCE)
	assert_float(CONCUSSION.get_modifier(BuffModifier.Stat.MOVE_SPEED, 1)).is_equal_approx(0.07, TOLERANCE)
	assert_float(CONCUSSION.get_modifier(BuffModifier.Stat.ABILITY_SPEED, 1)).is_equal_approx(0.05, TOLERANCE)
	assert_float(CONCUSSION.get_modifier(BuffModifier.Stat.CRIT_CHANCE, 1)).is_equal_approx(0.05, TOLERANCE)


func test_ac290_stacks_are_lost_one_at_a_time() -> void:
	for i: int in 3:
		_buffs.add_stack(CONCUSSION)
	assert_int(_buffs.get_stacks(CONCUSSION.id)).is_equal(3)
	assert_float(_buffs.get_time_left(CONCUSSION.id)).is_equal_approx(2.5, TOLERANCE)
	_buffs.advance(2.5)
	assert_int(_buffs.get_stacks(CONCUSSION.id)).is_equal(2)
	_buffs.advance(2.5)
	assert_int(_buffs.get_stacks(CONCUSSION.id)).is_equal(1)
	_buffs.advance(2.5)
	assert_int(_buffs.get_stacks(CONCUSSION.id)).is_equal(0)
	assert_bool(_buffs.get_active().is_empty()).is_true()
	assert_bool(_buffs.is_physics_processing()).is_false()


func test_ac290_a_new_stack_restarts_the_countdown() -> void:
	_buffs.add_stack(CONCUSSION)
	_buffs.add_stack(CONCUSSION)
	_buffs.advance(2.0)
	_buffs.add_stack(CONCUSSION)
	assert_int(_buffs.get_stacks(CONCUSSION.id)).is_equal(3)
	assert_float(_buffs.get_time_left(CONCUSSION.id)).is_equal_approx(2.5, TOLERANCE)
	_buffs.advance(2.0)
	assert_int(_buffs.get_stacks(CONCUSSION.id)).is_equal(3)


func test_ac290_never_past_the_cap() -> void:
	for i: int in 15:
		_buffs.add_stack(CONCUSSION)
	assert_int(_buffs.get_stacks(CONCUSSION.id)).is_equal(10)
	assert_float(_buffs.get_modifier(CONCUSSION.id, BuffModifier.Stat.CRIT_CHANCE)).is_equal_approx(0.5, TOLERANCE)


func test_ac290_modifier_is_zero_when_inactive() -> void:
	assert_float(_buffs.get_modifier(CONCUSSION.id, BuffModifier.Stat.MOVE_SPEED)).is_equal(0.0)
