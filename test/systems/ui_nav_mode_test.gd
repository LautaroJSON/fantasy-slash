extends GdUnitTestSuite
## The focus frame of menu cards only shows when navigating with keyboard or gamepad
## (docs/specs/upgrade-cards-redesign.md, AC1441-AC1443).

const ROLLS: RollConfig = preload("res://data/upgrades/roll_config.tres")
const DAMAGE: UpgradeData = preload("res://data/upgrades/damage.tres")
const PICKER_SCENE: PackedScene = preload("res://ui/upgrade_picker.tscn")
const MENU_SCENE: PackedScene = preload("res://ui/main_menu.tscn")


func after_test() -> void:
	UiNav.set_navigating(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _focus_style(button: Control) -> StyleBox:
	return button.get_theme_stylebox(&"focus")


func _nav_key(action: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_ac1441_the_mode_follows_navigation_actions_and_the_mouse() -> void:
	assert_bool(UiNav.is_navigating()).is_false()
	UiNav.handle_event(_nav_key(&"ui_down"))
	assert_bool(UiNav.is_navigating()).is_true()
	UiNav.handle_event(InputEventMouseMotion.new())
	assert_bool(UiNav.is_navigating()).is_false()
	UiNav.handle_event(_nav_key(&"ui_accept"))
	assert_bool(UiNav.is_navigating()).is_true()
	UiNav.handle_event(InputEventMouseButton.new())
	assert_bool(UiNav.is_navigating()).is_false()


func test_ac1442_upgrade_cards_draw_no_focus_frame_until_the_player_navigates() -> void:
	var picker: UpgradePicker = auto_free(PICKER_SCENE.instantiate()) as UpgradePicker
	picker.rolls = ROLLS
	add_child(picker)
	var offer: Array[UpgradeCard] = [DAMAGE.rolled(0)]
	picker.show_offer(offer, false)
	var card: Button = picker.get_card_buttons()[0]
	assert_bool(card.has_focus()).is_true()
	assert_object(_focus_style(card)).is_instanceof(StyleBoxEmpty)
	UiNav.set_navigating(true)
	var frame: StyleBoxFlat = _focus_style(card) as StyleBoxFlat
	assert_object(frame).is_not_null()
	assert_int(frame.border_width_left).is_equal(picker.config.focus_border_width)
	UiNav.set_navigating(false)
	assert_object(_focus_style(card)).is_instanceof(StyleBoxEmpty)


func test_ac1443_menu_cards_and_buttons_follow_the_same_rule() -> void:
	var menu: MainMenu = auto_free(MENU_SCENE.instantiate()) as MainMenu
	add_child(menu)
	var card: Button = menu.get_class_cards()[0]
	assert_object(_focus_style(card)).is_instanceof(StyleBoxEmpty)
	UiNav.set_navigating(true)
	assert_bool(card.has_theme_stylebox_override(&"focus")).is_false()
	UiNav.set_navigating(false)
	assert_object(_focus_style(card)).is_instanceof(StyleBoxEmpty)
