class_name ColmenaModel
extends EnemyModel
## La Colmena of La Plaga: an enormous abdomen of hexagonal cells behind a small
## torso and thin, raised arms; plum and mauve (the honey colour stays reserved
## for its shield aura). The cells open and light up lilac when it summons, it
## trembles outward on the pulse, and it shows the pulsing abdomen while exposed
## (docs/specs/enemy-models.md). The enemy is scaled to 2.6 by EnemyStats.body_scale.
##
## Joints (lower-case in the poses): hips → torso → head ; hips → abdomen → cells ;
## hips → foot_l, foot_r. The cells are the glow part; the shield aura is a sibling of the model.

const BODY_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/colmena_body_material.tres")
const ACCENT_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/colmena_accent_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/colmena_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.8, 0.0)
const TORSO_REST := Vector3(0.0, 0.05, -0.05)
const HEAD_REST := Vector3(0.0, 0.85, -0.02)
const ABDOMEN_REST := Vector3(0.0, 0.1, 0.28)
const CELLS_AT := Vector3(0.0, 0.1, 0.0)
const FOOT_L_REST := Vector3(-0.18, -0.8, 0.0)
const FOOT_R_REST := Vector3(0.18, -0.8, 0.0)
const OVERLAP: Dictionary = {&"torso": 0.05, &"head": 0.09, &"abdomen": 0.03, &"cells": 0.08}


func _type_id() -> StringName:
	return &"colmena"


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = BODY_MATERIAL
	shared.materials[&"accent"] = ACCENT_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	shared.materials[MATERIAL_GLOW_OFF] = ACCENT_MATERIAL
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _head_mesh()
	shared.meshes[&"abdomen"] = _abdomen_mesh()
	shared.meshes[&"cells"] = _cells_mesh()
	shared.meshes[&"foot"] = _foot_mesh()
	shared.hand_right = _hand_mesh()
	shared.hand_left = shared.hand_right
	shared.motion = _motion_library()
	shared.overlay = _standard_overlay(0.5)


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], BODY_MATERIAL, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	_joints[JOINT_HEAD] = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], BODY_MATERIAL, HEAD_REST)
	var abdomen: MeshInstance3D = _add_part(hips, &"Abdomen", shared.meshes[&"abdomen"], BODY_MATERIAL, ABDOMEN_REST)
	_joints[&"Abdomen"] = abdomen
	_joints[&"Cells"] = _add_glow_part(abdomen, &"Cells", shared.meshes[&"cells"], CELLS_AT)
	_joints[&"FootL"] = _add_part(hips, &"FootL", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_L_REST)
	_joints[&"FootR"] = _add_part(hips, &"FootR", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_R_REST)


# --- Meshes ------------------------------------------------------------------

func _torso_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.18, 0.16],
		[0.3, 0.26, 0.2],
		[0.6, 0.3, 0.2, 0.0, -0.03],
		[0.78, 0.14, 0.12, 0.0, -0.04],
	])
	return kit.build()


## Small head with two antennae.
func _head_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[-0.1, 0.1, 0.1],
		[0.02, 0.16, 0.15],
		[0.16, 0.12, 0.11],
		[0.24, 0.05, 0.06],
	])
	var forward := Basis(Vector3.RIGHT, deg_to_rad(-25.0))
	kit.add_cone(Vector3(-0.07, 0.18, -0.04), 0.02, 0.36, 4, forward)
	kit.add_cone(Vector3(0.07, 0.18, -0.04), 0.02, 0.36, 4, forward)
	return kit.build()


## The huge abdomen: an egg leaning back, about 1.1 wide.
func _abdomen_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[-0.5, 0.2, 0.2],
		[-0.25, 0.44, 0.44],
		[0.1, 0.55, 0.55],
		[0.5, 0.42, 0.42, 0.0, 0.05],
		[0.85, 0.16, 0.16, 0.0, 0.1],
	], 8)
	return kit.build()


## Hexagonal cells: flat plates set into the abdomen, each lighting up together.
func _cells_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	for row: int in 3:
		for column: int in 3:
			var x: float = (column - 1) * 0.26 + (0.13 if row == 1 else 0.0)
			var y: float = (row - 1) * 0.3
			var z: float = 0.5 - 0.04 * abs(x) * 4.0
			kit.add_prism(Vector3(x, y, z), 0.11, 0.11, 0.05, 6, Basis(Vector3.RIGHT, deg_to_rad(60.0)))
	return kit.build()


func _foot_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.05, 0.02), Vector3(0.14, 0.1, 0.22))
	return kit.build()


## Thin, claw-like hand held high.
func _hand_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_prism(Vector3(0.0, -0.1, 0.0), 0.1, 0.1, 0.2, 5)
	for x: float in [-0.05, 0.0, 0.05]:
		kit.add_cone(Vector3(x, 0.1, 0.0), 0.02, 0.16, 3)
	return kit.build()


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"abdomen": ^"Flinch/Hips/Abdomen", &"cells": ^"Flinch/Hips/Abdomen/Cells",
			&"foot_l": ^"Flinch/Hips/FootL", &"foot_r": ^"Flinch/Hips/FootR"},
		{&"hips": HIPS_REST, &"foot_l": FOOT_L_REST, &"foot_r": FOOT_R_REST},
		[&"hips", &"abdomen", &"cells"])
	var library := AnimationLibrary.new()
	var rest := {"torso": Vector3(0, 0, 0), "head": Vector3(2, 0, 0)}
	var throb := {
		"hips:p": Vector3(0, -0.02, 0), "abdomen:s": Vector3(1.03, 1.03, 1.03), "cells:s": Vector3(1.03, 1.03, 1.03),
		"torso": Vector3(1, 0, 0), "head": Vector3(3, 2, 0)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, rest], [0.5, throb], [1.0, rest]], true, OVERLAP))
	library.add_animation(CLIP_WALK, kit.make_clip(EnemyClipKit.gait_keys({
		"stride": 0.22, "lift": 0.08, "bob": 0.03, "sway": 0.02, "hip_twist": 2.0, "torso_twist": 2.0,
		"pitch": 0.0, "dip": 1.0, "head_pitch": 2.0}, [
			{"abdomen": Vector3(3, 0, 0)}, {"abdomen": Vector3(-3, 0, 0)}, {"abdomen": Vector3(3, 0, 0)}, {"abdomen": Vector3(-3, 0, 0)}]), true, OVERLAP))
	# Summon: the abdomen swells, the cells open outwards and light up, then burst.
	var swollen := {
		"hips:p": Vector3(0, 0.08, 0), "abdomen:s": Vector3(1.12, 1.12, 1.12), "cells:s": Vector3(1.2, 1.2, 1.2),
		"abdomen": Vector3(-8, 0, 0), "torso": Vector3(8, 0, 0), "head": Vector3(-10, 0, 0)}
	var burst := {
		"hips:p": Vector3(0, -0.04, 0), "abdomen:s": Vector3(1.22, 1.22, 1.22), "cells:s": Vector3(1.4, 1.4, 1.4),
		"abdomen": Vector3(-4, 0, 0), "torso": Vector3(-6, 0, 0), "head": Vector3(6, 0, 0)}
	library.add_animation(&"summon_windup", kit.make_clip([[0.0, rest], [0.6, swollen], [1.0, swollen]], false, OVERLAP))
	library.add_animation(&"summon_strike", kit.make_clip([[0.0, swollen], [0.35, burst], [1.0, burst]], false, OVERLAP))
	# Pulse: a tremble that gathers and goes outwards.
	var gather := {
		"abdomen:s": Vector3(0.9, 0.9, 0.9), "cells:s": Vector3(0.95, 0.95, 0.95), "torso": Vector3(-4, 0, 0), "head": Vector3(4, 0, 0)}
	var quiver := gather.duplicate()
	quiver["abdomen"] = Vector3(0, 0, 3)
	var quiver_other := gather.duplicate()
	quiver_other["abdomen"] = Vector3(0, 0, -3)
	var expel := {
		"abdomen:s": Vector3(1.3, 1.3, 1.3), "cells:s": Vector3(1.4, 1.4, 1.4), "torso": Vector3(8, 0, 0), "head": Vector3(-8, 0, 0)}
	library.add_animation(&"pulse_windup", kit.make_clip([[0.0, rest], [0.3, gather], [0.5, quiver], [0.7, quiver_other], [1.0, gather]], false, OVERLAP))
	library.add_animation(&"pulse_strike", kit.make_clip([[0.0, gather], [0.35, expel], [1.0, expel]], false, OVERLAP))
	library.add_animation(CLIP_WINDUP, library.get_animation(&"pulse_windup"))
	library.add_animation(CLIP_STRIKE, library.get_animation(&"pulse_strike"))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, burst], [1.0, rest]], false, OVERLAP))
	# Exposed: the abdomen pulses, open and vulnerable, and holds swollen.
	var open := {
		"hips:p": Vector3(0, -0.06, 0), "abdomen:s": Vector3(1.15, 1.15, 1.15), "cells:s": Vector3(1.25, 1.25, 1.25),
		"abdomen": Vector3(-10, 0, 0), "torso": Vector3(10, 0, 0), "head": Vector3(-12, 0, 0)}
	var beat := open.duplicate()
	beat["abdomen:s"] = Vector3(1.05, 1.05, 1.05)
	library.add_animation(&"exposed", kit.make_clip([[0.0, burst], [0.25, open], [0.45, beat], [0.65, open], [0.85, beat], [1.0, open]], false, OVERLAP))
	# Transition: it shakes hard while the cells open.
	var shake := open.duplicate()
	shake["abdomen"] = Vector3(-10, 0, 5)
	var shake_other := open.duplicate()
	shake_other["abdomen"] = Vector3(-10, 0, -5)
	library.add_animation(&"transition", kit.make_clip([
		[0.0, rest], [0.3, open], [0.45, shake], [0.6, shake_other], [0.75, shake], [1.0, open]], false, OVERLAP))
	return library
