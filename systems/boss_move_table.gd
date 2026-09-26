class_name BossMoveTable
extends RefCounted
## Pure weighted choice of a boss's next move (docs/specs/boss-verdugo.md).


## Index of the move to use at `distance` in boss phase `phase` (`roll` in
## [0, 1)). The previous move (`last_move`, −1 for none) is skipped unless it
## is the only one in reach; moves needing a hand are skipped without
## `hands_left`. −1 when no move reaches.
static func pick(moves: Array[BossMoveData], distance: float, phase: int, last_move: int, roll: float, hands_left: int = 2) -> int:
	var total: float = _total(moves, distance, phase, last_move, hands_left)
	var skip: int = last_move
	if total <= 0.0:
		skip = -1
		total = _total(moves, distance, phase, -1, hands_left)
	if total <= 0.0:
		return -1
	var target: float = roll * total
	var chosen: int = -1
	for i: int in moves.size():
		if i == skip:
			continue
		var weight: float = moves[i].weight_at(distance, phase, hands_left)
		if weight <= 0.0:
			continue
		chosen = i
		target -= weight
		if target < 0.0:
			return i
	return chosen


static func _total(moves: Array[BossMoveData], distance: float, phase: int, skip: int, hands_left: int) -> float:
	var total: float = 0.0
	for i: int in moves.size():
		if i != skip:
			total += moves[i].weight_at(distance, phase, hands_left)
	return total
