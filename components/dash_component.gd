class_name DashComponent
extends Node
## Short horizontal dash. The player is invulnerable exactly while it lasts
## (docs/specs/dash-iframes.md). The cooldown always exceeds the dash
## (guaranteed by StatsComponent), so invulnerability cannot be chained.

signal dash_started
signal dash_ready

@export var body: CharacterBody3D
@export var visual: Node3D
@export var health: HealthComponent
@export var stats: StatsComponent

var _direction: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _dash_time_left: float = 0.0
var _cooldown_left: float = 0.0
var _cooldown_total: float = 0.0


func _physics_process(delta: float) -> void:
	advance_timers(delta)


## A zero direction dashes towards where the visual is facing.
func try_dash(direction: Vector3) -> bool:
	if _cooldown_left > 0.0:
		return false
	_direction = _resolve_direction(direction)
	_speed = stats.get_stat(PlayerStats.Stat.DASH_SPEED)
	_dash_time_left = stats.get_stat(PlayerStats.Stat.DASH_DISTANCE) / _speed
	_cooldown_total = stats.get_stat(PlayerStats.Stat.DASH_COOLDOWN)
	_cooldown_left = _cooldown_total
	health.is_invulnerable = true
	dash_started.emit()
	return true


## Flat direction of the running (or last) dash.
func get_direction() -> Vector3:
	return _direction


func is_dashing() -> bool:
	return _dash_time_left > 0.0


## Moves the body for this physics step. The last step is shortened so the
## dash covers exactly dash_distance, then horizontal momentum is dropped.
func move_body(delta: float) -> void:
	var step: float = minf(delta, _dash_time_left)
	body.velocity = _direction * _speed * (step / delta)
	body.move_and_slide()
	_dash_time_left -= step
	if not is_dashing():
		body.velocity = Vector3.ZERO
		_end_dash()


## Cuts a running dash short and drops its horizontal momentum. The
## invulnerability ends with it; the cooldown keeps running.
func cancel() -> void:
	if not is_dashing():
		return
	_end_dash()
	body.velocity = Vector3(0.0, body.velocity.y, 0.0)


## Makes the dash ready at once (e.g. the "Zanshin" unique upgrade). Leaves a
## running dash untouched.
func reset_cooldown() -> void:
	if _cooldown_left <= 0.0:
		return
	_cooldown_left = 0.0
	dash_ready.emit()


func get_cooldown_remaining() -> float:
	return _cooldown_left


## 0 when ready, 1 right after dashing.
func get_cooldown_ratio() -> float:
	if _cooldown_total <= 0.0:
		return 0.0
	return _cooldown_left / _cooldown_total


func advance_timers(delta: float) -> void:
	_advance_cooldown(delta)


func _end_dash() -> void:
	_dash_time_left = 0.0
	health.is_invulnerable = false


func _advance_cooldown(delta: float) -> void:
	if _cooldown_left <= 0.0:
		return
	_cooldown_left -= delta
	if _cooldown_left <= 0.0:
		_cooldown_left = 0.0
		dash_ready.emit()


func _resolve_direction(direction: Vector3) -> Vector3:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.is_zero_approx():
		var forward: Vector3 = -visual.global_basis.z
		flat = Vector3(forward.x, 0.0, forward.z)
	return flat.normalized()
