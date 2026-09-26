extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const HELD_ACTIONS: Array[StringName] = [&"dash", &"jump", &"ability_basic"]

var _player: Player


func before_test() -> void:
	_release_all()
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	Session.character_class = SAMURAI
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = registry
	add_child(_player)
	await _physics_frames(10)


func after_test() -> void:
	get_tree().paused = false
	Session.character_class = null
	_release_all()


func _release_all() -> void:
	for action: StringName in HELD_ACTIONS:
		Input.action_release(action)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Pauses the tree, then presses `action` and resumes on the same frame, like B
## closing the pause (ui_cancel) or A choosing a card.
func _press_during_pause(action: StringName) -> void:
	get_tree().paused = true
	await _physics_frames(2)
	Input.action_press(action)
	get_tree().paused = false
	await _physics_frames(2)


func test_ac379_closing_the_pause_with_the_dash_button_does_not_dash() -> void:
	await _press_during_pause(&"dash")
	assert_bool(_player.dash.is_dashing()).is_false()
	Input.action_release(&"dash")
	await _physics_frames(1)
	Input.action_press(&"dash")
	await _physics_frames(2)
	assert_bool(_player.dash.is_dashing()).is_true()


func test_ac379_choosing_a_card_with_the_jump_button_does_not_jump() -> void:
	await _press_during_pause(&"jump")
	await _physics_frames(3)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.velocity.y).is_less_equal(0.0)


func test_ac379_a_charge_released_during_the_pause_is_let_go_on_resume() -> void:
	_player.basic_ability.equip(SHEATHE)
	Input.action_press(&"ability_basic")
	await _physics_frames(2)
	assert_bool(_player.basic_ability.is_charging()).is_true()
	get_tree().paused = true
	await _physics_frames(2)
	Input.action_release(&"ability_basic")
	get_tree().paused = false
	await _physics_frames(2)
	assert_bool(_player.basic_ability.is_charging()).is_false()
