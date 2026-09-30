extends SceneTree
## Builds the Samurai's katana and its sheath (docs/specs/katana-visual-rework.md):
## original low-poly meshes with flat normals, built from the constants below
## (they are the asset's data) and saved as .res. It reuses the loft and triangle
## helpers of the knight set generator (same style, same flat shading).
##
## Weapon space (both scenes, Model at identity): the blade points to -Z, the
## edge is on -X and the back (mune) on +X, the flat of the blade is the XZ plane
## (thickness along Y). The tip curves toward +X: the blade axis goes from x = 0
## at the guard to TIP_X at the tip with a bow of SORI_BOW toward the edge. The
## right fist sits at z = -0.0533 (the Hilt marker), in the middle of the handle.
##
## Surfaces: blade 0 steel, 1 hamon, 2 iron (tsuba), 3 gold, 4 handle cloth,
## 5 handle relief; sheath 0 black lacquer, 1 red lacquer, 2 gold, 3 sageo.
##
## Run headless from the project root:
##   godot --headless --path . -s res://assets/models/weapons/katana/tools/build_katana_meshes.gd

const KnightBuilder := preload("res://assets/models/weapons/knight_set/tools/build_knight_meshes.gd")

const BLADE_OUT: String = "res://assets/models/weapons/katana/katana_blade.res"
const SHEATH_OUT: String = "res://assets/models/weapons/katana/katana_sheath.res"

enum BladeSurface { STEEL, HAMON, IRON, GOLD, TSUKA, RELIEF }
enum SheathSurface { LACQUER, RED, GOLD, SAGEO }

# ------------------------------------------------------------------ HILT

## Weapon z of the parts of the hilt, from the back of the katana to the blade.
const KASHIRA_BACK_Z: float = 0.133
const KASHIRA_FRONT_Z: float = 0.111
const TSUKA_FRONT_Z: float = -0.152
const FUCHI_FRONT_Z: float = -0.170
const TSUBA_BACK_Z: float = -0.173
const TSUBA_FRONT_Z: float = -0.181
## Front face of the front seppa: where the guard ends and the sheath mouth starts.
const GUARD_FRONT_Z: float = -0.184
const HABAKI_FRONT_Z: float = -0.214
const FIST_Z: float = -0.0533

## Handle section: circumradii of the octagon and swell at its middle.
const TSUKA_HX: float = 0.0265
const TSUKA_HY: float = 0.0215
const TSUKA_SWELL: float = 0.06
const TSUKA_RINGS: int = 13
## Handle relief: lozenges on the two wide faces, menuki on the two narrow ones.
const LOZENGE_COUNT: int = 6
const LOZENGE_FIRST_Z: float = -0.128
const LOZENGE_STEP: float = 0.04
const LOZENGE_HALF_WIDTH: float = 0.009
const LOZENGE_HALF_LENGTH: float = 0.018
const LOZENGE_LIFT: float = 0.003
const MENUKI_HALF_HEIGHT: float = 0.006
const MENUKI_HALF_LENGTH: float = 0.012
const MENUKI_LIFT: float = 0.004

## Tsuba: 12 cm mokko outline (4 lobes on the axes), 4 rhombic openings on the
## diagonals, gold edge. Sectors of 45 degrees: the ones on the axes are solid.
const TSUBA_R_PEAK: float = 0.06
const TSUBA_R_BOUNDARY: float = 0.054
const TSUBA_R_INNER: float = 0.020
const HOLE_CENTER_R: float = 0.036
const HOLE_RADIAL: float = 0.0085
const HOLE_TANGENTIAL: float = 0.010
const SEPPA_RADIUS: float = 0.026
const HABAKI_HALF_WIDTH: float = 0.028
const HABAKI_HALF_THICKNESS: float = 0.008

# ------------------------------------------------------------------ BLADE

const BLADE_START_Z: float = -0.190
const TIP_Z: float = -1.267
const TIP_X: float = 0.096
## How far the middle of the blade bows toward the edge (-X) from the chord.
const SORI_BOW: float = 0.02
const WIDTH_BASE: float = 0.050
const WIDTH_YOKOTE: float = 0.040
const HALF_THICKNESS_BASE: float = 0.0045
const HALF_THICKNESS_YOKOTE: float = 0.003
const KISSAKI_LENGTH: float = 0.05
const BLADE_STATIONS: int = 16
## Shinogi line across the width (0 at the edge, 1 at the back) and the height of
## the back corners relative to it.
const SHINOGI_FRACTION: float = 0.60
const MUNE_FRACTION: float = 0.65
## Where the hamon line crosses the width at each station (a wavy gunome).
const HAMON_PATTERN: Array[float] = [0.18, 0.30, 0.34, 0.24]

# ------------------------------------------------------------------ SHEATH

const SHEATH_BODY_START_Z: float = -0.206
const SHEATH_END_Z: float = -1.282
const SHEATH_HALF_THICKNESS: float = 0.0125
## The sheath is this much wider than the blade on each side.
const SHEATH_MARGIN_X: float = 0.011
const SHEATH_STATIONS: int = 12
const KOIGUCHI_GROW: float = 0.003
const KOJIRI_START_Z: float = -1.222
const KURIGATA_Z: float = -0.45
const KURIGATA_HALF: Vector3 = Vector3(0.008, 0.0085, 0.015)
const SAGEO_RADIUS: float = 0.0035


static func _save(mesh: ArrayMesh, path: String) -> void:
	var err: Error = ResourceSaver.save(mesh, path)
	if err != OK:
		push_error("build_katana_meshes: could not save %s (%s)" % [path, error_string(err)])
	else:
		print("build_katana_meshes: saved %s (%d surfaces)" % [path, mesh.get_surface_count()])


func _init() -> void:
	_save(build_blade(), BLADE_OUT)
	_save(build_sheath(), SHEATH_OUT)
	quit()


## Weapon x of the blade axis at weapon z: 0 at the start, TIP_X at the tip, bowed.
static func axis_x(z: float) -> float:
	var s: float = (BLADE_START_Z - z) / (BLADE_START_Z - TIP_Z)
	return TIP_X * s - SORI_BOW * 4.0 * s * (1.0 - s)


## Weapon z where the kissaki starts (the yokote).
static func yokote_z() -> float:
	return TIP_Z + KISSAKI_LENGTH


## Blade width at weapon z (constant taper from the base to the yokote).
static func blade_width(z: float) -> float:
	var f: float = clampf((BLADE_START_Z - z) / (BLADE_START_Z - yokote_z()), 0.0, 1.0)
	return lerpf(WIDTH_BASE, WIDTH_YOKOTE, f)


# ================================================================== KATANA

static func build_blade() -> ArrayMesh:
	var surfaces: Array[SurfaceTool] = KnightBuilder._tools(6)
	_add_blade(surfaces[BladeSurface.STEEL], surfaces[BladeSurface.HAMON])
	var gold: SurfaceTool = surfaces[BladeSurface.GOLD]
	_add_tsuba(surfaces[BladeSurface.IRON], gold)
	_add_hilt_metal(gold)
	_add_tsuka(surfaces[BladeSurface.TSUKA])
	_add_relief(surfaces[BladeSurface.RELIEF], gold)
	return KnightBuilder._commit(surfaces)


# ------------------------------------------------------------------ blade

## Cross-section of the blade at z, from the edge (left) to the back (right):
## edge, hamon line, shinogi, back corner (top and bottom, mirrored).
static func _blade_ring(z: float, left: float, right: float, half_thickness: float, hamon: float) -> PackedVector3Array:
	var w: float = right - left
	var t: float = half_thickness
	return PackedVector3Array([
		Vector3(left, 0.0, z),
		Vector3(left + hamon * w, t * hamon / SHINOGI_FRACTION, z),
		Vector3(left + SHINOGI_FRACTION * w, t, z),
		Vector3(right, MUNE_FRACTION * t, z),
		Vector3(right, -MUNE_FRACTION * t, z),
		Vector3(left + SHINOGI_FRACTION * w, -t, z),
		Vector3(left + hamon * w, -t * hamon / SHINOGI_FRACTION, z),
	])


static func _blade_rings() -> Array[PackedVector3Array]:
	var rings: Array[PackedVector3Array] = []
	var end_z: float = yokote_z()
	for i: int in BLADE_STATIONS + 1:
		var f: float = float(i) / float(BLADE_STATIONS)
		var z: float = lerpf(BLADE_START_Z, end_z, f)
		var w: float = lerpf(WIDTH_BASE, WIDTH_YOKOTE, f)
		var t: float = lerpf(HALF_THICKNESS_BASE, HALF_THICKNESS_YOKOTE, f)
		var cx: float = axis_x(z)
		rings.append(_blade_ring(z, cx - w * 0.5, cx + w * 0.5, t, HAMON_PATTERN[i % HAMON_PATTERN.size()]))
	# Kissaki: the back keeps going, the edge rises to the point.
	var yokote_right: float = axis_x(end_z) + WIDTH_YOKOTE * 0.5
	var mid_right: float = lerpf(yokote_right, TIP_X, 0.5)
	rings.append(_blade_ring(TIP_Z + KISSAKI_LENGTH * 0.5, mid_right - WIDTH_YOKOTE * 0.55, mid_right, HALF_THICKNESS_YOKOTE * 0.7, 0.25))
	rings.append(_blade_ring(TIP_Z, TIP_X, TIP_X, 0.0, 0.25))
	return rings


static func _add_blade(steel: SurfaceTool, hamon: SurfaceTool) -> void:
	var rings: Array[PackedVector3Array] = _blade_rings()
	var edge_tools: Array[SurfaceTool] = [hamon, steel, steel, steel, steel, steel, hamon]
	_loft_by_edge(rings, edge_tools)
	KnightBuilder._cap(steel, rings[0], KnightBuilder._center(rings[0]) - KnightBuilder._center(rings[1]))


## Like the knight loft, but each side of the section goes to its own surface.
static func _loft_by_edge(rings: Array[PackedVector3Array], edge_tools: Array[SurfaceTool]) -> void:
	for r: int in rings.size() - 1:
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		var axis_mid: Vector3 = (KnightBuilder._center(a) + KnightBuilder._center(b)) * 0.5
		for i: int in a.size():
			var j: int = (i + 1) % a.size()
			var face_mid: Vector3 = (a[i] + a[j] + b[i] + b[j]) * 0.25
			KnightBuilder._quad(edge_tools[i], a[i], a[j], b[j], b[i], face_mid - axis_mid)


# ------------------------------------------------------------------ tsuba

static func _polar(radius: float, angle: float, z: float) -> Vector3:
	return Vector3(cos(angle) * radius, sin(angle) * radius, z)


## Angle of the boundary between sectors k-1 and k.
static func _boundary_angle(k: int) -> float:
	return deg_to_rad(45.0 * float(k) - 22.5)


static func _add_tsuba(iron: SurfaceTool, gold: SurfaceTool) -> void:
	_tsuba_face(iron, TSUBA_BACK_Z, Vector3.BACK)
	_tsuba_face(iron, TSUBA_FRONT_Z, Vector3.FORWARD)
	# Gold edge: the outer wall of the outline.
	var outline: PackedVector3Array = _tsuba_outline()
	for i: int in outline.size():
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % outline.size()]
		var out := Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, 0.0)
		KnightBuilder._quad(gold, Vector3(a.x, a.y, TSUBA_BACK_Z), Vector3(b.x, b.y, TSUBA_BACK_Z), Vector3(b.x, b.y, TSUBA_FRONT_Z), Vector3(a.x, a.y, TSUBA_FRONT_Z), out)
	# Openings: walls between the two faces.
	for k: int in range(1, 8, 2):
		var hole: PackedVector3Array = _hole_points(k)
		var center: Vector3 = KnightBuilder._center(hole)
		for i: int in hole.size():
			var a: Vector3 = hole[i]
			var b: Vector3 = hole[(i + 1) % hole.size()]
			var out := Vector3(center.x - (a.x + b.x) * 0.5, center.y - (a.y + b.y) * 0.5, 0.0)
			KnightBuilder._quad(iron, Vector3(a.x, a.y, TSUBA_BACK_Z), Vector3(b.x, b.y, TSUBA_BACK_Z), Vector3(b.x, b.y, TSUBA_FRONT_Z), Vector3(a.x, a.y, TSUBA_FRONT_Z), out)


## Outer outline in order of angle (z = 0): sector boundaries and the lobe peaks.
static func _tsuba_outline() -> PackedVector3Array:
	var outline := PackedVector3Array()
	for k: int in 8:
		outline.append(_polar(TSUBA_R_BOUNDARY, _boundary_angle(k), 0.0))
		if k % 2 == 0:
			outline.append(_polar(TSUBA_R_PEAK, deg_to_rad(45.0 * float(k)), 0.0))
	return outline


## The rhombic opening of the diagonal sector k, in order: minus side, outer,
## plus side, inner (z = 0).
static func _hole_points(k: int) -> PackedVector3Array:
	var angle: float = deg_to_rad(45.0 * float(k))
	var u := Vector3(cos(angle), sin(angle), 0.0)
	var v := Vector3(-sin(angle), cos(angle), 0.0)
	var c: Vector3 = u * HOLE_CENTER_R
	return PackedVector3Array([c - v * HOLE_TANGENTIAL, c + u * HOLE_RADIAL, c + v * HOLE_TANGENTIAL, c - u * HOLE_RADIAL])


static func _tsuba_face(iron: SurfaceTool, z: float, out: Vector3) -> void:
	for k: int in 8:
		var a: Vector3 = _polar(TSUBA_R_INNER, _boundary_angle(k), z)
		var b: Vector3 = _polar(TSUBA_R_BOUNDARY, _boundary_angle(k), z)
		var c: Vector3 = _polar(TSUBA_R_BOUNDARY, _boundary_angle(k + 1), z)
		var d: Vector3 = _polar(TSUBA_R_INNER, _boundary_angle(k + 1), z)
		if k % 2 == 0:
			var peak: Vector3 = _polar(TSUBA_R_PEAK, deg_to_rad(45.0 * float(k)), z)
			KnightBuilder._tri(iron, a, b, peak, out)
			KnightBuilder._tri(iron, a, peak, c, out)
			KnightBuilder._tri(iron, a, c, d, out)
			continue
		var hole: PackedVector3Array = _hole_points(k)
		var pl: Vector3 = hole[0] + Vector3(0, 0, z)
		var po: Vector3 = hole[1] + Vector3(0, 0, z)
		var pr: Vector3 = hole[2] + Vector3(0, 0, z)
		var pi: Vector3 = hole[3] + Vector3(0, 0, z)
		KnightBuilder._tri(iron, a, b, pl, out)
		KnightBuilder._tri(iron, b, po, pl, out)
		KnightBuilder._tri(iron, b, c, po, out)
		KnightBuilder._tri(iron, c, pr, po, out)
		KnightBuilder._tri(iron, c, d, pr, out)
		KnightBuilder._tri(iron, d, pi, pr, out)
		KnightBuilder._tri(iron, d, a, pi, out)
		KnightBuilder._tri(iron, a, pl, pi, out)


# ------------------------------------------------------------------ gold fittings

## Kashira, fuchi, both seppa and the habaki.
static func _add_hilt_metal(gold: SurfaceTool) -> void:
	var kashira: Array[PackedVector3Array] = [
		_oct_ring(KASHIRA_FRONT_Z, TSUKA_HX * 1.06, TSUKA_HY * 1.06),
		_oct_ring(KASHIRA_FRONT_Z + 0.009, TSUKA_HX * 1.10, TSUKA_HY * 1.10),
		_oct_ring(KASHIRA_BACK_Z - 0.004, TSUKA_HX * 0.95, TSUKA_HY * 0.95),
		_oct_ring(KASHIRA_BACK_Z, TSUKA_HX * 0.6, TSUKA_HY * 0.6),
	]
	KnightBuilder._loft(gold, kashira, true, true)
	var fuchi: Array[PackedVector3Array] = [
		_oct_ring(FUCHI_FRONT_Z, TSUKA_HX * 1.04, TSUKA_HY * 1.04),
		_oct_ring(TSUKA_FRONT_Z, TSUKA_HX * 1.07, TSUKA_HY * 1.07),
	]
	KnightBuilder._loft(gold, fuchi, true, true)
	var back_seppa: Array[PackedVector3Array] = [KnightBuilder._ring_z(FUCHI_FRONT_Z, SEPPA_RADIUS, 8), KnightBuilder._ring_z(TSUBA_BACK_Z, SEPPA_RADIUS, 8)]
	KnightBuilder._loft(gold, back_seppa, true, true)
	var front_seppa: Array[PackedVector3Array] = [KnightBuilder._ring_z(TSUBA_FRONT_Z, SEPPA_RADIUS, 8), KnightBuilder._ring_z(GUARD_FRONT_Z, SEPPA_RADIUS, 8)]
	KnightBuilder._loft(gold, front_seppa, true, true)
	var habaki_z: float = (GUARD_FRONT_Z + HABAKI_FRONT_Z) * 0.5
	KnightBuilder._box(gold, Vector3(0.0, 0.0, habaki_z), Vector3(HABAKI_HALF_WIDTH, HABAKI_HALF_THICKNESS, (GUARD_FRONT_Z - HABAKI_FRONT_Z) * 0.5))


## Octagon around the Z axis with flat sides facing +-X and +-Y.
static func _oct_ring(z: float, hx: float, hy: float, cx: float = 0.0) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for i: int in 8:
		var a: float = TAU * (float(i) + 0.5) / 8.0
		ring.append(Vector3(cx + cos(a) * hx, sin(a) * hy, z))
	return ring


# ------------------------------------------------------------------ tsuka

static func tsuka_scale(z: float) -> float:
	var mid: float = (TSUKA_FRONT_Z + KASHIRA_FRONT_Z) * 0.5
	var half: float = (KASHIRA_FRONT_Z - TSUKA_FRONT_Z) * 0.5
	var u: float = (z - mid) / half
	return 1.0 + TSUKA_SWELL * (1.0 - u * u)


static func _add_tsuka(cloth: SurfaceTool) -> void:
	var rings: Array[PackedVector3Array] = []
	for i: int in TSUKA_RINGS:
		var z: float = lerpf(TSUKA_FRONT_Z, KASHIRA_FRONT_Z, float(i) / float(TSUKA_RINGS - 1))
		var s: float = tsuka_scale(z)
		rings.append(_oct_ring(z, TSUKA_HX * s, TSUKA_HY * s))
	KnightBuilder._loft(cloth, rings, false, false)


## Lozenges of the braid (on the wide faces) and the menuki (on the narrow ones).
static func _add_relief(relief: SurfaceTool, gold: SurfaceTool) -> void:
	var flat: float = cos(deg_to_rad(22.5))
	for i: int in LOZENGE_COUNT:
		var z: float = LOZENGE_FIRST_Z + LOZENGE_STEP * float(i)
		var top: float = TSUKA_HY * flat * tsuka_scale(z) - 0.0005
		for side: float in [1.0, -1.0]:
			var apex := Vector3(0.0, side * (top + LOZENGE_LIFT), z)
			var base: Array[Vector3] = [
				Vector3(-LOZENGE_HALF_WIDTH, side * top, z), Vector3(0.0, side * top, z - LOZENGE_HALF_LENGTH),
				Vector3(LOZENGE_HALF_WIDTH, side * top, z), Vector3(0.0, side * top, z + LOZENGE_HALF_LENGTH),
			]
			for j: int in 4:
				KnightBuilder._tri(relief, apex, base[j], base[(j + 1) % 4], Vector3(0.0, side, 0.0))
	var wide: float = TSUKA_HX * flat * tsuka_scale(FIST_Z) - 0.0005
	for side: float in [1.0, -1.0]:
		var apex := Vector3(side * (wide + MENUKI_LIFT), 0.0, FIST_Z)
		var base: Array[Vector3] = [
			Vector3(side * wide, -MENUKI_HALF_HEIGHT, FIST_Z), Vector3(side * wide, 0.0, FIST_Z - MENUKI_HALF_LENGTH),
			Vector3(side * wide, MENUKI_HALF_HEIGHT, FIST_Z), Vector3(side * wide, 0.0, FIST_Z + MENUKI_HALF_LENGTH),
		]
		for j: int in 4:
			KnightBuilder._tri(gold, apex, base[j], base[(j + 1) % 4], Vector3(side, 0.0, 0.0))


# ================================================================== SHEATH

## Half width and half thickness (flats) of the sheath at weapon z.
static func sheath_dims(z: float) -> Vector2:
	return Vector2(blade_width(z) * 0.5 + SHEATH_MARGIN_X, SHEATH_HALF_THICKNESS)


## Section of the sheath: flats on the two narrow sides (edge -X, back +X) and on
## the two wide ones, with the corners cut. Sides 0 (+X) and 4 (-X) are the red ones.
static func _sheath_ring(z: float, grow: float, shrink: float) -> PackedVector3Array:
	var dims: Vector2 = sheath_dims(z)
	var hw: float = (dims.x + grow) * shrink
	var ht: float = (dims.y + grow) * shrink
	var cx: float = axis_x(z)
	var a: float = ht * 0.5
	var b: float = hw * 0.68
	return PackedVector3Array([
		Vector3(cx + hw, -a, z), Vector3(cx + hw, a, z), Vector3(cx + b, ht, z), Vector3(cx - b, ht, z),
		Vector3(cx - hw, a, z), Vector3(cx - hw, -a, z), Vector3(cx - b, -ht, z), Vector3(cx + b, -ht, z),
	])


static func build_sheath() -> ArrayMesh:
	var surfaces: Array[SurfaceTool] = KnightBuilder._tools(4)
	var lacquer: SurfaceTool = surfaces[SheathSurface.LACQUER]
	var red: SurfaceTool = surfaces[SheathSurface.RED]
	var gold: SurfaceTool = surfaces[SheathSurface.GOLD]
	var body: Array[PackedVector3Array] = []
	for i: int in SHEATH_STATIONS + 1:
		var z: float = lerpf(SHEATH_BODY_START_Z, KOJIRI_START_Z, float(i) / float(SHEATH_STATIONS))
		body.append(_sheath_ring(z, 0.0, 1.0))
	var edge_tools: Array[SurfaceTool] = [red, lacquer, lacquer, lacquer, red, lacquer, lacquer, lacquer]
	_loft_by_edge(body, edge_tools)
	var koiguchi: Array[PackedVector3Array] = [
		_sheath_ring(GUARD_FRONT_Z, KOIGUCHI_GROW, 1.0), _sheath_ring(SHEATH_BODY_START_Z, KOIGUCHI_GROW, 1.0),
	]
	KnightBuilder._loft(gold, koiguchi, true, false)
	var kojiri: Array[PackedVector3Array] = [
		_sheath_ring(KOJIRI_START_Z, 0.001, 1.0), _sheath_ring(-1.252, 0.001, 0.92),
		_sheath_ring(-1.272, 0.001, 0.72), _sheath_ring(SHEATH_END_Z, 0.001, 0.45),
	]
	KnightBuilder._loft(gold, kojiri, true, true)
	_add_kurigata(gold)
	_add_sageo(surfaces[SheathSurface.SAGEO])
	return KnightBuilder._commit(surfaces)


## Weapon x of the outer face of the sheath's back at weapon z.
static func _back_x(z: float) -> float:
	return axis_x(z) + sheath_dims(z).x


static func _add_kurigata(gold: SurfaceTool) -> void:
	var center := Vector3(_back_x(KURIGATA_Z) + 0.004, 0.0, KURIGATA_Z)
	KnightBuilder._box(gold, center, KURIGATA_HALF)


## Start of the sageo: inside the kurigata, on its outer face.
static func sageo_start() -> Vector3:
	return Vector3(_back_x(KURIGATA_Z) + 0.008, 0.0, KURIGATA_Z)


## The cord: a loop out of the kurigata, a knot and two short tails, in the plane
## of the sheath (a little lower at the ends).
static func _add_sageo(cord: SurfaceTool) -> void:
	var p0: Vector3 = sageo_start()
	var knot: Vector3 = p0 + Vector3(0.034, 0.0, -0.032)
	var loop: Array[Vector3] = [p0, p0 + Vector3(0.026, 0.0, 0.0), p0 + Vector3(0.038, 0.0, -0.014), knot]
	var tail_a: Array[Vector3] = [knot, p0 + Vector3(0.031, -0.003, -0.056), p0 + Vector3(0.029, -0.005, -0.080)]
	var tail_b: Array[Vector3] = [knot, p0 + Vector3(0.040, -0.003, -0.054), p0 + Vector3(0.043, -0.005, -0.076)]
	for path: Array[Vector3] in [loop, tail_a, tail_b]:
		_cord(cord, path)
	KnightBuilder._box(cord, knot, Vector3.ONE * 0.0065)


## Square-section tube along a polyline in the XZ plane.
static func _cord(cord: SurfaceTool, path: Array[Vector3]) -> void:
	var rings: Array[PackedVector3Array] = []
	for i: int in path.size():
		var before: Vector3 = path[maxi(i - 1, 0)]
		var after: Vector3 = path[mini(i + 1, path.size() - 1)]
		var direction: Vector3 = (after - before).normalized()
		var side: Vector3 = Vector3.UP.cross(direction).normalized() * SAGEO_RADIUS
		var up: Vector3 = Vector3.UP * SAGEO_RADIUS
		rings.append(PackedVector3Array([path[i] + side + up, path[i] - side + up, path[i] - side - up, path[i] + side - up]))
	KnightBuilder._loft(cord, rings, true, true)
