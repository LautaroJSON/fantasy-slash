class_name RunState
extends Node
## Progress of the current run. Lives in the level, so reloading the scene resets it.

signal changed

var wave: int = 1
var kills: int = 0
## Title of the current wave's boss challenge; empty on normal waves.
var challenge_title: String = ""

## First wave with Rage (docs/specs/enemy-rage.md); 0 = no rage yet.
var rage_start_wave: int = 0

## Upgrade cards banned with the red card; never offered again this run.
var _banned: Array[UpgradeCard] = []


func add_kill() -> void:
	kills += 1
	changed.emit()


func next_wave() -> void:
	wave += 1
	changed.emit()


func set_challenge(title: String) -> void:
	challenge_title = title
	changed.emit()


func is_boss_wave() -> bool:
	return not challenge_title.is_empty()


func ban(card: UpgradeCard) -> void:
	if is_banned(card):
		return
	_banned.append(card)
	changed.emit()


func is_banned(card: UpgradeCard) -> bool:
	return _banned.has(card)


func get_banned() -> Array[UpgradeCard]:
	return _banned


func ban_count() -> int:
	return _banned.size()


## The player ran out of upgrades: Rage starts with the next wave. Only the
## first call counts.
func start_rage() -> void:
	if rage_start_wave > 0:
		return
	rage_start_wave = wave + 1
	changed.emit()


## 0 without rage (or before its first wave); 1 on its first wave, +1 per wave.
func get_rage_level() -> int:
	if rage_start_wave <= 0 or wave < rage_start_wave:
		return 0
	return wave - rage_start_wave + 1
