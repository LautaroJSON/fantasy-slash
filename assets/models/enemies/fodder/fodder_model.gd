class_name FodderModel
extends EnemyModel
## The Esbirro of La Plaga: a pale pink egg of a body on many little legs, dark
## spots that light up pink while it winds up one big, slow, exaggerated swat
## (docs/specs/enemy-models.md). It reads as a mass, not as an individual: up to 16
## live at once, so it has no continuous emitter and stays under 300 triangles.
## The enemy itself is scaled to 0.7 by EnemyStats.body_scale.
##
## Joints (lower-case in the poses): hips → torso → head, spots ; hips → legs.

const BODY_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/fodder_body_material.tres")
const ACCENT_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/fodder_accent_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/fodder_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.35, 0.0)
const TORSO_REST := Vector3(0.0, 0.0, 0.0)
const HEAD_REST := Vector3(0.0, 1.3, -0.05)
const SPOTS_AT := Vector3(0.0, 0.7, -0.4)
const LEGS_REST := Vector3(0.0, 0.0, 0.0)
const OVERLAP: Dictionary = {&"torso": 0.05, &"head": 0.1, &"spots": 0.08, &"legs": 0.02}


func _type_id() -> StringName:
	return &"fodder"


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = BODY_MATERIAL
	shared.materials[&"accent"] = ACCENT_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	shared.materials[MATERIAL_GLOW_OFF] = ACCENT_MATERIAL
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _head_mesh()
	shared.meshes[&"spots"] = _spots_mesh()
	shared.meshes[&"legs"] = _legs_mesh()
	shared.hand_right = _fist_mesh()
	shared.hand_left = shared.hand_right
	shared.motion = _motion_library()
	shared.overlay = _standard_overlay(1.5)


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], BODY_MATERIAL, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	_joints[JOINT_HEAD] = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], BODY_MATERIAL, HEAD_REST)
	_joints[&"Spots"] = _add_glow_part(torso, &"Spots", shared.meshes[&"spots"], SPOTS_AT)
	_joints[&"Legs"] = _add_part(hips, &"Legs", shared.meshes[&"legs"], ACCENT_MATERIAL, LEGS_REST)


# --- Meshes ------------------------------------------------------------------

## A tall egg.
func _torso_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.3, 0.3],
		[0.33, 0.5, 0.5],
		[0.77, 0.55, 0.55],
		[1.2, 0.4, 0.4],
		[1.5, 0.15, 0.15],
	])
	return kit.build()


func _head_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[-0.05, 0.12, 0.12],
		[0.06, 0.2, 0.2],
		[0.2, 0.12, 0.12],
	])
	return kit.build()


## Three dark spots on the front of the belly.
func _spots_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.0, 0.0), Vector3(0.16, 0.16, 0.06))
	kit.add_box(Vector3(-0.22, -0.2, 0.02), Vector3(0.12, 0.12, 0.06))
	kit.add_box(Vector3(0.22, -0.2, 0.02), Vector3(0.12, 0.12, 0.06))
	return kit.build()


## Eight short legs fanning out under the body.
func _legs_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	for index: int in 8:
		var angle: float = TAU * index / 8.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var lean := Basis(out.cross(Vector3.UP).normalized(), deg_to_rad(35.0))
		kit.add_cone(out * 0.2 + Vector3(0.0, 0.12, 0.0), 0.05, -0.4, 4, lean)
	return kit.build()


## A big round fist for the big swat.
func _fist_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_prism(Vector3(0.0, -0.14, 0.0), 0.18, 0.18, 0.28, 6)
	return kit.build()


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"spots": ^"Flinch/Hips/Torso/Spots", &"legs": ^"Flinch/Hips/Legs"},
		{&"hips": HIPS_REST},
		[&"hips"])
	var library := AnimationLibrary.new()
	var rest := {"torso": Vector3(0, 0, 0), "head": Vector3(0, 0, 0)}
	var wobble := {"hips:p": Vector3(0, -0.02, 0), "hips:s": Vector3(1.03, 0.97, 1.03), "torso": Vector3(2, 0, 3), "head": Vector3(-3, 4, 0), "legs": Vector3(0, 6, 0)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, rest], [0.5, wobble], [1.0, rest]], true, OVERLAP))
	# Stumbling walk: uneven hops, the body rolling from side to side.
	var step_a := {"hips:p": Vector3(0.03, 0.08, 0), "torso": Vector3(-6, 0, 9), "head": Vector3(4, 0, -6), "legs": Vector3(0, 25, 8), "spots": Vector3(5, 0, 0)}
	var landing := {"hips:p": Vector3(0, -0.05, 0), "hips:s": Vector3(1.06, 0.94, 1.06), "torso": Vector3(-4, 0, 0), "head": Vector3(2, 0, 0), "legs": Vector3(0, 45, 0)}
	var step_b := {"hips:p": Vector3(-0.03, 0.06, 0), "torso": Vector3(-5, 0, -10), "head": Vector3(3, 0, 8), "legs": Vector3(0, 70, -8), "spots": Vector3(-5, 0, 0)}
	library.add_animation(CLIP_WALK, kit.make_clip([
		[0.0, landing], [0.18, step_a], [0.4, landing], [0.62, step_b], [0.82, {"hips:p": Vector3(0, 0.02, 0), "legs": Vector3(0, 85, 0)}], [1.0, landing]], true, OVERLAP))
	# Windup: it swells and leans far back, slowly, so the swat is unmistakable.
	var swell := {
		"hips:p": Vector3(0, -0.05, 0.1), "hips:s": Vector3(1.12, 0.92, 1.12), "torso": Vector3(-6, 0, 0), "head": Vector3(6, 0, 0), "spots": Vector3(0, 0, 0)}
	var lean := {
		"hips:p": Vector3(0, 0.05, 0.25), "hips:s": Vector3(0.95, 1.1, 0.95), "torso": Vector3(28, 0, 0), "head": Vector3(-16, 0, 0), "legs": Vector3(-15, 0, 0)}
	var lean_held := lean.duplicate()
	lean_held["torso"] = Vector3(32, 0, 0)
	library.add_animation(CLIP_WINDUP, kit.make_clip([[0.0, rest], [0.25, swell], [0.7, lean], [1.0, lean_held]], false, OVERLAP))
	# Strike: it throws itself forward with the swat.
	var swat := {
		"hips:p": Vector3(0, -0.08, -0.4), "hips:s": Vector3(1.08, 0.9, 1.08), "torso": Vector3(-30, 0, 0), "head": Vector3(14, 0, 0), "legs": Vector3(20, 0, 0)}
	var swat_settled := swat.duplicate()
	swat_settled["torso"] = Vector3(-26, 0, 0)
	library.add_animation(CLIP_STRIKE, kit.make_clip([[0.0, lean_held], [0.35, swat], [1.0, swat_settled]], false, OVERLAP))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, swat_settled], [1.0, rest]], false, OVERLAP))
	return library
