class_name HealthTrail
extends RefCounted
## Lost-health trail shared by the 3D enemy bar and the boss HUD bar: the fill
## drops instantly on a hit, the trail holds for trail_hold_time and then
## drains down to the fill at trail_drain_speed.

var fill_ratio: float = 1.0
var trail_ratio: float = 1.0
var hold_left: float = 0.0


func reset() -> void:
	fill_ratio = 1.0
	trail_ratio = 1.0
	hold_left = 0.0


## Returns true when the fill dropped (healing never raises it back).
func on_health(current: float, maximum: float, config: HealthBarConfig) -> bool:
	var ratio: float = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	if ratio >= fill_ratio:
		return false
	fill_ratio = ratio
	hold_left = config.trail_hold_time
	return true


## Returns true when the trail moved.
func advance(delta: float, config: HealthBarConfig) -> bool:
	if trail_ratio <= fill_ratio:
		return false
	if hold_left > 0.0:
		hold_left -= delta
		return false
	trail_ratio = maxf(trail_ratio - config.trail_drain_speed * delta, fill_ratio)
	return true
