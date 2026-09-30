extends Node3D
## Arena level. Applies the game mode chosen in the main menu (Session).

@export var player: Player
## Its pools grow to the sandbox caps (docs/specs/sandbox-arena-control.md).
@export var wave_manager: WaveManager


func _ready() -> void:
	_apply_mode()


## Sandbox: the player takes hits but cannot die, and every pool grows to the
## sandbox caps now, while the level loads (never in combat).
func _apply_mode() -> void:
	player.health.death_protected = Session.is_sandbox()
	if Session.is_sandbox():
		wave_manager.get_roster().grow_pools()
