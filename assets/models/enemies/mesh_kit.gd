class_name MeshKit
extends RefCounted
## Builds one flat-shaded low-poly `ArrayMesh` out of primitive parts (box, wedge,
## cone, prism, loft) so the parts that share a joint and a material become a
## single mesh. Every face gets its own normal (faceted look), like
## LowPolyHumanoid. Enemy models build their meshes with it once, at load.
## See docs/specs/enemy-models.md.

var _surface: SurfaceTool = SurfaceTool.new()
var _triangles: int = 0


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


## Number of triangles added so far.
func get_triangle_count() -> int:
	return _triangles


## Finishes the mesh. The kit can not be used afterwards.
func build() -> ArrayMesh:
	return _surface.commit()


## Box of `size` centred on `center`, turned by `orient` around its centre.
func add_box(center: Vector3, size: Vector3, orient: Basis = Basis.IDENTITY) -> MeshKit:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for i: int in 8:
		c.append(center + orient * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	_quad(c[0], c[1], c[3], c[2], center)
	_quad(c[4], c[5], c[7], c[6], center)
	_quad(c[0], c[1], c[5], c[4], center)
	_quad(c[2], c[3], c[7], c[6], center)
	_quad(c[0], c[2], c[6], c[4], center)
	_quad(c[1], c[3], c[7], c[5], center)
	return self


## Triangular prism: `size.x` wide, and along Z the top slopes from `size.y`
## high at the back (+Z) to nothing at the front (−Z).
func add_wedge(center: Vector3, size: Vector3, orient: Basis = Basis.IDENTITY) -> MeshKit:
	var h: Vector3 = size * 0.5
	var p: Array[Vector3] = [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z),
		Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z),
	]
	for i: int in p.size():
		p[i] = center + orient * p[i]
	var inside: Vector3 = center + orient * Vector3(0.0, -h.y * 0.3, h.z * 0.3)
	_quad(p[0], p[1], p[3], p[2], inside)
	_quad(p[2], p[3], p[5], p[4], inside)
	_quad(p[0], p[1], p[5], p[4], inside)
	_tri(p[0], p[2], p[4], inside)
	_tri(p[1], p[3], p[5], inside)
	return self


## Cone with its base centred on `base` and its tip `height` above along +Y.
func add_cone(base: Vector3, radius: float, height: float, sides: int = 5, orient: Basis = Basis.IDENTITY) -> MeshKit:
	return add_prism(base, radius, radius, height, sides, orient, 0.0)


## Prism of an elliptical `sides`-gon (`radius_x` × `radius_z`) from `base` up
## `height` along +Y. `top_scale` shrinks the top ring (0 = cone tip).
func add_prism(base: Vector3, radius_x: float, radius_z: float, height: float, sides: int = 6,
		orient: Basis = Basis.IDENTITY, top_scale: float = 1.0) -> MeshKit:
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i: int in sides:
		var angle: float = -PI / 2.0 + TAU * i / sides
		var ring := Vector3(cos(angle) * radius_x, 0.0, sin(angle) * radius_z)
		bottom.append(base + orient * ring)
		top.append(base + orient * (ring * top_scale + Vector3.UP * height))
	var inside: Vector3 = base + orient * (Vector3.UP * height * 0.5)
	var bottom_centre: Vector3 = base
	var top_centre: Vector3 = base + orient * (Vector3.UP * height)
	for i: int in sides:
		var j: int = (i + 1) % sides
		_quad(bottom[i], bottom[j], top[j], top[i], inside)
		_tri(bottom_centre, bottom[i], bottom[j], inside)
		_tri(top_centre, top[i], top[j], inside)
	return self


## Rings `[y, half_width, half_depth, shift_x, shift_z]` (the last two optional)
## joined into a closed shape with capped ends, `sides` around; one vertex faces
## the front (−Z) so the centre line shows.
func add_loft(rings: Array, sides: int = 8, offset: Vector3 = Vector3.ZERO, orient: Basis = Basis.IDENTITY) -> MeshKit:
	var points: Array = []
	for ring: Array in rings:
		var shift := Vector3(ring[3] if ring.size() > 3 else 0.0, 0.0, ring[4] if ring.size() > 4 else 0.0)
		var loop: Array[Vector3] = []
		for i: int in sides:
			var angle: float = -PI / 2.0 + TAU * i / sides
			loop.append(offset + orient * (Vector3(cos(angle) * ring[1], ring[0], sin(angle) * ring[2]) + shift))
		points.append(loop)
	for k: int in rings.size() - 1:
		var inside: Vector3 = (_ring_centre(points[k]) + _ring_centre(points[k + 1])) * 0.5
		for i: int in sides:
			var j: int = (i + 1) % sides
			_quad(points[k][i], points[k][j], points[k + 1][j], points[k + 1][i], inside)
	var first_centre: Vector3 = _ring_centre(points[0])
	var last_centre: Vector3 = _ring_centre(points[points.size() - 1])
	var middle: Vector3 = (first_centre + last_centre) * 0.5
	for i: int in sides:
		var j: int = (i + 1) % sides
		_tri(first_centre, points[0][i], points[0][j], middle)
		_tri(last_centre, points[points.size() - 1][i], points[points.size() - 1][j], middle)
	return self


func _ring_centre(loop: Array) -> Vector3:
	var sum := Vector3.ZERO
	for point: Vector3 in loop:
		sum += point
	return sum / loop.size()


## Quad (two triangles sharing one normal) facing away from `inside`.
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	var normal: Vector3 = (c - a).cross(d - b)
	_tri(a, b, c, inside, normal)
	_tri(a, c, d, inside, normal)


## Triangle with a flat normal that points away from `inside`. Godot's front
## face is clockwise seen from outside, so the winding is flipped to match.
func _tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, forced_normal: Vector3 = Vector3.ZERO) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() < 1e-12:
		return
	var outward: Vector3 = (a + b + c) / 3.0 - inside
	if normal.dot(outward) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	if forced_normal != Vector3.ZERO:
		normal = forced_normal if forced_normal.dot(outward) > 0.0 else -forced_normal
	normal = normal.normalized()
	for vertex: Vector3 in [a, c, b]:
		_surface.set_normal(normal)
		_surface.add_vertex(vertex)
	_triangles += 1
