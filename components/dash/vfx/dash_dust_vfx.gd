class_name DashDustVfx
extends DashVfxModule
## Module D (docs/specs/dash-feel.md): a burst of earth-coloured dust at the
## feet when the dash takes off and another when it ends, only on the floor.
## Two one-shot emitters, built once in setup().

@export var config: DashDustConfig
## Earth, translucent (shared with the wind cut dust).
@export var material: StandardMaterial3D

var _player: Player = null
var _take_off: CPUParticles3D = null
var _landing: CPUParticles3D = null


func setup(player: Player) -> void:
	_player = player
	var sphere := SphereMesh.new()
	sphere.radius = config.size / 2.0
	sphere.height = config.size
	sphere.material = material
	_take_off = _make_emitter(sphere)
	_landing = _make_emitter(sphere)


func dash_started(_dash: DashComponent) -> void:
	if _player.is_on_floor():
		_burst(_take_off)


func dash_ended(_dash: DashComponent, _cancelled: bool) -> void:
	if config.burst_on_end and _player.is_on_floor():
		_burst(_landing)


func get_take_off() -> CPUParticles3D:
	return _take_off


func get_landing() -> CPUParticles3D:
	return _landing


func _burst(emitter: CPUParticles3D) -> void:
	emitter.global_position = _player.global_position
	emitter.restart()
	emitter.emitting = true


## One-shot burst: every puff leaves at once, low and outwards, and fades out.
func _make_emitter(mesh: Mesh) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.mesh = mesh
	emitter.amount = config.amount
	emitter.lifetime = config.lifetime
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.emitting = false
	emitter.direction = Vector3.UP
	emitter.spread = config.spread_degrees
	emitter.initial_velocity_min = config.speed_min
	emitter.initial_velocity_max = config.speed_max
	emitter.gravity = Vector3.ZERO
	emitter.color_ramp = _fade_out_ramp()
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	return emitter


func _fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(Color.WHITE, 0.0))
	return ramp
