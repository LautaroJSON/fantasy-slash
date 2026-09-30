class_name BrutoModel
extends EnemyModel
## The Bruto (grunt) of La Plaga: a hunched soldier fused with moss-green
## chitin, wide shoulders, a resin bud on its back that lights up while it winds
## up, and floating boots (docs/specs/enemy-models.md). Meshes, materials and
## clips are built once and shared by every Bruto.
##
## Joints (all animated by the clips, names lower-case in the poses):
##   hips → torso → head, sprout ; hips → foot_l, foot_r
## Axes: rotation X > 0 tilts the top backwards (+Z); −Z is the front.

const BODY_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/bruto_body_material.tres")
const ACCENT_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/bruto_accent_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/bruto_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.75, 0.0)
const TORSO_REST := Vector3(0.0, 0.05, 0.0)
const HEAD_REST := Vector3(0.0, 0.82, -0.22)
const SPROUT_REST := Vector3(0.0, 0.5, 0.26)
const FOOT_L_REST := Vector3(-0.22, -0.75, 0.0)
const FOOT_R_REST := Vector3(0.22, -0.75, 0.0)
const SPORES_AT := Vector3(0.0, 0.12, 0.0)

## Delays (seconds of the nominal clip) of each joint behind the hips.
const OVERLAP: Dictionary = {&"torso": 0.05, &"head": 0.09, &"sprout": 0.14}

@export var spores: EnemyParticlesConfig


func _type_id() -> StringName:
	return &"bruto"


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = BODY_MATERIAL
	shared.materials[&"accent"] = ACCENT_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	# The bud rests as leather and lights up as resin: three materials in all.
	shared.materials[MATERIAL_GLOW_OFF] = ACCENT_MATERIAL
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _head_mesh()
	shared.meshes[&"sprout"] = _sprout_mesh()
	shared.meshes[&"foot"] = _foot_mesh()
	var spore := BoxMesh.new()
	spore.size = Vector3.ONE
	spore.material = GLOW_MATERIAL
	shared.meshes[&"spore"] = spore
	shared.hand_right = _fist_mesh()
	shared.hand_left = shared.hand_right
	shared.motion = _motion_library()
	shared.overlay = _overlay_library()


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], BODY_MATERIAL, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	var head: MeshInstance3D = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], BODY_MATERIAL, HEAD_REST)
	_joints[JOINT_HEAD] = head
	var sprout: MeshInstance3D = _add_glow_part(torso, &"Sprout", shared.meshes[&"sprout"], SPROUT_REST)
	_joints[&"Sprout"] = sprout
	_joints[&"FootL"] = _add_part(hips, &"FootL", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_L_REST)
	_joints[&"FootR"] = _add_part(hips, &"FootR", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_R_REST)
	_add_fx_root()
	if spores != null:
		_add_emitter(&"Spores", spores, shared.meshes[&"spore"], SPORES_AT)


# --- Meshes ------------------------------------------------------------------

## Hunched trunk: wide shoulders, the chest leaning forward (−Z).
func _torso_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.26, 0.2, 0.0, 0.0],
		[0.22, 0.34, 0.26, 0.0, -0.02],
		[0.5, 0.52, 0.3, 0.0, -0.1],
		[0.72, 0.5, 0.28, 0.0, -0.16],
		[0.8, 0.3, 0.2, 0.0, -0.2],
	])
	return kit.build()


## Low brow, heavy jaw and two short tusks.
func _head_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[-0.14, 0.13, 0.12],
		[0.0, 0.19, 0.17],
		[0.16, 0.16, 0.15],
		[0.24, 0.08, 0.09],
	])
	kit.add_box(Vector3(0.0, -0.1, -0.1), Vector3(0.22, 0.1, 0.16))
	kit.add_box(Vector3(0.0, 0.08, -0.15), Vector3(0.3, 0.05, 0.06))
	kit.add_cone(Vector3(-0.08, -0.14, -0.17), 0.03, 0.12, 4)
	kit.add_cone(Vector3(0.08, -0.14, -0.17), 0.03, 0.12, 4)
	return kit.build()


## Resin bud on the back: three cones leaning away from the spine.
func _sprout_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_cone(Vector3.ZERO, 0.09, 0.34, 5, Basis(Vector3.RIGHT, deg_to_rad(35.0)))
	kit.add_cone(Vector3(-0.11, -0.04, 0.02), 0.06, 0.24, 5, Basis.from_euler(Vector3(deg_to_rad(30.0), 0.0, deg_to_rad(-25.0))))
	kit.add_cone(Vector3(0.11, -0.04, 0.02), 0.06, 0.24, 5, Basis.from_euler(Vector3(deg_to_rad(30.0), 0.0, deg_to_rad(25.0))))
	return kit.build()


## Boot: a block with a sloped toe cap (the sole is at y = 0).
func _foot_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.06, 0.03), Vector3(0.2, 0.12, 0.26))
	kit.add_wedge(Vector3(0.0, 0.06, -0.2), Vector3(0.18, 0.12, 0.14))
	return kit.build()


## Fist: a hexagonal block with a knuckle ridge (about the size of the hand radius).
func _fist_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_prism(Vector3(0.0, -0.13, 0.0), 0.17, 0.17, 0.26, 6)
	kit.add_box(Vector3(0.0, 0.06, -0.13), Vector3(0.28, 0.08, 0.08))
	return kit.build()


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"sprout": ^"Flinch/Hips/Torso/Sprout", &"foot_l": ^"Flinch/Hips/FootL", &"foot_r": ^"Flinch/Hips/FootR"},
		{&"hips": HIPS_REST, &"foot_l": FOOT_L_REST, &"foot_r": FOOT_R_REST},
		[&"hips"],
		[&"Spores"])
	var library := AnimationLibrary.new()
	var rest := {"torso": Vector3(-10, 0, 0), "head": Vector3(6, 0, 0)}
	var breathe := {"hips:p": Vector3(0, -0.02, 0), "torso": Vector3(-13, 2, 0), "head": Vector3(8, -3, 0), "sprout": Vector3(4, 0, 0)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, rest], [0.5, breathe], [1.0, rest]], true, OVERLAP))
	var walk_keys: Array = _walk_keys()
	for walk_key: Array in walk_keys:
		walk_key[1]["emit:Spores"] = true
	library.add_animation(CLIP_WALK, kit.make_clip(walk_keys, true, OVERLAP))
	# Windup: a small coil forward, then the trunk and the shoulders go back and hold.
	var coil := {"hips:p": Vector3(0, -0.03, -0.04), "torso": Vector3(-17, 0, 0), "head": Vector3(10, 0, 0), "sprout": Vector3(10, 0, 0)}
	var back := {
		"hips:p": Vector3(0, -0.08, 0.12), "torso": Vector3(24, 0, 0), "head": Vector3(-10, 0, 0), "sprout": Vector3(-25, 0, 0),
		"foot_l:p": Vector3(0, 0, 0.08), "foot_r:p": Vector3(0, 0, -0.08)}
	var back_held := back.duplicate()
	back_held["torso"] = Vector3(27, 0, 0)
	library.add_animation(CLIP_WINDUP, kit.make_clip([[0.0, rest], [0.12, coil], [0.45, back], [1.0, back_held]], false, OVERLAP))
	# Strike: slams forward in a few frames, holds and settles a little.
	var slam := {
		"hips:p": Vector3(0, -0.06, -0.35), "torso": Vector3(-24, 0, 0), "head": Vector3(10, 0, 0), "sprout": Vector3(18, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.2), "foot_r:p": Vector3(0, 0, 0.15)}
	var settled := slam.duplicate()
	settled["torso"] = Vector3(-21, 0, 0)
	library.add_animation(CLIP_STRIKE, kit.make_clip([[0.0, back_held], [0.35, slam], [1.0, settled]], false, OVERLAP))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, settled], [1.0, rest]], false, OVERLAP))
	return library


## Shambling gait: the feet alternate, the hips bob and sway, the trunk twists
## against the stride. Left foot forward at 0, right foot forward at 0.5.
func _walk_keys() -> Array:
	return [
		[0.0, {"hips:p": Vector3(0.0, -0.05, 0.0), "hips": Vector3(0, -8, 0), "torso": Vector3(-17, 12, 0), "head": Vector3(8, -6, 0), "sprout": Vector3(8, 0, 5),
			"foot_l:p": Vector3(0, 0, -0.5), "foot_r:p": Vector3(0, 0, 0.5)}],
		[0.25, {"hips:p": Vector3(0.05, 0.03, 0.0), "hips": Vector3(0, 0, 0), "torso": Vector3(-13, 0, 4), "head": Vector3(6, 0, 0), "sprout": Vector3(-4, 0, 0),
			"foot_l:p": Vector3(0, 0, 0.0), "foot_r:p": Vector3(0, 0.16, 0.0)}],
		[0.5, {"hips:p": Vector3(0.0, -0.05, 0.0), "hips": Vector3(0, 8, 0), "torso": Vector3(-17, -12, 0), "head": Vector3(8, 6, 0), "sprout": Vector3(8, 0, -5),
			"foot_l:p": Vector3(0, 0, 0.5), "foot_r:p": Vector3(0, 0, -0.5)}],
		[0.75, {"hips:p": Vector3(-0.05, 0.03, 0.0), "hips": Vector3(0, 0, 0), "torso": Vector3(-13, 0, -4), "head": Vector3(6, 0, 0), "sprout": Vector3(-4, 0, 0),
			"foot_l:p": Vector3(0, 0.16, 0.0), "foot_r:p": Vector3(0, 0, 0.0)}],
		[1.0, {"hips:p": Vector3(0.0, -0.05, 0.0), "hips": Vector3(0, -8, 0), "torso": Vector3(-17, 12, 0), "head": Vector3(8, -6, 0), "sprout": Vector3(8, 0, 5),
			"foot_l:p": Vector3(0, 0, -0.5), "foot_r:p": Vector3(0, 0, 0.5)}],
	]


## The hit reaction: a short squash and tilt of Flinch (0.3 s, never stretched).
func _overlay_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new({&"flinch": ^"Flinch"}, {}, [&"flinch"])
	var library := AnimationLibrary.new()
	var still := {}
	var squash := {"flinch": Vector3(-6, 0, 3), "flinch:s": Vector3(1.06, 0.92, 1.06)}
	var rebound := {"flinch": Vector3(3, 0, -2), "flinch:s": Vector3(0.98, 1.03, 0.98)}
	library.add_animation(CLIP_HIT, kit.make_clip([[0.0, still], [0.06, squash], [0.14, rebound], [0.3, still]], false, {}, 0.3))
	return library
