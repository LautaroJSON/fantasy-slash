class_name BlockSparkVfx
extends Node3D
## Sparks on the shield when it blocks a hit (docs/specs/warrior-abilities-rework.md
## §3.1 and §3.2): a white additive burst in front of the player, towards the
## attacker, gone in tenths of a second (Principle II). A pool of one-shot
## CPUParticles3D created once (Principle V); when all of them play, the
## oldest restarts. Must be top_level.

@export var config: BlockSparkConfig
## White, unshaded, additive (alpha ≤ 0.5).
@export var spark_material: StandardMaterial3D

var _bursts: Array[CPUParticles3D] = []
var _next: int = 0


func _ready() -> void:
	for i: int in config.pool_size:
		_bursts.append(_create_burst(i))


## Plays one burst between `visual` (the player) and `source` (the attacker);
## `scale_factor` multiplies the speed of the sparks.
func play(visual: Node3D, source: Vector3, scale_factor: float) -> void:
	var to_source: Vector3 = source - visual.global_position
	to_source.y = 0.0
	var direction: Vector3 = -visual.global_basis.z if to_source.is_zero_approx() else to_source.normalized()
	direction.y = 0.0
	var burst: CPUParticles3D = _bursts[_next]
	_next = (_next + 1) % _bursts.size()
	burst.global_position = visual.global_position + direction.normalized() * config.forward_offset + Vector3.UP * config.height
	burst.direction = direction.normalized()
	burst.initial_velocity_min = config.spark_speed_min * scale_factor
	burst.initial_velocity_max = config.spark_speed_max * scale_factor
	burst.restart()
	burst.emitting = true


func get_pool_size() -> int:
	return _bursts.size()


## Bursts playing now (tests).
func count_emitting() -> int:
	var count: int = 0
	for burst: CPUParticles3D in _bursts:
		if burst.emitting:
			count += 1
	return count


func _create_burst(index: int) -> CPUParticles3D:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * config.spark_size
	box.material = spark_material
	var burst := CPUParticles3D.new()
	burst.name = "Burst%d" % index
	burst.mesh = box
	burst.amount = config.spark_amount
	burst.lifetime = config.spark_lifetime
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = false
	burst.top_level = true
	burst.local_coords = false
	burst.spread = config.spark_spread_degrees
	burst.gravity = Vector3.ZERO
	burst.color_ramp = _fade_out_ramp()
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(burst)
	return burst


func _fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(Color.WHITE, 0.0))
	return ramp
