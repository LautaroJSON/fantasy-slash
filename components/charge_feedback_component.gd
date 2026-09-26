class_name ChargeFeedbackComponent
extends Node
## Makes each charge milestone of a charged ability felt: shakes the camera and
## makes the player's body tremble around its rest position, stronger on every
## milestone and strongest at full charge. Only moves the body mesh: its
## reserved color and visibility are never changed (Principle II). Gaining an
## empowered cast also shakes the camera.

@export var abilities: Array[AbilityComponent] = []
@export var camera: ThirdPersonCamera
@export var body: Node3D
@export var config: ChargeFeedbackConfig

var _body_rest: Vector3 = Vector3.ZERO
var _tremor_left: float = 0.0
var _tremor_amplitude: float = 0.0


func _ready() -> void:
	_body_rest = body.position
	for ability: AbilityComponent in abilities:
		ability.charge_milestone_reached.connect(_on_charge_milestone_reached)
		ability.empowered_changed.connect(_on_empowered_changed)
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func is_trembling() -> bool:
	return _tremor_left > 0.0


## Offset of the body from its rest position, sideways, decaying to zero.
func advance(delta: float) -> void:
	if not is_trembling():
		return
	_tremor_left = maxf(_tremor_left - delta, 0.0)
	if not is_trembling():
		body.position = _body_rest
		set_process(false)
		return
	var elapsed: float = config.tremor_duration - _tremor_left
	var decay: float = _tremor_left / config.tremor_duration
	var offset: float = _tremor_amplitude * decay * sin(TAU * config.tremor_frequency * elapsed)
	body.position = _body_rest + Vector3(offset, 0.0, 0.0)


func _on_charge_milestone_reached(index: int, is_full: bool) -> void:
	camera.shake(config.shake_for(index, is_full))
	_tremor_amplitude = config.tremor_for(index, is_full)
	_tremor_left = config.tremor_duration
	set_process(true)


## Gaining an empowered cast (e.g. Tsubame Gaeshi) shakes the camera once.
func _on_empowered_changed(active: bool) -> void:
	if active:
		camera.shake(config.empowered_shake)
