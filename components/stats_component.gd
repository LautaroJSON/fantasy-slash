class_name StatsComponent
extends Node
## Effective player stats: base values from PlayerStats plus the run's upgrades.
## Values are cached and only recalculated when an upgrade is added.
## Global buffs (BuffData.global, e.g. Triumph) multiply MOVE_SPEED, DAMAGE
## and ATTACK_SPEED (Netsui, docs/specs/sheathe-upgrades-rework.md)
## on read, on top of the cache (docs/specs/warrior-abilities-rework.md §4.6).

signal stats_changed

@export var base_stats: PlayerStats
@export var rules: CombatRules
## Optional: without it no buff reaches the stats.
@export var buffs: BuffComponent

var _upgrades: Array[UpgradeData] = []
var _cache: PackedFloat64Array = PackedFloat64Array()


func _ready() -> void:
	if buffs != null:
		buffs.changed.connect(stats_changed.emit)


func get_stat(stat: PlayerStats.Stat) -> float:
	if _cache.is_empty():
		_recalculate()
	if buffs != null and stat == PlayerStats.Stat.MOVE_SPEED:
		return _cache[stat] * (1.0 + buffs.get_global_modifier(BuffModifier.Stat.MOVE_SPEED))
	if buffs != null and stat == PlayerStats.Stat.DAMAGE:
		return _cache[stat] * (1.0 + buffs.get_global_modifier(BuffModifier.Stat.DAMAGE))
	if buffs != null and stat == PlayerStats.Stat.ATTACK_SPEED:
		return _cache[stat] * (1.0 + buffs.get_global_modifier(BuffModifier.Stat.ATTACK_SPEED))
	return _cache[stat]


## Replaces the base values (the chosen class); upgrades are kept on top.
func set_base_stats(stats: PlayerStats) -> void:
	base_stats = stats
	_recalculate()
	stats_changed.emit()


func add_upgrade(upgrade: UpgradeData) -> void:
	_upgrades.append(upgrade)
	_recalculate()
	stats_changed.emit()


func get_upgrades() -> Array[UpgradeData]:
	return _upgrades


## Removes one copy of the upgrade (sandbox). Does nothing if it was not taken.
func remove_upgrade(upgrade: UpgradeData) -> void:
	var index: int = _index_of(upgrade)
	if index < 0:
		return
	_upgrades.remove_at(index)
	_recalculate()
	stats_changed.emit()


## Copies of the same stat: offered cards are rolled copies, so identity is not used.
func count_upgrade(upgrade: UpgradeData) -> int:
	var count: int = 0
	for taken: UpgradeData in _upgrades:
		if taken.stat == upgrade.stat:
			count += 1
	return count


func clear_upgrades() -> void:
	_upgrades.clear()
	_recalculate()
	stats_changed.emit()


func _recalculate() -> void:
	_cache.resize(PlayerStats.Stat.size())
	for i: int in PlayerStats.Stat.size():
		_cache[i] = base_stats.get_base(i as PlayerStats.Stat)
	var copies: Dictionary = {}
	for upgrade: UpgradeData in _upgrades:
		var taken: int = copies.get(upgrade.stat, 0)
		_cache[upgrade.stat] += upgrade.amount_for_copy(taken)
		copies[upgrade.stat] = taken + 1
	_apply_limits()


func _apply_limits() -> void:
	var crit: int = PlayerStats.Stat.CRIT_CHANCE
	var crit_damage: int = PlayerStats.Stat.CRIT_DAMAGE
	var arc: int = PlayerStats.Stat.ATTACK_ARC
	var cooldown: int = PlayerStats.Stat.DASH_COOLDOWN
	var dash_invulnerability: float = maxf(_cache[PlayerStats.Stat.DASH_DURATION], _cache[PlayerStats.Stat.DASH_INVULNERABILITY])
	_cache[crit] = minf(_cache[crit], rules.max_crit_chance)
	_cache[crit_damage] = minf(_cache[crit_damage], rules.max_crit_damage)
	_cache[arc] = minf(_cache[arc], rules.max_attack_arc_degrees)
	_cache[cooldown] = maxf(_cache[cooldown], dash_invulnerability + rules.min_dash_cooldown_gap)


## The very card if it was taken, else the last copy of the same stat.
func _index_of(upgrade: UpgradeData) -> int:
	var index: int = _upgrades.find(upgrade)
	if index >= 0:
		return index
	for i: int in range(_upgrades.size() - 1, -1, -1):
		if _upgrades[i].stat == upgrade.stat:
			return i
	return -1
