extends GdUnitTestSuite
## docs/specs/gamepad-support.md: HUD prompts follow the last input device.

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")

var _arena: Node3D
var _player: Player
var _monitor: InputDeviceMonitor
var _basic_slot: AbilitySlotView
var _ultimate_slot: AbilitySlotView


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_player = _arena.get_node("Player") as Player
	var hud: Hud = _arena.get_node("UI/Hud") as Hud
	_monitor = hud.get_node("%InputDeviceMonitor") as InputDeviceMonitor
	_basic_slot = hud.get_node("%BasicSlot") as AbilitySlotView
	_ultimate_slot = hud.get_node("%UltimateSlot") as AbilitySlotView
	await get_tree().process_frame
	(_arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHIELD_CHARGE)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _gamepad_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func test_ac373_slots_start_with_the_keys() -> void:
	assert_str(_basic_slot.get_prompt_text()).is_equal("E")
	assert_str(_ultimate_slot.get_prompt_text()).is_equal("R")


func test_ac373_slots_follow_the_last_device() -> void:
	_monitor.handle_event(_gamepad_event())
	assert_str(_basic_slot.get_prompt_text()).is_equal("LB")
	assert_str(_ultimate_slot.get_prompt_text()).is_equal("RT")
	_monitor.handle_event(InputEventKey.new())
	assert_str(_basic_slot.get_prompt_text()).is_equal("E")
	assert_str(_ultimate_slot.get_prompt_text()).is_equal("R")


func test_ac373_the_prompt_stays_hidden_during_the_cooldown() -> void:
	assert_bool(_player.basic_ability.try_cast()).is_true()
	_basic_slot.advance(0.0)
	assert_bool(_basic_slot.is_key_visible()).is_false()
	_monitor.handle_event(_gamepad_event())
	assert_bool(_basic_slot.is_key_visible()).is_false()
	_player.basic_ability.reset_cooldown()
	_basic_slot.advance(0.0)
	assert_bool(_basic_slot.is_key_visible()).is_true()
	assert_str(_basic_slot.get_prompt_text()).is_equal("LB")
