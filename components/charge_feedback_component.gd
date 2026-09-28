class_name ChargeFeedbackComponent
extends Node
## Makes each charge milestone of a charged ability felt: shakes the camera and
## makes the player's body tremble around its rest position, stronger on every
## milestone and strongest at full charge, and narrows the view a bit more on
## every milestone, holding it until the charged strike bursts out (the view
## then snaps wide with a kick) or the charge ends without one (it eases
## back; docs/specs/sheathe-visual-rework.md §2.1-2.2). Only moves the body
## mesh: its reserved color and visibility are never changed (Principle II).
## Gaining an empowered cast also shakes the camera.

@export var abilities: Array[AbilityComponent] = []
@export var camera: ThirdPersonCamera
@export var body: Node3D
@export var config: ChargeFeedbackConfig

var _body_rest: Vector3 = Vector3.ZERO
var _tremor_left: float = 0.0
var _tremor_amplitude: float = 0.0
## A milestone narrowed the view and it has not been let go yet.
var _zoom_held: bool = false


func _ready() -> void:
	_body_rest = body.position
	for ability: AbilityComponent in abilities:
		ability.charge_milestone_reached.connect(_on_charge_milestone_reached)
		ability.empowered_changed.connect(_on_empowered_changed)
		ability.charge_cancelled.connect(_release_zoom)
		ability.cast_released.connect(_release_zoom)
		ability.charge_unleashed.connect(_on_charge_unleashed)
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
	camera.hold_fov(-config.zoom_for(index, is_full), config.zoom_blend)
	_zoom_held = true
	_tremor_amplitude = config.tremor_for(index, is_full)
	_tremor_left = config.tremor_duration
	set_process(true)


## Gaining an empowered cast (e.g. Tsubame Gaeshi) shakes the camera once.
func _on_empowered_changed(active: bool) -> void:
	if active:
		camera.shake(config.empowered_shake)


func is_zoom_held() -> bool:
	return _zoom_held


## The charge ended without a burst (cancelled, or the cast was cut short):
## the view eases back.
func _release_zoom() -> void:
	if not _zoom_held:
		return
	_zoom_held = false
	camera.hold_fov(0.0, config.zoom_return)


## The charged strike burst out: the view lets go of the zoom at once and
## kicks wide, also for an empowered cast that skipped the charge.
func _on_charge_unleashed() -> void:
	_zoom_held = false
	camera.hold_fov(0.0, 0.0)
	camera.kick_fov(config.unleash_kick_deg, config.unleash_kick_return)
