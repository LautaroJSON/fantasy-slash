class_name GameSession
extends Node
## Choices that must outlive a level reload (e.g. "Reintentar" keeps the mode).
## Registered as the autoload `Session`. Holds no gameplay values.

enum Mode {
	NORMAL,
	SANDBOX,
}

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
