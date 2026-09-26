class_name CooldownClock
extends Control
## Translucent dark sector over an icon (LoL-style cooldown clock). It covers
## the fraction of time still left and uncovers clockwise from 12 o'clock.
## Redraws only when the fraction changes; the polygon buffer is reused
## (docs/specs/cooldown-clock.md).

enum Shape { CIRCLE, SQUARE }

## Tolerance when comparing angles (radians), so a sector edge that lands on a
## grid point is not added twice.
const ANGLE_EPSILON: float = 0.0001

@export var config: CooldownClockConfig
@export var shape: Shape

var _fraction: float = 0.0
var _points: PackedVector2Array = PackedVector2Array()


func _draw() -> void:
	_draw_sector()


## Clock covering its whole parent icon, ignoring the mouse.
static func create(clock_config: CooldownClockConfig, clock_shape: Shape) -> CooldownClock:
	var clock := CooldownClock.new()
	clock.config = clock_config
	clock.shape = clock_shape
	clock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return clock


## 0 = nothing drawn, 1 = the whole icon covered.
func set_fraction(fraction: float) -> void:
	var clamped: float = clampf(fraction, 0.0, 1.0)
	if clamped == _fraction:
		return
	_fraction = clamped
	queue_redraw()


func get_fraction() -> float:
	return _fraction


## Pure: fills `points` with the dark sector. A partial sector starts at the
## centre; a full turn is only the edge (a convex polygon). Empty when there is
## nothing to cover. `half_size` is the radius (CIRCLE) or half the side (SQUARE).
static func build_sector(points: PackedVector2Array, center: Vector2, half_size: float,
		fraction: float, shape: Shape, steps_per_turn: int) -> void:
	var step: float = TAU / steps_per_turn
	if fraction * TAU <= ANGLE_EPSILON:
		points.resize(0)
		return
	if fraction >= 1.0:
		points.resize(steps_per_turn)
		for k: int in steps_per_turn:
			points[k] = center + _edge(k * step, half_size, shape)
		return
	var start: float = (1.0 - fraction) * TAU
	var first_grid: int = floori((start + ANGLE_EPSILON) / step) + 1
	var grid_count: int = maxi(steps_per_turn - first_grid, 0)
	points.resize(3 + grid_count)
	points[0] = center
	points[1] = center + _edge(start, half_size, shape)
	for i: int in grid_count:
		points[2 + i] = center + _edge((first_grid + i) * step, half_size, shape)
	points[2 + grid_count] = center + _edge(TAU, half_size, shape)


## Point on the edge at `angle` (0 = 12 o'clock, clockwise). On the square the
## ray is projected onto its border.
static func _edge(angle: float, half_size: float, shape: Shape) -> Vector2:
	var direction := Vector2(sin(angle), -cos(angle))
	if shape == Shape.CIRCLE:
		return direction * half_size
	return direction * (half_size / maxf(absf(direction.x), absf(direction.y)))


func _draw_sector() -> void:
	var half: float = minf(size.x, size.y) / 2.0
	build_sector(_points, size / 2.0, half, _fraction, shape, config.steps_per_turn)
	if _points.size() >= 3:
		draw_colored_polygon(_points, config.color)
