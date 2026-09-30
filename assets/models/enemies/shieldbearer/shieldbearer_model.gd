class_name ShieldbearerModel
extends EnemyModel
## The Escudero of La Plaga: wide and tall, a steel-blue carapace held in front of
## its chest like a shield. Its soft pink interior shows only when the guard
## drops (`guard_down`: the carapace opens to the side and the interior lights up,
## the moment its damage is full). See docs/specs/enemy-models.md.
##
## Joints (lower-case in the poses): hips → torso → head, shell ; hips → foot_l, foot_r.
## The interior is a glow part on the torso, behind the shell.

const BODY_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/shieldbearer_body_material.tres")
const ACCENT_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/shieldbearer_accent_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/shieldbearer_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.8, 0.0)
const TORSO_REST := Vector3(0.0, 0.05, 0.0)
const HEAD_REST := Vector3(0.0, 0.98, -0.05)
const SHELL_REST := Vector3(0.0, 0.45, -0.42)
const INTERIOR_AT := Vector3(0.0, 0.45, -0.34)
const FOOT_L_REST := Vector3(-0.26, -0.8, 0.0)
const FOOT_R_REST := Vector3(0.26, -0.8, 0.0)
const OVERLAP: Dictionary = {&"torso": 0.06, &"head": 0.1, &"shell": 0.03}


func _type_id() -> StringName:
	return &"shieldbearer"


## The interior is lit by the open guard, not by the windup.
func _alerts_on_windup() -> bool:
	return false


func _alert_for_pose(pose: StringName) -> bool:
	return pose == &"guard_down"


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = BODY_MATERIAL
	shared.materials[&"accent"] = ACCENT_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	shared.materials[MATERIAL_GLOW_OFF] = ACCENT_MATERIAL
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _head_mesh()
	shared.meshes[&"shell"] = _shell_mesh()
	shared.meshes[&"interior"] = _interior_mesh()
	shared.meshes[&"foot"] = _foot_mesh()
	shared.hand_right = _gauntlet_mesh()
	shared.hand_left = shared.hand_right
	shared.motion = _motion_library()
	shared.overlay = _standard_overlay(0.6)


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], BODY_MATERIAL, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	_joints[JOINT_HEAD] = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], BODY_MATERIAL, HEAD_REST)
	_joints[&"Shell"] = _add_part(torso, &"Shell", shared.meshes[&"shell"], BODY_MATERIAL, SHELL_REST)
	_joints[&"Interior"] = _add_glow_part(torso, &"Interior", shared.meshes[&"interior"], INTERIOR_AT)
	_joints[&"FootL"] = _add_part(hips, &"FootL", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_L_REST)
	_joints[&"FootR"] = _add_part(hips, &"FootR", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_R_REST)


# --- Meshes ------------------------------------------------------------------

func _torso_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.3, 0.24],
		[0.25, 0.4, 0.3],
		[0.6, 0.46, 0.32],
		[0.82, 0.4, 0.26],
		[0.9, 0.22, 0.18],
	])
	return kit.build()


## Helmet with a ridge along the top.
func _head_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[-0.12, 0.14, 0.13],
		[0.02, 0.19, 0.18],
		[0.18, 0.17, 0.16],
		[0.26, 0.08, 0.08],
	])
	kit.add_wedge(Vector3(0.0, 0.25, 0.02), Vector3(0.06, 0.14, 0.3))
	return kit.build()


## The carapace: a broad plate with a raised boss and a crest on top.
func _shell_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3.ZERO, Vector3(0.95, 0.85, 0.14))
	kit.add_box(Vector3(0.0, 0.0, -0.09), Vector3(0.55, 0.45, 0.06))
	kit.add_wedge(Vector3(0.0, 0.47, -0.02), Vector3(0.5, 0.1, 0.14))
	return kit.build()


## Soft interior of the chest, hidden behind the shell.
func _interior_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3.ZERO, Vector3(0.6, 0.6, 0.04))
	return kit.build()


func _foot_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.07, 0.03), Vector3(0.24, 0.14, 0.3))
	kit.add_wedge(Vector3(0.0, 0.07, -0.23), Vector3(0.22, 0.14, 0.16))
	return kit.build()


func _gauntlet_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3.ZERO, Vector3(0.3, 0.3, 0.34))
	kit.add_box(Vector3(0.0, 0.0, -0.18), Vector3(0.34, 0.24, 0.06))
	return kit.build()


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"shell": ^"Flinch/Hips/Torso/Shell", &"foot_l": ^"Flinch/Hips/FootL", &"foot_r": ^"Flinch/Hips/FootR"},
		{&"hips": HIPS_REST, &"shell": SHELL_REST, &"foot_l": FOOT_L_REST, &"foot_r": FOOT_R_REST},
		[&"hips"])
	var library := AnimationLibrary.new()
	var guard := {"torso": Vector3(-4, 0, 0), "head": Vector3(3, 0, 0)}
	var breathe := {"hips:p": Vector3(0, -0.015, 0), "torso": Vector3(-5, 1, 0), "head": Vector3(4, -2, 0)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, guard], [0.5, breathe], [1.0, guard]], true, OVERLAP))
	library.add_animation(CLIP_WALK, kit.make_clip(EnemyClipKit.gait_keys({
		"stride": 0.35, "lift": 0.1, "bob": 0.03, "sway": 0.03, "hip_twist": 4.0, "torso_twist": 3.0,
		"pitch": -4.0, "dip": 2.0, "head_pitch": 3.0}), true, OVERLAP))
	# Windup: the carapace is pulled back and down, the trunk leans away.
	var pulled := {
		"hips:p": Vector3(0, -0.04, 0.1), "torso": Vector3(10, 0, 0), "head": Vector3(-5, 0, 0),
		"shell:p": Vector3(0, -0.1, 0.25), "shell": Vector3(12, 0, 0)}
	var pulled_held := pulled.duplicate()
	pulled_held["torso"] = Vector3(13, 0, 0)
	library.add_animation(CLIP_WINDUP, kit.make_clip([[0.0, guard], [0.15, {"torso": Vector3(-8, 0, 0), "shell:p": Vector3(0, 0, -0.05)}], [0.5, pulled], [1.0, pulled_held]], false, OVERLAP))
	# Strike: the carapace rams forward.
	var ram := {
		"hips:p": Vector3(0, -0.05, -0.3), "torso": Vector3(-16, 0, 0), "head": Vector3(8, 0, 0),
		"shell:p": Vector3(0, 0.05, -0.55), "shell": Vector3(-6, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.2), "foot_r:p": Vector3(0, 0, 0.12)}
	var ram_settled := ram.duplicate()
	ram_settled["torso"] = Vector3(-13, 0, 0)
	library.add_animation(CLIP_STRIKE, kit.make_clip([[0.0, pulled_held], [0.35, ram], [1.0, ram_settled]], false, OVERLAP))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, ram_settled], [1.0, guard]], false, OVERLAP))
	# Guard down: the carapace opens to the side and the trunk slumps.
	var open := {
		"hips:p": Vector3(0, -0.08, 0.05), "torso": Vector3(-18, 0, 0), "head": Vector3(-14, 0, 0),
		"shell:p": Vector3(-0.55, -0.05, -0.1), "shell": Vector3(0, -25, -55)}
	library.add_animation(&"guard_down", kit.make_clip([[0.0, guard], [0.5, open], [1.0, open]], false, OVERLAP))
	return library
