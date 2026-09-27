class_name DamageNumber
extends MeshInstance3D
## One pooled floating damage number: a flat TextMesh that rises and fades out.
## Normal hits are white (or tinted, e.g. Affliction damage in the color of its
## bar), slightly smaller and dimmer; damage-over-time ticks are italic.
## Critical hits are white too, carry a suffix ("23!"), pop in big and shrink
## to crit_scale, and float slower and longer
## (docs/specs/affliction-damage-colors.md). There is no bold: emboldened fonts break TextMesh
## triangulation (docs/specs/combat-feedback.md §2.2).

signal finished(number: DamageNumber)

var _config: DamageNumberConfig
var _material: StandardMaterial3D
var _crit_material: StandardMaterial3D
var _text_mesh: TextMesh
var _elapsed: float = 0.0
var _active: bool = false
var _is_crit: bool = false
## Per-type values, chosen in show_damage().
var _lifetime: float = 0.0
var _rise_speed: float = 0.0
var _base_transparency: float = 0.0


## Called once by the pool; the TextMesh is created here and reused forever.
func setup(config: DamageNumberConfig, material: StandardMaterial3D, crit_material: StandardMaterial3D) -> void:
	_config = config
	_material = material
	_crit_material = crit_material
	_text_mesh = TextMesh.new()
	_text_mesh.depth = 0.0
	_text_mesh.font_size = config.font_size
	_text_mesh.pixel_size = config.pixel_size
	mesh = _text_mesh
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## `tint` colors a normal number (null = white); `over_time` sets the italic
## font of damage-over-time ticks. Critical hits ignore both.
func show_damage(amount: float, is_crit: bool, at: Vector3, tint: StandardMaterial3D = null, over_time: bool = false) -> void:
	_is_crit = is_crit
	if is_crit:
		_show_crit(amount)
	else:
		_show_normal(str(roundi(amount)), tint, over_time)
	_start(at)


## A word instead of a number (e.g. the name of an Affliction that deals no
## damage), with the look of a normal number (docs/specs/affliction-name-popup.md).
func show_text(text: String, at: Vector3, tint: StandardMaterial3D = null) -> void:
	_is_crit = false
	_show_normal(text, tint, false)
	_start(at)


func advance(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	global_position.y += _rise_speed * delta
	transparency = lerpf(_base_transparency, 1.0, _fade_amount())
	if _is_crit:
		scale = Vector3.ONE * _crit_pop_scale()
	if _elapsed >= _lifetime:
		_finish()


func is_active() -> bool:
	return _active


func is_crit() -> bool:
	return _is_crit


func get_text() -> String:
	return _text_mesh.text


func _start(at: Vector3) -> void:
	global_position = at
	transparency = _base_transparency
	_elapsed = 0.0
	_active = true
	show()
	set_process(true)


func _show_normal(text: String, tint: StandardMaterial3D, over_time: bool) -> void:
	_text_mesh.text = text
	_text_mesh.font = _config.over_time_font if over_time else null
	material_override = _material if tint == null else tint
	scale = Vector3.ONE * _config.normal_scale
	_lifetime = _config.lifetime
	_rise_speed = _config.rise_speed
	_base_transparency = _config.normal_transparency


func _show_crit(amount: float) -> void:
	_text_mesh.text = str(roundi(amount)) + _config.crit_suffix
	_text_mesh.font = null
	material_override = _crit_material
	scale = Vector3.ONE * _config.crit_pop_scale
	_lifetime = _config.crit_lifetime
	_rise_speed = _config.crit_rise_speed
	_base_transparency = 0.0


## Linear from crit_pop_scale down to crit_scale over crit_pop_duration.
func _crit_pop_scale() -> float:
	if _config.crit_pop_duration <= 0.0:
		return _config.crit_scale
	var progress: float = clampf(_elapsed / _config.crit_pop_duration, 0.0, 1.0)
	return lerpf(_config.crit_pop_scale, _config.crit_scale, progress)


## 0 until fade_start (fraction of the lifetime), then linear up to 1.
func _fade_amount() -> float:
	var progress: float = _elapsed / _lifetime
	if progress <= _config.fade_start:
		return 0.0
	return clampf((progress - _config.fade_start) / (1.0 - _config.fade_start), 0.0, 1.0)


func _finish() -> void:
	_active = false
	hide()
	set_process(false)
	finished.emit(self)


func is_over_time() -> bool:
	return _text_mesh.font != null
