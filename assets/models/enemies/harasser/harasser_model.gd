class_name HarasserModel
extends EnemyModel
## The Hostigador of La Plaga: the tallest and thinnest of the common types, dark
## violet with bone spikes. Its right arm ends in a chitin blade (the floating hand
## with the blade mesh, turned forward by EnemyHandsConfig.hand_rotation). It
## orbits its target with side steps, jerks back before a lunge and stretches
## almost flat on it (docs/specs/enemy-models.md).
##
## Joints (lower-case in the poses): hips → torso → head, crest ; hips → foot_l, foot_r.
## The visor on the head is the glow part (it lights up during the windup).

const BODY_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/harasser_body_material.tres")
const ACCENT_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/harasser_accent_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/harasser_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.95, 0.0)
const TORSO_REST := Vector3(0.0, 0.05, 0.0)
const HEAD_REST := Vector3(0.0, 0.9, -0.02)
const CREST_REST := Vector3(0.0, 0.2, 0.14)
const VISOR_AT := Vector3(0.0, 0.05, -0.14)
const FOOT_L_REST := Vector3(-0.16, -0.95, 0.0)
const FOOT_R_REST := Vector3(0.16, -0.95, 0.0)
const OVERLAP: Dictionary = {&"torso": 0.05, &"head": 0.09, &"crest": 0.12}


func _type_id() -> StringName:
	return &"harasser"


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = BODY_MATERIAL
	shared.materials[&"accent"] = ACCENT_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	shared.materials[MATERIAL_GLOW_OFF] = ACCENT_MATERIAL
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _head_mesh()
	shared.meshes[&"crest"] = _crest_mesh()
	shared.meshes[&"visor"] = _visor_mesh()
	shared.meshes[&"foot"] = _foot_mesh()
	shared.hand_right = _blade_mesh()
	shared.hand_left = _claw_mesh()
	shared.motion = _motion_library()
	shared.overlay = _standard_overlay(1.4)


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], BODY_MATERIAL, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	var head: MeshInstance3D = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], BODY_MATERIAL, HEAD_REST)
	_joints[JOINT_HEAD] = head
	_joints[&"Visor"] = _add_glow_part(head, &"Visor", shared.meshes[&"visor"], VISOR_AT)
	_joints[&"Crest"] = _add_part(torso, &"Crest", shared.meshes[&"crest"], ACCENT_MATERIAL, CREST_REST)
	_joints[&"FootL"] = _add_part(hips, &"FootL", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_L_REST)
	_joints[&"FootR"] = _add_part(hips, &"FootR", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_R_REST)


# --- Meshes ------------------------------------------------------------------

## Long, narrow trunk with a small waist.
func _torso_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.16, 0.14],
		[0.3, 0.22, 0.16],
		[0.62, 0.3, 0.17, 0.0, -0.04],
		[0.75, 0.14, 0.12, 0.0, -0.06],
	])
	return kit.build()


## Narrow skull, elongated backwards.
func _head_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[-0.1, 0.09, 0.1],
		[0.02, 0.14, 0.15, 0.0, 0.03],
		[0.18, 0.12, 0.16, 0.0, 0.06],
		[0.28, 0.05, 0.08, 0.0, 0.08],
	])
	return kit.build()


## Bone spikes on the back.
func _crest_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	var back := Basis(Vector3.RIGHT, deg_to_rad(35.0))
	kit.add_cone(Vector3(0.0, 0.3, 0.0), 0.06, 0.34, 4, back)
	kit.add_cone(Vector3(0.0, 0.1, 0.03), 0.06, 0.28, 4, back)
	kit.add_cone(Vector3(0.0, -0.1, 0.05), 0.05, 0.22, 4, back)
	return kit.build()


func _visor_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3.ZERO, Vector3(0.2, 0.04, 0.04))
	return kit.build()


func _foot_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.05, 0.02), Vector3(0.14, 0.1, 0.24))
	kit.add_wedge(Vector3(0.0, 0.05, -0.17), Vector3(0.12, 0.1, 0.14))
	return kit.build()


## Chitin blade along +Y (hand_rotation turns it to point forward, −Z).
func _blade_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, -0.05, 0.0), Vector3(0.14, 0.12, 0.14))
	kit.add_prism(Vector3(0.0, 0.0, 0.0), 0.06, 0.014, 0.95, 4, Basis.IDENTITY, 0.15)
	return kit.build()


## Free hand: a small claw, also along +Y.
func _claw_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, -0.05, 0.0), Vector3(0.14, 0.12, 0.14))
	for x: float in [-0.04, 0.0, 0.04]:
		kit.add_cone(Vector3(x, 0.0, 0.0), 0.02, 0.2, 4)
	return kit.build()


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"crest": ^"Flinch/Hips/Torso/Crest", &"foot_l": ^"Flinch/Hips/FootL", &"foot_r": ^"Flinch/Hips/FootR"},
		{&"hips": HIPS_REST, &"foot_l": FOOT_L_REST, &"foot_r": FOOT_R_REST},
		[&"hips"])
	var library := AnimationLibrary.new()
	var rest := {"torso": Vector3(-6, 0, 0), "head": Vector3(4, 0, 0)}
	var twitch := {"hips:p": Vector3(0.02, -0.01, 0), "torso": Vector3(-8, 4, 1), "head": Vector3(6, -6, 0), "crest": Vector3(5, 0, 0)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, rest], [0.4, twitch], [0.6, rest], [1.0, rest]], true, OVERLAP))
	var gait := {
		"stride": 0.45, "lift": 0.12, "bob": 0.02, "sway": 0.02, "hip_twist": 5.0, "torso_twist": 4.0,
		"pitch": -6.0, "dip": 2.0, "head_pitch": 4.0}
	library.add_animation(CLIP_WALK, kit.make_clip(EnemyClipKit.gait_keys(gait), true, OVERLAP))
	var side := {
		"stride": 0.3, "lift": 0.1, "bob": 0.02, "sway": 0.03, "hip_twist": 0.0, "torso_twist": 2.0,
		"pitch": -8.0, "dip": 1.0, "head_pitch": 4.0}
	library.add_animation(STRAFE_RIGHT, kit.make_clip(EnemyClipKit.gait_keys(side, [{}, {}, {}, {}], Vector3.RIGHT), true, OVERLAP))
	library.add_animation(STRAFE_LEFT, kit.make_clip(EnemyClipKit.gait_keys(side, [{}, {}, {}, {}], Vector3.LEFT), true, OVERLAP))
	# Windup: a quick jerk backwards, coiled to lunge.
	var jerk := {
		"hips:p": Vector3(0, -0.03, 0.3), "torso": Vector3(18, 0, 0), "head": Vector3(-6, 0, 0), "crest": Vector3(-15, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.2), "foot_r:p": Vector3(0, 0, 0.25)}
	var jerk_held := jerk.duplicate()
	jerk_held["torso"] = Vector3(21, 0, 0)
	library.add_animation(CLIP_WINDUP, kit.make_clip([[0.0, rest], [0.5, jerk], [1.0, jerk_held]], false, OVERLAP))
	# Strike: the body goes almost flat along the lunge, the feet trailing.
	var lunge := {
		"hips:p": Vector3(0, -0.35, -0.7), "hips": Vector3(-15, 0, 0), "torso": Vector3(-75, 0, 0), "head": Vector3(30, 0, 0),
		"crest": Vector3(10, 0, 0), "foot_l:p": Vector3(0, 0.3, 0.7), "foot_r:p": Vector3(0, 0.2, 0.55)}
	library.add_animation(CLIP_STRIKE, kit.make_clip([[0.0, jerk_held], [0.3, lunge], [1.0, lunge]], false, OVERLAP))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, lunge], [1.0, rest]], false, OVERLAP))
	return library
