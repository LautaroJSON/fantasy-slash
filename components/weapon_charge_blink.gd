class_name WeaponChargeBlink
extends Node
## Makes the weapon blink while a charge is about to max out
## (docs/specs/air-slash-visual-rework.md §2.3): from `start_ratio` of the
## charge, the weapon's mesh alternates a shared white additive overlay on and
## off, each blink shorter, from `period_start` down to `period_end` at full
## charge. Only assigns or clears the overlay: nothing is created per frame.

var _model: MeshInstance3D = null
var _overlay: StandardMaterial3D = null
var _start_ratio: float = 1.0
var _period_start: float = 0.0
var _period_end: float = 0.0
## Blinks elapsed, fractional: lit during the first half of each one.
var _progress: float = 0.0
var _blinking: bool = false


## The mesh that blinks (the weapon's Model); null disables the blinking.
func set_model(model: MeshInstance3D) -> void:
	stop()
	_model = model


## When the blinking starts, how fast it goes and the overlay it shows.
func configure(start_ratio: float, period_start: float, period_end: float, overlay: StandardMaterial3D) -> void:
	_start_ratio = start_ratio
	_period_start = period_start
	_period_end = period_end
	_overlay = overlay


## Advances the blinking by `delta` seconds at charge `ratio` in [0, 1].
func update(ratio: float, delta: float) -> void:
	if _model == null or _overlay == null or ratio < _start_ratio:
		stop()
		return
	if not _blinking:
		_blinking = true
		_progress = 0.0
	else:
		_progress += delta / get_period(ratio)
	_model.material_overlay = _overlay if is_lit() else null


## Seconds of one blink at charge `ratio`: shorter as the charge nears full.
func get_period(ratio: float) -> float:
	var weight: float = clampf(inverse_lerp(_start_ratio, 1.0, ratio), 0.0, 1.0)
	return lerpf(_period_start, _period_end, weight)


## Ends the blinking and clears the overlay.
func stop() -> void:
	_blinking = false
	_progress = 0.0
	if _model != null:
		_model.material_overlay = null


func is_blinking() -> bool:
	return _blinking


## True while the overlay is shown.
func is_lit() -> bool:
	return _blinking and fposmod(_progress, 1.0) < 0.5
