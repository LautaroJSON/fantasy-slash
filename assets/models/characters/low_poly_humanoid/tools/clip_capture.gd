extends Node
## Before/after capture sheets of the Samurai's cuts (poc/samurai-motion).
## Run without --headless, with a fixed frame rate:
##   godot --path <copy> --fixed-fps 60 res://assets/models/characters/low_poly_humanoid/tools/clip_capture.tscn -- --out=<dir>
## For each sequence (the chained combo, then every cut alone) it writes
## <dir>/<sequence>.png: per view, a row with the classic humanoid and a row
## with the motion layer, sampled across the sequence. Yellow dots trace the
## blade tip, green and magenta dots the left and right feet.

const HUMANOID: PackedScene = preload("res://entities/player/humanoid.tscn")
const WEAPON: WeaponData = preload("res://data/classes/samurai/katana.tres")
const COMBO: AttackComboConfig = preload("res://data/classes/samurai/samurai_combo.tres")
const VIEW_SIZE := Vector2i(360, 360)
const COLUMNS: int = 10
const FPS: float = 60.0
const MARKERS: int = 900
const RIG_SPACING: float = 40.0
## View name -> [camera offset, look-at offset, orthogonal size (0 = perspective), fov].
const VIEWS := {
	"front": [Vector3(2.0, 1.5, -3.0), Vector3(0.0, 0.95, -0.4), 0.0, 30.0],
	"side": [Vector3(3.6, 1.0, -0.4), Vector3(0.0, 0.9, -0.4), 0.0, 30.0],
	"game": [Vector3(0.6, 2.4, 3.6), Vector3(0.0, 1.0, -1.0), 0.0, 52.0],
	"top": [Vector3(0.0, 6.0, -0.5), Vector3(0.0, 0.0, -0.51), 3.6, 30.0],
}

var _out_dir: String = "user://captures"
## --movie: shows before/after side by side for --write-movie (real speed, then slow motion).
var _movie: bool = false
var _view_size: Vector2i = VIEW_SIZE
var _slow: float = 1.0
var _rigs: Array[Dictionary] = []
var _tip_material: StandardMaterial3D
var _foot_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_build_world()
	_tip_material = _flat(Color(1.0, 0.85, 0.1))
	_foot_materials = [_flat(Color(0.2, 0.9, 0.3)), _flat(Color(0.95, 0.25, 0.8))]
	_rigs.append(_build_rig(false, 0.0))
	_rigs.append(_build_rig(true, RIG_SPACING))
	for i: int in 10:
		await RenderingServer.frame_post_draw
	if _movie:
		await _play_movie()
		get_tree().quit()
		return
	await _run(&"combo", _combo_plan())
	for s: int in COMBO.steps.size():
		await _run(StringName("cut_%d" % (s + 1)), _single_plan(s))
	print("clip_capture: done -> ", ProjectSettings.globalize_path(_out_dir))
	get_tree().quit()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--movie":
			_movie = true
			_view_size = Vector2i(640, 360)
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")


# ---------------------------------------------------------------- MOVIE

## 2x2 grid on the main window: game camera and front view, before | after.
## The combo plays at real speed, then at 30 %, then each cut at 30 %.
func _play_movie() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(grid)
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	for view: String in ["game", "front"]:
		for rig_index: int in _rigs.size():
			var rect := TextureRect.new()
			rect.texture = (_rigs[rig_index]["views"][view][0] as SubViewport).get_texture()
			grid.add_child(rect)
			var label := Label.new()
			label.text = "ANTES" if rig_index == 0 else "DESPUES"
			label.add_theme_font_size_override("font_size", 26)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 8)
			label.position = Vector2(12, 8)
			rect.add_child(label)
	layer.add_child(caption)
	caption.position = Vector2(560, 330)
	var passes: Array = [[1.0, &"combo", _combo_plan()], [0.3, &"combo", _combo_plan()]]
	for s: int in COMBO.steps.size():
		passes.append([0.3, StringName("cut_%d" % (s + 1)), _single_plan(s)])
	for p: Array in passes:
		_slow = p[0]
		caption.text = "%s  x%.1f" % [p[1], _slow]
		Engine.time_scale = _slow
		await _run(p[1], p[2])
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- WORLD

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.56, 0.74)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.36, 0.38, 0.36)
	ground.material_override = ground_material
	add_child(ground)


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = true
	return m


func _build_rig(motion: bool, x: float) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(x, 0, 0)
	add_child(root)
	var humanoid: LowPolyHumanoid = HUMANOID.instantiate() as LowPolyHumanoid
	humanoid.motion_enabled = motion
	humanoid.profile = &"samurai"
	root.add_child(humanoid)
	humanoid.set_profile(&"samurai")

	var pivot := Node3D.new()
	root.add_child(pivot)
	var model: Node3D = WEAPON.model.instantiate() as Node3D
	pivot.add_child(model)
	var grip := Transform3D(Basis.from_euler(WEAPON.grip_rotation), WEAPON.grip_position)
	var tip_local: Vector3 = model.transform * (model.get_node("TrailTip") as Node3D).position
	var base_local: Vector3 = model.transform * (model.get_node("TrailBase") as Node3D).position
	humanoid.set_weapon_frame(grip.basis * (tip_local - base_local).normalized(), grip.basis * -model.transform.basis.x.normalized(), grip.origin)

	var socket := Node3D.new()
	humanoid.attach_to_joint(String(WEAPON.sheath_joint), socket, WEAPON.sheath_position, WEAPON.sheath_rotation)
	socket.add_child(WEAPON.sheath.instantiate())

	var rig := {
		"root": root, "humanoid": humanoid, "pivot": pivot, "grip": grip,
		"tip": model.get_node("TrailTip"), "markers": [], "used": 0, "views": {},
	}
	humanoid.anim.mixer_applied.connect(_place_weapon.bind(rig))
	for i: int in MARKERS:
		var marker := MeshInstance3D.new()
		marker.visible = false
		root.get_parent().add_child(marker)
		rig["markers"].append(marker)
	for view: String in VIEWS:
		rig["views"][view] = _build_view(x, VIEWS[view])
	return rig


func _build_view(x: float, spec: Array) -> Array:
	var vp := SubViewport.new()
	vp.size = _view_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = spec[3]
	if spec[2] > 0.0:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = spec[2]
	cam.look_at_from_position(Vector3(x, 0, 0) + spec[0], Vector3(x, 0, 0) + spec[1])
	cam.current = true
	return [vp, cam]


func _place_weapon(rig: Dictionary) -> void:
	var humanoid: LowPolyHumanoid = rig["humanoid"]
	var pose: Transform3D = humanoid.get_right_hand().global_transform * (rig["grip"] as Transform3D)
	(rig["pivot"] as Node3D).global_transform = Transform3D(pose.basis.orthonormalized(), pose.origin)
	if rig.get("marking", false):
		_mark(rig)


# ---------------------------------------------------------------- PLANS

## [clip, seconds to play it, lunge step or null] chained like the game: each
## cut is cancelled into the next at its cancel point; the last one plays out.
func _combo_plan() -> Array:
	var plan: Array = []
	for s: int in COMBO.steps.size():
		var step: AttackComboStep = COMBO.steps[s]
		var last: bool = s == COMBO.steps.size() - 1
		plan.append([step.animation, step.end_time + 0.3 if last else step.cancel_point + 0.02, step])
	return plan


func _single_plan(s: int) -> Array:
	var step: AttackComboStep = COMBO.steps[s]
	return [[step.animation, step.end_time + 0.3, step]]


# ---------------------------------------------------------------- RUN

func _run(sequence: StringName, plan: Array) -> void:
	for rig: Dictionary in _rigs:
		_reset(rig)
	for i: int in 20:
		await RenderingServer.frame_post_draw
	var total_frames: int = 0
	for entry: Array in plan:
		total_frames += ceili((entry[1] + (entry[2] as AttackComboStep).hitlag) * FPS / _slow)
	var every: int = maxi(ceili(float(total_frames) / COLUMNS), 1)
	for rig: Dictionary in _rigs:
		rig["marking"] = true
	var shots: Dictionary = {}  # "<view>/<rig>" -> Array[Image]
	var times: PackedStringArray = []
	var frame: int = 0
	var base_z: float = 0.0
	for entry: Array in plan:
		var step: AttackComboStep = entry[2]
		for rig: Dictionary in _rigs:
			(rig["humanoid"] as LowPolyHumanoid).play(entry[0])
			(rig["humanoid"] as LowPolyHumanoid).anim.speed_scale = 1.0
		var hitlag_left: float = 0.0
		var hitlag_done: bool = false
		var clip_frames: int = ceili((entry[1] + step.hitlag) * FPS / _slow)
		for f: int in clip_frames:
			await RenderingServer.frame_post_draw
			frame += 1
			var anim: AnimationPlayer = (_rigs[0]["humanoid"] as LowPolyHumanoid).anim
			var t: float = anim.current_animation_position
			if not hitlag_done and t >= step.hit_start:
				hitlag_done = true
				hitlag_left = step.hitlag
			var speed: float = 1.0
			if hitlag_left > 0.0:
				hitlag_left -= _slow / FPS
				speed = 0.0
			for rig: Dictionary in _rigs:
				var humanoid: LowPolyHumanoid = rig["humanoid"]
				humanoid.anim.speed_scale = speed
				var root: Node3D = rig["root"]
				root.position.z = -(base_z + step.lunge_covered(t))
				for view: String in VIEWS:
					var spec: Array = VIEWS[view]
					(rig["views"][view][1] as Camera3D).look_at_from_position(root.position + spec[0], root.position + spec[1])
			if not _movie and frame % every == 0:
				times.append("%s %.2f" % [entry[0], t])
				for rig_index: int in _rigs.size():
					for view: String in VIEWS:
						var key: String = "%s/%d" % [view, rig_index]
						if not shots.has(key):
							shots[key] = []
						var image: Image = (_rigs[rig_index]["views"][view][0] as SubViewport).get_texture().get_image()
						image.convert(Image.FORMAT_RGBA8)
						shots[key].append(image)
		base_z += step.lunge_distance
	if not _movie:
		_save_sheet(sequence, shots, times)


func _reset(rig: Dictionary) -> void:
	var humanoid: LowPolyHumanoid = rig["humanoid"]
	humanoid.anim.speed_scale = 1.0
	humanoid.play(&"idle", 0.0)
	(rig["root"] as Node3D).position.z = 0.0
	rig["marking"] = false
	for marker: MeshInstance3D in rig["markers"]:
		marker.visible = false
	rig["used"] = 0


func _mark(rig: Dictionary) -> void:
	var humanoid: LowPolyHumanoid = rig["humanoid"]
	_drop(rig, (rig["tip"] as Node3D).global_position, _tip_material, 0.022)
	# The foot mesh is the ankle joint's only child.
	var left: Node3D = humanoid.get_joint("ankle_l").get_child(0) as Node3D
	var right: Node3D = humanoid.get_joint("ankle_r").get_child(0) as Node3D
	_drop(rig, left.global_position * Vector3(1, 0, 1) + Vector3(0, 0.01, 0), _foot_materials[0], 0.03)
	_drop(rig, right.global_position * Vector3(1, 0, 1) + Vector3(0, 0.01, 0), _foot_materials[1], 0.03)


func _drop(rig: Dictionary, at: Vector3, material: StandardMaterial3D, radius: float) -> void:
	var used: int = rig["used"]
	if used >= MARKERS:
		return
	var marker: MeshInstance3D = rig["markers"][used]
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	marker.mesh = sphere
	marker.material_override = material
	marker.global_position = at
	marker.visible = true
	rig["used"] = used + 1


func _save_sheet(sequence: StringName, shots: Dictionary, times: PackedStringArray) -> void:
	var columns: int = times.size()
	var gap: int = 4
	for view: String in VIEWS:
		var sheet := Image.create(columns * (VIEW_SIZE.x + gap), _rigs.size() * (VIEW_SIZE.y + gap), false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.08, 0.08, 0.1))
		for rig_index: int in _rigs.size():
			var images: Array = shots.get("%s/%d" % [view, rig_index], [])
			for c: int in images.size():
				var image: Image = images[c]
				sheet.blit_rect(image, Rect2i(Vector2i.ZERO, VIEW_SIZE), Vector2i(c * (VIEW_SIZE.x + gap), rig_index * (VIEW_SIZE.y + gap)))
		sheet.save_png(_out_dir.path_join("%s_%s.png" % [sequence, view]))
	var log := FileAccess.open(_out_dir.path_join("%s.txt" % sequence), FileAccess.WRITE)
	log.store_string("rows: [classic, motion]\ncolumns: %s\n" % " | ".join(times))
