class_name RuneRingPortal
extends PortalStyle
## Portal style 1 (docs/specs/stages.md §4): a stone ring with glowing runes
## rises out of the ground, its inner disc grows and a brief light flashes;
## once open, motes drift up through it.

@export var config: PortalStyleConfig
## Stone ring, runes and disc move and scale together.
@export var ring: Node3D
@export var disc: MeshInstance3D
@export var flash: OmniLight3D
@export var particles: CPUParticles3D

var _ring_rest: Vector3
var _open_elapsed: float = -1.0
var _open_duration: float = 0.0
var _flash_elapsed: float = -1.0


func _ready() -> void:
	_ring_rest = ring.position
	particles.amount = config.particle_amount
	particles.lifetime = config.particle_lifetime
	particles.initial_velocity_min = config.particle_speed
	particles.initial_velocity_max = config.particle_speed
	particles.emitting = false
	flash.light_energy = 0.0


func play_open(duration: float) -> void:
	_open_duration = duration
	_open_elapsed = 0.0
	_flash_elapsed = 0.0
	particles.emitting = false
	_apply_opening(0.0)


func play_idle() -> void:
	_open_elapsed = -1.0
	_apply_opening(1.0)
	particles.emitting = true


func advance(delta: float) -> void:
	_advance_opening(delta)
	_advance_flash(delta)


## 0 = closed (ring under the ground, disc small), 1 = open.
func get_opening() -> float:
	if _open_elapsed < 0.0:
		return 1.0
	return clampf(_open_elapsed / _open_duration, 0.0, 1.0) if _open_duration > 0.0 else 1.0


func _advance_opening(delta: float) -> void:
	if _open_elapsed < 0.0:
		return
	_open_elapsed += delta
	_apply_opening(get_opening())


func _advance_flash(delta: float) -> void:
	if _flash_elapsed < 0.0:
		return
	_flash_elapsed += delta
	var left: float = 1.0 - _flash_elapsed / config.flash_fade if config.flash_fade > 0.0 else 0.0
	flash.light_energy = config.flash_energy * maxf(left, 0.0)
	if left <= 0.0:
		_flash_elapsed = -1.0


func _apply_opening(t: float) -> void:
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	ring.position = _ring_rest - Vector3.UP * config.rise_depth * (1.0 - eased)
	disc.scale = Vector3.ONE * lerpf(config.disc_start_scale, 1.0, eased)
