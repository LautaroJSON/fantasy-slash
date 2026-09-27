extends GdUnitTestSuite
## Sprint input and the stamina bar (docs/specs/sprint-stamina.md): AC719-AC720,
## and AC777 (docs/specs/dash-button.md).

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const STAMINA_STYLE: PlayerHealthBarStyle = preload("res://data/ui/player_stamina_bar_style.tres")
const PROMPTS: InputPromptConfig = preload("res://data/ui/input_prompt_config.tres")
const DISPLAY_TABLE: StatDisplayTable = preload("res://data/ui/stat_display_table.tres")

var _arena: Node3D
var _player: Player
var _hud: Hud


## The ability picker stays open (tree paused), so no enemy spawns or hits.
func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_player = _arena.get_node("Player") as Player
	_hud = _arena.get_node("UI/Hud") as Hud
	get_tree().paused = true
	await get_tree().process_frame


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _has_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.physical_keycode == key:
			return true
	return false


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
		if joy_event != null and joy_event.button_index == button:
			return true
	return false


func test_ac719_sprint_bindings_guard_and_prompts() -> void:
	assert_bool(_has_key(&"sprint", KEY_SHIFT)).is_true()
	assert_bool(_has_joy_button(&"sprint", JOY_BUTTON_LEFT_STICK)).is_true()
	var guard: HeldInputGuard = _player.get("_input_guard") as HeldInputGuard
	var guarded: Array = guard.get("_actions")
	assert_bool(guarded.has(&"sprint")).is_true()
	assert_bool(guarded.has(&"move_forward")).is_true()
	assert_str(PROMPTS.get_prompt(&"sprint", InputDeviceMonitor.Device.KEYBOARD_MOUSE)).is_equal("Shift")
	assert_str(PROMPTS.get_prompt(&"sprint", InputDeviceMonitor.Device.GAMEPAD)).is_equal("L3")


func test_ac777_yellow_stamina_bar_alone_bottom_left() -> void:
	# Replaces the "under the dash bar" part of AC720 (docs/specs/dash-button.md).
	assert_object(_hud.get_node_or_null("%DashBar")).is_null()
	var stamina_bar: ProgressBar = _hud.get_node("%StaminaBar") as ProgressBar
	assert_that(STAMINA_STYLE.fill_color).is_equal(Color(1.0, 0.9, 0.2))
	assert_that((stamina_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color).is_equal(STAMINA_STYLE.fill_color)
	assert_float(stamina_bar.anchor_left).is_equal(0.0)
	assert_float(stamina_bar.anchor_top).is_equal(1.0)
	assert_float(stamina_bar.offset_left).is_equal(16.0)
	assert_float(stamina_bar.offset_bottom).is_equal(-16.0)
	assert_vector(stamina_bar.size).is_equal(Vector2(150.0, 12.0))


func test_ac720_the_bar_follows_the_stamina() -> void:
	var stamina_bar: ProgressBar = _hud.get_node("%StaminaBar") as ProgressBar
	assert_float(stamina_bar.value).is_equal(stamina_bar.max_value)
	_player.stamina.spend(40.0)
	assert_float(stamina_bar.max_value).is_equal(100.0)
	assert_float(stamina_bar.value).is_equal(60.0)


func test_ac720_pause_shows_the_max_stamina() -> void:
	var row: StatDisplay = DISPLAY_TABLE.find(PlayerStats.Stat.STAMINA_MAX)
	assert_object(row).is_not_null()
	assert_str(row.label).is_equal("Estamina máxima")
	assert_str(row.format_value(_player.stats.get_stat(PlayerStats.Stat.STAMINA_MAX))).is_equal("100")
