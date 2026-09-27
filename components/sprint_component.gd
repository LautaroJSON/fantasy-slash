class_name SprintComponent
extends Node
## Whether the player sprints (docs/specs/sprint-stamina.md §11). The Player
## decides when a sprint starts or stops; this node keeps the state, detects
## the double tap and spends the stamina while sprinting. An empty bar
## does not end the sprint: the player is winded (walks, spends nothing) until
## the stamina is back to `stamina_to_start_sprint`.

signal sprint_started(from_dash: bool)
signal sprint_ended

@export var stats: StatsComponent
@export var stamina: StaminaComponent
@export var config: SprintConfig

var _sprinting: bool = false
var _from_dash: bool = false
## Sprinting with an empty bar: walks and spends nothing until it recovers.
var _winded: bool = false
## Seconds of physics time, the clock of the double tap.
var _clock: float = 0.0
## Clock time and movement action of the last tap that did not complete a
## double tap.
var _last_tap: float = -INF
var _last_tap_action: StringName = &""


func _ready() -> void:
	stamina.depleted.connect(_on_depleted)


func _physics_process(delta: float) -> void:
	_clock += delta


## Pure: two taps `window` seconds apart or closer make a double tap.
static func is_double_tap(last_tap: float, now: float, window: float) -> bool:
	return now - last_tap <= window


## Records a tap of a movement action; true when it repeats the last tap's
## action within the window (a third tap starts a new pair; two different
## directions never count, docs/specs/sprint-stamina.md §12).
func register_tap(action: StringName) -> bool:
	if action == _last_tap_action and is_double_tap(_last_tap, _clock, config.double_tap_window):
		_last_tap = -INF
		return true
	_last_tap = _clock
	_last_tap_action = action
	return false


func is_sprinting() -> bool:
	return _sprinting


## Sprinting but out of breath.
func is_winded() -> bool:
	return _sprinting and _winded


## Sprinting at full speed: the sprint speed and clips.
func is_running() -> bool:
	return _sprinting and not _winded


func started_from_dash() -> bool:
	return _from_dash


## Starts sprinting if there is enough stamina. A running sprint is kept.
func try_start(from_dash: bool) -> bool:
	if _sprinting:
		return true
	if not stamina.has_at_least(config.stamina_to_start_sprint):
		return false
	_sprinting = true
	_winded = false
	_from_dash = from_dash
	sprint_started.emit(from_dash)
	return true


func stop() -> void:
	if not _sprinting:
		return
	_sprinting = false
	_winded = false
	sprint_ended.emit()


## Spends this step's stamina. Winded, it spends nothing and waits for the
## stamina to be back to `stamina_to_start_sprint`.
func drain(delta: float) -> void:
	if not _sprinting:
		return
	if _winded:
		_winded = not stamina.has_at_least(config.stamina_to_start_sprint)
		return
	stamina.spend(stats.get_stat(PlayerStats.Stat.SPRINT_STAMINA_COST) * delta)


## Multiplier of MOVE_SPEED: SPRINT_SPEED_FACTOR while running, else 1.
func get_speed_factor() -> float:
	if not is_running():
		return 1.0
	return stats.get_stat(PlayerStats.Stat.SPRINT_SPEED_FACTOR)


func _on_depleted() -> void:
	_winded = _sprinting
