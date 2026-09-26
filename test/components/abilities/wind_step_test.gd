extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const WIND_STEP: AbilityUniqueUpgradeData = preload("res://data/abilities/sheathe/unique/wind_step.tres")
const STEP: float = 0.05
const TOLERANCE: float = 0.0001

var _player: Player
var _ability: AbilityComponent
var _milestones: Array[Vector2i] = []


func before_test() -> void:
	Session.character_class = SAMURAI
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = registry
	add_child(_player)
	_ability = _player.basic_ability
	_milestones.clear()
	_ability.charge_milestone_reached.connect(_on_milestone)
	await get_tree().physics_frame


func after_test() -> void:
	Session.character_class = null
	get_tree().paused = false
	Input.action_release(&"ability_basic")
	Input.action_release(&"dash")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Stored as (index, 1 when full / 0 otherwise).
func _on_milestone(index: int, is_full: bool) -> void:
	_milestones.append(Vector2i(index, 1 if is_full else 0))


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


func _equip_by_hand(with_wind_step: bool) -> void:
	_ability.set_physics_process(false)
	_ability.equip(SHEATHE)
	if with_wind_step:
		_player.apply_upgrade(WIND_STEP)


func test_ac278_the_wind_step_card_is_a_binary_sheathe_unique() -> void:
	assert_str(WIND_STEP.id).is_equal("wind_step")
	assert_str(WIND_STEP.title).is_equal("Paso del Viento")
	assert_int(WIND_STEP.max_level).is_equal(1)
	assert_float(WIND_STEP.get_value(1)).is_equal_approx(1.5, TOLERANCE)
	assert_array(SHEATHE.unique_upgrades).contains([WIND_STEP])


func test_ac279_each_dash_while_charging_adds_charge_with_its_milestones() -> void:
	_equip_by_hand(true)
	_ability.try_cast()
	_advance(0.5)
	assert_array(_milestones).is_empty()
	_ability.notify_dash()
	assert_float(_ability.get_charge_ratio()).is_equal_approx(2.0 / 3.0, TOLERANCE)
	assert_array(_milestones).is_equal([Vector2i(1, 0), Vector2i(2, 0)])
	_ability.notify_dash()
	assert_float(_ability.get_charge_ratio()).is_equal(1.0)
	assert_array(_milestones).is_equal([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 1)])
	_ability.notify_dash()
	assert_int(_milestones.size()).is_equal(3)


func test_ac279_a_real_dash_while_charging_adds_the_charge() -> void:
	_ability.equip(SHEATHE)
	_player.apply_upgrade(WIND_STEP)
	Input.action_press(&"ability_basic")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_ability.is_charging()).is_true()
	var before: float = _ability.get_charge_ratio()
	Input.action_press(&"dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_float(_ability.get_charge_ratio()).is_greater_equal(before + 1.5 / SHEATHE.charge_time - TOLERANCE)


func test_ac280_without_the_card_the_dash_adds_no_charge() -> void:
	_equip_by_hand(false)
	_ability.try_cast()
	_advance(0.5)
	_ability.notify_dash()
	assert_float(_ability.get_charge_ratio()).is_equal_approx(0.5 / SHEATHE.charge_time, TOLERANCE)
	assert_array(_milestones).is_empty()


func test_ac281_a_dash_outside_the_charge_changes_nothing() -> void:
	_equip_by_hand(true)
	_ability.notify_dash()
	assert_bool(_ability.is_charging()).is_false()
	assert_float(_ability.get_charge_ratio()).is_equal(0.0)
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	assert_array(_milestones).is_empty()


func test_ac282_the_card_is_pooled_with_sheathe_and_leaves_once_taken() -> void:
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	get_tree().paused = true
	await get_tree().process_frame
	(arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHEATHE)
	var wave_manager: WaveManager = arena.get_node("WaveManager") as WaveManager
	var player: Player = arena.get_node("Player") as Player
	assert_bool(wave_manager.get_available_pool().has(WIND_STEP)).is_true()
	player.apply_upgrade(WIND_STEP)
	assert_bool(player.is_maxed(WIND_STEP)).is_true()
	assert_bool(wave_manager.get_available_pool().has(WIND_STEP)).is_false()
