extends GdUnitTestSuite
## The Mar de Flores stage (docs/specs/stages.md §3, AC1306–AC1307, AC1311–AC1318).

const DATA: StageData = preload("res://data/stages/mar_de_flores/mar_de_flores_stage.tres")
const TERRAIN: ArrayMesh = preload("res://assets/models/environment/mar_de_flores/terrain.res")
const HEIGHTS: HeightMapShape3D = preload("res://assets/models/environment/mar_de_flores/heights.res")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CAMERA_SCENE: PackedScene = preload("res://components/camera/third_person_camera.tscn")
const OBSTACLES_LAYER: int = 8
const MIN_HEIGHT: float = -0.8
const MAX_HEIGHT: float = 1.2
const MAX_SLOPE_DEG: float = 8.0
const MIN_GAP: float = 2.5
const HEIGHT_TOLERANCE: float = 0.05
const TELEGRAPH := Color(1.0, 0.3, 0.1)
const RAGE := Color(0.9, 0.1, 0.1)
const HUE_GAP_DEG: float = 20.0
const SATURATION_FLOOR: float = 0.3
const COMBAT_MATERIALS: Array[String] = [
	"terrain_material", "grass_material", "plant_material",
	"leaves_green_light_material", "leaves_green_dark_material", "leaves_yellow_material", "leaves_orange_material",
]
const PACKS: Array[String] = ["stylized_nature", "modular_dungeon", "castle_kit", "mar_de_flores"]

var _stage: StageMap
var _builder: MarDeFloresBuilder


func before_test() -> void:
	_builder = MarDeFloresBuilder.new()
	_stage = auto_free(DATA.scene.instantiate()) as StageMap
	_stage.setup(DATA)
	add_child(_stage)


func _in_spawn_area(point: Vector2) -> bool:
	return DATA.layout.contains(point)


# --- spawns ------------------------------------------------------------------

func test_ac1306_spawns_fall_inside_the_area_outside_obstacles_on_the_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1306
	for i: int in 200:
		var point: Vector3 = _stage.random_spawn_point(rng)
		var flat := Vector2(point.x, point.z)
		assert_bool(_in_spawn_area(flat)).is_true()
		assert_bool(_stage.is_blocked(flat, DATA.layout.obstacle_margin)).is_false()
		assert_float(point.y).is_equal_approx(_stage.height_at(point.x, point.z) + DATA.layout.spawn_lift, 0.0001)
	assert_float(DATA.layout.max_spawn_distance).is_greater(0.0)


func test_ac1307_clamped_points_stay_in_the_area() -> void:
	for point: Vector3 in [Vector3(40.0, 0.0, 0.0), Vector3(-30.0, 0.0, -30.0), Vector3(0.0, 0.0, 35.0), Vector3(-2.72, 0.0, -17.0)]:
		var inside: Vector3 = _stage.clamp_inside(point)
		var nudged: Vector2 = Vector2(inside.x, inside.z) * 0.999
		assert_bool(_in_spawn_area(nudged)).override_failure_message(str(point)).is_true()
		assert_bool(_stage.is_blocked(Vector2(inside.x, inside.z), DATA.layout.obstacle_margin - 0.01)).is_false()


# --- collision layers and bounds ------------------------------------------------

func test_ac1311_obstacles_block_bodies_but_not_the_camera() -> void:
	var player: Player = auto_free(PLAYER_SCENE.instantiate()) as Player
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate()) as Enemy
	var camera: Node = auto_free(CAMERA_SCENE.instantiate())
	assert_int(player.collision_mask & OBSTACLES_LAYER).is_equal(OBSTACLES_LAYER)
	assert_int(enemy.collision_mask & OBSTACLES_LAYER).is_equal(OBSTACLES_LAYER)
	assert_int((camera.get_node("SpringArm3D") as SpringArm3D).collision_mask & OBSTACLES_LAYER).is_equal(0)
	for body: Node in _stage.get_node("Bounds").get_children():
		assert_int((body as StaticBody3D).collision_layer).is_equal(OBSTACLES_LAYER)


## Every edge of the wall line is covered by a wall box tall enough for a jump.
func test_ac1312_the_walls_close_the_whole_line() -> void:
	var walls: Array[Node] = _stage.get_node("Bounds").get_children()
	assert_int(walls.size()).is_equal(MarDeFloresBuilder.BOUNDARY.size())
	for i: int in walls.size():
		var wall: StaticBody3D = walls[i] as StaticBody3D
		var box: BoxShape3D = (wall.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
		var a: Vector2 = MarDeFloresBuilder.BOUNDARY[i]
		var b: Vector2 = MarDeFloresBuilder.BOUNDARY[(i + 1) % MarDeFloresBuilder.BOUNDARY.size()]
		assert_float(box.size.x).is_greater_equal(a.distance_to(b))
		assert_float(wall.position.y + box.size.y * 0.5).is_greater(8.0)
		assert_float(wall.position.y - box.size.y * 0.5).is_less(MIN_HEIGHT)
		var middle: Vector2 = (a + b) * 0.5
		assert_float(Vector2(wall.position.x, wall.position.z).distance_to(middle)).is_less_equal(1.0)


# --- terrain -------------------------------------------------------------------

func test_ac1313_the_builder_reproduces_the_saved_terrain() -> void:
	var built: ArrayMesh = _builder.build_terrain_mesh()
	var saved_vertices: PackedVector3Array = TERRAIN.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var built_vertices: PackedVector3Array = built.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_int(built_vertices.size()).is_equal(saved_vertices.size())
	for i: int in range(0, saved_vertices.size(), 97):
		assert_vector(built_vertices[i]).is_equal_approx(saved_vertices[i], Vector3.ONE * 0.001)
	var heights: HeightMapShape3D = _builder.build_heights()
	assert_int(heights.map_width).is_equal(HEIGHTS.map_width)
	for i: int in range(0, HEIGHTS.map_data.size(), 13):
		assert_float(heights.map_data[i]).is_equal_approx(HEIGHTS.map_data[i], 0.001)


func test_ac1314_the_combat_area_is_gentle() -> void:
	var half: int = MarDeFloresBuilder.HEIGHT_HALF
	var size: int = HEIGHTS.map_width
	var max_rise: float = tan(deg_to_rad(MAX_SLOPE_DEG))
	for iz: int in size - 1:
		for ix: int in size - 1:
			var point := Vector2(ix - half, iz - half)
			if not _in_spawn_area(point):
				continue
			var h: float = HEIGHTS.map_data[iz * size + ix]
			assert_float(h).override_failure_message(str(point)).is_between(MIN_HEIGHT, MAX_HEIGHT)
			var dx: float = absf(HEIGHTS.map_data[iz * size + ix + 1] - h)
			var dz: float = absf(HEIGHTS.map_data[(iz + 1) * size + ix] - h)
			assert_float(maxf(dx, dz)).override_failure_message("slope at %s" % point).is_less_equal(max_rise)


func test_ac1315_height_at_matches_the_collision() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = _stage.get_world_3d().direct_space_state
	for point: Vector2 in [Vector2(0.0, 16.0), Vector2(-10.3, 4.7), Vector2(12.6, -8.1), Vector2(20.5, 9.5), Vector2(-3.2, -14.0)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 50.0, point.y), Vector3(point.x, -50.0, point.y), 1)
		var hit: Dictionary = space.intersect_ray(query)
		assert_bool(hit.is_empty()).override_failure_message(str(point)).is_false()
		assert_float((hit["position"] as Vector3).y).is_equal_approx(_stage.height_at(point.x, point.y), HEIGHT_TOLERANCE)


func test_ac1316_obstacles_leave_room_to_walk_between_them() -> void:
	assert_int(_stage.get_obstacles().size()).is_equal(_builder.obstacles().size())
	var props: Array = MarDeFloresBuilder.PROPS
	for i: int in props.size():
		for j: int in range(i + 1, props.size()):
			for a: Vector3 in _prop_circles(props[i]):
				for b: Vector3 in _prop_circles(props[j]):
					if not (_in_spawn_area(Vector2(a.x, a.y)) or _in_spawn_area(Vector2(b.x, b.y))):
						continue
					var gap: float = Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) - a.z - b.z
					assert_float(gap).override_failure_message("%s / %s" % [props[i][0], props[j][0]]).is_greater_equal(MIN_GAP)


## Obstacle circles of one prop, in stage space.
func _prop_circles(prop: Array) -> Array[Vector3]:
	var one: Array[Vector3] = []
	if not MarDeFloresBuilder.OBSTACLES.has(prop[0]):
		return one
	var yaw: float = deg_to_rad(prop[3])
	for circle: Array in MarDeFloresBuilder.OBSTACLES[prop[0]]:
		var local := Vector2(circle[0], circle[1]) * float(prop[4])
		one.append(Vector3(prop[1] + local.x * cos(yaw) + local.y * sin(yaw), prop[2] - local.x * sin(yaw) + local.y * cos(yaw), circle[2]))
	return one


# --- colours and assets --------------------------------------------------------

func _hue_gap(color: Color, reserved: Color) -> float:
	var diff: float = absf(color.h - reserved.h) * 360.0
	return minf(diff, 360.0 - diff)


func test_ac1317_scenery_avoids_reserved_and_warning_colours() -> void:
	for file: String in DirAccess.get_files_at("res://materials/environment"):
		if not file.ends_with(".tres"):
			continue
		var material: StandardMaterial3D = load("res://materials/environment/" + file) as StandardMaterial3D
		var color: Color = Color(material.albedo_color, 1.0)
		assert_bool(color.is_equal_approx(Color(1, 1, 1)) and material.albedo_texture == null and not material.vertex_color_use_as_albedo).override_failure_message(file).is_false()
		assert_bool(color.is_equal_approx(Color(0.5, 0.5, 0.5))).override_failure_message(file).is_false()
		if COMBAT_MATERIALS.has(file.get_basename()) and color.s > SATURATION_FLOOR:
			assert_float(_hue_gap(color, TELEGRAPH)).override_failure_message(file).is_greater(HUE_GAP_DEG)
			assert_float(_hue_gap(color, RAGE)).override_failure_message(file).is_greater(HUE_GAP_DEG)


func test_ac1317_about_a_third_of_the_trees_are_autumn() -> void:
	var autumn: int = 0
	var total: int = 0
	var yellow: bool = false
	var orange: bool = false
	for tree: Array in _builder.forest():
		var color: Color = tree[2]
		total += 1
		yellow = yellow or color.is_equal_approx(MarDeFloresBuilder.LEAVES["yellow"])
		orange = orange or color.is_equal_approx(MarDeFloresBuilder.LEAVES["orange"])
		if color.is_equal_approx(MarDeFloresBuilder.LEAVES["yellow"]) or color.is_equal_approx(MarDeFloresBuilder.LEAVES["orange"]):
			autumn += 1
	for prop: Array in MarDeFloresBuilder.PROPS:
		if String(prop[0]).begins_with("tree"):
			total += 1
			if prop[5] == "yellow" or prop[5] == "orange":
				autumn += 1
	assert_bool(yellow and orange).is_true()
	assert_float(float(autumn) / total).is_between(0.25, 0.35)


func test_ac1318_every_environment_pack_documents_its_source() -> void:
	for pack: String in PACKS:
		assert_bool(FileAccess.file_exists("res://assets/models/environment/%s/SOURCE.md" % pack)).override_failure_message(pack).is_true()
	for file: String in DirAccess.get_files_at("res://levels/stages/props"):
		if file.ends_with(".tscn"):
			var text: String = FileAccess.get_file_as_string("res://levels/stages/props/" + file)
			assert_bool(text.contains("res://assets/models/environment/")).override_failure_message(file).is_true()
