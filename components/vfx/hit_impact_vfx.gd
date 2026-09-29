class_name HitImpactVfx
extends Node3D
## One impact where the blade crossed an enemy (docs/specs/hit-impact-vfx.md):
## a thin shard of light stretches along the cut, then thins and fades, while a
## flash sphere grows and fades with a brief light and sparks fly along the
## cut. A critical hit is scaled up and shows a second crossed shard, in the
## same white. Built from primitives and one-shot CPUParticles3D
## (Principle II); every node is created once and reused by the pool of
## HitImpactVfxHost (Principle V). Must be top_level.

## Smallest size drawn, so no scale ever collapses to zero. Structural.
const MIN_SIZE: float = 0.001

var config: HitImpactVfxConfig
var glow_material: StandardMaterial3D

var _shard: MeshInstance3D = null
var _cross_shard: MeshInstance3D = null
## Wider, fainter copy of each shard (its child), so the cut glows.
var _halo: MeshInstance3D = null
var _cross_halo: MeshInstance3D = null
var _flash: MeshInstance3D = null
var _flash_light: OmniLight3D = null
var _sparks: CPUParticles3D = null
var _elapsed: float = 0.0
var _playing: bool = false
var _is_crit: bool = false


## Builds every node once; called by the host before the effect enters the tree.
func setup(vfx_config: HitImpactVfxConfig, glow: StandardMaterial3D) -> void:
	config = vfx_config
	glow_material = glow
	top_level = true
	_shard = _create_shard()
	_cross_shard = _create_shard()
	_halo = _create_halo(_shard)
	_cross_halo = _create_halo(_cross_shard)
	_create_flash()
	_create_sparks()
	_apply_material(glow_material)
	_stop()


func _process(delta: float) -> void:
	advance(delta)


## Plays at `point` on the enemy's surface, facing `normal` (towards the camera);
## `slash_dir` is the cut direction, already perpendicular to `normal`. A hit that
## leaves the enemy dead (`is_kill`) is bigger (docs/specs/kill-feedback.md).
func play(point: Vector3, normal: Vector3, slash_dir: Vector3, is_crit: bool, is_kill: bool = false) -> void:
	_is_crit = is_crit
	_elapsed = 0.0
	_playing = true
	var effect_scale: float = config.scale_for(is_crit, is_kill)
	global_transform = Transform3D(_basis_for(normal, slash_dir).scaled(Vector3.ONE * effect_scale), point)
	_cross_shard.rotation = Vector3(0.0, 0.0, deg_to_rad(config.crit_cross_angle))
	_shard.show()
	_cross_shard.visible = is_crit
	_flash.show()
	_flash_light.show()
	_update(0.0)
	_sparks.restart()
	_sparks.emitting = true
	set_process(true)


func advance(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_update(_elapsed)
	if _elapsed >= config.duration:
		_stop()


func is_playing() -> bool:
	return _playing


func is_crit() -> bool:
	return _is_crit


## Seconds since the effect started; used by the pool to reuse the oldest.
func get_elapsed() -> float:
	return _elapsed


func get_shard() -> MeshInstance3D:
	return _shard


func get_cross_shard() -> MeshInstance3D:
	return _cross_shard


func get_halo() -> MeshInstance3D:
	return _halo


func get_flash() -> MeshInstance3D:
	return _flash


func get_flash_light() -> OmniLight3D:
	return _flash_light


func get_sparks() -> CPUParticles3D:
	return _sparks


## Local X runs along the cut, Z towards the viewer and Y across the cut.
static func _basis_for(normal: Vector3, slash_dir: Vector3) -> Basis:
	var z: Vector3 = normal.normalized()
	var x: Vector3 = slash_dir.normalized()
	var y: Vector3 = z.cross(x).normalized()
	return Basis(x, y, z)


## The shard (core and halo) stretches during grow_time, then thins and fades
## until duration; the flash reaches its radius with the shard and fades over
## the whole duration.
func _update(elapsed: float) -> void:
	var grow: float = minf(elapsed / config.grow_time, 1.0)
	var fade: float = clampf((elapsed - config.grow_time) / (config.duration - config.grow_time), 0.0, 1.0)
	var shard_size := Vector3(
			maxf(config.shard_length * grow, MIN_SIZE),
			maxf(config.shard_width * (1.0 - fade), MIN_SIZE),
			config.shard_thickness)
	_shard.scale = shard_size
	_cross_shard.scale = shard_size
	var shard_transparency: float = lerpf(config.shard_start_transparency, 1.0, fade)
	_shard.transparency = shard_transparency
	var halo_transparency: float = lerpf(config.shard_halo_transparency, 1.0, fade)
	_halo.transparency = halo_transparency
	_cross_halo.transparency = halo_transparency
	_cross_shard.transparency = shard_transparency
	var progress: float = minf(elapsed / config.duration, 1.0)
	_flash.scale = Vector3.ONE * maxf(config.flash_radius * grow, MIN_SIZE)
	_flash.transparency = lerpf(config.flash_start_transparency, 1.0, progress)
	_flash_light.light_energy = config.flash_energy * (1.0 - progress)


func _apply_material(material: StandardMaterial3D) -> void:
	_shard.material_override = material
	_cross_shard.material_override = material
	_halo.material_override = material
	_cross_halo.material_override = material
	_flash.material_override = material
	_sparks.material_override = material
	_flash_light.light_color = material.albedo_color


## Unit-diameter ellipsoid scaled each frame to the shard's size, so its ends
## taper like a streak of light.
func _create_shard() -> MeshInstance3D:
	var shard := MeshInstance3D.new()
	shard.mesh = _unit_sphere()
	shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shard)
	return shard


## Child of `shard`: same length, shard_halo_scale times wider, fainter.
func _create_halo(shard: MeshInstance3D) -> MeshInstance3D:
	var halo := MeshInstance3D.new()
	halo.mesh = shard.mesh
	halo.scale = Vector3(1.0, config.shard_halo_scale, 1.0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shard.add_child(halo)
	return halo


func _unit_sphere() -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	return sphere


func _create_flash() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	_flash = MeshInstance3D.new()
	_flash.mesh = sphere
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.omni_range = config.flash_range
	_flash_light.shadow_enabled = false
	add_child(_flash_light)


## One-shot burst along the cut (local X), without gravity, fading out.
func _create_sparks() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * config.spark_size
	_sparks = CPUParticles3D.new()
	_sparks.mesh = box
	_sparks.amount = config.spark_amount
	_sparks.lifetime = config.spark_lifetime
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.emitting = false
	_sparks.direction = Vector3.RIGHT
	_sparks.spread = config.spark_spread
	_sparks.gravity = Vector3.ZERO
	_sparks.initial_velocity_min = config.spark_speed_min
	_sparks.initial_velocity_max = config.spark_speed_max
	_sparks.color_ramp = _fade_out_ramp()
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


## Opaque white to transparent: multiplies the material's color over the lifetime.
func _fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(Color.WHITE, 0.0))
	return ramp


## Shards, flash and light hide; the sparks finish on their own.
func _stop() -> void:
	_playing = false
	_shard.hide()
	_cross_shard.hide()
	_flash.hide()
	_flash_light.hide()
	set_process(false)
