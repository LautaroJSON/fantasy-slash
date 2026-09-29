class_name MultiKillFeelConfig
extends Resource
## Extra hit lag and camera shake of a strike that leaves several enemies dead
## (docs/specs/kill-feedback.md). Common to every class.

## Enemies left dead by one strike from which the bonuses start.
@export var min_kills: int
## Extra seconds the player's clip pauses, for min_kills, min_kills + 1, ...
## kills; a strike with more kills than entries uses the last one.
@export var hitlag_bonus: Array[float]
## Extra camera shake strength, same indexing as hitlag_bonus.
@export var shake_bonus: Array[float]


## Pure: extra hit lag seconds for a strike that left `kills` enemies dead.
func hitlag_bonus_for(kills: int) -> float:
	return _bonus(hitlag_bonus, kills)


## Pure: extra camera shake strength for a strike that left `kills` enemies dead.
func shake_bonus_for(kills: int) -> float:
	return _bonus(shake_bonus, kills)


func _bonus(table: Array[float], kills: int) -> float:
	if kills < min_kills or table.is_empty():
		return 0.0
	return table[mini(kills - min_kills, table.size() - 1)]
