extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const NUKI: AbilityUniqueUpgradeData = preload("res://data/abilities/sheathe/unique/nuki.tres")
const STEP: float = 0.05
const TOLERANCE: float = 0.0001

var _player: Player
var _ability: AbilityComponent


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
	await get_tree().physics_frame


func after_test() -> void:
	Session.character_class = null
	get_tree().paused = false
	Input.action_release(&"dash")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


func _equip_by_hand(with_nuki: bool) -> void:
	_ability.set_physics_process(false)
	_ability.equip(SHEATHE)
	if with_nuki:
		_player.apply_upgrade(NUKI)


## A tap slash that lands and leaves Envainar on cooldown. Takes CAST_DURATION + STEP.
func _slash() -> void:
	assert_bool(_ability.try_cast()).is_true()
	_ability.release_charge()
	_advance(SHEATHE.cast_duration + STEP)
	assert_bool(_ability.is_on_cooldown()).is_true()


func test_ac311_the_nuki_card_is_a_binary_sheathe_unique_without_value() -> void:
	assert_str(NUKI.id).is_equal("nuki")
	assert_str(NUKI.title).is_equal("Nuki")
	assert_int(NUKI.max_level).is_equal(1)
	assert_array(NUKI.level_values).is_empty()
	# Adapted (sheathe-upgrades-rework.md): Paso del Viento and Zanshin are gone.
	assert_array(SHEATHE.unique_upgrades).contains([NUKI])


func test_ac312_a_dash_on_cooldown_makes_sheathe_ready() -> void:
	_equip_by_hand(true)
	_slash()
	_ability.notify_dash()
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	assert_bool(_ability.is_on_cooldown()).is_false()


func test_ac312_a_real_dash_makes_sheathe_ready() -> void:
	_equip_by_hand(true)
	_slash()
	Input.action_press(&"dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_bool(_ability.is_on_cooldown()).is_false()


func test_ac313_every_dash_on_cooldown_makes_sheathe_ready_again() -> void:
	_equip_by_hand(true)
	_slash()
	_ability.notify_dash()
	assert_bool(_ability.is_on_cooldown()).is_false()
	_slash()
	_ability.notify_dash()
	assert_bool(_ability.is_on_cooldown()).is_false()


func test_ac314_a_dash_while_ready_changes_nothing() -> void:
	_equip_by_hand(true)
	_ability.notify_dash()
	assert_bool(_ability.is_on_cooldown()).is_false()
	assert_bool(_ability.is_casting()).is_false()


func test_ac314_a_dash_while_charging_changes_nothing() -> void:
	_equip_by_hand(true)
	_ability.try_cast()
	_ability.notify_dash()
	assert_bool(_ability.is_charging()).is_true()
	assert_bool(_ability.is_on_cooldown()).is_false()


func test_ac315_without_the_card_a_dash_keeps_the_cooldown() -> void:
	_equip_by_hand(false)
	_slash()
	var before: float = _ability.get_cooldown_ratio()
	_ability.notify_dash()
	assert_float(_ability.get_cooldown_ratio()).is_equal(before)


func test_ac316_the_card_is_pooled_with_sheathe_and_leaves_once_taken() -> void:
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	get_tree().paused = true
	await get_tree().process_frame
	(arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHEATHE)
	var wave_manager: WaveManager = arena.get_node("WaveManager") as WaveManager
	var player: Player = arena.get_node("Player") as Player
	assert_bool(wave_manager.get_available_pool().has(NUKI)).is_true()
	player.apply_upgrade(NUKI)
	assert_bool(player.is_maxed(NUKI)).is_true()
	assert_bool(wave_manager.get_available_pool().has(NUKI)).is_false()
