class_name PerfectDodgeComponent
extends Node
## Perfect dodge (docs/specs/perfect-dodge.md): when an enemy hit reaches the
## player while the dash makes it invulnerable, within the first
## config.effective_window() seconds of that dash, every active enemy slows to
## config.enemy_time_scale for config.slow_duration seconds (Enemy.dilate_time).
## The player, the camera and the UI keep their speed: Engine.time_scale is never
## touched. One per dash and one every config.min_interval seconds at most. The
## Parry's invulnerable riposte does not count: only a running dash does.

signal perfect_dodged(attacker: Enemy)

@export var dash: DashComponent
@export var health: HealthComponent
## Assigned by the player; the enemies to slow. Optional (tests).
@export var registry: EnemyRegistry
@export var config: PerfectDodgeConfig

var _triggered_this_dash: bool = false
## Seconds since the last perfect dodge (infinite before the first).
var _since_last: float = INF


func _ready() -> void:
	health.hit_evaded.connect(_on_hit_evaded)
	dash.dash_started.connect(_on_dash_started)


func _physics_process(delta: float) -> void:
	advance(delta)


## Counts the time since the last perfect dodge.
func advance(delta: float) -> void:
	_since_last += delta


func get_time_since_last() -> float:
	return _since_last


func _can_trigger(attacker: Enemy) -> bool:
	return attacker != null \
			and dash.is_dashing() \
			and not _triggered_this_dash \
			and _since_last >= config.min_interval \
			and dash.get_elapsed() <= config.effective_window(dash.get_duration())


func _on_hit_evaded(_raw: float, attacker: Enemy) -> void:
	if not _can_trigger(attacker):
		return
	_triggered_this_dash = true
	_since_last = 0.0
	_slow_enemies()
	perfect_dodged.emit(attacker)


func _on_dash_started() -> void:
	_triggered_this_dash = false


## Walks the registry's live list (no copy).
func _slow_enemies() -> void:
	if registry == null:
		return
	for enemy: Enemy in registry.get_active():
		enemy.dilate_time(config.enemy_time_scale, config.slow_duration)
