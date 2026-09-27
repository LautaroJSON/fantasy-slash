extends GdUnitTestSuite
## Sprint state (docs/specs/sprint-stamina.md): AC703, AC709, AC761-AC764 and AC768.

const SAMURAI_STATS: PlayerStats = preload("res://data/classes/samurai/samurai_stats.tres")
const RULES: CombatRules = preload("res://data/combat/combat_rules.tres")
const CONFIG: SprintConfig = preload("res://data/player/sprint_config.tres")

var _stats: StatsComponent
var _stamina: StaminaComponent
var _sprint: SprintComponent


func before_test() -> void:
	_stats = auto_free(StatsComponent.new())
	_stats.base_stats = SAMURAI_STATS
	_stats.rules = RULES
	add_child(_stats)
	_stamina = auto_free(StaminaComponent.new())
	_stamina.stats = _stats
	_stamina.config = CONFIG
	_stamina.set_physics_process(false)
	add_child(_stamina)
	_sprint = auto_free(SprintComponent.new())
	_sprint.stats = _stats
	_sprint.stamina = _stamina
	_sprint.config = CONFIG
	_sprint.set_physics_process(false)
	add_child(_sprint)


func test_ac703_double_tap_window() -> void:
	assert_float(CONFIG.double_tap_window).is_equal(0.3)
	assert_bool(SprintComponent.is_double_tap(1.0, 1.25, CONFIG.double_tap_window)).is_true()
	assert_bool(SprintComponent.is_double_tap(1.0, 1.35, CONFIG.double_tap_window)).is_false()
	assert_bool(SprintComponent.is_double_tap(-INF, 0.0, CONFIG.double_tap_window)).is_false()


func test_ac703_a_third_tap_starts_a_new_pair() -> void:
	# Adapted (§12): register_forward_tap() became register_tap(action).
	assert_bool(_sprint.register_tap(&"move_forward")).is_false()
	assert_bool(_sprint.register_tap(&"move_forward")).is_true()
	assert_bool(_sprint.register_tap(&"move_forward")).is_false()


func test_ac709_sprinting_spends_the_cost_per_second() -> void:
	assert_bool(_sprint.try_start(false)).is_true()
	for i: int in 10:
		_sprint.drain(0.1)
	assert_float(_stamina.get_current()).is_equal_approx(80.0, 0.5)
	assert_float(_sprint.get_speed_factor()).is_equal(1.6)


func test_ac709_not_sprinting_spends_nothing() -> void:
	_sprint.drain(1.0)
	assert_float(_stamina.get_current()).is_equal(100.0)
	assert_float(_sprint.get_speed_factor()).is_equal(1.0)


func test_ac761_an_empty_bar_leaves_the_sprint_winded() -> void:
	_sprint.try_start(false)
	_sprint.drain(10.0)
	assert_float(_stamina.get_current()).is_equal(0.0)
	assert_bool(_sprint.is_sprinting()).is_true()
	assert_bool(_sprint.is_winded()).is_true()
	assert_bool(_sprint.is_running()).is_false()
	assert_float(_sprint.get_speed_factor()).is_equal(1.0)


func test_ac762_winded_it_runs_again_at_the_start_threshold() -> void:
	_sprint.try_start(false)
	_sprint.drain(10.0)
	_stamina.advance(CONFIG.stamina_regen_delay - 0.05)
	_stamina.advance(0.4)  # regenerates 10
	_sprint.drain(0.1)
	assert_float(_stamina.get_current()).is_equal_approx(10.0, 0.01)
	assert_bool(_sprint.is_winded()).is_true()
	_stamina.advance(0.41)  # back past the 20 needed to run
	_sprint.drain(0.0)
	assert_bool(_sprint.is_running()).is_true()
	assert_float(_sprint.get_speed_factor()).is_equal(1.6)


func test_ac763_stopping_clears_the_winded_state() -> void:
	_sprint.try_start(false)
	_sprint.drain(10.0)
	_sprint.stop()
	assert_bool(_sprint.is_winded()).is_false()
	assert_bool(_sprint.is_running()).is_false()


func test_ac764_winded_drain_spends_nothing_and_keeps_the_regen() -> void:
	_sprint.try_start(false)
	_sprint.drain(10.0)
	var changes: Array[float] = []
	_stamina.stamina_changed.connect(func(current: float, _maximum: float) -> void: changes.append(current))
	_stamina.advance(CONFIG.stamina_regen_delay - 0.2)
	_sprint.drain(0.1)
	assert_array(changes).is_empty()
	_stamina.advance(0.3)
	assert_float(_stamina.get_current()).is_greater(0.0)


func test_ac768_two_different_directions_are_not_a_double_tap() -> void:
	assert_bool(_sprint.register_tap(&"move_left")).is_false()
	assert_bool(_sprint.register_tap(&"move_right")).is_false()
	assert_bool(_sprint.register_tap(&"move_right")).is_true()
