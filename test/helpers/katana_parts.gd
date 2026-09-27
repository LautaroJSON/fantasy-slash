extends RefCounted
## Parts of the derived katana mesh, in the space of the weapon scene
## (docs/specs/katana-hand-proportions.md). The regions are the ones the
## generator writes (mesh +Y is the blade axis).

const KatanaBuilder := preload("res://assets/models/weapons/katana/tools/build_katana_meshes.gd")
## Slack on the region limits, in mesh meters.
const REGION_EPSILON: float = 0.0005


## Guard (tsuba) vertices of the katana Model, in its parent's space.
static func guard_points(model: MeshInstance3D) -> PackedVector3Array:
	var points: PackedVector3Array = []
	var back: float = KatanaBuilder.NEW_GUARD_BACK_Y - REGION_EPSILON
	var front: float = KatanaBuilder.new_guard_front_y() + REGION_EPSILON
	for p: Vector3 in _vertices(model):
		if p.y >= back and p.y <= front and absf(p.z) > KatanaBuilder.BLADE_HALF_THICKNESS:
			points.append(model.transform * p)
	return points


## Handle (tsuka) vertices of the katana Model, in its parent's space.
static func handle_points(model: MeshInstance3D) -> PackedVector3Array:
	var points: PackedVector3Array = []
	for p: Vector3 in _vertices(model):
		if p.y < KatanaBuilder.NEW_GUARD_BACK_Y - REGION_EPSILON:
			points.append(model.transform * p)
	return points


## Bounds of a set of points.
static func bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	return box


static func _vertices(model: MeshInstance3D) -> PackedVector3Array:
	return model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
