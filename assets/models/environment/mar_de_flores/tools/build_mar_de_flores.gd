extends SceneTree
## Offline tool (docs/specs/stages.md §3): writes every generated file of the
## Mar de Flores from MarDeFloresBuilder and assembles its stage scene.
## Run from a copy of the project, WITHOUT --headless (the dummy renderer of
## --headless drops the MultiMesh instance buffers):
##   godot --path <copy> -s res://assets/models/environment/mar_de_flores/tools/build_mar_de_flores.gd
## then copy the written files back (see SOURCE.md).

const BASE: String = "res://assets/models/environment/mar_de_flores"
const NATURE: String = "res://assets/models/environment/stylized_nature/meshes"
const CASTLE: String = "res://assets/models/environment/castle_kit/meshes"
const MATERIALS: String = "res://materials/environment"
const STAGE_SCENE: String = "res://levels/stages/mar_de_flores/mar_de_flores_stage.tscn"
const ENVIRONMENT: String = "res://levels/stages/mar_de_flores/mar_de_flores_environment.tres"
const LAYOUT: String = "res://data/stages/mar_de_flores/mar_de_flores_layout.tres"
const PROPS: String = "res://levels/stages/props"

## Scatter kinds → [source mesh, materials per surface, visibility range (m)].
const SCATTER_MESHES: Dictionary = {
	MarDeFloresBuilder.Scatter.PETAL: ["flower_petal", ["flower_material"], 45.0],
	MarDeFloresBuilder.Scatter.SINGLE_A: ["flower_single_a", ["flower_material", "plant_material"], 45.0],
	MarDeFloresBuilder.Scatter.SINGLE_B: ["flower_single_b", ["plant_material", "flower_material"], 45.0],
	MarDeFloresBuilder.Scatter.GROUP_A: ["flower_group_a", ["flower_material", "plant_material"], 45.0],
	MarDeFloresBuilder.Scatter.VIOLET: ["violet_patch", ["plant_material"], 45.0],
	MarDeFloresBuilder.Scatter.GRASS_SHORT: ["grass_short", ["grass_material"], 40.0],
	MarDeFloresBuilder.Scatter.GRASS_TALL: ["grass_tall", ["grass_material"], 40.0],
}
const TREE_MESHES: Array[String] = ["tree_a", "tree_b", "tree_c", "tree_d", "tree_e"]
const LEAF_MATERIALS: Dictionary = {
	"green_light": "leaves_green_light_material",
	"green_dark": "leaves_green_dark_material",
	"yellow": "leaves_yellow_material",
	"orange": "leaves_orange_material",
}
## Layout of the StageLayout written for the stage.
const MAX_SPAWN_DISTANCE: float = 18.0
const SPAWN_LIFT: float = 0.3
const OBSTACLE_MARGIN: float = 0.5
const POINT_ATTEMPTS: int = 20
## Invisible walls: height, thickness, and the y of their centre.
const WALL_HEIGHT: float = 14.0
const WALL_THICKNESS: float = 1.0
const WALL_CENTER_Y: float = 3.0
const OBSTACLES_LAYER: int = 8
const FAR_GROUND_SIZE: float = 1600.0
const FAR_GROUND_Y: float = -0.3
## Castle: kit units scaled by CASTLE_SCALE on top of the castle hill.
const CASTLE_SCALE: float = 12.0
const CASTLE_SINK: float = 1.0
## Sky, fog and sun.
const SKY_TOP := Color(0.18, 0.42, 0.86)
const SKY_HORIZON := Color(0.62, 0.78, 0.95)
const GROUND_BOTTOM := Color(0.3, 0.45, 0.3)
const SUN_ANGLE_MAX: float = 20.0
const FOG_COLOR := Color(0.7, 0.82, 0.95)
const FOG_DENSITY: float = 0.0011
const FOG_AERIAL: float = 0.5
const GLOW_INTENSITY: float = 0.4
const SUN_COLOR := Color(1.0, 0.95, 0.85)
const SUN_ENERGY: float = 1.25
const SUN_PITCH: float = -48.0
const SUN_YAW: float = -35.0
const SHADOW_DISTANCE: float = 60.0

var _builder := MarDeFloresBuilder.new()


func _init() -> void:
	for dir: String in [BASE + "/scatter", BASE + "/scatter_meshes", STAGE_SCENE.get_base_dir(), LAYOUT.get_base_dir()]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save(_builder.build_terrain_mesh(), BASE + "/terrain.res")
	_save(_builder.build_heights(), BASE + "/heights.res")
	_save(_builder.build_backdrop_mesh(), BASE + "/backdrop.res")
	_save(_builder.build_water_mesh(), BASE + "/water.res")
	_save_scatter_meshes()
	_save_scatter()
	_save_forest()
	_save_clouds()
	_save_layout()
	_save_environment()
	_save_stage_scene()
	quit()


func _save(resource: Resource, path: String) -> void:
	var error: Error = ResourceSaver.save(resource, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("cannot save %s (%d)" % [path, error])
	resource.take_over_path(path)


func _material(key: String) -> Material:
	return load("%s/%s.tres" % [MATERIALS, key])


## Copies of the pack meshes with their materials on (a MultiMesh has no per-surface override).
func _save_scatter_meshes() -> void:
	for kind: int in SCATTER_MESHES:
		var entry: Array = SCATTER_MESHES[kind]
		var mesh: ArrayMesh = (load("%s/%s.res" % [NATURE, entry[0]]) as ArrayMesh).duplicate() as ArrayMesh
		for s: int in mesh.get_surface_count():
			mesh.surface_set_material(s, _material(entry[1][s]))
		_save(mesh, "%s/scatter_meshes/%s.res" % [BASE, entry[0]])
	for tree: String in TREE_MESHES:
		var mesh: ArrayMesh = (load("%s/%s.res" % [NATURE, tree]) as ArrayMesh).duplicate() as ArrayMesh
		mesh.surface_set_material(0, _material("bark_material"))
		mesh.surface_set_material(1, _material("leaves_tint_material"))
		_save(mesh, "%s/scatter_meshes/%s.res" % [BASE, tree])
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 12
	puff.rings = 6
	puff.material = _material("cloud_material")
	_save(puff, BASE + "/cloud_puff.tres")
	var plane := PlaneMesh.new()
	plane.size = Vector2(FAR_GROUND_SIZE, FAR_GROUND_SIZE)
	plane.material = _material("far_ground_material")
	_save(plane, BASE + "/far_ground.tres")


func _save_scatter() -> void:
	for kind: int in SCATTER_MESHES:
		var items: Array = _builder.scatter(kind)
		var mesh: Mesh = load("%s/scatter_meshes/%s.res" % [BASE, SCATTER_MESHES[kind][0]])
		for parcel: int in MarDeFloresBuilder.PARCELS * MarDeFloresBuilder.PARCELS:
			var transforms: Array[Transform3D] = []
			var colors: Array[Color] = []
			for item: Array in items:
				if int(item[2]) == parcel:
					transforms.append(item[0])
					colors.append(item[1])
			_save(_multimesh(mesh, transforms, colors), _scatter_path(kind, parcel))


func _scatter_path(kind: int, parcel: int) -> String:
	return "%s/scatter/%s_%d.res" % [BASE, SCATTER_MESHES[kind][0], parcel]


func _save_forest() -> void:
	var trees: Array = _builder.forest()
	for index: int in TREE_MESHES.size():
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		for tree: Array in trees:
			if int(tree[0]) == index:
				transforms.append(tree[1])
				colors.append(tree[2])
		var mesh: Mesh = load("%s/scatter_meshes/%s.res" % [BASE, TREE_MESHES[index]])
		_save(_multimesh(mesh, transforms, colors), "%s/scatter/forest_%s.res" % [BASE, TREE_MESHES[index]])


func _save_clouds() -> void:
	var puffs: Array[Transform3D] = _builder.clouds()
	var colors: Array[Color] = []
	_save(_multimesh(load(BASE + "/cloud_puff.tres"), puffs, colors), BASE + "/scatter/clouds.res")


func _multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i])
	return multimesh


func _save_layout() -> void:
	var layout := StageLayout.new()
	layout.spawn_polygon = _builder.spawn_polygon()
	layout.max_spawn_distance = MAX_SPAWN_DISTANCE
	layout.spawn_lift = SPAWN_LIFT
	layout.obstacle_margin = OBSTACLE_MARGIN
	layout.point_attempts = POINT_ATTEMPTS
	_save(layout, LAYOUT)


func _save_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP
	sky_material.sky_horizon_color = SKY_HORIZON
	sky_material.ground_horizon_color = SKY_HORIZON
	sky_material.ground_bottom_color = GROUND_BOTTOM
	sky_material.sun_angle_max = SUN_ANGLE_MAX
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = FOG_COLOR
	environment.fog_density = FOG_DENSITY
	environment.fog_aerial_perspective = FOG_AERIAL
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = true
	environment.glow_intensity = GLOW_INTENSITY
	_save(environment, ENVIRONMENT)


# --- stage scene -------------------------------------------------------------

func _save_stage_scene() -> void:
	var root := StageMap.new()
	root.name = "MarDeFloresStage"
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = load(ENVIRONMENT)
	_add(root, root, world)
	_add(root, root, _sun())
	var terrain_shape: CollisionShape3D = _add_terrain(root)
	var far_ground := MeshInstance3D.new()
	far_ground.name = "FarGround"
	far_ground.mesh = load(BASE + "/far_ground.tres")
	far_ground.position.y = FAR_GROUND_Y
	far_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(root, root, far_ground)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = load(BASE + "/water.res")
	water.material_override = _material("water_material")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(root, root, water)
	_add_bounds(root)
	_add_props(root)
	_add_scatter(root)
	_add_backdrop(root)
	var start := Marker3D.new()
	start.name = "PlayerStart"
	var start_point: Vector2 = MarDeFloresBuilder.PLAYER_START
	start.position = Vector3(start_point.x, _builder.height(start_point.x, start_point.y), start_point.y)
	_add(root, root, start)
	var portal := Marker3D.new()
	portal.name = "PortalPoint"
	portal.position = Vector3(0.0, _builder.height(0.0, MarDeFloresBuilder.ARCH_Z), MarDeFloresBuilder.ARCH_Z)
	_add(root, root, portal)
	root.player_start = start
	root.portal_point = portal
	root.terrain_shape = terrain_shape
	var scene := PackedScene.new()
	if scene.pack(root) != OK:
		push_error("cannot pack the stage")
	_save(scene, STAGE_SCENE)
	root.free()


func _add(root: Node, parent: Node, child: Node) -> Node:
	parent.add_child(child)
	child.owner = root
	return child


func _group(root: Node, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	_add(root, root, node)
	return node


func _sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	sun.rotation = Vector3(deg_to_rad(SUN_PITCH), deg_to_rad(SUN_YAW), 0.0)
	return sun


func _add_terrain(root: Node) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_mask = 0
	_add(root, root, body)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = load(BASE + "/terrain.res")
	mesh.material_override = _material("terrain_material")
	_add(root, body, mesh)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = load(BASE + "/heights.res")
	_add(root, body, shape)
	return shape


## One box per edge of the wall line, just outside it.
func _add_bounds(root: Node) -> void:
	var bounds: Node3D = _group(root, "Bounds")
	var boundary: PackedVector2Array = MarDeFloresBuilder.BOUNDARY
	var centroid := Vector2.ZERO
	for point: Vector2 in boundary:
		centroid += point / boundary.size()
	for i: int in boundary.size():
		var a: Vector2 = boundary[i]
		var b: Vector2 = boundary[(i + 1) % boundary.size()]
		var along: Vector2 = (b - a).normalized()
		var outward := Vector2(along.y, -along.x)
		var middle: Vector2 = (a + b) * 0.5
		if outward.dot(middle - centroid) < 0.0:
			outward = -outward
		var center: Vector2 = middle + outward * WALL_THICKNESS * 0.5
		var wall := StaticBody3D.new()
		wall.name = "Wall%d" % i
		wall.collision_layer = OBSTACLES_LAYER
		wall.collision_mask = 0
		wall.transform = Transform3D(Basis(Vector3.UP, atan2(-along.y, along.x)), Vector3(center.x, WALL_CENTER_Y, center.y))
		_add(root, bounds, wall)
		var box := BoxShape3D.new()
		box.size = Vector3(a.distance_to(b) + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		shape.shape = box
		_add(root, wall, shape)


func _add_props(root: Node) -> void:
	var props: Node3D = _group(root, "Props")
	var counts: Dictionary = {}
	for prop: Array in MarDeFloresBuilder.PROPS:
		var key: String = prop[0]
		var instance: Node3D = (load("%s/%s.tscn" % [PROPS, key]) as PackedScene).instantiate() as Node3D
		counts[key] = int(counts.get(key, 0)) + 1
		instance.name = "%s%d" % [key.to_pascal_case(), counts[key]]
		var x: float = prop[1]
		var z: float = prop[2]
		instance.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(prop[3])).scaled(Vector3.ONE * float(prop[4])), Vector3(x, _builder.height(x, z), z))
		_add(root, props, instance)
		if not String(prop[5]).is_empty():
			root.set_editable_instance(instance, true)
			(instance.get_node("Model") as MeshInstance3D).set_surface_override_material(1, _material(LEAF_MATERIALS[prop[5]]))


func _add_scatter(root: Node) -> void:
	var scatter: Node3D = _group(root, "Scatter")
	for kind: int in SCATTER_MESHES:
		for parcel: int in MarDeFloresBuilder.PARCELS * MarDeFloresBuilder.PARCELS:
			var instance := MultiMeshInstance3D.new()
			instance.name = "%s%d" % [String(SCATTER_MESHES[kind][0]).to_pascal_case(), parcel]
			instance.multimesh = load(_scatter_path(kind, parcel))
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = SCATTER_MESHES[kind][2]
			_add(root, scatter, instance)
	var forest: Node3D = _group(root, "Forest")
	for tree: String in TREE_MESHES:
		var instance := MultiMeshInstance3D.new()
		instance.name = tree.to_pascal_case()
		instance.multimesh = load("%s/scatter/forest_%s.res" % [BASE, tree])
		_add(root, forest, instance)


func _add_backdrop(root: Node) -> void:
	var backdrop: Node3D = _group(root, "Backdrop")
	var mountains := MeshInstance3D.new()
	mountains.name = "Mountains"
	mountains.mesh = load(BASE + "/backdrop.res")
	mountains.material_override = _material("backdrop_material")
	mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(root, backdrop, mountains)
	var clouds := MultiMeshInstance3D.new()
	clouds.name = "Clouds"
	clouds.multimesh = load(BASE + "/scatter/clouds.res")
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(root, backdrop, clouds)
	_add_castle(root, backdrop)


## Kit pieces in kit units (1 ≈ one wall block), scaled as a whole.
func _add_castle(root: Node, parent: Node) -> void:
	var castle := Node3D.new()
	castle.name = "Castle"
	var top: Vector3 = MarDeFloresBuilder.CASTLE_HILL + Vector3.UP * (MarDeFloresBuilder.CASTLE_HILL_HEIGHT - CASTLE_SINK)
	castle.transform = Transform3D(Basis.from_scale(Vector3.ONE * CASTLE_SCALE), top)
	_add(root, parent, castle)
	# The keep: base, two floors with windows and the high roof.
	_stack(root, castle, Vector3(0.0, 0.0, 0.0), ["tower_square_base", "tower_square_mid_windows", "tower_square_mid_windows", "tower_square_top_roof_high"])
	# Round towers of different heights around it.
	var towers: Array = [[-2.2, 0.8, 3], [2.2, 0.8, 4], [-1.3, -1.8, 5], [1.4, -1.9, 6], [0.0, -2.6, 7]]
	for tower: Array in towers:
		var pieces: Array[String] = ["tower_hexagon_base"]
		for k: int in int(tower[2]):
			pieces.append("tower_hexagon_mid")
		pieces.append("tower_hexagon_roof")
		_stack(root, castle, Vector3(tower[0], 0.0, tower[1]), pieces)
	# Front wall with the gate between the two front towers.
	for x: float in [-1.2, 1.2]:
		_piece(root, castle, "wall", Vector3(x, 0.0, 0.8), 0.0)
	_piece(root, castle, "gate", Vector3(0.0, 0.0, 0.8), PI * 0.5)
	_piece(root, castle, "flag_pennant", Vector3(0.0, 5.4, 0.0), 0.0)


func _stack(root: Node, parent: Node, at: Vector3, pieces: Array) -> void:
	var y: float = at.y
	for piece: String in pieces:
		var mesh: Mesh = load("%s/%s.res" % [CASTLE, piece])
		_piece(root, parent, piece, Vector3(at.x, y, at.z), 0.0)
		y += mesh.get_aabb().size.y


func _piece(root: Node, parent: Node, piece: String, at: Vector3, yaw: float) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "%s%d" % [piece.to_pascal_case(), parent.get_child_count()]
	mesh.mesh = load("%s/%s.res" % [CASTLE, piece])
	mesh.set_surface_override_material(0, _material("castle_material"))
	mesh.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(root, parent, mesh)
