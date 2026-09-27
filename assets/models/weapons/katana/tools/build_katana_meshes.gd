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
## - blade and sheath: compressed along Y so the tip does not move.
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
		out_positions.append(Vector3(p.x * section, mapped.x, p.z * section))
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
