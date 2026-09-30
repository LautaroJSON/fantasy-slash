class_name ChargerModel
extends EnemyModel
## The Embestidor of La Plaga: a low wedge of a beast, head down, tusks forward and
## bone plates along the back. It scrapes the floor to warn (head down, a foot
## digging, dust), stretches out flat on the charge and, stunned by a wall, plants
## its head with its legs shaking and steaming (docs/specs/enemy-models.md).
##
## Joints (lower-case in the poses): hips → torso → head, plates ; hips → foot_l, foot_r.
## The eyes are a glow part on the head; the only emitter, Puff, is dust and steam.

const BODY_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/charger_body_material.tres")
const ACCENT_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/charger_accent_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/charger_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.75, 0.0)
const TORSO_REST := Vector3(0.0, 0.05, 0.0)
const HEAD_REST := Vector3(0.0, 0.6, -0.3)
const PLATES_REST := Vector3(0.0, 0.1, 0.0)
const EYES_AT := Vector3(0.0, 0.06, -0.2)
const FOOT_L_REST := Vector3(-0.25, -0.75, -0.1)
const FOOT_R_REST := Vector3(0.25, -0.75, -0.1)
const PUFF_AT := Vector3(0.0, 0.25, -0.5)
const OVERLAP: Dictionary = {&"torso": 0.05, &"head": 0.08, &"plates": 0.12}

@export var puff: EnemyParticlesConfig


func _type_id() -> StringName:
	return &"charger"


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = BODY_MATERIAL
	shared.materials[&"accent"] = ACCENT_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	shared.materials[MATERIAL_GLOW_OFF] = BODY_MATERIAL
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _head_mesh()
	shared.meshes[&"plates"] = _plates_mesh()
	shared.meshes[&"eyes"] = _eyes_mesh()
	shared.meshes[&"foot"] = _foot_mesh()
	var dust := BoxMesh.new()
	dust.size = Vector3.ONE
	dust.material = ACCENT_MATERIAL
	shared.meshes[&"puff"] = dust
	shared.hand_right = _claw_mesh()
	shared.hand_left = shared.hand_right
	shared.motion = _motion_library()
	shared.overlay = _standard_overlay(1.0)


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], BODY_MATERIAL, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	var head: MeshInstance3D = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], BODY_MATERIAL, HEAD_REST)
	_joints[JOINT_HEAD] = head
	_joints[&"Eyes"] = _add_glow_part(head, &"Eyes", shared.meshes[&"eyes"], EYES_AT)
	_joints[&"Plates"] = _add_part(torso, &"Plates", shared.meshes[&"plates"], ACCENT_MATERIAL, PLATES_REST)
	_joints[&"FootL"] = _add_part(hips, &"FootL", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_L_REST)
	_joints[&"FootR"] = _add_part(hips, &"FootR", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_R_REST)
	_add_fx_root()
	if puff != null:
		_add_emitter(&"Puff", puff, shared.meshes[&"puff"], PUFF_AT)


# --- Meshes ------------------------------------------------------------------

## A wedge: the trunk climbs to a hump and leans far forward (−Z).
func _torso_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.3, 0.28, 0.0, 0.0],
		[0.25, 0.42, 0.36, 0.0, -0.1],
		[0.5, 0.44, 0.34, 0.0, -0.25],
		[0.62, 0.3, 0.24, 0.0, -0.22],
	])
	return kit.build()


## Blunt snout and two tusks pointing forward and up.
func _head_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[-0.2, 0.08, 0.14],
		[0.0, 0.2, 0.2],
		[0.18, 0.16, 0.14],
		[0.26, 0.08, 0.08],
	])
	var forward := Basis(Vector3.RIGHT, deg_to_rad(-70.0))
	kit.add_cone(Vector3(-0.12, -0.1, -0.16), 0.04, 0.22, 4, forward)
	kit.add_cone(Vector3(0.12, -0.1, -0.16), 0.04, 0.22, 4, forward)
	return kit.build()


## Bone spines along the back, leaning away from the spine.
func _plates_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	var back := Basis(Vector3.RIGHT, deg_to_rad(20.0))
	kit.add_cone(Vector3(0.0, 0.5, 0.05), 0.11, 0.5, 4, back)
	kit.add_cone(Vector3(0.0, 0.3, 0.16), 0.1, 0.42, 4, back)
	kit.add_cone(Vector3(0.0, 0.08, 0.24), 0.09, 0.34, 4, back)
	return kit.build()


func _eyes_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3.ZERO, Vector3(0.28, 0.05, 0.04))
	return kit.build()


func _foot_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.06, 0.03), Vector3(0.2, 0.12, 0.26))
	kit.add_wedge(Vector3(0.0, 0.06, -0.2), Vector3(0.18, 0.12, 0.14))
	return kit.build()


## Forelimb stub: a block with three claws in front.
func _claw_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3.ZERO, Vector3(0.26, 0.22, 0.26))
	var forward := Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	for x: float in [-0.08, 0.0, 0.08]:
		kit.add_cone(Vector3(x, 0.0, -0.12), 0.03, 0.14, 4, forward)
	return kit.build()


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"plates": ^"Flinch/Hips/Torso/Plates", &"foot_l": ^"Flinch/Hips/FootL", &"foot_r": ^"Flinch/Hips/FootR"},
		{&"hips": HIPS_REST, &"foot_l": FOOT_L_REST, &"foot_r": FOOT_R_REST},
		[&"hips"],
		[&"Puff"])
	var library := AnimationLibrary.new()
	var rest := {"torso": Vector3(-8, 0, 0), "head": Vector3(16, 0, 0)}
	var snort := {"hips:p": Vector3(0, -0.015, 0), "torso": Vector3(-14, 1, 0), "head": Vector3(24, -2, 0), "plates": Vector3(3, 0, 0)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, rest], [0.5, snort], [1.0, rest]], true, OVERLAP))
	library.add_animation(CLIP_WALK, kit.make_clip(EnemyClipKit.gait_keys({
		"stride": 0.4, "lift": 0.12, "bob": 0.04, "sway": 0.05, "hip_twist": 6.0, "torso_twist": 5.0,
		"pitch": -14.0, "dip": 5.0, "head_pitch": 18.0}), true, OVERLAP))
	# Windup: head down, the trunk lowered, a foot scraping the floor with dust.
	var lowered := {
		"hips:p": Vector3(0, -0.15, -0.1), "torso": Vector3(-32, 0, 0), "head": Vector3(50, 0, 0), "plates": Vector3(8, 0, 0)}
	var scrape_up := lowered.duplicate()
	scrape_up.merge({"foot_l:p": Vector3(0, 0.14, -0.15), "emit:Puff": true}, true)
	var scrape_back := lowered.duplicate()
	scrape_back.merge({"foot_l:p": Vector3(0, 0.0, 0.3), "emit:Puff": true}, true)
	library.add_animation(CLIP_WINDUP, kit.make_clip([
		[0.0, rest], [0.2, scrape_up], [0.4, scrape_back], [0.6, scrape_up], [0.8, scrape_back], [1.0, scrape_back]], false, OVERLAP))
	# Strike: the whole body stretches out flat for the charge.
	var stretched := {
		"hips:p": Vector3(0, -0.2, -0.45), "hips": Vector3(-25, 0, 0), "torso": Vector3(-40, 0, 0), "head": Vector3(10, 0, 0),
		"plates": Vector3(-6, 0, 0), "foot_l:p": Vector3(0, 0.2, 0.6), "foot_r:p": Vector3(0, 0.05, 0.5), "emit:Puff": true}
	library.add_animation(CLIP_STRIKE, kit.make_clip([[0.0, scrape_back], [0.35, stretched], [1.0, stretched]], false, OVERLAP))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, stretched], [1.0, rest]], false, OVERLAP))
	# Stunned: the head planted in the wall, the legs shaking, steam.
	var planted := {
		"hips:p": Vector3(0, -0.3, -0.3), "torso": Vector3(-55, 0, 0), "head": Vector3(75, 0, 0),
		"plates": Vector3(-10, 0, 0), "emit:Puff": true}
	var shake_left := planted.duplicate()
	shake_left.merge({"foot_l:p": Vector3(0.04, 0, 0), "foot_r:p": Vector3(0.04, 0, 0)}, true)
	var shake_right := planted.duplicate()
	shake_right.merge({"foot_l:p": Vector3(-0.04, 0, 0), "foot_r:p": Vector3(-0.04, 0, 0)}, true)
	library.add_animation(&"stunned", kit.make_clip([
		[0.0, stretched], [0.2, shake_left], [0.4, shake_right], [0.6, shake_left], [0.8, shake_right], [1.0, planted]], false, OVERLAP))
	return library
