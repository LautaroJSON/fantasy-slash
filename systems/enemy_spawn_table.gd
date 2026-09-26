class_name EnemySpawnTable
extends RefCounted
## Pure weighted choice of the enemy types of a regular wave
## (docs/specs/enemy-types.md).


## Index of the entry to spawn: a weighted draw (`roll` in [0, 1)) among the
## entries already allowed in `wave` that have not reached max_per_wave
## (`counts[i]` = enemies of entries[i] spawned this wave). Entry 0 is the
## fallback when none qualifies.
static func pick(entries: Array[EnemySpawnEntry], wave: int, counts: Array[int], roll: float) -> int:
	var total: float = 0.0
	for i: int in entries.size():
		if _allowed(entries[i], wave, counts[i]):
			total += entries[i].weight
	if total <= 0.0:
		return 0
	var target: float = roll * total
	var last_allowed: int = 0
	for i: int in entries.size():
		if not _allowed(entries[i], wave, counts[i]):
			continue
		last_allowed = i
		target -= entries[i].weight
		if target < 0.0:
			return i
	return last_allowed


static func _allowed(entry: EnemySpawnEntry, wave: int, count: int) -> bool:
	return entry.weight > 0.0 and entry.first_wave <= wave and count < entry.max_per_wave
