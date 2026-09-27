class_name DashComponent
extends Node
## Short horizontal dash. The player is invulnerable exactly while it lasts
## (docs/specs/dash-iframes.md). The cooldown always exceeds the dash
## (guaranteed by StatsComponent), so invulnerability cannot be chained.
## The body turns to the dash direction when it starts. A class dash (DashData,
## docs/specs/dash-feel.md) sets its clip, its VFX and an optional DashBehavior
## whose hooks add rules; without one it is the standard dash.

signal dash_started
signal dash_ready
## The dash is over: it ran its full distance, or `cancelled` cut it short.
signal dash_ended(cancelled: bool)
## Every dash step, after the body moved (the VFX follow it).
signal dash_step(delta: float)

@export var body: CharacterBody3D
@export var visual: Node3D
@export var health: HealthComponent
@export var stats: StatsComponent

var _direction: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _dash_time_left: float = 0.0
var _cooldown_left: float = 0.0
var _cooldown_total: float = 0.0
## Seconds the running (or last) dash lasts, and how far into it we are.
var _duration: float = 0.0
var _elapsed: float = 0.0
var _data: DashData = null
var _behavior: DashBehavior = null


func _physics_process(delta: float) -> void:
	advance_timers(delta)


## The class dash: instantiates its behavior (the previous one is freed).
func equip(data: DashData) -> void:
	_data = data
	if _behavior != null:
		_behavior.queue_free()
		_behavior = null
	if data != null and data.behavior != null:
		_behavior = data.behavior.instantiate() as DashBehavior
		add_child(_behavior)


func get_data() -> DashData:
	return _data


func get_behavior() -> DashBehavior:
	return _behavior


## A zero direction dashes towards where the visual is facing. The visual turns
## to the dash direction at once.
func try_dash(direction: Vector3) -> bool:
	if _cooldown_left > 0.0:
		return false
	if _behavior != null and not _behavior.can_start(self):
		return false
	_direction = _resolve_direction(direction)
	_face_direction()
	_speed = stats.get_stat(PlayerStats.Stat.DASH_SPEED)
	_dash_time_left = stats.get_stat(PlayerStats.Stat.DASH_DISTANCE) / _speed
	_duration = _dash_time_left
	_elapsed = 0.0
	_cooldown_total = stats.get_stat(PlayerStats.Stat.DASH_COOLDOWN)
	_cooldown_left = _cooldown_total
	health.is_invulnerable = true
	dash_started.emit()
	if _behavior != null:
		_behavior.started(self)
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
	_elapsed += step
	dash_step.emit(step)
	if _behavior != null:
		_behavior.step(self, step)
	if not is_dashing():
		body.velocity = Vector3.ZERO
		_end_dash(false)


## Cuts a running dash short and drops its horizontal momentum. The
## invulnerability ends with it; the cooldown keeps running.
func cancel() -> void:
	if not is_dashing():
		return
	_end_dash(true)
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


func _end_dash(cancelled: bool) -> void:
	_dash_time_left = 0.0
	health.is_invulnerable = false
	if _behavior != null:
		_behavior.ended(self, cancelled)
	dash_ended.emit(cancelled)


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


## Clip of the running dash: the class clip, unless its behavior picks another.
func get_clip() -> StringName:
	if _data == null:
		return &""
	if _behavior != null:
		return _behavior.get_clip(self, _data.clip)
	return _data.clip


## 0 at the start of the running dash, 1 at its end.
func get_progress() -> float:
	if _duration <= 0.0:
		return 0.0
	return clampf(_elapsed / _duration, 0.0, 1.0)


## Seconds the running (or last) dash lasts.
func get_duration() -> float:
	return _duration


func is_airborne() -> bool:
	return not body.is_on_floor()


## The dashing player, for behaviors and VFX (null in isolated tests).
func get_player() -> Player:
	return body as Player


func _face_direction() -> void:
	if visual == null:
		return
	visual.rotation.y = atan2(-_direction.x, -_direction.z)
