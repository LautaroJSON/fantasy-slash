class_name SandboxRoster
extends RefCounted
## Everything the sandbox can summon, in menu order: the regular types, the
## horde's fodder and then the bosses (docs/specs/sandbox-arena-control.md).
## Built once from the WaveManager pools.


class Entry:
	var title: String
	var pool: EnemyPool
	var is_boss: bool
	## Most enemies of this entry summoned at once.
	var max_count: int


var _entries: Array[Entry] = []


static func build(regular: Array[EnemyPool], horde: EnemyPool, bosses: Array[EnemyPool], config: SandboxConfig) -> SandboxRoster:
	var roster := SandboxRoster.new()
	for pool: EnemyPool in regular:
		roster._add(pool.spawn_entry.stats.display_name, pool, false, config.max_regular_count)
	if horde != null:
		roster._add(horde.spawn_entry.stats.display_name, horde, false, config.max_regular_count)
	for pool: EnemyPool in bosses:
		roster._add(pool.challenge.title, pool, true, config.max_boss_count)
	return roster


func size() -> int:
	return _entries.size()


func get_entry(index: int) -> Entry:
	return _entries[clampi(index, 0, _entries.size() - 1)]


## Index of the first boss (the menu puts a separator before it); size() when none.
func first_boss_index() -> int:
	for i: int in _entries.size():
		if _entries[i].is_boss:
			return i
	return _entries.size()


## Grows every pool to its entry's cap (sandbox only, while the level loads).
func grow_pools() -> void:
	for entry: Entry in _entries:
		entry.pool.grow_to(entry.max_count)


func _add(title: String, pool: EnemyPool, is_boss: bool, max_count: int) -> void:
	var entry := Entry.new()
	entry.title = title
	entry.pool = pool
	entry.is_boss = is_boss
	entry.max_count = max_count
	_entries.append(entry)
