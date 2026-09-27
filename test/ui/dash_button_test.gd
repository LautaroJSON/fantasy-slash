extends GdUnitTestSuite
## Dash button in the HUD (docs/specs/dash-button.md): AC769-AC775.

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const SLOT_CONFIG: AbilitySlotViewConfig = preload("res://data/ui/ability_slot_view_config.tres")
const PROMPTS: InputPromptConfig = preload("res://data/ui/input_prompt_config.tres")
const TOLERANCE: float = 0.0001

var _arena: Node3D
var _player: Player
var _hud: Hud
var _slot: AbilitySlotView


## The ability picker stays open (tree paused), so nothing advances on its own.
func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_player = _arena.get_node("Player") as Player
	_hud = _arena.get_node("UI/Hud") as Hud
	_slot = _hud.get_node("%DashSlot") as AbilitySlotView
	get_tree().paused = true
	await get_tree().process_frame


func after_test() -> void:
	get_tree().paused = false
	Input.action_release(&"dash")
	Input.action_release(&"ability_basic")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _touch(slot: AbilitySlotView, position: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = position
	touch.pressed = pressed
	slot._gui_input(touch)


func _centre(slot: AbilitySlotView) -> Vector2:
	return Vector2(slot.get_radius(), slot.get_radius())


func test_ac769_the_dash_is_a_button_left_of_e() -> void:
	assert_object(_hud.get_node_or_null("%DashBar")).is_null()
	assert_object(_hud.get_node_or_null("%DashLabel")).is_null()
	var slots: Node = _hud.get_node("AbilitySlots")
	assert_object(slots.get_child(0)).is_same(_slot)
	assert_str(String(slots.get_child(1).name)).is_equal("BasicSlot")
	assert_float(_slot.get_radius()).is_equal(SLOT_CONFIG.basic_radius)
	assert_float(_slot.global_position.x).is_less((_hud.get_node("%BasicSlot") as Control).global_position.x)


func test_ac770_ready_it_shows_the_dash_prompt() -> void:
	assert_str(PROMPTS.get_prompt(&"dash", InputDeviceMonitor.Device.KEYBOARD_MOUSE)).is_equal("Clic D")
	assert_str(PROMPTS.get_prompt(&"dash", InputDeviceMonitor.Device.GAMEPAD)).is_equal("B")
	var monitor: InputDeviceMonitor = _hud.get_node("%InputDeviceMonitor") as InputDeviceMonitor
	assert_str(_slot.get_prompt_text()).is_equal(PROMPTS.get_prompt(&"dash", monitor.get_device()))
	_slot.advance(0.0)
	assert_bool(_slot.is_key_visible()).is_true()
	assert_float(_slot.get_clock_fraction()).is_equal(0.0)


func test_ac771_the_cooldown_shows_seconds_and_the_clock() -> void:
	assert_bool(_player.dash.try_dash(Vector3.FORWARD)).is_true()
	_slot.advance(0.0)
	assert_str(_slot.get_time_text()).is_equal("1.5")
	assert_bool(_slot.is_key_visible()).is_false()
	_player.dash.advance_timers(0.7)
	_slot.advance(0.0)
	assert_str(_slot.get_time_text()).is_equal("0.8")
	assert_float(_slot.get_shown_ratio()).is_equal_approx(0.8 / 1.5, TOLERANCE)
	assert_float(_slot.get_clock_fraction()).is_equal_approx(0.8 / 1.5, TOLERANCE)
	_player.dash.advance_timers(1.0)
	_slot.advance(0.0)
	assert_bool(_slot.is_key_visible()).is_true()
	assert_float(_slot.get_clock_fraction()).is_equal(0.0)


func test_ac772_it_pulses_when_ready_again() -> void:
	_player.dash.try_dash(Vector3.FORWARD)
	_slot.advance(0.0)
	_player.dash.advance_timers(2.0)
	_slot.advance(0.0)
	assert_bool(_slot.is_pulsing()).is_true()


func test_ac773_never_locked_charging_or_empowered() -> void:
	for step: int in 2:
		_slot.advance(0.0)
		assert_bool(_slot.is_locked()).is_false()
		assert_bool(_slot.is_showing_charge()).is_false()
		assert_bool(_slot.is_showing_empowered()).is_false()
		_player.dash.try_dash(Vector3.FORWARD)


func test_ac774_a_touch_presses_dash_and_the_player_dashes() -> void:
	get_tree().paused = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	_touch(_slot, _centre(_slot), true)
	assert_bool(_slot.is_touch_held()).is_true()
	assert_bool(Input.is_action_pressed(&"dash")).is_true()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_player.dash.get_cooldown_remaining()).is_greater(0.0)
	_touch(_slot, _centre(_slot), false)
	assert_bool(_slot.is_touch_held()).is_false()
	assert_bool(Input.is_action_pressed(&"dash")).is_false()


func test_ac775_outside_mouse_or_other_buttons_press_nothing() -> void:
	_touch(_slot, _centre(_slot) + Vector2(_slot.get_radius() + 2.0, 0.0), true)
	assert_bool(Input.is_action_pressed(&"dash")).is_false()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _centre(_slot)
	_slot._gui_input(click)
	assert_bool(Input.is_action_pressed(&"dash")).is_false()
	var basic: AbilitySlotView = _hud.get_node("%BasicSlot") as AbilitySlotView
	assert_str(String(basic.touch_action)).is_empty()
	_touch(basic, _centre(basic), true)
	assert_bool(Input.is_action_pressed(&"ability_basic")).is_false()
	assert_bool(basic.is_touch_held()).is_false()
