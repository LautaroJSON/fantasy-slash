class_name CircleSlashVfx
extends MeshInstance3D
## Circular slash VFX (docs/specs/parry-riposte-rework.md §2.6): a flat ribbon
## around the player at the blade's height. Its head starts on the player's
## left and sweeps 360° (front, right, back) in sweep_duration; the tail fades
## behind it and the whole ribbon fades after one turn. Rebuilt every frame on
## one ImmediateMesh made once (Principle V). Top level: it stays where the
## slash was dealt.

@export var config: CircleSlashVfxConfig

var _immediate: ImmediateMesh = null
var _elapsed: float = 0.0
var _playing: bool = false
var _radius: float = 0.0


func _ready() -> void:
	top_level = true
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	visible = false


func _process(delta: float) -> void:
	advance(delta)


## Starts the slash around `center` (its −Z is the front), with the hit radius.
func play(center: Node3D, radius: float) -> void:
	global_transform = Transform3D(center.global_basis.orthonormalized(), center.global_position)
	_radius = radius
	_elapsed = 0.0
	_playing = true
	visible = true
	_rebuild()


func advance(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if _elapsed >= config.sweep_duration + config.fade_duration:
		_stop()
		return
	_rebuild()


func is_playing() -> bool:
	return _playing


## Degrees the head has swept from the player's left (0 to 360).
func get_head_degrees() -> float:
	return minf(_elapsed / config.sweep_duration, 1.0) * 360.0


## Alpha of the head now: head_alpha while sweeping, then fading to 0.
func get_head_alpha() -> float:
	if _elapsed <= config.sweep_duration:
		return config.head_alpha
	return config.head_alpha * maxf(1.0 - (_elapsed - config.sweep_duration) / config.fade_duration, 0.0)


func _stop() -> void:
	_playing = false
	visible = false
	_immediate.clear_surfaces()


func _rebuild() -> void:
	_immediate.clear_surfaces()
	var head: float = get_head_degrees()
	var tail: float = maxf(head - config.tail_degrees, 0.0)
	var span: float = head - tail
	if span <= 0.0:
		return
	var step: float = 360.0 / float(config.segments)
	var count: int = maxi(ceili(span / step), 1)
	var alpha: float = get_head_alpha()
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, config.material)
	for i: int in count + 1:
		var angle: float = tail + span * float(i) / float(count)
		var fade: float = float(i) / float(count)  # 0 at the tail, 1 at the head
		var direction := Vector3(-cos(deg_to_rad(angle)), 0.0, -sin(deg_to_rad(angle)))
		_immediate.surface_set_color(Color(1.0, 1.0, 1.0, alpha * fade))
		_immediate.surface_add_vertex(direction * (_radius - config.band_width) + Vector3.UP * config.height)
		_immediate.surface_set_color(Color(1.0, 1.0, 1.0, alpha * fade))
		_immediate.surface_add_vertex(direction * _radius + Vector3.UP * config.height)
	_immediate.surface_end()
