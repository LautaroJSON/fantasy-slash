class_name StaminaComponent
extends Node
## The player's stamina (docs/specs/sprint-stamina.md): starts full, is spent
## by the sprint and regenerates STAMINA_REGEN per second once
## `stamina_regen_delay` seconds have passed without spending.

signal stamina_changed(current: float, maximum: float)
## The stamina reached 0 (once per emptying).
signal depleted

@export var stats: StatsComponent
@export var config: SprintConfig

var _current: float = 0.0
## Seconds since the last spend; regeneration waits for the regen delay.
var _since_spent: float = 0.0


func _ready() -> void:
	stats.stats_changed.connect(_on_stats_changed)
	_current = get_max()
	_since_spent = config.stamina_regen_delay


func _physics_process(delta: float) -> void:
	advance(delta)


func get_current() -> float:
	return _current


func get_max() -> float:
	return stats.get_stat(PlayerStats.Stat.STAMINA_MAX)


func has_at_least(amount: float) -> bool:
	return _current >= amount


## Clamps at 0 and restarts the regen delay.
func spend(amount: float) -> void:
	if amount <= 0.0:
		return
	_since_spent = 0.0
	if _current <= 0.0:
		return
	_current = maxf(_current - amount, 0.0)
	stamina_changed.emit(_current, get_max())
	if _current <= 0.0:
		depleted.emit()


## Full bar (the start of a run, or the class just chosen).
func refill() -> void:
	_current = get_max()
	_since_spent = config.stamina_regen_delay
	stamina_changed.emit(_current, get_max())


## Regeneration step, once the regen delay has passed.
func advance(delta: float) -> void:
	_since_spent += delta
	if _since_spent < config.stamina_regen_delay:
		return
	var maximum: float = get_max()
	if _current >= maximum:
		return
	_current = minf(_current + stats.get_stat(PlayerStats.Stat.STAMINA_REGEN) * delta, maximum)
	stamina_changed.emit(_current, maximum)


## A lower maximum (an upgrade removed) trims the current stamina.
func _on_stats_changed() -> void:
	var maximum: float = get_max()
	_current = minf(_current, maximum)
	stamina_changed.emit(_current, maximum)
