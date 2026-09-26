class_name ShakeState
extends RefCounted
## Timer of a sideways shake shared by the 3D enemy bar and the boss HUD bar.
## advance() returns a normalized offset (sine × linear decay); callers scale it
## to meters or pixels.

var _left: float = 0.0
var _duration: float = 0.0


func start(duration: float) -> void:
	_duration = duration
	_left = duration


func stop() -> void:
	_left = 0.0


func is_active() -> bool:
	return _left > 0.0


## Offset in [-1, 1]; 0 when the shake is over (or ends this step).
func advance(delta: float, frequency: float) -> float:
	if not is_active():
		return 0.0
	_left -= delta
	if _left <= 0.0:
		stop()
		return 0.0
	var elapsed: float = _duration - _left
	return (_left / _duration) * sin(elapsed * frequency * TAU)
