class_name EnemyHealthBar
extends Node3D
## Floating health bar (LoL style): the fill drops instantly on a hit, the
## lost chunk stays as a dark "trail" for a moment and then drains down.
## Hidden until the first hit; always faces the active camera. Shakes sideways
## (in the camera plane) on critical or heavy hits. Bosses suppress it: their
## health is shown in the HUD instead (docs/specs/boss-hud-bar.md).

@export var health: HealthComponent
@export var config: HealthBarConfig

var _trail_state: HealthTrail = HealthTrail.new()
var _shake: ShakeState = ShakeState.new()
## Never shown nor processed (bosses, whose bar lives in the HUD).
var _suppressed: bool = false
## Resting position in the enemy, set once in _ready.
var _rest_position: Vector3 = Vector3.ZERO
## Uniform scale of the bar (bosses), kept when facing the camera.
var _bar_scale: float = 1.0

@onready var _background: MeshInstance3D = $Background
@onready var _trail: MeshInstance3D = $Trail
@onready var _fill: MeshInstance3D = $Fill
@onready var _level_label: MeshInstance3D = $LevelLabel
## Local to each bar instance (resource_local_to_scene), so pooled enemies never share text.
@onready var _level_text: TextMesh = _level_label.mesh as TextMesh


func _ready() -> void:
	_rest_position = Vector3(0.0, config.height_offset, 0.0)
	position = _rest_position
	_background.scale = Vector3(config.size.x, config.size.y, 1.0)
	_setup_level_label()
	health.health_changed.connect(_on_health_changed)
	reset()


func _process(delta: float) -> void:
	_face_camera()
	advance(delta)
	advance_shake(delta)


func reset() -> void:
	_trail_state.reset()
	_stop_shake()
	_apply_ratios()
	hide()
	set_process(false)


func advance(delta: float) -> void:
	if _trail_state.advance(delta, config):
		_apply_ratios()


func get_fill_ratio() -> float:
	return _trail_state.fill_ratio


func get_trail_ratio() -> float:
	return _trail_state.trail_ratio


## Called once by the enemy: lifts the bar above a bigger body and scales it
## (level label, debuff icons and shake scale with it).
func apply_body(body_scale: float, bar_scale: float) -> void:
	_rest_position = Vector3(0.0, config.height_offset * body_scale, 0.0)
	position = _rest_position
	_bar_scale = bar_scale
	scale = Vector3.ONE * bar_scale


## Called once by the enemy. A suppressed bar stays hidden for good.
func set_suppressed(value: bool) -> void:
	_suppressed = value
	if value:
		reset()


func is_suppressed() -> bool:
	return _suppressed


## Called on activation only; the label shares the bar's visibility.
func set_level(level: int) -> void:
	_level_text.text = config.level_format % level


func get_level_text() -> String:
	return _level_text.text


## Right-aligned text whose right edge sits level_gap left of the bar.
func _setup_level_label() -> void:
	_level_text.font_size = config.level_font_size
	_level_text.pixel_size = config.level_pixel_size
	_level_label.position.x = -config.size.x / 2.0 - config.level_gap


func _on_health_changed(current: float, maximum: float) -> void:
	if not _trail_state.on_health(current, maximum, config):
		return
	_apply_ratios()
	if _suppressed:
		return
	show()
	set_process(true)


func _face_camera() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		global_basis = camera.global_basis.orthonormalized() * _bar_scale


func _apply_ratios() -> void:
	_set_segment(_trail, _trail_state.trail_ratio)
	_set_segment(_fill, _trail_state.fill_ratio)


## Left-anchored segment: a unit quad scaled to `ratio` of the bar width.
func _set_segment(segment: MeshInstance3D, ratio: float) -> void:
	segment.visible = ratio > 0.0
	if not segment.visible:
		return
	var width: float = config.size.x * ratio
	segment.scale = Vector3(width, config.size.y, 1.0)
	segment.position.x = (width - config.size.x) / 2.0


## Pure: whether a hit should shake the bar.
static func should_shake(applied: float, max_health: float, is_crit: bool, bar_config: HealthBarConfig) -> bool:
	return is_crit or applied >= max_health * bar_config.heavy_hit_fraction


## Starts (or restarts) the shake when the hit is critical or heavy.
func notify_hit(applied: float, is_crit: bool) -> void:
	if _suppressed:
		return
	if should_shake(applied, health.max_health, is_crit, config):
		_shake.start(config.shake_duration)


func is_shaking() -> bool:
	return _shake.is_active()


## Called by _process and by tests. Offset decays linearly to 0 over shake_duration.
func advance_shake(delta: float) -> void:
	if not is_shaking():
		return
	var offset: float = config.shake_amplitude * _shake.advance(delta, config.shake_frequency)
	position = _rest_position + basis.x.normalized() * offset


func _stop_shake() -> void:
	_shake.stop()
	position = _rest_position
