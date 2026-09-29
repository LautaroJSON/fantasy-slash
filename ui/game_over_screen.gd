class_name GameOverScreen
extends Control
## Shown when the player dies. Retry reloads the level, which resets the whole
## run: base stats, no upgrades, wave 1 (all run state lives in the scene);
## the game mode lives in Session, so it is kept. "Menú principal" leaves the run.
## "Reintentar" takes the focus when it shows up (gamepad).

@export var player: Player
@export var run_state: RunState
@export_file("*.tscn") var main_menu_path: String

@onready var _summary: Label = %Summary
@onready var _retry_button: Button = %RetryButton
@onready var _menu_button: Button = %MainMenuButton


func _ready() -> void:
	hide()
	player.died.connect(_on_player_died)
	_retry_button.pressed.connect(restart_run)
	_menu_button.pressed.connect(go_to_main_menu)


func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_path)


func _on_player_died() -> void:
	_summary.text = "Oleada %d · %d enemigos eliminados" % [run_state.wave, run_state.kills]
	get_tree().paused = true
	PointerMode.release_for_ui()
	show()
	_retry_button.grab_focus()
