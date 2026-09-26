class_name HitboxMath
extends RefCounted
## Pure hitbox tests on the XZ plane. No state, no side effects.


## True when `point` lies in the rectangle that starts at `origin` and extends
## `length` along `flat_forward` (normalized), `half_width` to each side.
static func in_rectangle(origin: Vector3, flat_forward: Vector2, point: Vector3, length: float, half_width: float) -> bool:
	var offset := Vector2(point.x - origin.x, point.z - origin.z)
	var along: float = offset.dot(flat_forward)
	if along < 0.0 or along > length:
		return false
	var side: float = absf(offset.dot(flat_forward.orthogonal()))
	return side <= half_width


## True when `point` is within `radius` of `origin` on the XZ plane.
static func in_radius(origin: Vector3, point: Vector3, radius: float) -> bool:
	var offset := Vector2(point.x - origin.x, point.z - origin.z)
	return offset.length_squared() <= radius * radius
