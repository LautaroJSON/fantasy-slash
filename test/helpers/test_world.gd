extends RefCounted
## Builders shared by physics-based tests. Not a test suite (no `_test` suffix).

const WORLD_LAYER: int = 1


## Static floor whose top surface is at y = 0.
static func make_floor(size: float) -> StaticBody3D:
	return make_box(Vector3(size, 1.0, size), Vector3(0.0, -0.5, 0.0))


static func make_box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = position
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body
