extends GdUnitTestSuite
## Sprint and stamina on the real player (docs/specs/sprint-stamina.md):
## AC698, AC704-AC709, AC712, AC714; revision §11: AC757-AC763 (AC710, AC711
## and AC713 were replaced by it); revision §12: AC765-AC768.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const CLASS_STATS: Array[PlayerStats] = [
	preload("res://data/classes/warrior/warrior_stats.tres"),
	preload("res://data/classes/berserker/berserker_stats.tres"),
	preload("res://data/classes/samurai/samurai_stats.tres"),
]
const CONFIG: SprintConfig = preload("res://data/player/sprint_config.tres")
const ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"dash", &"jump", &"attack"]
const SPEED_TOLERANCE: float = 0.3

var _registry: EnemyRegistry
var _player: Player
var _started: Array[bool] = []


func before_test() -> void:
	_release_all()
	_started.clear()
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(200.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	Session.character_class = SAMURAI
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_player.sprint.sprint_started.connect(func(from_dash: bool) -> void: _started.append(from_dash))
	await _physics_frames(10)


func after_test() -> void:
	_release_all()
	Session.character_class = null


func _release_all() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await _physics_frames(ceili(seconds * Engine.physics_ticks_per_second))


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


## W, W: the second press stays held.
func _double_tap_forward() -> void:
	Input.action_press(&"move_forward")
	await _physics_frames(2)
	Input.action_release(&"move_forward")
	await _physics_frames(2)
	Input.action_press(&"move_forward")
	await _physics_frames(2)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	Input.action_release(action)


func _move_speed() -> float:
	return _player.stats.get_stat(PlayerStats.Stat.MOVE_SPEED)


func test_ac698_stamina_and_sprint_stats_of_every_class() -> void:
	for stats: PlayerStats in CLASS_STATS:
		assert_float(stats.get_base(PlayerStats.Stat.STAMINA_MAX)).is_equal(100.0)
		assert_float(stats.get_base(PlayerStats.Stat.STAMINA_REGEN)).is_equal(25.0)
		assert_float(stats.get_base(PlayerStats.Stat.SPRINT_STAMINA_COST)).is_equal(20.0)
		assert_float(stats.get_base(PlayerStats.Stat.SPRINT_SPEED_FACTOR)).is_equal(1.6)


func test_ac704_forward_double_tap_starts_the_sprint() -> void:
	await _double_tap_forward()
	assert_bool(_player.is_sprinting()).is_true()
	assert_array(_started).is_equal([false])


func test_ac704_two_slow_taps_do_not() -> void:
	Input.action_press(&"move_forward")
	await _physics_frames(2)
	Input.action_release(&"move_forward")
	await _seconds(CONFIG.double_tap_window + 0.1)
	Input.action_press(&"move_forward")
	await _physics_frames(2)
	assert_bool(_player.is_sprinting()).is_false()


func test_ac705_not_enough_stamina() -> void:
	_player.stamina.spend(_player.stamina.get_max() - CONFIG.stamina_to_start_sprint + 1.0)
	await _double_tap_forward()
	assert_bool(_player.is_sprinting()).is_false()


func test_ac705_not_in_the_air() -> void:
	await _tap(&"jump")
	await _physics_frames(2)
	assert_bool(_player.is_on_floor()).is_false()
	await _double_tap_forward()
	assert_bool(_player.is_sprinting()).is_false()


func test_ac705_not_during_a_committed_strike() -> void:
	await _tap(&"attack")
	assert_bool(_player.attack.is_committed()).is_true()
	Input.action_press(&"sprint")
	await _physics_frames(2)
	assert_bool(_player.attack.is_committed()).is_true()
	assert_bool(_player.is_sprinting()).is_false()


func test_ac706_the_sprint_action_starts_it_and_does_not_toggle_it() -> void:
	Input.action_press(&"move_forward")
	await _tap(&"sprint")
	await _physics_frames(2)
	assert_bool(_player.is_sprinting()).is_true()
	await _tap(&"sprint")
	await _physics_frames(2)
	assert_bool(_player.is_sprinting()).is_true()


func test_ac707_a_dash_with_forward_held_goes_on_as_a_sprint() -> void:
	Input.action_press(&"move_forward")
	await _physics_frames(2)
	await _tap(&"dash")
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await _physics_frames(1)
	assert_bool(_player.is_sprinting()).is_true()
	assert_array(_started).is_equal([true])


func test_ac707_without_forward_the_dash_does_not() -> void:
	await _tap(&"dash")
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await _physics_frames(1)
	assert_bool(_player.is_sprinting()).is_false()


func test_ac708_sprint_top_speed() -> void:
	Input.action_press(&"move_forward")
	await _seconds(1.0)
	assert_float(_horizontal_speed()).is_equal_approx(_move_speed(), SPEED_TOLERANCE)
	Input.action_release(&"move_forward")
	await _double_tap_forward()
	await _seconds(1.0)
	assert_float(_move_speed() * 1.6).is_equal_approx(10.4, 0.01)
	assert_float(_horizontal_speed()).is_equal_approx(_move_speed() * 1.6, SPEED_TOLERANCE)


func test_ac709_sprinting_spends_stamina_but_the_dash_does_not() -> void:
	await _double_tap_forward()
	await _seconds(1.0)
	assert_float(_player.stamina.get_current()).is_equal_approx(80.0, 1.0)
	await _tap(&"dash")
	var before: float = _player.stamina.get_current()
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	assert_float(_player.stamina.get_current()).is_equal_approx(before, 0.4)


func test_ac712_a_strike_stops_it_for_good() -> void:
	await _double_tap_forward()
	await _tap(&"attack")
	assert_bool(_player.is_sprinting()).is_false()
	while _player.attack.is_attacking():
		await get_tree().physics_frame
	await _physics_frames(2)
	assert_bool(_player.is_sprinting()).is_false()


func test_ac712_a_hold_stops_it() -> void:
	await _double_tap_forward()
	_player.begin_hold(0.2)
	assert_bool(_player.is_sprinting()).is_false()


func test_ac714_a_new_run_starts_full_and_walking() -> void:
	assert_float(_player.stamina.get_current()).is_equal(_player.stamina.get_max())
	assert_bool(_player.is_sprinting()).is_false()


func test_ac757_letting_go_of_forward_while_moving_keeps_it() -> void:
	await _double_tap_forward()
	Input.action_press(&"move_right")
	Input.action_release(&"move_forward")
	await _seconds(1.0)
	assert_bool(_player.is_running()).is_true()
	assert_float(_horizontal_speed()).is_equal_approx(_move_speed() * 1.6, SPEED_TOLERANCE)


func test_ac758_standing_still_stops_it() -> void:
	await _double_tap_forward()
	Input.action_release(&"move_forward")
	await _physics_frames(2)
	assert_bool(_player.is_sprinting()).is_false()
	Input.action_press(&"move_forward")
	await _seconds(1.0)
	assert_bool(_player.is_sprinting()).is_false()
	assert_float(_horizontal_speed()).is_equal_approx(_move_speed(), SPEED_TOLERANCE)


func test_ac759_jumping_stops_it() -> void:
	await _double_tap_forward()
	await _tap(&"jump")
	assert_bool(_player.is_sprinting()).is_false()
	while not _player.is_on_floor():
		await get_tree().physics_frame
	await _physics_frames(2)
	assert_bool(_player.is_sprinting()).is_false()


func test_ac760_damage_stops_it_but_not_during_the_dash() -> void:
	await _double_tap_forward()
	await _tap(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	_player.health.receive_hit(5.0)
	assert_bool(_player.is_sprinting()).is_true()
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await _physics_frames(1)
	assert_float(_player.health.receive_hit(5.0)).is_greater(0.0)
	assert_bool(_player.is_sprinting()).is_false()


func test_ac761_an_empty_bar_leaves_it_winded_at_walking_speed() -> void:
	await _double_tap_forward()
	_player.stamina.spend(_player.stamina.get_current() - 1.0)
	await _seconds(0.2)
	assert_float(_player.stamina.get_current()).is_equal(0.0)
	assert_bool(_player.is_sprinting()).is_true()
	assert_bool(_player.sprint.is_winded()).is_true()
	await _seconds(0.6)
	assert_float(_player.stamina.get_current()).is_equal(0.0)
	assert_float(_horizontal_speed()).is_equal_approx(_move_speed(), SPEED_TOLERANCE)
	var humanoid: LowPolyHumanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	assert_str(String(humanoid.anim.current_animation)).is_equal("run")


func test_ac762_winded_it_runs_again_once_recovered() -> void:
	await _double_tap_forward()
	_player.stamina.spend(_player.stamina.get_current())
	await _seconds(CONFIG.stamina_regen_delay + CONFIG.stamina_to_start_sprint / 25.0 + 0.2)
	assert_bool(_player.is_running()).is_true()
	await _seconds(0.6)
	assert_float(_horizontal_speed()).is_equal_approx(_move_speed() * 1.6, SPEED_TOLERANCE)


func test_ac763_winded_the_sprint_still_ends_for_good() -> void:
	await _double_tap_forward()
	_player.stamina.spend(_player.stamina.get_current())
	await _physics_frames(2)
	assert_bool(_player.sprint.is_winded()).is_true()
	await _tap(&"jump")
	assert_bool(_player.is_sprinting()).is_false()
	await _seconds(CONFIG.stamina_regen_delay + CONFIG.stamina_to_start_sprint / 25.0 + 0.3)
	assert_bool(_player.is_sprinting()).is_false()


## Double tap of `action`: the second press stays held.
func _double_tap(action: StringName) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	Input.action_release(action)
	await _physics_frames(2)
	Input.action_press(action)
	await _physics_frames(2)


func _dash_holding(action: StringName) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	await _tap(&"dash")
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await _physics_frames(1)


func test_ac765_a_dash_while_moving_any_way_goes_on_as_a_sprint() -> void:
	for action: StringName in [&"move_back", &"move_left", &"move_right"]:
		await _dash_holding(action)
		assert_bool(_player.is_running()).override_failure_message(String(action)).is_true()
		await _seconds(0.6)
		assert_float(_horizontal_speed()).override_failure_message(String(action)).is_equal_approx(_move_speed() * 1.6, SPEED_TOLERANCE)
		Input.action_release(action)
		await _physics_frames(2)
		assert_bool(_player.is_sprinting()).is_false()
		while _player.dash.get_cooldown_remaining() > 0.0:
			await get_tree().physics_frame
	assert_array(_started).is_equal([true, true, true])


func test_ac766_a_dash_without_movement_or_cut_by_an_ability_does_not() -> void:
	await _tap(&"dash")
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await _physics_frames(1)
	assert_bool(_player.is_sprinting()).is_false()
	Input.action_press(&"move_left")
	await _physics_frames(2)
	await _tap(&"dash")
	_player.dash.cancel()
	await _physics_frames(2)
	assert_bool(_player.is_sprinting()).is_false()


func test_ac767_double_tap_any_direction() -> void:
	for action: StringName in [&"move_left", &"move_back", &"move_right"]:
		await _double_tap(action)
		assert_bool(_player.is_running()).override_failure_message(String(action)).is_true()
		await _seconds(0.6)
		assert_float(_horizontal_speed()).is_equal_approx(_move_speed() * 1.6, SPEED_TOLERANCE)
		Input.action_release(action)
		await _seconds(0.4)
		assert_bool(_player.is_sprinting()).is_false()


func test_ac768_left_then_right_does_not_start_it() -> void:
	Input.action_press(&"move_left")
	await _physics_frames(2)
	Input.action_release(&"move_left")
	await _physics_frames(2)
	Input.action_press(&"move_right")
	await _physics_frames(4)
	assert_bool(_player.is_sprinting()).is_false()
