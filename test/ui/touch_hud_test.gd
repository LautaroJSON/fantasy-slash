extends GdUnitTestSuite
## docs/specs/mobile-touch-controls.md: the touch controls inside the arena HUD,
## the player driven by them, the pause button and the Android back gesture.

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://ui/main_menu.tscn")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const CONFIG: TouchControlsConfig = preload("res://data/ui/touch_controls_config.tres")
const SLOT_CONFIG: AbilitySlotViewConfig = preload("res://data/ui/ability_slot_view_config.tres")
const ACTIONS: Array[StringName] = [&"attack", &"jump", &"dash", &"ability_basic", &"ability_ultimate", &"pause", &"ui_cancel"]

var _arena: Node3D
var _player: Player
var _hud: Hud
var _monitor: InputDeviceMonitor
var _touch: TouchControls
var _pause: PauseMenu


func before_test() -> void:
	Session.character_class = SAMURAI
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_player = _arena.get_node("Player") as Player
	_hud = _arena.get_node("UI/Hud") as Hud
	_pause = _arena.get_node("UI/PauseMenu") as PauseMenu
	_monitor = _hud.get_node("%InputDeviceMonitor") as InputDeviceMonitor
	_touch = _hud.get_node("%TouchControls") as TouchControls
	await get_tree().process_frame
	(_arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(THRUST)
	_monitor.handle_event(_touch_event(0, Vector2(500.0, 100.0), false))
	await _physics_frames(10)


func after_test() -> void:
	get_tree().paused = false
	Session.character_class = null
	_touch.release_all()
	for action: StringName in ACTIONS:
		Input.action_release(action)
	Input.flush_buffered_events()


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _touch_event(finger: int, point: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = point
	event.pressed = pressed
	return event


func _tap_down(finger: int, action: StringName) -> void:
	_touch.handle_event(_touch_event(finger, _touch.get_button(action).get_global_center(), true))
	Input.flush_buffered_events()


func _tap_up(finger: int) -> void:
	_touch.handle_event(_touch_event(finger, Vector2.ZERO, false))
	Input.flush_buffered_events()


func test_ac716_touch_swaps_the_pc_slots_and_dash_bar_for_the_controls() -> void:
	var slots: Control = _hud.get_node("%AbilitySlots") as Control
	var dash_bar: Control = _hud.get_node("%DashBar") as Control
	assert_bool(_touch.visible).is_true()
	assert_bool(slots.visible).is_false()
	assert_bool(dash_bar.visible).is_false()
	_monitor.handle_event(InputEventKey.new())
	assert_bool(_touch.visible).is_false()
	assert_bool(slots.visible).is_true()
	assert_bool(dash_bar.visible).is_true()
	var gamepad := InputEventJoypadButton.new()
	gamepad.pressed = true
	_monitor.handle_event(gamepad)
	assert_bool(_touch.visible).is_false()
	assert_bool(slots.visible).is_true()


func test_ac716_leaving_touch_releases_a_held_button() -> void:
	_tap_down(0, &"attack")
	assert_bool(Input.is_action_pressed(&"attack")).is_true()
	_monitor.handle_event(InputEventKey.new())
	Input.flush_buffered_events()
	assert_bool(Input.is_action_pressed(&"attack")).is_false()


func test_ac717_the_cluster_slots_mirror_the_pc_slots() -> void:
	var pc_slot: AbilitySlotView = _hud.get_node("%BasicSlot") as AbilitySlotView
	var touch_slot: AbilitySlotView = _touch.get_node("%BasicSlot") as AbilitySlotView
	assert_float(touch_slot.get_radius()).is_equal(CONFIG.side_button_radius)
	assert_bool(_player.basic_ability.try_cast()).is_true()
	pc_slot.advance(0.0)
	touch_slot.advance(0.0)
	assert_float(touch_slot.get_clock_fraction()).is_equal(pc_slot.get_clock_fraction())
	assert_str(touch_slot.get_time_text()).is_equal(pc_slot.get_time_text())
	assert_str(touch_slot.get_time_text()).is_not_empty()


func test_ac717_the_dash_button_shows_the_dash_cooldown() -> void:
	assert_bool(_player.dash.try_dash(Vector3.FORWARD)).is_true()
	await _physics_frames(2)
	_touch.update_dash_cooldown()
	var dash_button: TouchActionButton = _touch.get_button(&"dash")
	assert_float(dash_button.get_cooldown_fraction()).is_equal_approx(clampf(_player.dash.get_cooldown_ratio(), 0.0, 1.0), 0.0001)
	assert_float(dash_button.get_cooldown_fraction()).is_greater(0.0)
	assert_str(dash_button.get_time_text()).is_equal(CooldownText.format(_player.dash.get_cooldown_remaining(), SLOT_CONFIG.cooldown_text))


func test_ac714_a_tap_is_one_strike_and_holding_does_not_repeat() -> void:
	var swings: Array[int] = [0]
	_player.attack.attacked.connect(func(_h: int, _t: float, _c: bool) -> void: swings[0] += 1)
	_tap_down(0, &"attack")
	await _physics_frames(90)
	assert_int(swings[0]).is_equal(1)
	_tap_up(0)
	await _physics_frames(1)
	_tap_down(0, &"attack")
	await _physics_frames(60)
	assert_int(swings[0]).is_equal(2)


func test_ac714_holding_the_basic_button_charges_sheathe_and_lifting_releases_it() -> void:
	_player.basic_ability.equip(SHEATHE)
	_tap_down(0, &"ability_basic")
	await _physics_frames(2)
	assert_bool(_player.basic_ability.is_charging()).is_true()
	_tap_up(0)
	await _physics_frames(2)
	assert_bool(_player.basic_ability.is_charging()).is_false()


## Like B closing the pause (AC379): a finger that lands on dash while the
## game is paused does nothing on resume, even if it stays down; the next
## tap dashes.
func test_ac715_a_dash_touch_during_a_pause_does_not_dash_on_resume() -> void:
	get_tree().paused = true
	await _physics_frames(2)
	_tap_down(0, &"dash")
	get_tree().paused = false
	await _physics_frames(3)
	assert_bool(_player.dash.is_dashing()).is_false()
	_tap_up(0)
	await _physics_frames(1)
	_tap_down(0, &"dash")
	await _physics_frames(2)
	assert_bool(_player.dash.is_dashing()).is_true()


func test_ac723_the_pause_button_opens_the_pause() -> void:
	_tap_down(0, &"pause")
	assert_bool(_pause.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()


func test_ac722_back_gesture_opens_the_pause_in_game_and_closes_it_when_open() -> void:
	Session.handle_go_back()
	Input.flush_buffered_events()
	assert_bool(_pause.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	Session.handle_go_back()
	Input.flush_buffered_events()
	assert_bool(_pause.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_ac722_back_gesture_goes_back_one_panel_in_the_main_menu() -> void:
	var menu: MainMenu = auto_free(MAIN_MENU_SCENE.instantiate()) as MainMenu
	add_child(menu)
	await get_tree().process_frame
	menu.show_classes()
	Session.handle_go_back()
	Input.flush_buffered_events()
	assert_bool(menu.is_showing_modes()).is_true()
