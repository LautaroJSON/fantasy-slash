class_name SwordSwing
extends Node
## Procedural horizontal sweep of the class weapon for the basic attack. The
## blade crosses exactly the attack arc (ATTACK_ARC, upgrades included),
## starting on alternating sides, then blends back to the weapon's rest pose
## (WeaponData, given by setup()).
## Ability animations own the sword: if the AnimationPlayer starts playing,
## the sweep is cancelled without touching the pivot.

## Emitted when a sweep starts.
signal swing_started
## Emitted when a sweep stops, finished or cancelled.
signal swing_ended

enum Phase {
	IDLE,
	SWING,
	RECOVER,
}

@export var pivot: Node3D
@export var animator: AnimationPlayer

## Set by setup() from the class weapon.
var config: SwordSwingConfig = null

var _phase: Phase = Phase.IDLE
var _elapsed: float = 0.0
var _duration: float = 0.0
var _half_arc: float = 0.0
## +1 starts on the left (positive yaw), -1 on the right; flips every swing.
var _start_side: float = -1.0
var _rest_position: Vector3 = Vector3.ZERO
var _rest_rotation: Vector3 = Vector3.ZERO
var _recover_from_position: Vector3 = Vector3.ZERO
var _recover_from_rotation: Vector3 = Vector3.ZERO
## Recovery time of the current blend: scaled after an attack, unscaled after an ability.
var _recover_duration: float = 0.0
## True while the swing blends to a given pose (swing_to) instead of sweeping.
var _to_pose: bool = false
var _from_position: Vector3 = Vector3.ZERO
var _from_rotation: Vector3 = Vector3.ZERO
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## Takes the weapon's sweep config and rest pose, and puts the pivot at rest.
func setup(weapon: WeaponData) -> void:
	config = weapon.swing
	_rest_position = weapon.rest_position
	_rest_rotation = weapon.rest_rotation
	_stop()
	pivot.position = _rest_position
	pivot.rotation = _rest_rotation


## Cancels the sweep and holds the weapon at a fixed pose (e.g. during a spin).
func hold_pose(held_position: Vector3, held_rotation: Vector3) -> void:
	_stop()
	pivot.position = held_position
	pivot.rotation = held_rotation


## Blends from the current pose back to rest (e.g. after an ability held the weapon).
func recover() -> void:
	_recover_duration = config.recover_duration
	_start_recover()
	set_process(true)


## `time_scale` (base / current ATTACK_SPEED) also speeds up the recovery that follows.
func play(arc_degrees: float, duration: float, time_scale: float) -> void:
	_recover_duration = config.recover_duration * time_scale
	_to_pose = false
	animator.stop()
	_start_side = -_start_side
	_half_arc = deg_to_rad(arc_degrees) / 2.0
	_duration = duration
	_elapsed = 0.0
	_set_phase(Phase.SWING)
	_pose_at(0.0)
	set_process(true)


## Swings from the current pose to a given one in `duration` (e.g. a descending
## slash from a raised pose), then blends back to rest as after a sweep.
func swing_to(target_position: Vector3, target_rotation: Vector3, duration: float) -> void:
	_recover_duration = config.recover_duration
	animator.stop()
	_to_pose = true
	_from_position = pivot.position
	_from_rotation = pivot.rotation
	_target_position = target_position
	_target_rotation = target_rotation
	_duration = duration
	_elapsed = 0.0
	_set_phase(Phase.SWING)
	set_process(true)


func advance(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	if animator.is_playing():
		_stop()
		return
	_elapsed += delta
	if _phase == Phase.SWING:
		_advance_swing()
	else:
		_advance_recover()


func is_swinging() -> bool:
	return _phase == Phase.SWING


## Current yaw of the blade relative to the player's facing, in radians.
func get_sweep_yaw() -> float:
	return pivot.rotation.y


## +1 when the last swing started on the left, -1 on the right.
func get_last_start_side() -> float:
	return _start_side


## Seconds the current (or last) sweep takes to cross the arc.
func get_swing_duration() -> float:
	return _duration


## Seconds of the current (or last) blend back to rest.
func get_recover_duration() -> float:
	return _recover_duration


func get_rest_position() -> Vector3:
	return _rest_position


func get_rest_rotation() -> Vector3:
	return _rest_rotation


func _advance_swing() -> void:
	if _elapsed < _duration:
		_pose_at(ease(_elapsed / _duration, config.sweep_ease))
		return
	_pose_at(1.0)
	_start_recover()


func _start_recover() -> void:
	_recover_from_position = pivot.position
	_recover_from_rotation = pivot.rotation
	_elapsed = 0.0
	_set_phase(Phase.RECOVER)


func _advance_recover() -> void:
	var weight: float = minf(_elapsed / _recover_duration, 1.0)
	pivot.position = _recover_from_position.lerp(_rest_position, weight)
	pivot.rotation = _recover_from_rotation.lerp(_rest_rotation, weight)
	if weight >= 1.0:
		_stop()


## Places the blade at `progress` in [0, 1] of the sweep.
func _pose_at(progress: float) -> void:
	if _to_pose:
		pivot.position = _from_position.lerp(_target_position, progress)
		pivot.rotation = _from_rotation.lerp(_target_rotation, progress)
		return
	var yaw: float = lerpf(_start_side * _half_arc, -_start_side * _half_arc, progress)
	pivot.rotation = Vector3(config.blade_tilt, yaw, 0.0)
	pivot.position = Vector3(0.0, config.pivot_height, 0.0) + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, -config.hilt_offset)


func _stop() -> void:
	_set_phase(Phase.IDLE)
	set_process(false)


## Changes phase and reports entering or leaving a sweep.
func _set_phase(next: Phase) -> void:
	var was_swinging: bool = _phase == Phase.SWING
	_phase = next
	if was_swinging:
		swing_ended.emit()
	if next == Phase.SWING:
		swing_started.emit()
