class_name SlashArc
extends RefCounted
## A cut as geometry (poc/samurai-motion): the grip travels a circular arc
## around the right shoulder, in the humanoid's root space (forward -Z, right
## +X, up +Y, unscaled units), from `start` through `mid` to `end`. The blade
## points outward along the radius and its edge leads along the tangent.
##
## Progress along the arc is `f` in [0, 2]: 0 = start, 1 = mid, 2 = end
## (each half is linear in angle). `timing` maps clip seconds to `f` with a
## monotone cubic, so the author writes where the blade is at each moment
## (slow load, whip through the hit, soft settle) instead of joint angles.

var start: Vector3
var mid: Vector3
var axis: Vector3
var first_angle: float
var second_angle: float
## Grip distance from the arc centre.
var radius: float = 0.3
## Offset of the arc centre from the animated right shoulder.
var center_offset: Vector3 = Vector3.ZERO
## (clip seconds, f) points, ascending in time.
var timing: PackedVector2Array
## Weight ramps 0 -> 1 over blend_in.x..blend_in.y and 1 -> 0 over blend_out.
var blend_in: Vector2
var blend_out: Vector2
## Seconds the blade tip lags behind the grip at full angular speed (whip).
var tip_lag: float = 0.012
## Cap of the lag, in radians.
var max_lag: float = 0.6
## Tilt of the blade out of the arc plane, toward `axis` (radians).
var blade_lift: float = 0.0


static func create(start_dir: Vector3, mid_dir: Vector3, end_dir: Vector3) -> SlashArc:
	var arc := SlashArc.new()
	arc.start = start_dir.normalized()
	arc.axis = arc.start.cross(mid_dir.normalized()).normalized()
	arc.mid = (mid_dir - arc.axis * arc.axis.dot(mid_dir)).normalized()
	arc.first_angle = arc.start.angle_to(arc.mid)
	var end_flat: Vector3 = (end_dir - arc.axis * arc.axis.dot(end_dir)).normalized()
	var second: float = arc.mid.signed_angle_to(end_flat, arc.axis)
	if second < 0.0:
		second += TAU
	arc.second_angle = second
	return arc


## Radial direction of the grip at progress `f`.
func direction_at(f: float) -> Vector3:
	if f <= 1.0:
		return start.rotated(axis, first_angle * f)
	return mid.rotated(axis, second_angle * (f - 1.0))


## Angle swept per unit of `f` around `f`.
func angle_rate_at(f: float) -> float:
	return first_angle if f <= 1.0 else second_angle


func progress_at(t: float) -> float:
	return monotone_cubic(timing, t)


func weight_at(t: float) -> float:
	var w_in: float = 1.0 if blend_in.y <= blend_in.x else smoothstep(blend_in.x, blend_in.y, t)
	var w_out: float = 1.0 if blend_out.y <= blend_out.x else 1.0 - smoothstep(blend_out.x, blend_out.y, t)
	return minf(w_in, w_out)


## Fritsch-Carlson monotone cubic through `points` (x ascending), clamped at
## the ends: no overshoot between points, smooth velocity through them.
static func monotone_cubic(points: PackedVector2Array, x: float) -> float:
	var n: int = points.size()
	if n == 0:
		return 0.0
	if x <= points[0].x:
		return points[0].y
	if x >= points[n - 1].x:
		return points[n - 1].y
	var i: int = 0
	while points[i + 1].x < x:
		i += 1
	var m0: float = _tangent(points, i)
	var m1: float = _tangent(points, i + 1)
	var h: float = points[i + 1].x - points[i].x
	var s: float = (x - points[i].x) / h
	var s2: float = s * s
	var s3: float = s2 * s
	return (2.0 * s3 - 3.0 * s2 + 1.0) * points[i].y + (s3 - 2.0 * s2 + s) * h * m0 \
		+ (-2.0 * s3 + 3.0 * s2) * points[i + 1].y + (s3 - s2) * h * m1


static func _secant(points: PackedVector2Array, i: int) -> float:
	return (points[i + 1].y - points[i].y) / (points[i + 1].x - points[i].x)


static func _tangent(points: PackedVector2Array, i: int) -> float:
	var n: int = points.size()
	if n < 2:
		return 0.0
	if i == 0:
		return _secant(points, 0)
	if i == n - 1:
		return _secant(points, n - 2)
	var a: float = _secant(points, i - 1)
	var b: float = _secant(points, i)
	if a * b <= 0.0:
		return 0.0
	return 2.0 / (1.0 / a + 1.0 / b)
