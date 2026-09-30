class_name MarDeFloresBuilder
extends RefCounted
## Deterministic geometry of the Mar de Flores stage (docs/specs/stages.md §3):
## terrain, height map, backdrop, stream, prop layout, vegetation scatter and
## clouds, all from the constants below and fixed noise seeds. Used offline by
## build_mar_de_flores.gd (never at runtime) and by the tests that check the
## saved files match it.

enum Scatter { PETAL, SINGLE_A, SINGLE_B, GROUP_A, VIOLET, GRASS_SHORT, GRASS_TALL }

## Invisible wall line (x, z), clockwise seen from above; ~2 000 m² inside.
const BOUNDARY: PackedVector2Array = [
	Vector2(-22.2, -15.1), Vector2(-12.8, -20.8), Vector2(0.0, -22.2), Vector2(12.8, -20.6),
	Vector2(23.3, -16.1), Vector2(28.6, -7.0), Vector2(27.5, 4.6), Vector2(23.3, 14.0),
	Vector2(12.8, 19.8), Vector2(0.0, 22.2), Vector2(-12.8, 20.4), Vector2(-22.2, 15.1),
	Vector2(-27.3, 5.9), Vector2(-26.9, -5.9)]
## The spawn area is the boundary shrunk towards the centre by this factor.
const SPAWN_SCALE: float = 0.9
## Stream centre line (x, z), from the east hills to the south hills.
const STREAM: PackedVector2Array = [
	Vector2(47.0, -6.3), Vector2(30.3, -1.7), Vector2(24.7, 3.2), Vector2(22.2, 7.0),
	Vector2(20.0, 12.1), Vector2(18.7, 16.4), Vector2(15.1, 22.2), Vector2(11.6, 33.6), Vector2(8.4, 50.4)]
const STREAM_HALF_WIDTH: float = 4.5
const STREAM_DEPTH: float = 0.3
## Extra carving of the stream where the hills rise (fraction of the rise).
const STREAM_VALLEY: float = 0.85
const WATER_HALF_WIDTH: float = 1.5
const WATER_ABOVE_BED: float = 0.22
const PLAYER_START := Vector2(0.0, 16.0)
const ARCH_Z: float = -17.0
## Dirt path from the start to the arch: |x - PATH_WAVE sin(PATH_FREQ z)| < PATH_HALF_WIDTH.
const PATH_HALF_WIDTH: float = 0.9
const PATH_WAVE: float = 0.6
const PATH_FREQ: float = 0.25
## Terrain mesh: square grid of GRID_STEP metres over ±GRID_HALF.
const GRID_HALF: int = 60
const GRID_STEP: float = 1.0
## The terrain eases down to the far ground between these distances (m).
const FADE_FROM: float = 50.0
const FADE_TO: float = 60.0
## Height map for collision: ±HEIGHT_HALF metres, one sample per metre.
const HEIGHT_HALF: int = 40
## Relief: rolling meadow, the ruins mound and the hills beyond the walls.
const ROLL_A: float = 0.25
const ROLL_B: float = 0.15
const DETAIL: float = 0.1
const MOUND_HEIGHT: float = 0.45
const MOUND_RADIUS := Vector2(9.0, 5.0)
const RIM_FROM: float = -2.0
const RIM_TO: float = 14.0
const RIM_HEIGHT: float = 7.0
const HILLS_FROM: float = 6.0
const HILLS_SPAN: float = 20.0
const HILLS_NOISE: float = 10.0
const HILLS_BASE: float = 3.0
const DETAIL_SEED: int = 3
const DETAIL_FREQUENCY: float = 0.05
const HILLS_SEED: int = 11
const HILLS_FREQUENCY: float = 0.015
const PATCH_SEED: int = 29
const PATCH_FREQUENCY: float = 0.06
## Ground colours (sRGB, see docs/color-registry.md "Escenario").
const MEADOW := Color(0.47, 0.68, 0.31)
const MEADOW_VARIATION := Vector2(0.05, 0.06)
const OUTSIDE := Color(0.4, 0.6, 0.28)
const HIGH_ROCK := Color(0.56, 0.56, 0.5)
const HIGH_FROM: float = 9.0
const HIGH_SPAN: float = 6.0
const HIGH_MAX: float = 0.7
const STREAM_BED := Color(0.46, 0.5, 0.36)
const STREAM_BED_WIDTH: float = 2.2
const PATH_DIRT := Color(0.76, 0.68, 0.5)
const PATCH_THRESHOLD: float = 0.35
const PATCH_LIGHTEN: float = 0.08

## Props: [scene key, x, z, yaw (degrees), scale, leaves ("" or key of LEAVES)].
const PROPS: Array = [
	["arch", 0.0, -17.0, 0.0, 1.0, ""],
	["column", -9.1, -15.4, 10.0, 1.0, ""],
	["column", 9.1, -16.1, 40.0, 1.0, ""],
	["column", -5.6, -11.4, 70.0, 1.0, ""],
	["column_broken", 6.1, -11.2, 20.0, 1.0, ""],
	["column_fallen", 14.7, -13.4, 30.0, 1.0, ""],
	["tree_a", -22.2, -7.0, 20.0, 1.0, "green_dark"],
	["tree_c", -18.0, -4.2, 110.0, 0.9, "orange"],
	["tree_b", -22.7, 0.4, 200.0, 1.0, "green_light"],
	["tree_d", -17.2, 4.2, 300.0, 0.95, "green_dark"],
	["tree_e", -21.9, 8.4, 45.0, 1.05, "yellow"],
	["tree_c", -14.7, -9.8, 160.0, 0.9, "green_light"],
	["tree_a", 24.7, -11.0, 250.0, 0.95, "green_light"],
	["tree_d", -13.5, 16.5, 80.0, 0.9, "green_dark"],
	["tree_b", 3.5, -24.5, 10.0, 1.1, "orange"],
	["rock_a", -10.5, 9.5, 30.0, 1.0, ""],
	["rock_b", 11.0, -4.5, 120.0, 1.0, ""],
	["rock_c", 15.0, 9.0, 250.0, 0.9, ""],
	["bush", -24.5, -2.5, 0.0, 1.0, ""],
	["bush_flowers", -6.5, -19.0, 60.0, 1.0, ""],
	["bush_flowers", 8.5, -19.5, 200.0, 1.0, ""],
	["bush", 19.0, -17.0, 90.0, 1.0, ""],
	["bush_flowers", -20.0, 12.0, 300.0, 1.0, ""],
	["stone_path", 0.0, -13.6, 0.0, 1.0, ""],
	["stone_path", 0.7, -11.2, 40.0, 1.0, ""],
	["stone_path", -0.3, -8.9, 80.0, 1.0, ""],
	["pebble", 21.0, 4.5, 0.0, 1.0, ""],
	["pebble", 23.8, 6.3, 70.0, 1.0, ""],
	["pebble", 19.2, 13.5, 140.0, 1.0, ""],
	["pebble", 17.4, 16.8, 210.0, 1.0, ""],
	["pebble", 25.5, 1.2, 280.0, 1.0, ""],
]
## Obstacle circles of each prop key in its own space: [x, z, radius]
## (must match the StageObstacle nodes of levels/stages/props/<key>.tscn).
const OBSTACLES: Dictionary = {
	"arch": [[-2.72, 0.0, 1.1], [2.72, 0.0, 1.1]],
	"column": [[0.0, 0.0, 0.75]],
	"column_broken": [[0.0, 0.0, 0.75]],
	"column_fallen": [[-1.6, 0.0, 0.8], [0.0, 0.0, 0.8], [1.6, 0.0, 0.8]],
	"tree_a": [[0.0, 0.0, 0.55]], "tree_b": [[0.0, 0.0, 0.55]], "tree_c": [[0.0, 0.0, 0.55]],
	"tree_d": [[0.0, 0.0, 0.55]], "tree_e": [[0.0, 0.0, 0.55]],
	"rock_a": [[0.0, 0.0, 1.1]], "rock_b": [[0.0, 0.0, 1.1]], "rock_c": [[0.0, 0.0, 1.1]],
}
## Border forest (vegetation scatter of whole trees): how many, where and how.
const FOREST_SEED: int = 7
const FOREST_COUNT: int = 150
const FOREST_ATTEMPTS: int = 4000
const FOREST_AREA: float = 70.0
const FOREST_FROM: float = 1.5
const FOREST_TO: float = 30.0
const FOREST_SPACING: float = 3.6
const FOREST_STREAM_GAP: float = 4.0
## Most trees are left out of the north corridor so the castle shows.
const CORRIDOR_HALF_WIDTH: float = 12.0
const CORRIDOR_FROM_Z: float = -22.0
const CORRIDOR_KEEP: float = 0.15
const FOREST_SCALE := Vector2(0.65, 1.0)
const TREE_BASE_SCALE: float = 0.75
const TREE_SINK: float = 0.1
const TREE_MESHES: int = 5
## Foliage: every tree whose index has one of these remainders mod 10 is autumn
## (30 %), alternating yellow and orange; the rest alternate light and dark green.
const AUTUMN_REMAINDERS: Array[int] = [2, 5, 8]
const LEAVES: Dictionary = {
	"green_light": Color(0.36, 0.6, 0.3),
	"green_dark": Color(0.24, 0.47, 0.26),
	"yellow": Color(0.9, 0.78, 0.28),
	"orange": Color(0.9, 0.6, 0.15),
}
## Flower and grass scatter: [count, min scale, max scale, max distance past the
## wall, stream gap, patchy (0/1)], by Scatter kind.
const SCATTER_SEED: int = 41
const SCATTER_AREA: float = 45.0
const SCATTER_ATTEMPTS_PER_ITEM: int = 12
const SCATTER: Dictionary = {
	Scatter.PETAL: [2600, 0.55, 0.8, 3.0, 2.0, 1],
	Scatter.SINGLE_A: [700, 0.26, 0.34, 3.0, 2.0, 1],
	Scatter.SINGLE_B: [300, 0.24, 0.3, 3.0, 2.0, 1],
	Scatter.GROUP_A: [160, 0.26, 0.32, 3.0, 2.0, 1],
	Scatter.VIOLET: [350, 0.6, 0.9, 3.0, 2.0, 1],
	Scatter.GRASS_SHORT: [3000, 0.28, 0.4, 12.0, 1.4, 0],
	Scatter.GRASS_TALL: [700, 0.25, 0.35, 12.0, 1.4, 0],
}
const SCATTER_CLEARANCE: float = 0.3
const PATCH_ACCEPT_FLOOR: float = 0.25
const GRASS_TINT := Color(1.0, 1.0, 1.0)
const GRASS_TINT_VARIATION: float = 0.12
## Scatter parcels (for culling): PARCELS × PARCELS squares over ±SCATTER_AREA.
const PARCELS: int = 3
## Arch footprint kept free of scatter: half extents around (0, ARCH_Z).
const ARCH_CLEAR := Vector2(4.0, 1.5)
## Backdrop: mountains (north half and a lower south ring), hills and the castle hill.
const BACKDROP_SEED: int = 5
const NORTH_PEAKS: int = 16
const SOUTH_PEAKS: int = 7
const PEAK_DISTANCE := Vector2(380.0, 520.0)
const PEAK_HEIGHT := Vector2(90.0, 190.0)
const PEAK_RADIUS := Vector2(90.0, 140.0)
const SOUTH_PEAK_SCALE: float = 0.7
const PEAK_SEGMENTS: int = 7
const SNOW_FROM: float = 0.66
const SNOW_RADIUS: float = 0.34
const HILL_COUNT: int = 10
const HILL_DISTANCE := Vector2(130.0, 220.0)
const HILL_RADIUS := Vector2(40.0, 70.0)
const HILL_HEIGHT := Vector2(20.0, 40.0)
const HILL_RINGS: int = 4
const HILL_SEGMENTS: int = 10
const MOUNTAIN_ROCK := Color(0.55, 0.62, 0.74)
const MOUNTAIN_SNOW := Color(0.94, 0.95, 0.98)
const HILL_GREEN := Color(0.4, 0.58, 0.32)
const CASTLE_HILL := Vector3(4.0, 0.0, -200.0)
const CASTLE_HILL_RADIUS: float = 55.0
const CASTLE_HILL_HEIGHT: float = 30.0
## Clouds: clusters of puffs (a unit SphereMesh scaled per instance).
const CLOUD_SEED: int = 13
const CLOUD_CLUSTERS: int = 12
const CLOUD_PUFFS := Vector2i(6, 9)
const CLOUD_DISTANCE := Vector2(420.0, 600.0)
const CLOUD_HEIGHT := Vector2(190.0, 280.0)
const CLOUD_PUFF_SIZE := Vector2(28.0, 55.0)
const CLOUD_SPREAD := Vector3(55.0, 22.0, 25.0)
const CLOUD_FLATTEN: float = 0.7

var _detail := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _patches := FastNoiseLite.new()


func _init() -> void:
	_detail.seed = DETAIL_SEED
	_detail.frequency = DETAIL_FREQUENCY
	_hills.seed = HILLS_SEED
	_hills.frequency = HILLS_FREQUENCY
	_patches.seed = PATCH_SEED
	_patches.frequency = PATCH_FREQUENCY


# --- shape ---------------------------------------------------------------------

func spawn_polygon() -> PackedVector2Array:
	var polygon: PackedVector2Array = []
	for point: Vector2 in BOUNDARY:
		polygon.append(point * SPAWN_SCALE)
	return polygon


## Distance to the wall line: negative inside, positive outside.
func signed_distance(point: Vector2) -> float:
	var best: float = INF
	for i: int in BOUNDARY.size():
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, BOUNDARY[i], BOUNDARY[(i + 1) % BOUNDARY.size()])
		best = minf(best, point.distance_to(closest))
	return -best if Geometry2D.is_point_in_polygon(point, BOUNDARY) else best


func stream_distance(point: Vector2) -> float:
	var best: float = INF
	for i: int in STREAM.size() - 1:
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, STREAM[i], STREAM[i + 1])))
	return best


func is_on_path(point: Vector2, margin: float) -> bool:
	if point.y < ARCH_Z + 1.0 or point.y > PLAYER_START.y + 1.5:
		return false
	return absf(point.x - PATH_WAVE * sin(point.y * PATH_FREQ)) < PATH_HALF_WIDTH + margin


func height(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var h: float = ROLL_A * sin(x * 0.16 + 0.5) * cos(z * 0.13) + ROLL_B * sin(x * 0.07 - z * 0.11 + 1.3)
	h += _detail.get_noise_2d(x, z) * DETAIL
	h += MOUND_HEIGHT * exp(-(pow(x / MOUND_RADIUS.x, 2.0) + pow((z - ARCH_Z + 2.0) / MOUND_RADIUS.y, 2.0)))
	var d: float = signed_distance(point)
	var rise: float = smoothstep(RIM_FROM, RIM_TO, d) * RIM_HEIGHT
	rise += clampf((d - HILLS_FROM) / HILLS_SPAN, 0.0, 1.0) * (_hills.get_noise_2d(x, z) * HILLS_NOISE + HILLS_BASE)
	h += rise
	var s: float = stream_distance(point)
	if s < STREAM_HALF_WIDTH:
		h -= (STREAM_DEPTH + maxf(rise, 0.0) * STREAM_VALLEY) * (1.0 - smoothstep(0.0, STREAM_HALF_WIDTH, s))
	var edge: float = maxf(absf(x), absf(z))
	return lerpf(h, 0.0, smoothstep(FADE_FROM, FADE_TO, edge))


func ground_color(x: float, z: float, h: float) -> Color:
	var point := Vector2(x, z)
	var n: float = _detail.get_noise_2d(x * 2.0, z * 2.0)
	var color := Color(MEADOW.r + n * MEADOW_VARIATION.x, MEADOW.g + n * MEADOW_VARIATION.y, MEADOW.b)
	var d: float = signed_distance(point)
	if d > 0.0:
		color = Color(OUTSIDE.r + n * MEADOW_VARIATION.x * 0.8, OUTSIDE.g + n * MEADOW_VARIATION.y * 0.8, OUTSIDE.b)
	elif _patches.get_noise_2d(x, z) > PATCH_THRESHOLD:
		color = color.lightened(PATCH_LIGHTEN)
	if h > HIGH_FROM:
		color = color.lerp(HIGH_ROCK, clampf((h - HIGH_FROM) / HIGH_SPAN, 0.0, HIGH_MAX))
	if stream_distance(point) < STREAM_BED_WIDTH:
		color = STREAM_BED
	if is_on_path(point, 0.0):
		color = PATH_DIRT
	return color


# --- meshes ------------------------------------------------------------------

func build_terrain_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var cells: int = roundi(GRID_HALF * 2 / GRID_STEP)
	var heights: PackedFloat32Array = []
	heights.resize((cells + 1) * (cells + 1))
	for iz: int in cells + 1:
		for ix: int in cells + 1:
			heights[iz * (cells + 1) + ix] = height(-GRID_HALF + ix * GRID_STEP, -GRID_HALF + iz * GRID_STEP)
	for iz: int in cells:
		for ix: int in cells:
			var x0: float = -GRID_HALF + ix * GRID_STEP
			var z0: float = -GRID_HALF + iz * GRID_STEP
			var a := Vector3(x0, heights[iz * (cells + 1) + ix], z0)
			var b := Vector3(x0 + GRID_STEP, heights[iz * (cells + 1) + ix + 1], z0)
			var c := Vector3(x0, heights[(iz + 1) * (cells + 1) + ix], z0 + GRID_STEP)
			var d := Vector3(x0 + GRID_STEP, heights[(iz + 1) * (cells + 1) + ix + 1], z0 + GRID_STEP)
			_ground_triangle(st, a, b, d)
			_ground_triangle(st, a, d, c)
	st.generate_normals()
	return st.commit()


func build_heights() -> HeightMapShape3D:
	var size: int = HEIGHT_HALF * 2 + 1
	var data: PackedFloat32Array = []
	data.resize(size * size)
	for iz: int in size:
		for ix: int in size:
			data[iz * size + ix] = height(ix - HEIGHT_HALF, iz - HEIGHT_HALF)
	var shape := HeightMapShape3D.new()
	shape.map_width = size
	shape.map_depth = size
	shape.map_data = data
	return shape


func build_water_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = 8
	var points: PackedVector2Array = []
	for i: int in STREAM.size() - 1:
		for k: int in steps:
			points.append(STREAM[i].lerp(STREAM[i + 1], float(k) / steps))
	points.append(STREAM[STREAM.size() - 1])
	for i: int in points.size() - 1:
		var along: Vector2 = (points[i + 1] - points[i]).normalized()
		var side := Vector2(-along.y, along.x) * WATER_HALF_WIDTH
		var y0: float = height(points[i].x, points[i].y) + WATER_ABOVE_BED
		var y1: float = height(points[i + 1].x, points[i + 1].y) + WATER_ABOVE_BED
		var a := Vector3(points[i].x - side.x, y0, points[i].y - side.y)
		var b := Vector3(points[i].x + side.x, y0, points[i].y + side.y)
		var c := Vector3(points[i + 1].x - side.x, y1, points[i + 1].y - side.y)
		var d := Vector3(points[i + 1].x + side.x, y1, points[i + 1].y + side.y)
		for vertex: Vector3 in [a, b, d, a, d, c]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()


func build_backdrop_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = BACKDROP_SEED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i: int in NORTH_PEAKS:
		var angle: float = lerpf(-PI * 0.95, -PI * 0.05, float(i) / (NORTH_PEAKS - 1)) + rng.randf_range(-0.08, 0.08)
		_peak(st, rng, angle, 1.0)
	for i: int in SOUTH_PEAKS:
		var angle: float = lerpf(PI * 0.1, PI * 0.9, float(i) / (SOUTH_PEAKS - 1)) + rng.randf_range(-0.1, 0.1)
		_peak(st, rng, angle, SOUTH_PEAK_SCALE)
	for i: int in HILL_COUNT:
		var angle: float = TAU * float(i) / HILL_COUNT + rng.randf_range(-0.2, 0.2)
		var distance: float = rng.randf_range(HILL_DISTANCE.x, HILL_DISTANCE.y)
		_dome(st, Vector3(cos(angle) * distance, 0.0, sin(angle) * distance), rng.randf_range(HILL_RADIUS.x, HILL_RADIUS.y), rng.randf_range(HILL_HEIGHT.x, HILL_HEIGHT.y))
	_dome(st, CASTLE_HILL, CASTLE_HILL_RADIUS, CASTLE_HILL_HEIGHT)
	st.generate_normals()
	return st.commit()


# --- layout ------------------------------------------------------------------

## Obstacle circles (x, z, radius) of every prop, in stage space.
func obstacles() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for prop: Array in PROPS:
		if not OBSTACLES.has(prop[0]):
			continue
		var yaw: float = deg_to_rad(prop[3])
		for circle: Array in OBSTACLES[prop[0]]:
			var local := Vector2(circle[0], circle[1]) * float(prop[4])
			var rotated := Vector2(local.x * cos(yaw) + local.y * sin(yaw), -local.x * sin(yaw) + local.y * cos(yaw))
			out.append(Vector3(prop[1] + rotated.x, prop[2] + rotated.y, circle[2]))
	return out


## Border forest: [mesh index, Transform3D, foliage colour] per tree.
func forest() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = FOREST_SEED
	var placed: Array[Vector2] = []
	for prop: Array in PROPS:
		if String(prop[0]).begins_with("tree"):
			placed.append(Vector2(prop[1], prop[2]))
	var trees: Array = []
	for attempt: int in FOREST_ATTEMPTS:
		if trees.size() >= FOREST_COUNT:
			break
		var point := Vector2(rng.randf_range(-FOREST_AREA, FOREST_AREA), rng.randf_range(-FOREST_AREA, FOREST_AREA))
		var keep_roll: float = rng.randf()
		var d: float = signed_distance(point)
		if d < FOREST_FROM or d > FOREST_TO or stream_distance(point) < FOREST_STREAM_GAP:
			continue
		if point.y < CORRIDOR_FROM_Z and absf(point.x) < CORRIDOR_HALF_WIDTH and keep_roll > CORRIDOR_KEEP:
			continue
		if _too_close(point, placed, FOREST_SPACING):
			continue
		placed.append(point)
		var scale: float = rng.randf_range(FOREST_SCALE.x, FOREST_SCALE.y) * TREE_BASE_SCALE
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
		var origin := Vector3(point.x, height(point.x, point.y) - TREE_SINK, point.y)
		trees.append([rng.randi_range(0, TREE_MESHES - 1), Transform3D(basis, origin), foliage_for(trees.size())])
	return trees


## Foliage colour of the index-th forest tree (30 % autumn, spread evenly).
func foliage_for(index: int) -> Color:
	var remainder: int = index % 10
	if AUTUMN_REMAINDERS.has(remainder):
		return LEAVES["yellow"] if (floori(index / 10.0) + AUTUMN_REMAINDERS.find(remainder)) % 2 == 0 else LEAVES["orange"]
	return LEAVES["green_light"] if index % 2 == 0 else LEAVES["green_dark"]


## Flower or grass instances of `kind`: [Transform3D, Color, parcel index] each.
func scatter(kind: int) -> Array:
	var rule: Array = SCATTER[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + kind * 101
	var circles: Array[Vector3] = obstacles()
	var items: Array = []
	var attempts: int = int(rule[0]) * SCATTER_ATTEMPTS_PER_ITEM
	for attempt: int in attempts:
		if items.size() >= int(rule[0]):
			break
		var point := Vector2(rng.randf_range(-SCATTER_AREA, SCATTER_AREA), rng.randf_range(-SCATTER_AREA, SCATTER_AREA))
		var accept_roll: float = rng.randf()
		var yaw: float = rng.randf() * TAU
		var scale: float = rng.randf_range(rule[1], rule[2])
		var tint: float = rng.randf_range(-GRASS_TINT_VARIATION, GRASS_TINT_VARIATION)
		if signed_distance(point) > float(rule[3]) or stream_distance(point) < float(rule[4]):
			continue
		if is_on_path(point, SCATTER_CLEARANCE) or _in_arch(point) or _in_obstacle(point, circles):
			continue
		if int(rule[5]) == 1 and accept_roll > maxf(PATCH_ACCEPT_FLOOR, (_patches.get_noise_2d(point.x, point.y) + 1.0) * 0.5):
			continue
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
		var origin := Vector3(point.x, height(point.x, point.y), point.y)
		var color: Color = GRASS_TINT.darkened(maxf(tint, 0.0)).lightened(maxf(-tint, 0.0))
		items.append([Transform3D(basis, origin), color, parcel_of(point)])
	return items


func parcel_of(point: Vector2) -> int:
	var size: float = SCATTER_AREA * 2.0 / PARCELS
	var px: int = clampi(floori((point.x + SCATTER_AREA) / size), 0, PARCELS - 1)
	var pz: int = clampi(floori((point.y + SCATTER_AREA) / size), 0, PARCELS - 1)
	return pz * PARCELS + px


## Cloud puffs (a unit sphere scaled by each transform).
func clouds() -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = CLOUD_SEED
	var puffs: Array[Transform3D] = []
	for i: int in CLOUD_CLUSTERS:
		var angle: float = TAU * float(i) / CLOUD_CLUSTERS + rng.randf_range(-0.2, 0.2)
		var distance: float = rng.randf_range(CLOUD_DISTANCE.x, CLOUD_DISTANCE.y)
		var center := Vector3(cos(angle) * distance, rng.randf_range(CLOUD_HEIGHT.x, CLOUD_HEIGHT.y), sin(angle) * distance)
		var along := Vector3(-sin(angle), 0.0, cos(angle))
		var out := Vector3(cos(angle), 0.0, sin(angle))
		for k: int in rng.randi_range(CLOUD_PUFFS.x, CLOUD_PUFFS.y):
			var size: float = rng.randf_range(CLOUD_PUFF_SIZE.x, CLOUD_PUFF_SIZE.y)
			var offset: Vector3 = along * rng.randf_range(-CLOUD_SPREAD.x, CLOUD_SPREAD.x) + Vector3.UP * rng.randf_range(-CLOUD_SPREAD.y * 0.4, CLOUD_SPREAD.y) + out * rng.randf_range(-CLOUD_SPREAD.z, CLOUD_SPREAD.z)
			puffs.append(Transform3D(Basis.from_scale(Vector3(size, size * CLOUD_FLATTEN, size)), center + offset))
	return puffs


# --- helpers -------------------------------------------------------------------

## Colour per vertex (soft edges for the path and the stream bed); the normals
## stay flat, so the light still shows the facets.
func _ground_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex: Vector3 in [a, b, c]:
		st.set_color(ground_color(vertex.x, vertex.z, vertex.y))
		st.add_vertex(vertex)


func _peak(st: SurfaceTool, rng: RandomNumberGenerator, angle: float, size: float) -> void:
	var distance: float = rng.randf_range(PEAK_DISTANCE.x, PEAK_DISTANCE.y)
	var peak_height: float = rng.randf_range(PEAK_HEIGHT.x, PEAK_HEIGHT.y) * size
	var radius: float = rng.randf_range(PEAK_RADIUS.x, PEAK_RADIUS.y) * size
	var twist: float = rng.randf() * TAU
	var base := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	var apex: Vector3 = base + Vector3.UP * peak_height
	var snow_y: float = peak_height * SNOW_FROM
	for k: int in PEAK_SEGMENTS:
		var a0: float = twist + TAU * k / PEAK_SEGMENTS
		var a1: float = twist + TAU * (k + 1) / PEAK_SEGMENTS
		var b0: Vector3 = base + Vector3(cos(a0), 0.0, sin(a0)) * radius
		var b1: Vector3 = base + Vector3(cos(a1), 0.0, sin(a1)) * radius
		var s0: Vector3 = base + Vector3(cos(a0) * radius * SNOW_RADIUS, snow_y, sin(a0) * radius * SNOW_RADIUS)
		var s1: Vector3 = base + Vector3(cos(a1) * radius * SNOW_RADIUS, snow_y, sin(a1) * radius * SNOW_RADIUS)
		_colored_triangle(st, MOUNTAIN_ROCK, b0, s1, b1)
		_colored_triangle(st, MOUNTAIN_ROCK, b0, s0, s1)
		_colored_triangle(st, MOUNTAIN_SNOW, s0, apex, s1)


func _dome(st: SurfaceTool, center: Vector3, radius: float, dome_height: float) -> void:
	for ring: int in HILL_RINGS:
		var t0: float = float(ring) / HILL_RINGS * PI * 0.5
		var t1: float = float(ring + 1) / HILL_RINGS * PI * 0.5
		for k: int in HILL_SEGMENTS:
			var a0: float = TAU * k / HILL_SEGMENTS
			var a1: float = TAU * (k + 1) / HILL_SEGMENTS
			var p00: Vector3 = center + Vector3(cos(a0) * cos(t0) * radius, sin(t0) * dome_height, sin(a0) * cos(t0) * radius)
			var p01: Vector3 = center + Vector3(cos(a1) * cos(t0) * radius, sin(t0) * dome_height, sin(a1) * cos(t0) * radius)
			var p10: Vector3 = center + Vector3(cos(a0) * cos(t1) * radius, sin(t1) * dome_height, sin(a0) * cos(t1) * radius)
			var p11: Vector3 = center + Vector3(cos(a1) * cos(t1) * radius, sin(t1) * dome_height, sin(a1) * cos(t1) * radius)
			_colored_triangle(st, HILL_GREEN, p00, p10, p11)
			_colored_triangle(st, HILL_GREEN, p00, p11, p01)


func _colored_triangle(st: SurfaceTool, color: Color, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _too_close(point: Vector2, others: Array[Vector2], spacing: float) -> bool:
	for other: Vector2 in others:
		if other.distance_to(point) < spacing:
			return true
	return false


func _in_arch(point: Vector2) -> bool:
	return absf(point.x) < ARCH_CLEAR.x and absf(point.y - ARCH_Z) < ARCH_CLEAR.y


func _in_obstacle(point: Vector2, circles: Array[Vector3]) -> bool:
	for circle: Vector3 in circles:
		if point.distance_to(Vector2(circle.x, circle.y)) < circle.z + SCATTER_CLEARANCE:
			return true
	return false
