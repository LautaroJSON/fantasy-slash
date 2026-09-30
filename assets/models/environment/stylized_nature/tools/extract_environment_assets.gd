extends SceneTree
## Offline tool (docs/specs/stages.md §3.3): turns the downloaded source .glb
## files of the three environment packs into the files the game uses:
## - one static ArrayMesh .res per model (geometry only, node transforms baked,
##   no materials: the adapter scenes put the shared .tres materials on);
## - the stylized nature textures, once each, at TEXTURE_SIZE (they come
##   embedded and repeated in every .glb), plus two derived textures:
##   a white leaf mask (tinted per tree by its material) and a flower atlas
##   whose reds and salmon pinks are turned magenta (docs/color-registry.md).
## Run from a copy of the project: godot --headless -s <this> -- <source dir>
## with <source dir> holding stylized_nature/, modular_dungeon/ and castle_kit/
## as listed in the SOURCE.md of each pack.

const OUT: String = "res://assets/models/environment"
const TEXTURE_SIZE: int = 512
## Hue band (degrees) of the flower petals moved away from the attack
## telegraph orange-red, and the hue they are moved to.
const RED_BAND_FROM: float = 335.0
const RED_BAND_TO: float = 35.0
const MAGENTA_HUE: float = 318.0
const MIN_SATURATION: float = 0.25
## Leaf mask brightness: luminance scale and floor (keeps a little shading).
const MASK_GAIN: float = 2.2
const MASK_FLOOR: float = 0.75

## [pack, source file (without .glb), output mesh name]
const MODELS: Array = [
	["stylized_nature", "tree_4", "tree_a"],
	["stylized_nature", "tree_5", "tree_b"],
	["stylized_nature", "tree_6", "tree_c"],
	["stylized_nature", "tree_7", "tree_d"],
	["stylized_nature", "tree_10", "tree_e"],
	["stylized_nature", "bush_0", "bush"],
	["stylized_nature", "bush_with_flowers_3", "bush_flowers"],
	["stylized_nature", "rock_medium_56", "rock_a"],
	["stylized_nature", "rock_medium_57", "rock_b"],
	["stylized_nature", "rock_medium_58", "rock_c"],
	["stylized_nature", "pebble_round_24", "pebble"],
	["stylized_nature", "rock_path_round_wide_54", "stone_path"],
	["stylized_nature", "flower_group_36", "flower_group_a"],
	["stylized_nature", "flower_group_39", "flower_group_b"],
	["stylized_nature", "flower_single_34", "flower_single_a"],
	["stylized_nature", "flower_single_37", "flower_single_b"],
	["stylized_nature", "flower_petal_17", "flower_petal"],
	["stylized_nature", "plant_big_42", "violet_patch"],
	["stylized_nature", "grass_13", "grass_short"],
	["stylized_nature", "grass_wispy_14", "grass_wispy"],
	["stylized_nature", "tall_grass_15", "grass_tall"],
	["stylized_nature", "fern_22", "fern"],
	["modular_dungeon", "column_11", "column_a"],
	["modular_dungeon", "column_12", "column_b"],
	["modular_dungeon", "arch_22", "arch"],
	["castle_kit", "tower-hexagon-base", "tower_hexagon_base"],
	["castle_kit", "tower-hexagon-mid", "tower_hexagon_mid"],
	["castle_kit", "tower-hexagon-roof", "tower_hexagon_roof"],
	["castle_kit", "tower-square-base", "tower_square_base"],
	["castle_kit", "tower-square-mid", "tower_square_mid"],
	["castle_kit", "tower-square-mid-windows", "tower_square_mid_windows"],
	["castle_kit", "tower-square-roof", "tower_square_roof"],
	["castle_kit", "tower-square-top-roof-high", "tower_square_top_roof_high"],
	["castle_kit", "wall", "wall"],
	["castle_kit", "wall-pillar", "wall_pillar"],
	["castle_kit", "gate", "gate"],
	["castle_kit", "flag-pennant", "flag_pennant"],
]
## Embedded image name → texture file of the stylized nature pack.
const NATURE_TEXTURES: Dictionary = {
	"Bark_NormalTree.png": "bark.png",
	"Rocks_Diffuse.png": "rocks.png",
	"PathRocks_Diffuse.png": "path_rocks.png",
	"Grass.png": "grass.png",
	"Leaves.png": "leaves.png",
}
const LEAF_MASK_SOURCE: String = "Leaves_NormalTree_C.png"
const FLOWER_ATLAS: String = "Flowers.png"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <source dir>")
		quit(1)
		return
	var source_dir: String = args[0]
	var saved: Dictionary = {}
	for model: Array in MODELS:
		var path: String = "%s/%s/%s.glb" % [source_dir, model[0], model[1]]
		_extract(path, model[0], model[2], saved)
	var colormap: Image = Image.load_from_file("%s/castle_kit/Textures/colormap.png" % source_dir)
	var target: String = OUT + "/castle_kit/textures/colormap.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	colormap.save_png(ProjectSettings.globalize_path(target))
	quit()


func _extract(path: String, pack: String, out_name: String, saved: Dictionary) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("cannot read " + path)
		return
	if pack == "stylized_nature":
		_save_textures(state, saved)
	var root: Node = doc.generate_scene(state)
	var instance: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh: ArrayMesh = _baked_mesh(instance.mesh, _global_transform(instance, root))
	var target: String = "%s/%s/meshes/%s.res" % [OUT, pack, out_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	ResourceSaver.save(mesh, target, ResourceSaver.FLAG_COMPRESS)
	root.free()


func _baked_mesh(source: Mesh, xf: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i: int in vertices.size():
			vertices[i] = xf * vertices[i]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i: int in normals.size():
			normals[i] = (xf.basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals if normals.size() > 0 else null
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func _global_transform(node: Node3D, root: Node) -> Transform3D:
	var xf: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent is Node3D:
		xf = (parent as Node3D).transform * xf
		if parent == root:
			break
		parent = parent.get_parent()
	return xf


func _save_textures(state: GLTFState, saved: Dictionary) -> void:
	var images: Array[Texture2D] = state.get_images()
	var infos: Array = state.json.get("images", [])
	for i: int in images.size():
		var image_name: String = String((infos[i] as Dictionary).get("name", "")) if i < infos.size() else ""
		if saved.has(image_name):
			continue
		var file: String = ""
		var image: Image = images[i].get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		if NATURE_TEXTURES.has(image_name):
			file = NATURE_TEXTURES[image_name]
		elif image_name == LEAF_MASK_SOURCE:
			file = "leaves_mask.png"
			_to_white_mask(image)
		elif image_name == FLOWER_ATLAS:
			file = "flowers.png"
			_move_reds_to_magenta(image)
		if file.is_empty():
			continue
		image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
		var target: String = "%s/stylized_nature/textures/%s" % [OUT, file]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
		image.save_png(ProjectSettings.globalize_path(target))
		saved[image_name] = true


## Keeps the alpha and a little of the leaves' shading; the colour comes from the material.
func _to_white_mask(image: Image) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var light: float = clampf(c.get_luminance() * MASK_GAIN, MASK_FLOOR, 1.0)
			image.set_pixel(x, y, Color(light, light, light, c.a))


func _move_reds_to_magenta(image: Image) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var hue: float = c.h * 360.0
			if c.s >= MIN_SATURATION and (hue >= RED_BAND_FROM or hue <= RED_BAND_TO):
				image.set_pixel(x, y, Color.from_hsv(MAGENTA_HUE / 360.0, c.s, c.v, c.a))
