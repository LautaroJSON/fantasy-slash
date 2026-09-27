class_name DashSpeedLinesVfx
extends DashVfxModule
## Module C (docs/specs/dash-feel.md): thin additive streaks behind the body,
## along the dash. They follow the player while it dashes and fade out once
## it ends. Built once in setup(); their layout is fixed (no randomness).

## Spreads the streak heights evenly (golden-ratio sequence). Structural.
const HEIGHT_SEQUENCE_STEP: float = 0.618

@export var config: DashSpeedLinesConfig
## White, unshaded, additive (shared with the wind cut).
@export var material: StandardMaterial3D

var _player: Player = null
var _lines: Array[MeshInstance3D] = []
var _following: bool = false
## Seconds left of the fade after the dash; 0 = not fading.
var _fade_left: float = 0.0


func _process(delta: float) -> void:
	advance(delta)


func setup(player: Player) -> void:
	_player = player
	var box := BoxMesh.new()
	box.size = Vector3(config.thickness, config.thickness, config.length)
	for i: int in config.count:
		var line := MeshInstance3D.new()
		line.mesh = box
		line.material_override = material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.position = _line_position(i)
		line.hide()
		add_child(line)
		_lines.append(line)
	set_process(false)


func dash_started(dash: DashComponent) -> void:
	var direction: Vector3 = dash.get_direction()
	global_basis = Basis(Vector3.UP, atan2(-direction.x, -direction.z))
	global_position = _player.global_position
	_following = true
	_fade_left = 0.0
	_set_alpha(config.alpha)
	for line: MeshInstance3D in _lines:
		line.show()
	set_process(true)


func dash_step(_dash: DashComponent) -> void:
	if _following:
		global_position = _player.global_position


func dash_ended(_dash: DashComponent, _cancelled: bool) -> void:
	_following = false
	_fade_left = config.fade


func advance(delta: float) -> void:
	if _following:
		global_position = _player.global_position
		return
	if _fade_left <= 0.0:
		return
	_fade_left = maxf(_fade_left - delta, 0.0)
	_set_alpha(config.alpha * _fade_left / config.fade)
	if _fade_left <= 0.0:
		for line: MeshInstance3D in _lines:
			line.hide()
		set_process(false)


func get_lines() -> Array[MeshInstance3D]:
	return _lines


## Local position of streak `index`: spread sideways and in height, behind the
## body (+Z is behind: the module faces the dash).
func _line_position(index: int) -> Vector3:
	var side: float = 0.0 if config.count <= 1 else lerpf(-config.spread, config.spread, float(index) / float(config.count - 1))
	var height: float = lerpf(config.height_min, config.height_max, fposmod(float(index) * HEIGHT_SEQUENCE_STEP, 1.0))
	return Vector3(side, height, config.length / 2.0 + config.thickness)


func _set_alpha(alpha: float) -> void:
	for line: MeshInstance3D in _lines:
		line.transparency = 1.0 - alpha
