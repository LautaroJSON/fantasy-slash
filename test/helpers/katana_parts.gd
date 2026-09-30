extends RefCounted
## Parts of the generated katana mesh, in the space of the weapon scene
## (docs/specs/katana-visual-rework.md). The meshes are built in weapon space and
## their Model sits at identity, so vertices are already in the weapon's space.

const KatanaBuilder := preload("res://assets/models/weapons/katana/tools/build_katana_meshes.gd")
## Slack on the region limits, in meters.
const REGION_EPSILON: float = 0.0005


## Vertices of one surface of a mesh.
static func surface_points(mesh: Mesh, surface: int) -> PackedVector3Array:
	return mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]


## Guard vertices of the katana Model, in its parent's space: the tsuba and the
## two seppa (the habaki is in front of them, the fuchi behind).
static func guard_points(model: MeshInstance3D) -> PackedVector3Array:
	var points: PackedVector3Array = []
	var front: float = KatanaBuilder.GUARD_FRONT_Z - REGION_EPSILON
	var back: float = KatanaBuilder.TSUBA_BACK_Z + REGION_EPSILON
	for surface: int in [KatanaBuilder.BladeSurface.IRON, KatanaBuilder.BladeSurface.GOLD]:
		for p: Vector3 in surface_points(model.mesh, surface):
			if p.z < front or p.z > back:
				continue
			if surface == KatanaBuilder.BladeSurface.GOLD and p.z < KatanaBuilder.GUARD_FRONT_Z + REGION_EPSILON and absf(p.x) > KatanaBuilder.HABAKI_HALF_WIDTH - REGION_EPSILON:
				continue
			points.append(model.transform * p)
	return points


## Handle vertices (tsuka, kashira and fuchi) of the katana Model, in its
## parent's space: everything behind the guard.
static func handle_points(model: MeshInstance3D) -> PackedVector3Array:
	var points: PackedVector3Array = []
	for surface: int in [KatanaBuilder.BladeSurface.GOLD, KatanaBuilder.BladeSurface.TSUKA, KatanaBuilder.BladeSurface.RELIEF]:
		for p: Vector3 in surface_points(model.mesh, surface):
			if p.z > KatanaBuilder.TSUBA_BACK_Z + REGION_EPSILON:
				points.append(model.transform * p)
	return points


## Blade vertices (steel and hamon), in the weapon's space.
static func blade_points(model: MeshInstance3D) -> PackedVector3Array:
	var points: PackedVector3Array = []
	for surface: int in [KatanaBuilder.BladeSurface.STEEL, KatanaBuilder.BladeSurface.HAMON]:
		for p: Vector3 in surface_points(model.mesh, surface):
			points.append(model.transform * p)
	return points


## Bounds of a set of points.
static func bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	return box
