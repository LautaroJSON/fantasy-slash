class_name MainMenu
extends Control
## Entry screen: "Jugar" opens the game mode choice (Normal / Sandbox), then the
## class choice (one card per class). Mode and class are stored in Session and
## the arena is loaded; the ability choice happens there, from the class pool.
## Each panel focuses its first button (gamepad) and `ui_cancel` goes back one panel.

signal mode_chosen(mode: GameSession.Mode)
signal class_chosen(character_class: CharacterClassData)

const ACTION_BACK: StringName = &"ui_cancel"

## Arena scene. Empty = only store the choices (used by tests).
@export_file("*.tscn") var game_scene_path: String
@export var class_catalog: ClassCatalog

@onready var _main_panel: Control = %MainPanel
@onready var _mode_panel: Control = %ModePanel
@onready var _class_panel: Control = %ClassPanel
@onready var _play_button: Button = %PlayButton
@onready var _normal_button: Button = %NormalButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _back_button: Button = %BackButton
@onready var _class_back_button: Button = %ClassBackButton
@onready var _classes: HBoxContainer = %Classes
@onready var _class_card_template: Button = %ClassCardTemplate


func _ready() -> void:
	PointerMode.release_for_ui()
	_play_button.pressed.connect(show_modes)
	_back_button.pressed.connect(show_main)
	_class_back_button.pressed.connect(show_modes)
	_normal_button.pressed.connect(choose_mode.bind(GameSession.Mode.NORMAL))
	_sandbox_button.pressed.connect(choose_mode.bind(GameSession.Mode.SANDBOX))
	_build_class_cards()
	for button: Button in [_play_button, _back_button, _class_back_button, _normal_button, _sandbox_button]:
		UiNav.bind_focus_frame(button)
	show_main()


func _unhandled_input(event: InputEvent) -> void:
	_handle_back_input(event)


func show_main() -> void:
	_show_only(_main_panel)
	_play_button.grab_focus()


func show_modes() -> void:
	_show_only(_mode_panel)
	_normal_button.grab_focus()


func show_classes() -> void:
	_show_only(_class_panel)
	get_class_cards()[0].grab_focus()


## `ui_cancel` (B, Esc) goes back one panel, like the "Volver" buttons.
func go_back() -> void:
	if _class_panel.visible:
		show_modes()
	elif _mode_panel.visible:
		show_main()


func choose_mode(mode: GameSession.Mode) -> void:
	Session.mode = mode
	mode_chosen.emit(mode)
	show_classes()


func choose_class(character_class: CharacterClassData) -> void:
	Session.character_class = character_class
	class_chosen.emit(character_class)
	if not game_scene_path.is_empty():
		get_tree().change_scene_to_file(game_scene_path)


func is_showing_modes() -> bool:
	return _mode_panel.visible


func is_showing_classes() -> bool:
	return _class_panel.visible


func get_offered_classes() -> Array[CharacterClassData]:
	return class_catalog.classes


## Cards shown in the class panel, in catalog order (the template excluded).
func get_class_cards() -> Array[Button]:
	var cards: Array[Button] = []
	for child: Node in _classes.get_children():
		if child != _class_card_template:
			cards.append(child as Button)
	return cards


func _show_only(panel: Control) -> void:
	_main_panel.visible = panel == _main_panel
	_mode_panel.visible = panel == _mode_panel
	_class_panel.visible = panel == _class_panel


func _build_class_cards() -> void:
	_class_card_template.hide()
	for character_class: CharacterClassData in class_catalog.classes:
		_classes.add_child(_make_class_card(character_class))


func _make_class_card(character_class: CharacterClassData) -> Button:
	var card: Button = _class_card_template.duplicate() as Button
	card.text = "%s\n\n%s" % [character_class.title, character_class.description]
	card.visible = true
	card.pressed.connect(choose_class.bind(character_class))
	UiNav.bind_focus_frame(card)
	return card


func _handle_back_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_BACK) and not _main_panel.visible:
		go_back()
		get_viewport().set_input_as_handled()
