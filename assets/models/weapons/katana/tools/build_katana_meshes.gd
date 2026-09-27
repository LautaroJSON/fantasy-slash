extends SceneTree
## Builds the derived katana meshes from katana.glb (docs/specs/katana-hand-proportions.md).
##
## The glb holds one skinned mesh with two bones: bone 0 is the blade with its
## handle and guard, bone 1 is the sheath. Each bone becomes a static mesh, and
## each region is reproportioned along the blade axis (mesh +Y) to match the
## player's hand:
## - handle (tsuka): stretched along Y, section scaled up;
## - guard (tsuba): diameter scaled up, a bit thicker, moved to just in front of
##   the fist;
## - blade: compressed along Y so the tip does not move.
## The sheath (docs/specs/katana-sheath-shape.md) follows the guard at its mouth,
## is twice as thick (its neck rings keep standing out of it as much as before)
## and its end reaches 1.2 cm farther, with both corners rounded, by moving the
## end outline points onto a filleted profile.
## Vertex count, indices and UV are kept, so the palette material still fits.
##
## Run headless from the project root:
##   godot --headless --path . -s res://assets/models/weapons/katana/tools/build_katana_meshes.gd

const SOURCE: String = "res://assets/models/weapons/katana/katana.glb"
const BLADE_OUT: String = "res://assets/models/weapons/katana/katana_blade.res"
const SHEATH_OUT: String = "res://assets/models/weapons/katana/katana_sheath.res"

const BLADE_BONE: int = 0
const SHEATH_BONE: int = 1

## Regions of the source mesh, as heights along its blade axis (mesh Y).
const POMMEL_Y: float = 0.004
const GUARD_BACK_Y: float = 0.1605
const GUARD_FRONT_Y: float = 0.1725
const BLADE_TIP_Y: float = 1.20223
const SHEATH_MOUTH_Y: float = 0.1627
const SHEATH_END_Y: float = 1.20458

## New heights of the same regions. katana.tscn places the mesh with a 1.1 scale
## and the pommel end toward +Z (weapon z = 0.055 - 1.1 * y), so these put the
## pommel 8 cm behind the right fist and the guard 1 cm in front of it.
const NEW_POMMEL_Y: float = -0.07091
const NEW_GUARD_BACK_Y: float = 0.20455
const GUARD_THICKNESS_SCALE: float = 1.25

## Cross-section scale of the handle and of the guard.
const HANDLE_SECTION_SCALE: float = 1.5
const GUARD_SECTION_SCALE: float = 2.0

## Blade vertices are flat (|z| of about 1 mm): inside the guard band they keep
## the blade width instead of taking the guard scale.
const BLADE_HALF_THICKNESS: float = 0.0011

## Sheath thickness (mesh Z): the body (|z| up to this) is scaled, the neck rings
## are moved out by the same amount.
const SHEATH_BODY_HALF_THICKNESS: float = 0.005
const SHEATH_THICKNESS_SCALE: float = 2.0
## New end of the sheath (weapon z = -1.282), and radius of its end corners.
const NEW_SHEATH_END_Y: float = 1.21545
const SHEATH_CORNER_RADIUS: float = 0.01364
## Source height from which the sheath outline belongs to its end (weapon
## z = -1.24).
const SHEATH_END_REGION_Y: float = 1.1773
## Two outline points closer than this are the same point.
const OUTLINE_EPSILON: float = 0.00005


func _init() -> void:
	_save(build(BLADE_BONE), BLADE_OUT)
	_save(build(SHEATH_BONE), SHEATH_OUT)
	quit()


## Arrays of the source skinned mesh (one surface, both bones).
static func source_arrays() -> Array:
	var source: Node = (load(SOURCE) as PackedScene).instantiate()
	var arrays: Array = _find_mesh(source).surface_get_arrays(0)
	source.free()
	return arrays


## The derived mesh of one bone (BLADE_BONE or SHEATH_BONE), without saving it.
static func build(bone: int) -> ArrayMesh:
	return _build(source_arrays(), bone)


static func _find_mesh(node: Node) -> ArrayMesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh as ArrayMesh
	for child: Node in node.get_children():
		var found: ArrayMesh = _find_mesh(child)
		if found != null:
			return found
	return null


static func new_guard_front_y() -> float:
	return NEW_GUARD_BACK_Y + (GUARD_FRONT_Y - GUARD_BACK_Y) * GUARD_THICKNESS_SCALE


## Maps a source height to its new height, and the Y scale of that region.
static func _map_y(y: float, bone: int) -> Vector2:
	var front: float = new_guard_front_y()
	if bone == SHEATH_BONE:
		return _segment(y, SHEATH_MOUTH_Y, SHEATH_END_Y, front, SHEATH_END_Y)
	if y <= GUARD_BACK_Y:
		return _segment(y, POMMEL_Y, GUARD_BACK_Y, NEW_POMMEL_Y, NEW_GUARD_BACK_Y)
	if y <= GUARD_FRONT_Y:
		return _segment(y, GUARD_BACK_Y, GUARD_FRONT_Y, NEW_GUARD_BACK_Y, front)
	return _segment(y, GUARD_FRONT_Y, BLADE_TIP_Y, front, BLADE_TIP_Y)


static func _segment(y: float, from_a: float, from_b: float, to_a: float, to_b: float) -> Vector2:
	var scale: float = (to_b - to_a) / (from_b - from_a)
	return Vector2(to_a + (y - from_a) * scale, scale)


## Cross-section scale of a source vertex.
static func _section_scale(p: Vector3, bone: int) -> float:
	if bone == SHEATH_BONE:
		return 1.0
	if p.y <= GUARD_BACK_Y:
		return HANDLE_SECTION_SCALE
	if p.y <= GUARD_FRONT_Y and absf(p.z) > BLADE_HALF_THICKNESS:
		return GUARD_SECTION_SCALE
	return 1.0


static func _build(src: Array, bone: int) -> ArrayMesh:
	var positions: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = src[Mesh.ARRAY_TANGENT]
	var uvs: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var per_vertex: int = bones.size() / positions.size()
	var remap: PackedInt32Array = []
	remap.resize(positions.size())
	var out_positions: PackedVector3Array = []
	var out_normals: PackedVector3Array = []
	var out_tangents: PackedFloat32Array = []
	var out_uvs: PackedVector2Array = []
	for i: int in positions.size():
		remap[i] = -1
		if main_bone(bones, weights, i, per_vertex) != bone:
			continue
		remap[i] = out_positions.size()
		var p: Vector3 = positions[i]
		var mapped: Vector2 = _map_y(p.y, bone)
		var section: float = _section_scale(p, bone)
		var scale := Vector3(section, mapped.y, section)
		var z: float = p.z * section
		if bone == SHEATH_BONE:
			z = _sheath_thickness(p.z)
			scale.z = SHEATH_THICKNESS_SCALE if absf(p.z) <= SHEATH_BODY_HALF_THICKNESS + OUTLINE_EPSILON else 1.0
		out_positions.append(Vector3(p.x * section, mapped.x, z))
		out_normals.append((normals[i] / scale).normalized())
		var t: Vector3 = (Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2]) * scale).normalized()
		out_tangents.append_array([t.x, t.y, t.z, tangents[i * 4 + 3]])
		out_uvs.append(uvs[i])
	var out_indices: PackedInt32Array = []
	for t: int in indices.size() / 3:
		var a: int = remap[indices[t * 3]]
		var b: int = remap[indices[t * 3 + 1]]
		var c: int = remap[indices[t * 3 + 2]]
		if a >= 0 and b >= 0 and c >= 0:
			out_indices.append_array([a, b, c])
	if bone == SHEATH_BONE:
		_round_sheath_end(out_positions, out_normals, out_indices)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_positions
	out[Mesh.ARRAY_NORMAL] = out_normals
	out[Mesh.ARRAY_TANGENT] = out_tangents
	out[Mesh.ARRAY_TEX_UV] = out_uvs
	out[Mesh.ARRAY_INDEX] = out_indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return result


static func main_bone(bones: PackedInt32Array, weights: PackedFloat32Array, vertex: int, per_vertex: int) -> int:
	var best: int = 0
	for j: int in per_vertex:
		if weights[vertex * per_vertex + j] > weights[vertex * per_vertex + best]:
			best = j
	return bones[vertex * per_vertex + best]


static func _save(mesh: ArrayMesh, path: String) -> void:
	var err: Error = ResourceSaver.save(mesh, path)
	if err != OK:
		push_error("build_katana_meshes: could not save %s (%s)" % [path, error_string(err)])
	else:
		print("build_katana_meshes: saved %s (%d vertices)" % [path, mesh.surface_get_array_len(0)])


## New thickness of a sheath vertex: the body is scaled, the neck rings moved
## out by as much as the body grew.
static func _sheath_thickness(z: float) -> float:
	var body: float = clampf(z, -SHEATH_BODY_HALF_THICKNESS, SHEATH_BODY_HALF_THICKNESS)
	return z + body * (SHEATH_THICKNESS_SCALE - 1.0)


## Distinct outline points (mesh X, Y) of the sheath, sorted by Y.
static func _outline_points(positions: PackedVector3Array) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for p: Vector3 in positions:
		var q := Vector2(p.x, p.y)
		var known: bool = false
		for o: Vector2 in points:
			if o.distance_to(q) < OUTLINE_EPSILON:
				known = true
				break
		if not known:
			points.append(q)
	var sorted: Array = Array(points)
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	return PackedVector2Array(sorted)


## Moves the end outline of the sheath onto a profile with rounded corners:
## outer edge, arc, straight end at NEW_SHEATH_END_Y, arc, inner edge. The end
## points keep their order (outer to inner) and their fraction of the outline
## length. The side normals of the end are recomputed from the new faces.
static func _round_sheath_end(positions: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> void:
	var end_start: float = _map_y(SHEATH_END_REGION_Y, SHEATH_BONE).x
	var outline: PackedVector2Array = _outline_points(positions)
	var body: Array[Vector2] = []
	var end: Array[Vector2] = []
	for q: Vector2 in outline:
		if q.y > end_start:
			end.append(q)
		else:
			body.append(q)
	# End points from outer to inner (X decreases along the end outline).
	end.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x > b.x)
	# The last station before the end is a pair of an inner and an outer point
	# (the outer one has the greater X). Each edge goes on from it through the
	# first end point of its side, which keeps the widening of the end.
	var n: int = body.size()
	var outer_b: Vector2 = body[n - 1] if body[n - 1].x > body[n - 2].x else body[n - 2]
	var inner_b: Vector2 = body[n - 1] if body[n - 1].x <= body[n - 2].x else body[n - 2]
	var outer_dir: Vector2 = (end[0] - outer_b).normalized()
	var inner_dir: Vector2 = (end[end.size() - 1] - inner_b).normalized()
	# Fillet centers: R inside both the edge and the end line.
	var r: float = SHEATH_CORNER_RADIUS
	var outer_in := Vector2(-outer_dir.y, outer_dir.x)
	var inner_in := Vector2(inner_dir.y, -inner_dir.x)
	var outer_c: Vector2 = _fillet_center(outer_b, outer_dir, outer_in, r)
	var inner_c: Vector2 = _fillet_center(inner_b, inner_dir, inner_in, r)
	var path: Array[Vector2] = []
	path.append_array(_arc(outer_c, outer_c - outer_in * r, Vector2(outer_c.x, NEW_SHEATH_END_Y)))
	path.append_array(_arc(inner_c, Vector2(inner_c.x, NEW_SHEATH_END_Y), inner_c - inner_in * r))
	var targets: Dictionary = {}
	var old_lengths: PackedFloat32Array = _cumulative(end)
	var new_lengths: PackedFloat32Array = _cumulative(path)
	for i: int in end.size():
		var fraction: float = old_lengths[i] / old_lengths[old_lengths.size() - 1]
		targets[end[i]] = _point_at(path, new_lengths, fraction * new_lengths[new_lengths.size() - 1])
	var moved: Array[bool] = []
	for i: int in positions.size():
		var p: Vector3 = positions[i]
		var q := Vector2(p.x, p.y)
		moved.append(false)
		for key: Vector2 in targets:
			if key.distance_to(q) < OUTLINE_EPSILON:
				var t: Vector2 = targets[key]
				positions[i] = Vector3(t.x, t.y, p.z)
				moved[i] = true
				break
	# Side normals (in the outline plane) of the moved vertices, from their faces.
	var face_normals: PackedVector3Array = []
	face_normals.resize(positions.size())
	for t: int in indices.size() / 3:
		var a: int = indices[t * 3]
		var b: int = indices[t * 3 + 1]
		var c: int = indices[t * 3 + 2]
		var face: Vector3 = (positions[b] - positions[a]).cross(positions[c] - positions[a])
		for v: int in [a, b, c]:
			if moved[v] and absf(normals[v].z) < 0.5:
				face_normals[v] += face if face.dot(normals[v]) >= 0.0 else -face
	for i: int in positions.size():
		if face_normals[i].length_squared() > 0.0:
			normals[i] = face_normals[i].normalized()


static func _fillet_center(edge_point: Vector2, edge_dir: Vector2, inward: Vector2, r: float) -> Vector2:
	var center_y: float = NEW_SHEATH_END_Y - r
	var base: Vector2 = edge_point + inward * r
	return base + edge_dir * ((center_y - base.y) / edge_dir.y)


## Points of an arc around center, from one point to another (the short way).
static func _arc(center: Vector2, from: Vector2, to: Vector2) -> Array[Vector2]:
	var steps: int = 16
	var a0: float = (from - center).angle()
	var sweep: float = wrapf((to - center).angle() - a0, -PI, PI)
	var r: float = from.distance_to(center)
	var points: Array[Vector2] = []
	for i: int in steps + 1:
		points.append(center + Vector2.from_angle(a0 + sweep * i / steps) * r)
	return points


static func _cumulative(points: Array[Vector2]) -> PackedFloat32Array:
	var lengths: PackedFloat32Array = [0.0]
	for i: int in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i].distance_to(points[i - 1]))
	return lengths


static func _point_at(points: Array[Vector2], lengths: PackedFloat32Array, length: float) -> Vector2:
	for i: int in range(1, points.size()):
		if length <= lengths[i] or i == points.size() - 1:
			var span: float = lengths[i] - lengths[i - 1]
			var w: float = 0.0 if span <= 0.0 else clampf((length - lengths[i - 1]) / span, 0.0, 1.0)
			return points[i - 1].lerp(points[i], w)
	return points[points.size() - 1]
