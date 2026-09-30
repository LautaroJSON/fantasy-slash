class_name StageTransition
extends Control
## Fade between stages and the stage banner (docs/specs/stages.md §5).
## play(): fade out → `covered` (swap the stage now) → hold → fade in →
## `finished`, then the banner stays up for a while. show_banner(): only the banner.

signal covered
signal finished

enum Phase { IDLE, FADING_OUT, HOLDING, FADING_IN }

@export var config: StageTransitionConfig
@export var fade: ColorRect
@export var banner: Control
@export var title_label: Label
@export var name_label: Label
@export var subtitle_label: Label

var _phase: Phase = Phase.IDLE
var _phase_left: float = 0.0
## Seconds the banner has been up (< 0 = hidden).
var _banner_elapsed: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()
	_set_fade_alpha(0.0)
	banner.visible = false


func _process(delta: float) -> void:
	advance(delta)


## Fades out, swaps (covered), fades in (finished) and shows the banner.
func play(title: String, stage_name: String, subtitle: String) -> void:
	_set_texts(title, stage_name, subtitle)
	_enter(Phase.FADING_OUT, config.fade_out)


## Only the banner (the start of the run).
func show_banner(title: String, stage_name: String, subtitle: String) -> void:
	_set_texts(title, stage_name, subtitle)
	_start_banner()


func is_playing() -> bool:
	return _phase != Phase.IDLE


## Seconds from play() until the screen is visible again.
func get_cover_duration() -> float:
	return config.fade_out + config.hold + config.fade_in


func get_fade_alpha() -> float:
	return fade.color.a


func is_banner_visible() -> bool:
	return banner.visible


func get_title_text() -> String:
	return title_label.text


func get_name_text() -> String:
	return name_label.text


func get_subtitle_text() -> String:
	return subtitle_label.text


## Steps the fade and the banner (public so tests can step it).
func advance(delta: float) -> void:
	_advance_phase(delta)
	_advance_banner(delta)


func _advance_phase(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_phase_left -= delta
	match _phase:
		Phase.FADING_OUT:
			_set_fade_alpha(_progress(config.fade_out))
			if _phase_left <= 0.0:
				_set_fade_alpha(1.0)
				_enter(Phase.HOLDING, config.hold)
				covered.emit()
		Phase.HOLDING:
			if _phase_left <= 0.0:
				_enter(Phase.FADING_IN, config.fade_in)
				_start_banner()
		Phase.FADING_IN:
			_set_fade_alpha(1.0 - _progress(config.fade_in))
			if _phase_left <= 0.0:
				_set_fade_alpha(0.0)
				_enter(Phase.IDLE, 0.0)
				finished.emit()


func _advance_banner(delta: float) -> void:
	if _banner_elapsed < 0.0:
		return
	_banner_elapsed += delta
	var fade_start: float = config.banner_duration - config.banner_fade
	if _banner_elapsed >= config.banner_duration:
		_banner_elapsed = -1.0
		banner.visible = false
		return
	banner.modulate.a = 1.0 if _banner_elapsed < fade_start else 1.0 - (_banner_elapsed - fade_start) / config.banner_fade


func _start_banner() -> void:
	_banner_elapsed = 0.0
	banner.visible = true
	banner.modulate.a = 1.0


func _enter(phase: Phase, duration: float) -> void:
	_phase = phase
	_phase_left = duration


## 0 → 1 over the current phase of length `total`.
func _progress(total: float) -> float:
	return 1.0 if total <= 0.0 else clampf(1.0 - _phase_left / total, 0.0, 1.0)


func _set_fade_alpha(alpha: float) -> void:
	fade.color = Color(config.fade_color, alpha)
	fade.visible = alpha > 0.0


func _set_texts(title: String, stage_name: String, subtitle: String) -> void:
	title_label.text = title
	name_label.text = stage_name
	subtitle_label.text = subtitle


func _apply_style() -> void:
	title_label.add_theme_font_size_override("font_size", config.title_font_size)
	name_label.add_theme_font_size_override("font_size", config.name_font_size)
	subtitle_label.add_theme_font_size_override("font_size", config.subtitle_font_size)
	for label: Label in [title_label, name_label, subtitle_label]:
		label.add_theme_color_override("font_color", config.text_color)
		label.add_theme_color_override("font_outline_color", config.outline_color)
		label.add_theme_constant_override("outline_size", config.outline_size)
