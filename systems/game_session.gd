class_name GameSession
extends Node
## Choices that must outlive a level reload (e.g. "Reintentar" keeps the mode).
## Registered as the autoload `Session`. Holds no gameplay values.
## Also turns the Android back gesture into `ui_cancel`/`pause` (the app does
## not quit on it; docs/specs/mobile-touch-controls.md).

enum Mode {
	NORMAL,
	SANDBOX,
}

const ACTION_BACK: StringName = &"ui_cancel"
const ACTION_PAUSE: StringName = &"pause"

var mode: Mode = Mode.NORMAL
## Class chosen in the main menu; null until one is chosen.
var character_class: CharacterClassData = null


func is_sandbox() -> bool:
	return mode == Mode.SANDBOX


## Mode name as shown in the menus (same text as the main menu buttons).
func get_mode_name() -> String:
	match mode:
		Mode.SANDBOX:
			return "Sandbox"
	return "Normal"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_go_back()


## Paused (pause, cards, ban, Game Over): `ui_cancel` only, like B. Not paused:
## `ui_cancel` (the main menu goes back one panel), then `pause` (in game it
## opens the pause). In that order: the other way round the pause would open
## and close on the same gesture.
func handle_go_back() -> void:
	_tap(ACTION_BACK)
	if not get_tree().paused:
		_tap(ACTION_PAUSE)


func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
