extends Node3D
## Arena level. Applies the game mode chosen in the main menu (Session).

@export var player: Player


func _ready() -> void:
	_apply_mode()


## Sandbox: the player takes hits but cannot die.
func _apply_mode() -> void:
	player.health.death_protected = Session.is_sandbox()
