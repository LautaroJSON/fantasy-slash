class_name VerdugoModel
extends EnemyModel
## El Verdugo of La Plaga: a tall, broad executioner in a torn hood, charcoal black
## with dark-steel pauldrons and an enormous blade in the right hand (the blade is
## the hand mesh, turned forward by EnemyHandsConfig.hand_rotation). Every move of
## its repertoire has its own clips (slash_a to slash_d, shockwave, grab, transition);
## in phase 2 the glow of its chest stays lit (docs/specs/enemy-models.md).
##
## Joints (lower-case in the poses): hips → torso → head ; hips → cloak, foot_l, foot_r.
## The chest is the glow part; Sparks is the emitter (the blade driven into the floor).

const BODY_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/verdugo_body_material.tres")
const ACCENT_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/verdugo_accent_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/verdugo_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.85, 0.0)
const TORSO_REST := Vector3(0.0, 0.05, 0.0)
const HEAD_REST := Vector3(0.0, 0.95, -0.05)
const CLOAK_REST := Vector3(0.0, 0.0, 0.05)
const SHOULDERS_AT := Vector3(0.0, 0.8, 0.0)
const CHEST_AT := Vector3(0.0, 0.55, -0.32)
const FOOT_L_REST := Vector3(-0.28, -0.85, 0.0)
const FOOT_R_REST := Vector3(0.28, -0.85, 0.0)
const SPARKS_AT := Vector3(0.0, 0.1, -1.0)
const OVERLAP: Dictionary = {&"torso": 0.05, &"head": 0.1, &"cloak": 0.14}

@export var sparks: EnemyParticlesConfig

var _phase: int = 1


func _type_id() -> StringName:
	return &"verdugo"


func on_phase(phase: int) -> void:
	_phase = phase
	set_alert(false)


## The chest stays lit in phase 2 whatever the moves do.
func set_alert(on: bool) -> void:
	super.set_alert(on or _phase >= 2)


## Only phase 2 lights the chest, not the windups.
func _alerts_on_windup() -> bool:
	return false


func _alert_for_pose(_pose: StringName) -> bool:
	return false


func is_alert() -> bool:
	return _phase >= 2 and super.is_alert()


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = BODY_MATERIAL
	shared.materials[&"accent"] = ACCENT_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	shared.materials[MATERIAL_GLOW_OFF] = ACCENT_MATERIAL
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _hood_mesh()
	shared.meshes[&"shoulders"] = _pauldrons_mesh()
	shared.meshes[&"chest"] = _chest_mesh()
	shared.meshes[&"cloak"] = _cloak_mesh()
	shared.meshes[&"foot"] = _foot_mesh()
	var spark := BoxMesh.new()
	spark.size = Vector3.ONE
	spark.material = ACCENT_MATERIAL
	shared.meshes[&"spark"] = spark
	shared.hand_right = _blade_mesh()
	shared.hand_left = _open_hand_mesh()
	shared.motion = _motion_library()
	shared.overlay = _standard_overlay(0.4)


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], BODY_MATERIAL, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	_joints[JOINT_HEAD] = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], BODY_MATERIAL, HEAD_REST)
	_joints[&"Shoulders"] = _add_part(torso, &"Shoulders", shared.meshes[&"shoulders"], ACCENT_MATERIAL, SHOULDERS_AT)
	_joints[&"Chest"] = _add_glow_part(torso, &"Chest", shared.meshes[&"chest"], CHEST_AT)
	_joints[&"Cloak"] = _add_part(hips, &"Cloak", shared.meshes[&"cloak"], BODY_MATERIAL, CLOAK_REST)
	_joints[&"FootL"] = _add_part(hips, &"FootL", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_L_REST)
	_joints[&"FootR"] = _add_part(hips, &"FootR", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_R_REST)
	_add_fx_root()
	if sparks != null:
		_add_emitter(&"Sparks", sparks, shared.meshes[&"spark"], SPARKS_AT)


# --- Meshes ------------------------------------------------------------------

func _torso_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.3, 0.24],
		[0.25, 0.4, 0.3],
		[0.6, 0.5, 0.32, 0.0, -0.02],
		[0.82, 0.44, 0.26, 0.0, -0.04],
		[0.9, 0.22, 0.18, 0.0, -0.04],
	])
	return kit.build()


## A tall torn hood ending in a point, with rags hanging at the back.
func _hood_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[-0.15, 0.18, 0.18],
		[0.05, 0.24, 0.24],
		[0.25, 0.2, 0.2, 0.0, 0.03],
		[0.38, 0.05, 0.06, 0.0, 0.08],
	])
	for x: float in [-0.14, 0.0, 0.14]:
		kit.add_cone(Vector3(x, -0.12, 0.2), 0.05, -0.32, 3)
	return kit.build()


func _pauldrons_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	for side: float in [-1.0, 1.0]:
		kit.add_box(Vector3(side * 0.46, 0.0, 0.0), Vector3(0.18, 0.14, 0.32))
		kit.add_cone(Vector3(side * 0.46, 0.07, 0.0), 0.06, 0.2, 4)
	return kit.build()


func _chest_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3.ZERO, Vector3(0.22, 0.22, 0.04))
	return kit.build()


## Ragged cloak hanging from the hips down to the shins.
func _cloak_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.05, 0.36, 0.3],
		[-0.3, 0.46, 0.38],
		[-0.72, 0.42, 0.34],
	], 7)
	return kit.build()


func _foot_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.07, 0.03), Vector3(0.24, 0.14, 0.3))
	kit.add_wedge(Vector3(0.0, 0.07, -0.23), Vector3(0.22, 0.14, 0.16))
	return kit.build()


## The great blade along +Y (hand_rotation points it forward, −Z): grip, guard, long edge.
func _blade_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_prism(Vector3(0.0, -0.32, 0.0), 0.04, 0.04, 0.32, 6)
	kit.add_box(Vector3(0.0, 0.0, 0.0), Vector3(0.38, 0.07, 0.1))
	kit.add_prism(Vector3(0.0, 0.03, 0.0), 0.09, 0.02, 1.3, 4, Basis.IDENTITY, 0.25)
	return kit.build()


## Free hand: broad and open, ready to grab.
func _open_hand_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, -0.05, 0.0), Vector3(0.3, 0.26, 0.14))
	for x: float in [-0.11, -0.037, 0.037, 0.11]:
		kit.add_box(Vector3(x, 0.15, 0.0), Vector3(0.06, 0.24, 0.06))
	return kit.build()


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"cloak": ^"Flinch/Hips/Cloak", &"foot_l": ^"Flinch/Hips/FootL", &"foot_r": ^"Flinch/Hips/FootR"},
		{&"hips": HIPS_REST, &"foot_l": FOOT_L_REST, &"foot_r": FOOT_R_REST},
		[&"hips"],
		[&"Sparks"])
	var library := AnimationLibrary.new()
	var rest := {"torso": Vector3(-3, 0, 0), "head": Vector3(4, 0, 0)}
	var sway := {"hips:p": Vector3(0, -0.02, 0), "torso": Vector3(-5, 3, 0), "head": Vector3(6, -4, 0), "cloak": Vector3(4, 0, 2)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, rest], [0.5, sway], [1.0, rest]], true, OVERLAP))
	library.add_animation(CLIP_WALK, kit.make_clip(EnemyClipKit.gait_keys({
		"stride": 0.45, "lift": 0.1, "bob": 0.03, "sway": 0.03, "hip_twist": 5.0, "torso_twist": 6.0,
		"pitch": -4.0, "dip": 2.0, "head_pitch": 4.0}, [
			{"cloak": Vector3(8, 0, 0)}, {"cloak": Vector3(0, 0, 3)}, {"cloak": Vector3(8, 0, 0)}, {"cloak": Vector3(0, 0, -3)}]), true, OVERLAP))
	# The three slashes and the extra one of phase 2: each pair of clips is a windup and a strike.
	_add_slash(library, kit, &"slash_a", rest, 38.0, 8.0, -42.0, -12.0)
	_add_slash(library, kit, &"slash_b", rest, -34.0, 8.0, 40.0, -12.0)
	_add_slash(library, kit, &"slash_c", rest, 0.0, 28.0, 0.0, -38.0)
	_add_slash(library, kit, &"slash_d", rest, -55.0, 4.0, 65.0, -6.0)
	# Shockwave: the blade goes up and is driven into the floor, with sparks.
	var raised := {
		"hips:p": Vector3(0, 0.08, 0.1), "torso": Vector3(30, 0, 0), "head": Vector3(-14, 0, 0), "cloak": Vector3(-10, 0, 0)}
	var driven := {
		"hips:p": Vector3(0, -0.22, -0.3), "torso": Vector3(-42, 0, 0), "head": Vector3(18, 0, 0), "cloak": Vector3(25, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.2), "foot_r:p": Vector3(0, 0, 0.2), "emit:Sparks": true}
	library.add_animation(&"shockwave_windup", kit.make_clip([[0.0, rest], [0.5, raised], [1.0, raised]], false, OVERLAP))
	library.add_animation(&"shockwave_strike", kit.make_clip([[0.0, raised], [0.35, driven], [1.0, driven]], false, OVERLAP))
	# Grab: it reaches forward with the free hand, then lunges.
	var reach := {
		"hips:p": Vector3(0, -0.06, -0.1), "torso": Vector3(-14, -10, 0), "head": Vector3(6, 0, 0), "cloak": Vector3(6, 0, 0)}
	var lunge := {
		"hips:p": Vector3(0, -0.2, -0.55), "hips": Vector3(-10, 0, 0), "torso": Vector3(-48, -6, 0), "head": Vector3(20, 0, 0),
		"foot_l:p": Vector3(0, 0.1, 0.5), "foot_r:p": Vector3(0, 0, 0.35), "cloak": Vector3(30, 0, 0)}
	library.add_animation(&"grab_windup", kit.make_clip([[0.0, rest], [0.6, reach], [1.0, reach]], false, OVERLAP))
	library.add_animation(&"grab_strike", kit.make_clip([[0.0, reach], [0.3, lunge], [1.0, lunge]], false, OVERLAP))
	library.add_animation(CLIP_WINDUP, library.get_animation(&"slash_a_windup"))
	library.add_animation(CLIP_STRIKE, library.get_animation(&"slash_a_strike"))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, lunge], [1.0, rest]], false, OVERLAP))
	# Transition: the hood tears, it hunches and roars, shaking.
	var roar := {
		"hips:p": Vector3(0, -0.18, 0.05), "torso": Vector3(28, 0, 0), "head": Vector3(-30, 0, 0), "cloak": Vector3(-12, 0, 0)}
	var shudder := roar.duplicate()
	shudder["torso"] = Vector3(24, 4, 2)
	var shudder_other := roar.duplicate()
	shudder_other["torso"] = Vector3(24, -4, -2)
	library.add_animation(&"transition", kit.make_clip([
		[0.0, rest], [0.3, roar], [0.45, shudder], [0.6, shudder_other], [0.75, shudder], [1.0, roar]], false, OVERLAP))
	return library


## `<name>_windup` (the blade goes back to `twist_back`° of yaw and `lean_back`° of pitch) and
## `<name>_strike` (it comes through to `twist_through` and `lean_through`), holding the last pose.
func _add_slash(library: AnimationLibrary, kit: EnemyClipKit, slash: StringName, rest: Dictionary,
		twist_back: float, lean_back: float, twist_through: float, lean_through: float) -> void:
	var coil := {
		"hips:p": Vector3(0, -0.03, 0.05), "torso": Vector3(-6, -twist_back * 0.15, 0), "head": Vector3(6, 0, 0)}
	var back := {
		"hips:p": Vector3(0, -0.04, 0.1), "hips": Vector3(0, twist_back * 0.3, 0), "torso": Vector3(lean_back, twist_back, 0),
		"head": Vector3(-6, -twist_back * 0.3, 0), "cloak": Vector3(-8, 0, 0)}
	var through := {
		"hips:p": Vector3(0, -0.08, -0.3), "hips": Vector3(0, twist_through * 0.3, 0), "torso": Vector3(lean_through, twist_through, 0),
		"head": Vector3(8, -twist_through * 0.3, 0), "cloak": Vector3(20, 0, 0), "foot_l:p": Vector3(0, 0, -0.15), "foot_r:p": Vector3(0, 0, 0.1)}
	var settled := through.duplicate()
	settled["torso"] = Vector3(lean_through * 0.85, twist_through * 0.92, 0)
	library.add_animation(StringName("%s_windup" % slash), kit.make_clip([[0.0, rest], [0.15, coil], [0.5, back], [1.0, back]], false, OVERLAP))
	library.add_animation(StringName("%s_strike" % slash), kit.make_clip([[0.0, back], [0.3, through], [1.0, settled]], false, OVERLAP))
