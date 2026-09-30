class_name GoldWallet
extends Node
## Gold of the current run. Lives in the level, so reloading the scene resets it.

signal changed

var _gold: int = 0


func get_gold() -> int:
	return _gold


func add(amount: int) -> void:
	if amount <= 0:
		return
	_gold += amount
	changed.emit()


func can_afford(amount: int) -> bool:
	return _gold >= amount


## Spends `amount`; false (and nothing changes) when the gold does not reach.
func try_spend(amount: int) -> bool:
	if amount < 0 or _gold < amount:
		return false
	_gold -= amount
	changed.emit()
	return true
