class_name SpinVortexVfx
extends Node3D
## Effects of the Spin (docs/specs/spin-visual-rework.md §2.4), visual only:
## - a white, very transparent disc on the ground as wide as the spin's reach
##   (HIT_RANGE), that fades in and out with the spin;
## - a pulse of the disc (brighter and growing back to full size) on every
##   completed turn, the moment the turn's damage lands;
## - dust kicked up under the blade, left behind as the body turns.
## Built from primitives and CPUParticles3D (Principle II); every node is
## created once and reused (Principle V). Must be top_level: it follows the
## player through follow().

## Emitted on every pulse (one per completed turn).
signal pulsed

@export var config: SpinVortexConfig
## White, unshaded, transparent: the area of the abilities on the ground.
@export var area_material: StandardMaterial3D
## Earth-colored dust.
@export var dust_material: StandardMaterial3D

var _area: MeshInstance3D = null
var _dust: CPUParticles3D = null
## The player's Visual while spinning; the vortex stays where it ended after.
var _target: Node3D = null
var _radius: float = 0.0
## Scale of the disc relative to the radius (the pulse shrinks it).
var _scale_factor: float = 1.0
var _showing: bool = false
var _fading_in: bool = false
var _fading_out: bool = false
var _fade_elapsed: float = 0.0
## Opacity when the fade out started (it may cut a fade in or a pulse).
var _fade_from: float = 0.0
var _pulsing: bool = false
var _pulse_elapsed: float = 0.0
var _alpha: float = 0.0


func _ready() -> void:
	_create_area()
	_create_dust()
	_hide_vortex()


func _process(delta: float) -> void:
	advance(delta)


## Shows the area around `visual` (the player), `radius` wide, and starts the dust.
func begin(visual: Node3D, radius: float) -> void:
	_target = visual
	follow(visual)
	set_radius(radius)
	_showing = true
	_fading_in = true
	_fading_out = false
	_pulsing = false
	_fade_elapsed = 0.0
	_apply_alpha(0.0)
	_dust.emitting = true
	show()
	set_process(true)


## Keeps the area under the player and the dust under the blade, which turns
## with the body. One transform copy, no allocations.
func follow(visual: Node3D) -> void:
	global_position = visual.global_position + Vector3.UP * config.ground_offset
	global_basis = Basis(Vector3.UP, visual.global_rotation.y)


## Follows HIT_RANGE (an upgrade may change it mid-spin), keeping the pulse's scale.
func set_radius(radius: float) -> void:
	_radius = radius
	_apply_scale(_scale_factor)


## The disc flashes brighter and grows back from pulse_start_scale.
func pulse() -> void:
	if not _showing or _fading_out:
		return
	_pulsing = true
	_pulse_elapsed = 0.0
	_apply_scale(config.pulse_start_scale)
	_apply_alpha(config.pulse_alpha)
	pulsed.emit()


## The spin is over: the dust stops (the puffs alive finish on their own) and
## the area fades out.
func finish() -> void:
	if not _showing or _fading_out:
		return
	_dust.emitting = false
	_fading_in = false
	_pulsing = false
	_fading_out = true
	_fade_elapsed = 0.0
	_fade_from = _alpha
	_target = null
	_apply_scale(1.0)


func advance(delta: float) -> void:
	if _target != null:
		follow(_target)
	if _fading_out:
		_advance_fade_out(delta)
		return
	if _fading_in:
		_advance_fade_in(delta)
	if _pulsing:
		_advance_pulse(delta)


func is_showing() -> bool:
	return _showing


func is_pulsing() -> bool:
	return _pulsing


func is_dust_emitting() -> bool:
	return _dust.emitting


## Radius of the disc on the ground, in meters (with the pulse's scale).
func get_area_radius() -> float:
	return _area.scale.x


func get_area_alpha() -> float:
	return _alpha


func get_area() -> MeshInstance3D:
	return _area


func get_dust() -> CPUParticles3D:
	return _dust


## Opacity of the disc at rest: grows during the fade in.
func _resting_alpha() -> float:
	if _fading_in:
		return config.area_alpha * minf(_fade_elapsed / config.area_fade_in, 1.0)
	return config.area_alpha


func _advance_fade_in(delta: float) -> void:
	_fade_elapsed += delta
	if _fade_elapsed >= config.area_fade_in:
		_fading_in = false
	if not _pulsing:
		_apply_alpha(_resting_alpha())


func _advance_pulse(delta: float) -> void:
	_pulse_elapsed += delta
	var weight: float = minf(_pulse_elapsed / config.pulse_duration, 1.0)
	_apply_scale(lerpf(config.pulse_start_scale, 1.0, weight))
	_apply_alpha(lerpf(config.pulse_alpha, _resting_alpha(), weight))
	if weight >= 1.0:
		_pulsing = false


func _advance_fade_out(delta: float) -> void:
	_fade_elapsed += delta
	if _fade_elapsed >= config.area_fade_out:
		_hide_vortex()
		return
	_apply_alpha(lerpf(_fade_from, 0.0, _fade_elapsed / config.area_fade_out))


func _apply_alpha(value: float) -> void:
	_alpha = value
	_area.transparency = 1.0 - value


func _apply_scale(factor: float) -> void:
	_scale_factor = factor
	var radius: float = _radius * factor
	_area.scale = Vector3(radius, config.area_height, radius)


func _hide_vortex() -> void:
	_target = null
	_showing = false
	_fading_in = false
	_fading_out = false
	_pulsing = false
	_dust.emitting = false
	_apply_alpha(0.0)
	hide()
	set_process(false)


## Unit disc (radius 1, height 1), scaled to the reach and the thickness.
func _create_area() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 1.0
	disc.material = area_material
	_area = MeshInstance3D.new()
	_area.name = "Area"
	_area.mesh = disc
	_area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_area)


## Continuous dust under the blade, in world space so it stays behind the turn.
func _create_dust() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = config.dust_size / 2.0
	sphere.height = config.dust_size
	sphere.material = dust_material
	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.mesh = sphere
	_dust.amount = config.dust_amount
	_dust.lifetime = config.dust_lifetime
	_dust.local_coords = false
	_dust.emitting = false
	_dust.direction = Vector3.UP
	_dust.spread = 0.0
	_dust.initial_velocity_min = config.dust_rise_speed
	_dust.initial_velocity_max = config.dust_rise_speed
	_dust.gravity = Vector3.ZERO
	_dust.color_ramp = _fade_out_ramp()
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dust.position = config.dust_offset
	add_child(_dust)


## Opaque white to transparent: multiplies the material's color over the lifetime.
func _fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(Color.WHITE, 0.0))
	return ramp
