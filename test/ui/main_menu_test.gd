extends GdUnitTestSuite

const MAIN_MENU_PATH: String = "res://ui/main_menu.tscn"
const MAIN_MENU_SCENE: PackedScene = preload("res://ui/main_menu.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")

var _menu: MainMenu


func before_test() -> void:
	_menu = auto_free(MAIN_MENU_SCENE.instantiate())
	# Only store the mode: loading the arena would replace the test scene.
	_menu.game_scene_path = ""
	add_child(_menu)


func after_test() -> void:
	Session.mode = GameSession.Mode.NORMAL
	Session.character_class = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_ac107_main_menu_is_the_entry_scene_and_session_is_autoloaded() -> void:
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal(MAIN_MENU_PATH)
	assert_bool(ProjectSettings.has_setting("autoload/Session")).is_true()
	assert_object(Session).is_not_null()


func test_ac108_play_shows_the_modes_and_back_returns() -> void:
	assert_bool(_menu.is_showing_modes()).is_false()
	_menu.show_modes()
	assert_bool(_menu.is_showing_modes()).is_true()
	_menu.show_main()
	assert_bool(_menu.is_showing_modes()).is_false()


func test_ac109_choosing_a_mode_stores_it_in_the_session() -> void:
	var chosen: Array[int] = []
	_menu.mode_chosen.connect(func(mode: GameSession.Mode) -> void: chosen.append(mode))
	_menu.choose_mode(GameSession.Mode.SANDBOX)
	assert_bool(Session.is_sandbox()).is_true()
	_menu.choose_mode(GameSession.Mode.NORMAL)
	assert_bool(Session.is_sandbox()).is_false()
	assert_array(chosen).is_equal([GameSession.Mode.SANDBOX, GameSession.Mode.NORMAL])


func test_ac109_the_menu_loads_the_arena() -> void:
	var fresh: MainMenu = auto_free(MAIN_MENU_SCENE.instantiate())
	assert_bool(ResourceLoader.exists(fresh.game_scene_path)).is_true()
	assert_str(fresh.game_scene_path).is_equal("res://levels/arena/arena.tscn")


func test_ac177_choosing_a_mode_shows_the_classes_and_back_returns_to_modes() -> void:
	_menu.show_modes()
	_menu.choose_mode(GameSession.Mode.SANDBOX)
	assert_bool(Session.is_sandbox()).is_true()
	assert_bool(_menu.is_showing_classes()).is_true()
	assert_bool(_menu.is_showing_modes()).is_false()
	_menu.show_modes()
	assert_bool(_menu.is_showing_modes()).is_true()
	assert_bool(_menu.is_showing_classes()).is_false()


func test_ac178_one_card_per_class_with_title_and_description() -> void:
	assert_array(_menu.get_offered_classes()).is_equal([WARRIOR, BERSERKER, SAMURAI])
	var cards: Array[Button] = _menu.get_class_cards()
	assert_int(cards.size()).is_equal(3)
	for i: int in cards.size():
		var character_class: CharacterClassData = _menu.get_offered_classes()[i]
		assert_bool(cards[i].visible).is_true()
		assert_str(cards[i].text).contains(character_class.title)
		assert_str(cards[i].text).contains(character_class.description)


func test_ac179_choosing_a_class_stores_it_and_keeps_the_mode() -> void:
	var chosen: Array[CharacterClassData] = []
	_menu.class_chosen.connect(func(c: CharacterClassData) -> void: chosen.append(c))
	_menu.choose_mode(GameSession.Mode.SANDBOX)
	_menu.choose_class(WARRIOR)
	assert_object(Session.character_class).is_same(WARRIOR)
	assert_bool(Session.is_sandbox()).is_true()
	assert_array(chosen).is_equal([WARRIOR])


func test_ac179_pressing_the_class_card_chooses_it() -> void:
	_menu.choose_mode(GameSession.Mode.NORMAL)
	_menu.get_class_cards()[0].pressed.emit()
	assert_object(Session.character_class).is_same(WARRIOR)
