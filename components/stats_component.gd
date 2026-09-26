class_name StatsComponent
extends Node
## Effective player stats: base values from PlayerStats plus the run's upgrades.
## Values are cached and only recalculated when an upgrade is added.

signal stats_changed

@export var base_stats: PlayerStats
@export var rules: CombatRules

var _upgrades: Array[UpgradeData] = []
var _cache: PackedFloat64Array = PackedFloat64Array()


func get_stat(stat: PlayerStats.Stat) -> float:
	if _cache.is_empty():
		_recalculate()
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
	var index: int = _upgrades.find(upgrade)
	if index < 0:
		return
	_upgrades.remove_at(index)
	_recalculate()
	stats_changed.emit()


func count_upgrade(upgrade: UpgradeData) -> int:
	return _upgrades.count(upgrade)


func clear_upgrades() -> void:
	_upgrades.clear()
	_recalculate()
	stats_changed.emit()


func _recalculate() -> void:
	_cache.resize(PlayerStats.Stat.size())
	for i: int in PlayerStats.Stat.size():
		_cache[i] = base_stats.get_base(i as PlayerStats.Stat)
	for upgrade: UpgradeData in _upgrades:
		_cache[upgrade.stat] += upgrade.amount
	_apply_limits()


func _apply_limits() -> void:
	var crit: int = PlayerStats.Stat.CRIT_CHANCE
	var crit_damage: int = PlayerStats.Stat.CRIT_DAMAGE
	var arc: int = PlayerStats.Stat.ATTACK_ARC
	var cooldown: int = PlayerStats.Stat.DASH_COOLDOWN
	var dash_duration: float = _cache[PlayerStats.Stat.DASH_DISTANCE] / _cache[PlayerStats.Stat.DASH_SPEED]
	_cache[crit] = minf(_cache[crit], rules.max_crit_chance)
	_cache[crit_damage] = minf(_cache[crit_damage], rules.max_crit_damage)
	_cache[arc] = minf(_cache[arc], rules.max_attack_arc_degrees)
	_cache[cooldown] = maxf(_cache[cooldown], dash_duration + rules.min_dash_cooldown_gap)
