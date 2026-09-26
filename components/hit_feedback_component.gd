class_name HitFeedbackComponent
extends Node
## Makes damage taken by the player noticeable: shakes the camera (stronger
## for bigger hits) and flickers the player's visual. Hits absorbed by
## invulnerability deal no damage, so they trigger nothing. Only toggles
## visibility: the player's reserved colors are never changed (Principle II).

@export var health: HealthComponent
@export var visual: Node3D
@export var camera: ThirdPersonCamera
@export var config: HitFeedbackConfig

var _flicker_left: float = 0.0
var _toggle_left: float = 0.0


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	set_process(false)


func _process(delta: float) -> void:
	_update_flicker(delta)


## Shake strength in [min_strength, 1], proportional to the damage taken.
static func shake_strength(amount: float, feedback: HitFeedbackConfig) -> float:
	return clampf(amount / feedback.damage_for_full_shake, feedback.min_strength, 1.0)


func is_flickering() -> bool:
	return _flicker_left > 0.0


func _on_damaged(amount: float) -> void:
	camera.shake(shake_strength(amount, config))
	_start_flicker()


func _on_died() -> void:
	camera.stop_shake()
	_stop_flicker()


func _start_flicker() -> void:
	_flicker_left = config.flicker_duration
	_toggle_left = config.flicker_interval
	visual.visible = false
	set_process(true)


func _update_flicker(delta: float) -> void:
	_flicker_left -= delta
	if _flicker_left <= 0.0:
		_stop_flicker()
		return
	_toggle_left -= delta
	if _toggle_left <= 0.0:
		_toggle_left += config.flicker_interval
		visual.visible = not visual.visible


func _stop_flicker() -> void:
	_flicker_left = 0.0
	visual.visible = true
	set_process(false)
