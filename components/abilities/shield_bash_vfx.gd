class_name ShieldBashVfx
extends Node3D
## Dust of the Shield Charge (docs/specs/warrior-abilities-rework.md §3.1),
## visual only: puffs kicked up at the player's feet while charging (they live
## in world space and stay behind), and a flat earth ring that opens and fades
## where the shield bash lands. Primitives and one CPUParticles3D created once
## and reused (Principles II and V). Must be top_level.

@export var config: ShieldBashVfxConfig
## Earth-colored dust (the registered earth of the Principle II).
@export var dust_material: StandardMaterial3D
## Flat earth ring (the one of the bosses' shockwave).
@export var ring_material: StandardMaterial3D

var _dust: CPUParticles3D = null
var _ring: MeshInstance3D = null
## The player's Visual while charging; null once the charge is over.
var _target: Node3D = null
## Seconds the ring has been opening; < 0 when hidden.
var _ring_time: float = -1.0
var _ring_radius: float = 0.0


func _ready() -> void:
	_create_dust()
	_create_ring()
	finish_dust()


func _process(delta: float) -> void:
	advance(delta)


## Starts the dust under `visual` (the player).
func begin_dust(visual: Node3D) -> void:
	_target = visual
	_follow()
	_dust.emitting = true
	set_process(true)


## The charge is over: the dust stops (the puffs alive finish on their own).
func finish_dust() -> void:
	_target = null
	_dust.emitting = false


## Opens the ring in front of `visual`; `scale` multiplies its radius.
func play_ring(visual: Node3D, scale_factor: float) -> void:
	var forward: Vector3 = -visual.global_basis.z
	forward.y = 0.0
	_ring.global_position = visual.global_position + forward.normalized() * config.ring_forward_offset + Vector3.UP * config.ground_offset
	_ring_radius = config.ring_radius * scale_factor
	_ring_time = 0.0
	_ring.visible = true
	_pose_ring(0.0)
	set_process(true)


func advance(delta: float) -> void:
	if _target != null:
		_follow()
	if _ring_time >= 0.0:
		_ring_time += delta
		if _ring_time >= config.ring_duration:
			_ring_time = -1.0
			_ring.visible = false
		else:
			_pose_ring(_ring_time / config.ring_duration)
	if _target == null and _ring_time < 0.0:
		set_process(false)


func is_dust_emitting() -> bool:
	return _dust.emitting


func is_ring_visible() -> bool:
	return _ring.visible


func get_ring_radius() -> float:
	return _ring_radius


func _follow() -> void:
	global_position = _target.global_position + Vector3.UP * config.ground_offset


## `progress` 0 → 1: the ring opens with an ease-out and fades out.
func _pose_ring(progress: float) -> void:
	var grown: float = 1.0 - pow(1.0 - progress, 2.0)
	var radius: float = maxf(_ring_radius * grown, 0.001)
	_ring.scale = Vector3(radius, 1.0, radius)
	_ring.transparency = lerpf(config.ring_start_transparency, 1.0, progress)


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
	_dust.spread = config.dust_spread_degrees
	_dust.initial_velocity_min = config.dust_speed
	_dust.initial_velocity_max = config.dust_speed
	_dust.gravity = Vector3.ZERO
	_dust.color_ramp = _fade_out_ramp()
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)


## A unit torus (outer radius 1) scaled to the ring's radius; lives in world space.
func _create_ring() -> void:
	var torus := TorusMesh.new()
	torus.outer_radius = 1.0
	torus.inner_radius = maxf(1.0 - config.ring_thickness, 0.0)
	torus.material = ring_material
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = torus
	_ring.top_level = true
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(Color.WHITE, 0.0))
	return ramp
