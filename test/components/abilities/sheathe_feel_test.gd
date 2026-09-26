extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const CHARGE_UPGRADE: AbilityUpgradeData = preload("res://data/abilities/sheathe/upgrades/charge_speed.tres")
const FEEDBACK: ChargeFeedbackConfig = preload("res://data/player/charge_feedback_config.tres")
const INDICATOR_CONFIG: AbilityIndicatorConfig = preload("res://data/abilities/sheathe/sheathe_indicator_config.tres")
const THRUST_INDICATOR_CONFIG: AbilityIndicatorConfig = preload("res://data/abilities/thrust/thrust_indicator_config.tres")
const STEP: float = 0.05
const TOLERANCE: float = 0.0001
const YAW_TOLERANCE: float = 0.01

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _visual: Node3D
var _milestones: Array[Vector2i] = []


func before_test() -> void:
	Session.character_class = SAMURAI
	_add_static(TestWorld.make_floor(60.0))
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_visual = _player.get_node("Visual") as Node3D
	_milestones.clear()
	_ability.charge_milestone_reached.connect(_on_milestone)
	await _physics_frames(20)


func after_test() -> void:
	Session.character_class = null
	Input.action_release(&"ability_basic")
	Input.action_release(&"dash")
	Input.action_release(&"move_forward")
	Input.action_release(&"move_left")


## Stored as (index, 1 when full / 0 otherwise).
func _on_milestone(index: int, is_full: bool) -> void:
	_milestones.append(Vector2i(index, 1 if is_full else 0))


func _add_static(body: StaticBody3D) -> void:
	auto_free(body)
	add_child(body)


func _spawn_idle_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


func _equip_by_hand() -> void:
	_ability.set_physics_process(false)
	_ability.equip(SHEATHE)


func _yaw_towards(enemy: Enemy) -> float:
	var to_target: Vector3 = enemy.global_position - _visual.global_position
	return atan2(-to_target.x, -to_target.z)


func _assert_facing(enemy: Enemy) -> void:
	assert_float(angle_difference(_visual.rotation.y, _yaw_towards(enemy))).is_equal_approx(0.0, YAW_TOLERANCE)


func test_ac256_the_slash_reaches_six_meters_at_full_charge() -> void:
	assert_float(SHEATHE.hit_range).is_equal(6.0)
	assert_float(SHEATHE.hit_width).is_equal_approx(1.6, TOLERANCE)
	_equip_by_hand()
	var hits: Array[Enemy] = []
	_ability.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: hits.append(enemy))
	var enemy: Enemy = _spawn_idle_enemy(_player.global_position + Vector3(0.0, 0.0, -5.0))
	_ability.try_cast()
	_ability.release_charge()
	_advance(SHEATHE.cast_duration + STEP)
	assert_bool(hits.has(enemy)).is_false()
	_ability.reset_cooldown()
	_ability.try_cast()
	_advance(SHEATHE.charge_time + STEP)
	_ability.release_charge()
	_advance(SHEATHE.cast_duration + STEP)
	assert_bool(hits.has(enemy)).is_true()


func test_ac257_charging_keeps_facing_the_nearest_enemy_while_walking() -> void:
	_ability.equip(SHEATHE)
	var right: Enemy = _spawn_idle_enemy(_player.global_position + Vector3(4.0, 0.0, 0.0))
	Input.action_press(&"ability_basic")
	await _physics_frames(2)
	assert_bool(_ability.is_charging()).is_true()
	Input.action_press(&"move_forward")
	await _physics_frames(30)
	_assert_facing(right)
	var left: Enemy = _spawn_idle_enemy(_player.global_position + Vector3(-2.0, 0.0, 0.0))
	await _physics_frames(3)
	_assert_facing(left)


func test_ac258_the_facing_survives_a_dash_while_charging() -> void:
	_ability.equip(SHEATHE)
	var enemy: Enemy = _spawn_idle_enemy(_player.global_position + Vector3(4.0, 0.0, 2.0))
	Input.action_press(&"ability_basic")
	await _physics_frames(2)
	Input.action_press(&"move_forward")
	Input.action_press(&"dash")
	await _physics_frames(2)
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await _physics_frames(1)
	assert_bool(_ability.is_charging()).is_true()
	_assert_facing(enemy)


func test_ac259_without_enemies_walking_keeps_the_facing_while_charging() -> void:
	_ability.equip(SHEATHE)
	Input.action_press(&"ability_basic")
	await _physics_frames(2)
	var yaw: float = _visual.rotation.y
	Input.action_press(&"move_left")
	await _physics_frames(30)
	assert_float(Vector2(_player.velocity.x, _player.velocity.z).length()).is_greater(0.0)
	assert_float(angle_difference(_visual.rotation.y, yaw)).is_equal_approx(0.0, TOLERANCE)


func test_ac260_after_the_release_walking_turns_the_player_again() -> void:
	_ability.equip(SHEATHE)
	Input.action_press(&"ability_basic")
	await _physics_frames(2)
	var yaw: float = _visual.rotation.y
	Input.action_release(&"ability_basic")
	await _physics_frames(30)
	assert_bool(_ability.is_casting()).is_false()
	Input.action_press(&"move_left")
	await _physics_frames(30)
	var velocity: Vector3 = _player.velocity
	var walk_yaw: float = atan2(-velocity.x, -velocity.z)
	assert_float(absf(angle_difference(_visual.rotation.y, yaw))).is_greater(0.5)
	assert_float(angle_difference(_visual.rotation.y, walk_yaw)).is_equal_approx(0.0, 0.05)


func test_ac261_one_milestone_per_second_and_one_at_full_charge() -> void:
	_equip_by_hand()
	_ability.try_cast()
	_advance(0.95)
	assert_array(_milestones).is_empty()
	_advance(0.1)
	assert_array(_milestones).is_equal([Vector2i(1, 0)])
	_advance(1.0)
	assert_array(_milestones).is_equal([Vector2i(1, 0), Vector2i(2, 0)])
	_advance(1.0)
	assert_array(_milestones).is_equal([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 1)])
	_advance(2.0)
	assert_int(_milestones.size()).is_equal(3)
	assert_float(FEEDBACK.milestone_interval).is_equal(1.0)


func test_ac261_a_faster_charge_reaches_full_before_the_third_second() -> void:
	_equip_by_hand()
	_ability.add_upgrade(CHARGE_UPGRADE)
	_ability.try_cast()
	_advance(2.65)
	assert_array(_milestones).is_equal([Vector2i(1, 0), Vector2i(2, 0)])
	_advance(0.1)
	assert_array(_milestones).is_equal([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 1)])
	assert_float(_ability.get_charge_ratio()).is_equal(1.0)


func test_ac262_each_milestone_shakes_the_camera_harder() -> void:
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	_equip_by_hand()
	_ability.try_cast()
	_advance(1.0 + STEP)
	assert_float(camera.get_shake_strength()).is_equal_approx(0.25, TOLERANCE)
	camera.stop_shake()
	_advance(1.0)
	assert_float(camera.get_shake_strength()).is_equal_approx(0.40, TOLERANCE)
	camera.stop_shake()
	_advance(1.0)
	assert_float(camera.get_shake_strength()).is_equal_approx(0.8, TOLERANCE)
	assert_float(FEEDBACK.shake_for(2, false)).is_greater(FEEDBACK.shake_for(1, false))


func test_ac263_each_milestone_pulses_the_outline() -> void:
	_equip_by_hand()
	var indicator: AbilityRectIndicator = (_ability.get_behavior() as SheatheAbility).get_indicator()
	_ability.try_cast()
	var resting: float = indicator.get_transparency()
	_advance(1.0 + STEP)
	assert_bool(indicator.is_pulsing()).is_true()
	assert_float(indicator.get_transparency()).is_equal_approx(INDICATOR_CONFIG.pulse_transparency, TOLERANCE)
	indicator.advance(INDICATOR_CONFIG.pulse_duration)
	assert_bool(indicator.is_pulsing()).is_false()
	assert_float(indicator.get_transparency()).is_equal_approx(resting, TOLERANCE)


func test_ac264_each_milestone_makes_the_body_tremble_and_it_returns_to_rest() -> void:
	var feedback: ChargeFeedbackComponent = _player.get_node("ChargeFeedback") as ChargeFeedbackComponent
	var body: Node3D = _player.get_node("Visual/Body") as Node3D
	var rest: Vector3 = body.position
	feedback.set_process(false)
	_equip_by_hand()
	_ability.try_cast()
	_advance(1.0 + STEP)
	feedback.set_process(false)
	assert_bool(feedback.is_trembling()).is_true()
	var quarter_period: float = 1.0 / (4.0 * FEEDBACK.tremor_frequency)
	feedback.advance(quarter_period)
	var first_peak: float = absf(body.position.x - rest.x)
	assert_float(first_peak).is_greater(0.0)
	feedback.advance(FEEDBACK.tremor_duration)
	assert_bool(feedback.is_trembling()).is_false()
	assert_vector(body.position).is_equal(rest)
	assert_float(FEEDBACK.tremor_for(3, true)).is_greater(FEEDBACK.tremor_for(2, false))
	assert_float(FEEDBACK.tremor_for(2, false)).is_greater(FEEDBACK.tremor_for(1, false))


func test_ac266_the_thrust_outline_has_no_pulse() -> void:
	assert_float(THRUST_INDICATOR_CONFIG.pulse_duration).is_equal(0.0)
