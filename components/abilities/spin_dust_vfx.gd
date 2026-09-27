class_name SpinDustVfx
extends Node3D
## Dust of the Spin (docs/specs/spin-visual-rework.md §12), visual only: puffs
## kicked up from a small ring around the player's feet (the center of the
## spin), rising and opening outwards while the spin lasts. The puffs live in
## world space, so they stay behind when the player walks while spinning.
## Built from primitives and one CPUParticles3D (Principle II), created once
## and reused (Principle V). Must be top_level: it follows the player through
## follow().

@export var config: SpinDustConfig
## Earth-colored dust.
@export var dust_material: StandardMaterial3D

var _dust: CPUParticles3D = null
## The player's Visual while spinning; null once the spin is over.
var _target: Node3D = null


func _ready() -> void:
	_create_dust()
	finish()


func _process(_delta: float) -> void:
	advance()


## Starts the dust under `visual` (the player).
func begin(visual: Node3D) -> void:
	_target = visual
	follow(visual)
	_dust.emitting = true
	set_process(true)


## Keeps the ring under the player's feet. One transform copy, no allocations.
func follow(visual: Node3D) -> void:
	global_position = visual.global_position + Vector3.UP * config.ground_offset


## The spin is over: the dust stops (the puffs alive finish on their own).
func finish() -> void:
	_target = null
	_dust.emitting = false
	set_process(false)


func advance() -> void:
	if _target != null:
		follow(_target)


func is_dust_emitting() -> bool:
	return _dust.emitting


func get_dust() -> CPUParticles3D:
	return _dust


## Continuous dust from a flat ring around the feet, in world space.
func _create_dust() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = config.dust_size / 2.0
	sphere.height = config.dust_size
	sphere.material = dust_material
	_dust = CPUParticles3D.new()
	_dust.name = "Particles"
	_dust.mesh = sphere
	_dust.amount = config.dust_amount
	_dust.lifetime = config.dust_lifetime
	_dust.local_coords = false
	_dust.emitting = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_dust.emission_ring_axis = Vector3.UP
	_dust.emission_ring_radius = config.dust_ring_radius
	_dust.emission_ring_inner_radius = config.dust_ring_radius
	_dust.emission_ring_height = 0.0
	_dust.direction = Vector3.UP
	_dust.spread = config.dust_spread_degrees
	_dust.initial_velocity_min = config.dust_rise_speed
	_dust.initial_velocity_max = config.dust_rise_speed
	_dust.gravity = Vector3.ZERO
	_dust.color_ramp = _fade_out_ramp()
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)


## Opaque white to transparent: multiplies the material's color over the lifetime.
func _fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(Color.WHITE, 0.0))
	return ramp
