extends SceneTree
## Builds the Warrior's knight set (docs/specs/warrior-sword-and-shield.md):
## an arming sword and a curved heater shield with the cross of Santiago.
## Both are original low-poly meshes with flat normals, built from the
## constants below (they are the asset's data) and saved as .res.
##
## Sword space (knight_sword.tscn, Model at identity): the blade points to -Z,
## the guard spans X and the flat of the blade is the XZ plane. The right fist
## sits at z = FIST_Z, in the middle of the grip.
## Shield space (knight_shield.tscn, Model at identity): +Y up, the outer
## (convex) face looks to -Z, the grip is on the back (+Z).
##
## Surfaces: sword 0 steel, 1 brass, 2 leather; shield 0 dark steel, 1 brass,
## 2 leather, 3 steel (rim and edge).
##
## Run headless from the project root:
##   godot --headless --path . -s res://assets/models/weapons/knight_set/tools/build_knight_meshes.gd

const SWORD_OUT: String = "res://assets/models/weapons/knight_set/knight_sword.res"
const SHIELD_OUT: String = "res://assets/models/weapons/knight_set/knight_shield.res"

# ------------------------------------------------------------------ SWORD

## Right fist center (weapon z); the grip is centered on it.
const FIST_Z: float = -0.205
const GRIP_LENGTH: float = 0.17
const GRIP_RADIUS: float = 0.016
const GRIP_BULGE_RADIUS: float = 0.0175
const GRIP_RING_RADIUS: float = 0.0195
const GRIP_RING_LENGTH: float = 0.009
const TIP_Z: float = -1.26
const BLADE_BASE_WIDTH: float = 0.08
const BLADE_POINT_WIDTH: float = 0.058
## The point closes over this length.
const BLADE_POINT_LENGTH: float = 0.13
const BLADE_RIDGE_HALF_THICKNESS: float = 0.012
const GUARD_HALF_WIDTH: float = 0.155
const GUARD_LENGTH: float = 0.032
const GUARD_HALF_THICKNESS: float = 0.018
## Central langet over the blade, and the flared fleur ends.
const GUARD_LANGET_HALF_LENGTH: float = 0.026
const GUARD_LANGET_HALF_WIDTH: float = 0.04
const GUARD_FLARE_X: float = 0.12
const GUARD_FLARE_HALF_LENGTH: float = 0.036
const POMMEL_RADIUS: float = 0.03
const POMMEL_HALF_THICKNESS: float = 0.012
const POMMEL_BEVEL: float = 0.007

# ------------------------------------------------------------------ SHIELD

const SHIELD_HALF_WIDTH: float = 0.29
## Height of the top corners (shoulders), of the top peak and of the bottom point.
const SHIELD_SHOULDER_Y: float = 0.30
const SHIELD_PEAK_Y: float = 0.40
const SHIELD_POINT_Y: float = -0.40
## Shape of the top arc and of the bottom curve (0 at the sides, 1 at the middle).
const SHIELD_TOP_EXPONENT: float = 0.7
const SHIELD_BOTTOM_EXPONENT: float = 0.6
## Radius of the horizontal curvature (convex to -Z) and number of strips.
const SHIELD_CURVE_RADIUS: float = 0.75
const SHIELD_COLUMNS: int = 12
const SHIELD_THICKNESS: float = 0.012
const RIM_WIDTH: float = 0.015
const RIM_LIFT: float = 0.003
const CROSS_CENTER_Y: float = 0.12
const CROSS_ARM_HALF_WIDTH: float = 0.02
const CROSS_TOP_Y: float = 0.30
const CROSS_ARM_X: float = 0.20
const CROSS_BLADE_HALF_WIDTH: float = 0.025
const CROSS_BLADE_NARROW_HALF_WIDTH: float = 0.018
const CROSS_BLADE_NARROW_Y: float = -0.20
const CROSS_POINT_Y: float = -0.30
const RELIEF_LIFT: float = 0.005
## Relief and rivet bases sink this much into the face (no gaps on the curve).
const RELIEF_SINK: float = 0.002
## Longest edge of a relief triangle, so it follows the curve.
const RELIEF_MAX_EDGE: float = 0.03
## Fleur-de-lis end of a cross arm, as (along the arm, across it) offsets in meters
## from where the arm widens: a side petal that curls back and out, its
## rounded top, the notch, the base of the middle petal and its tip.
const FLEUR_PETAL_BACK: Vector2 = Vector2(-0.012, 0.042)
const FLEUR_PETAL_TOP: Vector2 = Vector2(0.004, 0.05)
const FLEUR_PETAL_IN: Vector2 = Vector2(0.018, 0.034)
const FLEUR_NOTCH: Vector2 = Vector2(0.012, 0.014)
const FLEUR_MIDDLE: Vector2 = Vector2(0.03, 0.02)
const FLEUR_TIP: float = 0.05
const RIVET_COUNT: int = 16
const RIVET_INSET: float = 0.04
const RIVET_RADIUS: float = 0.014
const RIVET_HEIGHT: float = 0.006
const RIVET_SIDES: int = 6
## Grip on the back: bar standing off the plate (room for the fist) and straps.
const GRIP_BAR_HALF_WIDTH: float = 0.07
const GRIP_BAR_SIZE: Vector2 = Vector2(0.03, 0.022)
const GRIP_STANDOFF: float = 0.09
const GRIP_Y: float = -0.05
const STRAP_Y: float = 0.16
const STRAP_HALF_WIDTH: float = 0.11
const STRAP_SIZE: Vector2 = Vector2(0.025, 0.008)

# ------------------------------------------------------------------ GREATSWORD
# The Berserker's greatsword (docs/specs/berserker-greatsword.md): a wide, thick
# slab with bevelled edges, a brass block guard, a long two-handed leather grip
# and a small cross of Santiago near the guard. Same space as the sword.

const GREATSWORD_OUT: String = "res://assets/models/weapons/knight_set/knight_greatsword.res"
const GS_TIP_Z: float = -2.21
## Grip from the guard back to the pommel; both hands fit (right fist at
## +0.133, OffHand at -0.1) with a brass ring between them.
const GS_GRIP_FRONT_Z: float = -0.19
const GS_GRIP_BACK_Z: float = 0.23
const GS_GRIP_MIDDLE_RING_Z: float = 0.02
const GS_GRIP_RADIUS: float = 0.021
const GS_GRIP_RING_RADIUS: float = 0.026
const GS_GRIP_RING_LENGTH: float = 0.012
const GS_GUARD_LENGTH: float = 0.07
const GS_GUARD_HALF_WIDTH: float = 0.18
const GS_GUARD_HALF_THICKNESS: float = 0.03
## Guard ends: where they flare, how much, and the lance tip beyond.
const GS_GUARD_FLARE_X: float = 0.14
const GS_GUARD_FLARE_HALF_LENGTH: float = 0.05
const GS_GUARD_TIP_LENGTH: float = 0.02
const GS_BLADE_HALF_WIDTH: float = 0.15
## Flat of the blade (dark steel): half width and half thickness; the bevels
## (steel) close from there to the edge, whose thickness is zero.
const GS_FLAT_HALF_WIDTH: float = 0.11
const GS_FLAT_HALF_THICKNESS: float = 0.015
## Oblique point: over its last stretch the +X edge cuts across to a point
## shifted toward -X.
const GS_POINT_LENGTH: float = 0.36
const GS_POINT_X: float = -0.12
## Forge mark: the shield's cross, scaled, its blade arm toward the tip.
const GS_MARK_HEIGHT: float = 0.18
const GS_MARK_GAP: float = 0.08
const GS_MARK_LIFT: float = 0.003
const GS_POMMEL_RADIUS: float = 0.04
const GS_POMMEL_HALF_THICKNESS: float = 0.016
const GS_POMMEL_BEVEL: float = 0.009

enum SwordSurface { STEEL, BRASS, LEATHER }
enum ShieldSurface { DARK_STEEL, BRASS, LEATHER, STEEL }
enum GreatswordSurface { DARK_STEEL, STEEL, BRASS, LEATHER }


func _init() -> void:
	_save(build_sword(), SWORD_OUT)
	_save(build_shield(), SHIELD_OUT)
	_save(build_greatsword(), GREATSWORD_OUT)
	quit()


static func _save(mesh: ArrayMesh, path: String) -> void:
	var err: Error = ResourceSaver.save(mesh, path)
	if err != OK:
		push_error("Could not save %s (%d)" % [path, err])


# ================================================================== SWORD

static func build_sword() -> ArrayMesh:
	var surfaces: Array[SurfaceTool] = _tools(3)
	_add_blade(surfaces[SwordSurface.STEEL])
	_add_guard(surfaces[SwordSurface.BRASS])
	_add_grip(surfaces[SwordSurface.LEATHER], surfaces[SwordSurface.BRASS])
	_add_pommel(surfaces[SwordSurface.BRASS])
	return _commit(surfaces)


## Weapon z of the guard's front face (where the blade starts).
static func guard_front_z() -> float:
	return FIST_Z - GRIP_LENGTH * 0.5 - GUARD_LENGTH


static func _add_blade(st: SurfaceTool) -> void:
	var base_z: float = guard_front_z()
	var shoulder_z: float = TIP_Z + BLADE_POINT_LENGTH
	var rings: Array[PackedVector3Array] = [
		_diamond_ring(base_z, BLADE_BASE_WIDTH * 0.5, BLADE_RIDGE_HALF_THICKNESS),
		_diamond_ring(shoulder_z, BLADE_POINT_WIDTH * 0.5, BLADE_RIDGE_HALF_THICKNESS * 0.8),
		_diamond_ring(TIP_Z, 0.0, 0.0),
	]
	_loft(st, rings, true, false)


static func _diamond_ring(z: float, half_width: float, half_thickness: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(half_width, 0, z), Vector3(0, half_thickness, z),
		Vector3(-half_width, 0, z), Vector3(0, -half_thickness, z),
	])


## Straight brass guard along X, with a langet over the blade and flared ends
## that close in a lance tip (the fleur of the shield's cross).
static func _add_guard(st: SurfaceTool) -> void:
	var z0: float = guard_front_z()
	var zc: float = z0 + GUARD_LENGTH * 0.5
	var t: float = GUARD_HALF_THICKNESS
	var half: float = GUARD_LENGTH * 0.5
	# Stations along X (from -X to +X): x, half length along Z, half thickness.
	var stations: Array[Vector3] = [
		Vector3(-GUARD_HALF_WIDTH, 0.0, t * 0.4),
		Vector3(-GUARD_HALF_WIDTH + 0.018, GUARD_FLARE_HALF_LENGTH, t * 0.8),
		Vector3(-GUARD_FLARE_X, half * 0.8, t * 0.8),
		Vector3(-GUARD_LANGET_HALF_WIDTH, half, t),
		Vector3(0.0, half + GUARD_LANGET_HALF_LENGTH, t * 1.15),
		Vector3(GUARD_LANGET_HALF_WIDTH, half, t),
		Vector3(GUARD_FLARE_X, half * 0.8, t * 0.8),
		Vector3(GUARD_HALF_WIDTH - 0.018, GUARD_FLARE_HALF_LENGTH, t * 0.8),
		Vector3(GUARD_HALF_WIDTH, 0.0, t * 0.4),
	]
	var rings: Array[PackedVector3Array] = []
	for s: Vector3 in stations:
		rings.append(PackedVector3Array([
			Vector3(s.x, 0, zc - s.y), Vector3(s.x, s.z, zc),
			Vector3(s.x, 0, zc + s.y), Vector3(s.x, -s.z, zc),
		]))
	_loft(st, rings, false, false)


static func _add_grip(leather: SurfaceTool, brass: SurfaceTool) -> void:
	var front: float = FIST_Z - GRIP_LENGTH * 0.5
	var back: float = FIST_Z + GRIP_LENGTH * 0.5
	var sides: int = 8
	_loft(leather, [
		_ring_z(front, GRIP_RADIUS, sides), _ring_z(FIST_Z, GRIP_BULGE_RADIUS, sides), _ring_z(back, GRIP_RADIUS, sides),
	], true, true)
	for z: float in [front, back - GRIP_RING_LENGTH]:
		_loft(brass, [_ring_z(z, GRIP_RING_RADIUS, sides), _ring_z(z + GRIP_RING_LENGTH, GRIP_RING_RADIUS, sides)], true, true)


## Octagonal ring around the Z axis.
static func _ring_z(z: float, radius: float, sides: int) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for i: int in sides:
		var a: float = TAU * (float(i) + 0.5) / float(sides)
		ring.append(Vector3(cos(a) * radius, sin(a) * radius, z))
	return ring


## Wheel pommel: a bevelled disc in the XZ plane, behind the grip.
static func _add_pommel(st: SurfaceTool) -> void:
	var center := Vector3(0, 0, FIST_Z + GRIP_LENGTH * 0.5 + POMMEL_RADIUS - 0.004)
	_disc_pommel(st, center, POMMEL_RADIUS, POMMEL_HALF_THICKNESS, POMMEL_BEVEL)


## Bevelled disc in the XZ plane (wheel pommel), with octagonal rims.
static func _disc_pommel(st: SurfaceTool, center: Vector3, radius: float, half_thickness: float, bevel: float) -> void:
	var sides: int = 8
	var rings: Array[PackedVector3Array] = []
	var profile: Array[Vector2] = [  # (y, radius)
		Vector2(-half_thickness, radius - bevel),
		Vector2(-half_thickness + bevel * 0.6, radius),
		Vector2(half_thickness - bevel * 0.6, radius),
		Vector2(half_thickness, radius - bevel),
	]
	for p: Vector2 in profile:
		var ring := PackedVector3Array()
		for i: int in sides:
			var a: float = TAU * float(i) / float(sides)
			ring.append(center + Vector3(cos(a) * p.y, p.x, sin(a) * p.y))
		rings.append(ring)
	_loft(st, rings, true, true)


## Weapon z of the pommel's back end (the sword's rear end).
static func pommel_end_z() -> float:
	return FIST_Z + GRIP_LENGTH * 0.5 + POMMEL_RADIUS * 2.0 - 0.004


# ================================================================== GREATSWORD

static func build_greatsword() -> ArrayMesh:
	var surfaces: Array[SurfaceTool] = _tools(4)
	_add_gs_blade(surfaces[GreatswordSurface.DARK_STEEL], surfaces[GreatswordSurface.STEEL])
	var brass: SurfaceTool = surfaces[GreatswordSurface.BRASS]
	_add_gs_guard(brass)
	for side: float in [1.0, -1.0]:
		_add_gs_mark(brass, side)
	_add_gs_grip(surfaces[GreatswordSurface.LEATHER], brass)
	var pommel := Vector3(0, 0, GS_GRIP_BACK_Z + GS_POMMEL_RADIUS - 0.005)
	_disc_pommel(brass, pommel, GS_POMMEL_RADIUS, GS_POMMEL_HALF_THICKNESS, GS_POMMEL_BEVEL)
	return _commit(surfaces)


## Weapon z of the guard's front face (where the blade starts).
static func gs_guard_front_z() -> float:
	return GS_GRIP_FRONT_Z - GS_GUARD_LENGTH


## Hexagonal blade section at z: edge +X, flat top, edge -X, flat bottom.
## Vertices 1-2 and 4-5 bound the flats; the other quads are the bevels.
static func _gs_ring(z: float, edge_px: float, edge_nx: float, flat_px: float, flat_nx: float, half_thickness: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(edge_px, 0, z), Vector3(flat_px, half_thickness, z), Vector3(flat_nx, half_thickness, z),
		Vector3(edge_nx, 0, z), Vector3(flat_nx, -half_thickness, z), Vector3(flat_px, -half_thickness, z),
	])


## The slab: full width from the guard to the start of the point, then the
## +X edge cuts obliquely to a point shifted toward -X.
static func _add_gs_blade(flat: SurfaceTool, bevel: SurfaceTool) -> void:
	var base_z: float = gs_guard_front_z()
	var shoulder_z: float = GS_TIP_Z + GS_POINT_LENGTH
	var w: float = GS_BLADE_HALF_WIDTH
	var f: float = GS_FLAT_HALF_WIDTH
	var rings: Array[PackedVector3Array] = [
		_gs_ring(base_z, w, -w, f, -f, GS_FLAT_HALF_THICKNESS),
		_gs_ring(shoulder_z, w, -w, f, -f, GS_FLAT_HALF_THICKNESS),
		_gs_ring(GS_TIP_Z, GS_POINT_X, GS_POINT_X, GS_POINT_X, GS_POINT_X, 0.0),
	]
	for r: int in rings.size() - 1:
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		var mid: Vector3 = (_center(a) + _center(b)) * 0.5
		for i: int in a.size():
			var j: int = (i + 1) % a.size()
			var st: SurfaceTool = flat if i == 1 or i == 4 else bevel
			var face_mid: Vector3 = (a[i] + a[j] + b[i] + b[j]) * 0.25
			_quad(st, a[i], a[j], b[j], b[i], face_mid - mid)


## Brass block guard, its ends flaring into the sword's lance tip.
static func _add_gs_guard(st: SurfaceTool) -> void:
	var zc: float = gs_guard_front_z() + GS_GUARD_LENGTH * 0.5
	var t: float = GS_GUARD_HALF_THICKNESS
	var half: float = GS_GUARD_LENGTH * 0.5
	var tip_x: float = GS_GUARD_HALF_WIDTH
	var flare_x: float = tip_x - GS_GUARD_TIP_LENGTH
	# Stations along X (from -X to +X): x, half length along Z, half thickness.
	var stations: Array[Vector3] = [
		Vector3(-tip_x, 0.0, t * 0.4),
		Vector3(-flare_x, GS_GUARD_FLARE_HALF_LENGTH, t * 0.8),
		Vector3(-GS_GUARD_FLARE_X, half * 0.85, t * 0.9),
		Vector3(0.0, half, t),
		Vector3(GS_GUARD_FLARE_X, half * 0.85, t * 0.9),
		Vector3(flare_x, GS_GUARD_FLARE_HALF_LENGTH, t * 0.8),
		Vector3(tip_x, 0.0, t * 0.4),
	]
	var rings: Array[PackedVector3Array] = []
	for s: Vector3 in stations:
		# Octagonal section with bevelled corners, so the block reads chunky.
		rings.append(PackedVector3Array([
			Vector3(s.x, s.z * 0.55, zc - s.y), Vector3(s.x, s.z, zc - s.y * 0.55),
			Vector3(s.x, s.z, zc + s.y * 0.55), Vector3(s.x, s.z * 0.55, zc + s.y),
			Vector3(s.x, -s.z * 0.55, zc + s.y), Vector3(s.x, -s.z, zc + s.y * 0.55),
			Vector3(s.x, -s.z, zc - s.y * 0.55), Vector3(s.x, -s.z * 0.55, zc - s.y),
		]))
	_loft(st, rings, false, false)


## The shield's cross of Santiago, small, raised on one flat of the blade
## (side +1 on +Y, -1 on -Y), its blade arm pointing to the tip.
static func _add_gs_mark(st: SurfaceTool, side: float) -> void:
	var cross: PackedVector2Array = cross_outline()
	var k: float = GS_MARK_HEIGHT / (CROSS_TOP_Y - CROSS_POINT_Y)
	var top_z: float = gs_guard_front_z() - GS_MARK_GAP
	var up := Vector3(0, side, 0)
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(cross)
	for t: int in tris.size() / 3:
		_tri(st, _gs_mark_point(cross[tris[t * 3]], GS_MARK_LIFT, k, top_z, side), _gs_mark_point(cross[tris[t * 3 + 1]], GS_MARK_LIFT, k, top_z, side),
				_gs_mark_point(cross[tris[t * 3 + 2]], GS_MARK_LIFT, k, top_z, side), up)
	var n: int = cross.size()
	for i: int in n:
		var p: Vector2 = cross[i]
		var q: Vector2 = cross[(i + 1) % n]
		var out := Vector3(q.y - p.y, 0.0, p.x - q.x)  # outward in the XZ plane (Z grows with y)
		_quad(st, _gs_mark_point(p, GS_MARK_LIFT, k, top_z, side), _gs_mark_point(q, GS_MARK_LIFT, k, top_z, side),
				_gs_mark_point(q, -RELIEF_SINK, k, top_z, side), _gs_mark_point(p, -RELIEF_SINK, k, top_z, side), out)


## A point of the forge mark outline, raised `lift` over the flat of one side.
static func _gs_mark_point(p: Vector2, lift: float, k: float, top_z: float, side: float) -> Vector3:
	return Vector3(p.x * k, side * (GS_FLAT_HALF_THICKNESS + lift), top_z + (p.y - CROSS_TOP_Y) * k)


## Long octagonal leather grip with brass rings at both ends and between the hands.
static func _add_gs_grip(leather: SurfaceTool, brass: SurfaceTool) -> void:
	var sides: int = 8
	_loft(leather, [_ring_z(GS_GRIP_FRONT_Z, GS_GRIP_RADIUS, sides), _ring_z(GS_GRIP_BACK_Z, GS_GRIP_RADIUS, sides)], true, true)
	for z: float in [GS_GRIP_FRONT_Z, GS_GRIP_MIDDLE_RING_Z - GS_GRIP_RING_LENGTH * 0.5, GS_GRIP_BACK_Z - GS_GRIP_RING_LENGTH]:
		_loft(brass, [_ring_z(z, GS_GRIP_RING_RADIUS, sides), _ring_z(z + GS_GRIP_RING_LENGTH, GS_GRIP_RING_RADIUS, sides)], true, true)


# ================================================================== SHIELD

static func build_shield() -> ArrayMesh:
	var surfaces: Array[SurfaceTool] = _tools(4)
	var outline: PackedVector2Array = shield_outline()
	_add_plate(surfaces[ShieldSurface.DARK_STEEL], surfaces[ShieldSurface.STEEL], outline)
	_add_rim(surfaces[ShieldSurface.STEEL], outline)
	_add_relief(surfaces[ShieldSurface.BRASS], cross_outline(), RELIEF_LIFT)
	_add_rivets(surfaces[ShieldSurface.BRASS], outline)
	_add_back_grip(surfaces[ShieldSurface.LEATHER])
	return _commit(surfaces)


static func _column_x(i: int) -> float:
	return -SHIELD_HALF_WIDTH + 2.0 * SHIELD_HALF_WIDTH * float(i) / float(SHIELD_COLUMNS)


## Top edge height at x (peak in the middle, shoulders at the sides).
static func top_y(x: float) -> float:
	var u: float = absf(x) / SHIELD_HALF_WIDTH
	return SHIELD_PEAK_Y - (SHIELD_PEAK_Y - SHIELD_SHOULDER_Y) * pow(u, SHIELD_TOP_EXPONENT)


## Bottom edge height at x (vertical at the sides, closing in a point).
static func bottom_y(x: float) -> float:
	var u: float = clampf(absf(x) / SHIELD_HALF_WIDTH, 0.0, 1.0)
	return SHIELD_POINT_Y * pow(1.0 - u, SHIELD_BOTTOM_EXPONENT)


## Z of the outer face on the exact curve (0 at the sides, most negative in the middle).
static func _curve_z(x: float) -> float:
	var r2: float = SHIELD_CURVE_RADIUS * SHIELD_CURVE_RADIUS
	return -(sqrt(r2 - x * x) - sqrt(r2 - SHIELD_HALF_WIDTH * SHIELD_HALF_WIDTH))


## Z of the outer face as built (flat strips between the columns).
static func face_z(x: float) -> float:
	var f: float = (x + SHIELD_HALF_WIDTH) / (2.0 * SHIELD_HALF_WIDTH) * float(SHIELD_COLUMNS)
	var i: int = clampi(floori(f), 0, SHIELD_COLUMNS - 1)
	var a: float = _column_x(i)
	var b: float = _column_x(i + 1)
	return lerpf(_curve_z(a), _curve_z(b), (x - a) / (b - a))


## Outer face point over (x, y), lifted toward -Z by `lift`.
static func on_face(p: Vector2, lift: float) -> Vector3:
	return Vector3(p.x, p.y, face_z(p.x) - lift)


## Outline of the face, counterclockwise in XY (seen from +Z): top from
## +X to -X, then the bottom from -X back to +X.
static func shield_outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(SHIELD_COLUMNS, -1, -1):  # top, from +X to -X
		var x: float = _column_x(i)
		pts.append(Vector2(x, top_y(x)))
	for i: int in range(0, SHIELD_COLUMNS + 1):  # bottom, from -X to +X
		var x: float = _column_x(i)
		pts.append(Vector2(x, bottom_y(x)))
	return pts


static func _add_plate(face: SurfaceTool, edge: SurfaceTool, outline: PackedVector2Array) -> void:
	for i: int in SHIELD_COLUMNS:
		var a: float = _column_x(i)
		var b: float = _column_x(i + 1)
		var quad: Array[Vector2] = [Vector2(a, bottom_y(a)), Vector2(b, bottom_y(b)), Vector2(b, top_y(b)), Vector2(a, top_y(a))]
		var front: Array[Vector3] = []
		var back: Array[Vector3] = []
		for p: Vector2 in quad:
			front.append(on_face(p, 0.0))
			back.append(on_face(p, -SHIELD_THICKNESS))
		_quad(face, front[0], front[1], front[2], front[3], Vector3.FORWARD)
		_quad(face, back[0], back[1], back[2], back[3], Vector3.BACK)
	# Edge walls all around.
	var n: int = outline.size()
	for k: int in n:
		var p: Vector2 = outline[k]
		var q: Vector2 = outline[(k + 1) % n]
		var out := Vector3(q.y - p.y, p.x - q.x, 0.0)  # outward: the outline is counterclockwise in XY
		_quad(edge, on_face(p, 0.0), on_face(q, 0.0), on_face(q, -SHIELD_THICKNESS), on_face(p, -SHIELD_THICKNESS), out)


## Raised steel band along the outline of the face.
static func _add_rim(st: SurfaceTool, outline: PackedVector2Array) -> void:
	var inner: PackedVector2Array = _inset(outline, RIM_WIDTH)
	var n: int = outline.size()
	for k: int in n:
		var j: int = (k + 1) % n
		var o0: Vector3 = on_face(outline[k], RIM_LIFT)
		var o1: Vector3 = on_face(outline[j], RIM_LIFT)
		var i0: Vector3 = on_face(inner[k], RIM_LIFT)
		var i1: Vector3 = on_face(inner[j], RIM_LIFT)
		_quad(st, o0, o1, i1, i0, Vector3.FORWARD)
		var d0: Vector3 = on_face(inner[k], -RELIEF_SINK)
		var d1: Vector3 = on_face(inner[j], -RELIEF_SINK)
		var toward_center := Vector3(-inner[k].x, -inner[k].y, 0.0)
		_quad(st, i0, i1, d1, d0, toward_center)
		var e0: Vector3 = on_face(outline[k], -RELIEF_SINK)
		var e1: Vector3 = on_face(outline[j], -RELIEF_SINK)
		_quad(st, o0, o1, e1, e0, -toward_center)


## Moves every point of a counterclockwise polygon inward by `amount` (miter).
static func _inset(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = poly.size()
	for k: int in n:
		var prev: Vector2 = poly[(k - 1 + n) % n]
		var next: Vector2 = poly[(k + 1) % n]
		var p: Vector2 = poly[k]
		var n0: Vector2 = _left_normal(prev, p)
		var n1: Vector2 = _left_normal(p, next)
		if n0 == Vector2.ZERO:
			n0 = n1
		if n1 == Vector2.ZERO:
			n1 = n0
		var bis: Vector2 = (n0 + n1).normalized()
		var miter: float = amount / maxf(bis.dot(n1), 0.5)
		out.append(p + bis * miter)
	return out


## Inward normal of a counterclockwise polygon edge (zero for a null edge).
static func _left_normal(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = b - a
	if d.length() < 0.0001:
		return Vector2.ZERO
	return Vector2(-d.y, d.x).normalized()


## Cross of Santiago: upper and side arms end in a fleur-de-lis, the lower arm
## is a sword blade. Counterclockwise in XY, like the outline.
static func cross_outline() -> PackedVector2Array:
	var c := Vector2(0, CROSS_CENTER_Y)
	var h: float = CROSS_ARM_HALF_WIDTH
	var pts := PackedVector2Array()
	pts.append_array(_fleur(c, Vector2(0, 1), CROSS_TOP_Y - CROSS_CENTER_Y))
	pts.append(Vector2(-h, CROSS_CENTER_Y + h))
	pts.append_array(_fleur(c, Vector2.LEFT, CROSS_ARM_X))
	pts.append(Vector2(-CROSS_BLADE_HALF_WIDTH, CROSS_CENTER_Y - h))
	pts.append(Vector2(-CROSS_BLADE_NARROW_HALF_WIDTH, CROSS_BLADE_NARROW_Y))
	pts.append(Vector2(0, CROSS_POINT_Y))
	pts.append(Vector2(CROSS_BLADE_NARROW_HALF_WIDTH, CROSS_BLADE_NARROW_Y))
	pts.append(Vector2(CROSS_BLADE_HALF_WIDTH, CROSS_CENTER_Y - h))
	pts.append_array(_fleur(c, Vector2.RIGHT, CROSS_ARM_X))
	pts.append(Vector2(h, CROSS_CENTER_Y + h))
	return pts


## End of one arm, from its right side to its left side (seen along `dir`);
## `reach` is the distance from the cross center to the lance tip.
static func _fleur(center: Vector2, dir: Vector2, reach: float) -> PackedVector2Array:
	var side := Vector2(-dir.y, dir.x)  # left of dir
	var u0: float = reach - FLEUR_TIP
	var h: float = CROSS_ARM_HALF_WIDTH
	var half: Array[Vector2] = [FLEUR_PETAL_BACK, FLEUR_PETAL_TOP, FLEUR_PETAL_IN, FLEUR_NOTCH, FLEUR_MIDDLE]
	var local: Array[Vector2] = [Vector2(u0, -h)]
	for p: Vector2 in half:
		local.append(Vector2(u0 + p.x, -p.y))
	local.append(Vector2(reach, 0.0))
	for i: int in range(half.size() - 1, -1, -1):
		local.append(Vector2(u0 + half[i].x, half[i].y))
	local.append(Vector2(u0, h))
	var pts := PackedVector2Array()
	for p: Vector2 in local:
		pts.append(center + dir * p.x + side * p.y)
	return pts


## A flat shape raised `lift` over the curved face: top cap (subdivided so it
## follows the curve) and side walls sunk into the face.
static func _add_relief(st: SurfaceTool, poly: PackedVector2Array, lift: float) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	for t: int in tris.size() / 3:
		_relief_cap(st, poly[tris[t * 3]], poly[tris[t * 3 + 1]], poly[tris[t * 3 + 2]], lift)
	var n: int = poly.size()
	for k: int in n:
		var p: Vector2 = poly[k]
		var q: Vector2 = poly[(k + 1) % n]
		var steps: int = maxi(1, ceili(p.distance_to(q) / RELIEF_MAX_EDGE))
		var out := Vector3(q.y - p.y, p.x - q.x, 0.0)
		for s: int in steps:
			var a: Vector2 = p.lerp(q, float(s) / float(steps))
			var b: Vector2 = p.lerp(q, float(s + 1) / float(steps))
			_quad(st, on_face(a, lift), on_face(b, lift), on_face(b, -RELIEF_SINK), on_face(a, -RELIEF_SINK), out)


static func _relief_cap(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, lift: float) -> void:
	if maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) > RELIEF_MAX_EDGE:
		var ab: Vector2 = (a + b) * 0.5
		var bc: Vector2 = (b + c) * 0.5
		var ca: Vector2 = (c + a) * 0.5
		_relief_cap(st, a, ab, ca, lift)
		_relief_cap(st, ab, b, bc, lift)
		_relief_cap(st, ca, bc, c, lift)
		_relief_cap(st, ab, bc, ca, lift)
		return
	_tri(st, on_face(a, lift), on_face(b, lift), on_face(c, lift), Vector3.FORWARD)


## Rivet centers: evenly spaced along the outline moved inward, plus one on
## the cross center.
static func rivet_points(outline: PackedVector2Array) -> PackedVector2Array:
	var path: PackedVector2Array = _inset(outline, RIVET_INSET)
	var n: int = path.size()
	var total: float = 0.0
	for k: int in n:
		total += path[k].distance_to(path[(k + 1) % n])
	var pts := PackedVector2Array()
	var step: float = total / float(RIVET_COUNT)
	var target: float = 0.0
	var walked: float = 0.0
	for k: int in n:
		var p: Vector2 = path[k]
		var q: Vector2 = path[(k + 1) % n]
		var length: float = p.distance_to(q)
		while target < walked + length and pts.size() < RIVET_COUNT:
			pts.append(p.lerp(q, (target - walked) / length))
			target += step
		walked += length
	pts.append(Vector2(0, CROSS_CENTER_Y))
	return pts


static func _add_rivets(st: SurfaceTool, outline: PackedVector2Array) -> void:
	var pts: PackedVector2Array = rivet_points(outline)
	for k: int in pts.size():
		var base_lift: float = RELIEF_LIFT if k == pts.size() - 1 else 0.0
		_rivet(st, pts[k], base_lift)


## Low hexagonal dome over the face.
static func _rivet(st: SurfaceTool, c: Vector2, base_lift: float) -> void:
	var base: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for i: int in RIVET_SIDES:
		var a: float = TAU * float(i) / float(RIVET_SIDES)
		var d := Vector2(cos(a), sin(a))
		base.append(on_face(c + d * RIVET_RADIUS, base_lift - RELIEF_SINK))
		mid.append(on_face(c + d * RIVET_RADIUS * 0.7, base_lift + RIVET_HEIGHT * 0.7))
	var apex: Vector3 = on_face(c, base_lift + RIVET_HEIGHT)
	for i: int in RIVET_SIDES:
		var j: int = (i + 1) % RIVET_SIDES
		var out: Vector3 = (base[i] + base[j]) * 0.5 - on_face(c, base_lift)
		_quad(st, base[i], base[j], mid[j], mid[i], out + Vector3.FORWARD * 0.01)
		_tri(st, mid[i], mid[j], apex, Vector3.FORWARD)


## Leather grip bar standing off the back on two posts, and a strap above it.
static func _add_back_grip(st: SurfaceTool) -> void:
	var back_z: float = face_z(0.0) + SHIELD_THICKNESS
	var bar_z: float = back_z + GRIP_STANDOFF
	_box(st, Vector3(0, GRIP_Y, bar_z), Vector3(GRIP_BAR_HALF_WIDTH + GRIP_BAR_SIZE.y * 0.5, GRIP_BAR_SIZE.x * 0.5, GRIP_BAR_SIZE.y * 0.5))
	for side: float in [-1.0, 1.0]:
		var x: float = side * GRIP_BAR_HALF_WIDTH
		var post_back: float = face_z(x) + SHIELD_THICKNESS
		var half_len: float = (bar_z - post_back) * 0.5
		_box(st, Vector3(x, GRIP_Y, post_back + half_len), Vector3(GRIP_BAR_SIZE.y * 0.5, GRIP_BAR_SIZE.x * 0.5, half_len))
	# The strap follows the back with one flat box per shield strip.
	var steps: int = 4
	for s: int in steps:
		var a: float = -STRAP_HALF_WIDTH + 2.0 * STRAP_HALF_WIDTH * float(s) / float(steps)
		var b: float = -STRAP_HALF_WIDTH + 2.0 * STRAP_HALF_WIDTH * float(s + 1) / float(steps)
		var za: float = face_z(a) + SHIELD_THICKNESS
		var zb: float = face_z(b) + SHIELD_THICKNESS
		var h: float = STRAP_SIZE.x * 0.5
		var t: float = STRAP_SIZE.y
		var p0 := Vector3(a, STRAP_Y - h, za)
		var p1 := Vector3(b, STRAP_Y - h, zb)
		var p2 := Vector3(b, STRAP_Y + h, zb)
		var p3 := Vector3(a, STRAP_Y + h, za)
		var off := Vector3(0, 0, t)
		_quad(st, p0 + off, p1 + off, p2 + off, p3 + off, Vector3.BACK)
		_quad(st, p0, p1, p1 + off, p0 + off, Vector3.DOWN)
		_quad(st, p3, p2, p2 + off, p3 + off, Vector3.UP)


## Grip point for the left hand, in shield space (the center of the grip bar).
static func grip_point() -> Vector3:
	return Vector3(0, GRIP_Y, face_z(0.0) + SHIELD_THICKNESS + GRIP_STANDOFF)


# ================================================================== HELPERS

static func _tools(count: int) -> Array[SurfaceTool]:
	var surfaces: Array[SurfaceTool] = []
	for i: int in count:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces.append(st)
	return surfaces


static func _commit(surfaces: Array[SurfaceTool]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for st: SurfaceTool in surfaces:
		st.commit(mesh)
	return mesh


## Joins consecutive rings (same vertex count) with quads whose normals face
## away from the ring centers; optionally closes the first and last ring.
static func _loft(st: SurfaceTool, rings: Array[PackedVector3Array], cap_start: bool, cap_end: bool) -> void:
	for r: int in rings.size() - 1:
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		var axis_mid: Vector3 = (_center(a) + _center(b)) * 0.5
		for i: int in a.size():
			var j: int = (i + 1) % a.size()
			var face_mid: Vector3 = (a[i] + a[j] + b[i] + b[j]) * 0.25
			_quad(st, a[i], a[j], b[j], b[i], face_mid - axis_mid)
	if cap_start:
		_cap(st, rings[0], _center(rings[0]) - _center(rings[1]))
	if cap_end:
		var last: int = rings.size() - 1
		_cap(st, rings[last], _center(rings[last]) - _center(rings[last - 1]))


static func _cap(st: SurfaceTool, ring: PackedVector3Array, out: Vector3) -> void:
	var c: Vector3 = _center(ring)
	for i: int in ring.size():
		_tri(st, c, ring[i], ring[(i + 1) % ring.size()], out)


static func _center(ring: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p: Vector3 in ring:
		sum += p
	return sum / float(ring.size())


static func _box(st: SurfaceTool, center: Vector3, half: Vector3) -> void:
	var c: Array[Vector3] = []
	for i: int in 8:
		c.append(center + Vector3(half.x * (1 if i & 1 else -1), half.y * (1 if i & 2 else -1), half.z * (1 if i & 4 else -1)))
	_quad(st, c[0], c[1], c[3], c[2], Vector3.FORWARD)
	_quad(st, c[4], c[5], c[7], c[6], Vector3.BACK)
	_quad(st, c[0], c[2], c[6], c[4], Vector3.LEFT)
	_quad(st, c[1], c[3], c[7], c[5], Vector3.RIGHT)
	_quad(st, c[0], c[1], c[5], c[4], Vector3.DOWN)
	_quad(st, c[2], c[3], c[7], c[6], Vector3.UP)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	_tri(st, a, b, c, out)
	_tri(st, a, c, d, out)


## One flat-shaded triangle facing `out` (skipped when degenerate).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	if n.dot(out) < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		n = -n
	# Godot's front faces wind clockwise.
	for p: Vector3 in [a, c, b]:
		st.set_normal(n)
		st.add_vertex(p)
