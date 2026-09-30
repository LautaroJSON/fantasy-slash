class_name LeaperModel
extends EnemyModel
## The Saltador of La Plaga: enormous hind legs, a small torso and a big-eyed
## head; crouched it looks like a spring. The whole body squashes on the windup
## (hips scale Y below 0.85), stretches in the air (above 1.1) and squashes
## again on the landing, with a splash of resin (docs/specs/enemy-models.md).
##
## Joints (lower-case in the poses): hips → torso → head, spots ; hips → thigh_l,
## thigh_r, foot_l, foot_r. The resin spots are the glow part; Splash is the emitter.

const BODY_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/leaper_body_material.tres")
const ACCENT_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/leaper_accent_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/leaper_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.95, 0.0)
const TORSO_REST := Vector3(0.0, 0.0, -0.05)
const HEAD_REST := Vector3(0.0, 0.6, -0.12)
const SPOTS_AT := Vector3(0.0, 0.3, 0.2)
const THIGH_L_REST := Vector3(-0.32, -0.05, 0.05)
const THIGH_R_REST := Vector3(0.32, -0.05, 0.05)
const FOOT_L_REST := Vector3(-0.32, -0.95, -0.1)
const FOOT_R_REST := Vector3(0.32, -0.95, -0.1)
const SPLASH_AT := Vector3(0.0, 0.1, -0.2)
## The squash and stretch poses move the hips so the feet stay on the floor (hips Y × scale Y).
const OVERLAP: Dictionary = {&"torso": 0.05, &"head": 0.09, &"spots": 0.12, &"thigh_l": 0.02, &"thigh_r": 0.02}

@export var splash: EnemyParticlesConfig


func _type_id() -> StringName:
	return &"leaper"


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = BODY_MATERIAL
	shared.materials[&"accent"] = ACCENT_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	shared.materials[MATERIAL_GLOW_OFF] = ACCENT_MATERIAL
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _head_mesh()
	shared.meshes[&"spots"] = _spots_mesh()
	shared.meshes[&"thigh"] = _thigh_mesh()
	shared.meshes[&"foot"] = _foot_mesh()
	var drop := BoxMesh.new()
	drop.size = Vector3.ONE
	drop.material = GLOW_MATERIAL
	shared.meshes[&"splash"] = drop
	shared.hand_right = _hand_mesh()
	shared.hand_left = shared.hand_right
	shared.motion = _motion_library()
	shared.overlay = _standard_overlay(1.2)


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], BODY_MATERIAL, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	_joints[JOINT_HEAD] = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], BODY_MATERIAL, HEAD_REST)
	_joints[&"Spots"] = _add_glow_part(torso, &"Spots", shared.meshes[&"spots"], SPOTS_AT)
	_joints[&"ThighL"] = _add_part(hips, &"ThighL", shared.meshes[&"thigh"], BODY_MATERIAL, THIGH_L_REST)
	_joints[&"ThighR"] = _add_part(hips, &"ThighR", shared.meshes[&"thigh"], BODY_MATERIAL, THIGH_R_REST)
	_joints[&"FootL"] = _add_part(hips, &"FootL", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_L_REST)
	_joints[&"FootR"] = _add_part(hips, &"FootR", shared.meshes[&"foot"], ACCENT_MATERIAL, FOOT_R_REST)
	_add_fx_root()
	if splash != null:
		_add_emitter(&"Splash", splash, shared.meshes[&"splash"], SPLASH_AT)


# --- Meshes ------------------------------------------------------------------

## Small, round trunk.
func _torso_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.2, 0.2],
		[0.25, 0.28, 0.24, 0.0, -0.05],
		[0.5, 0.2, 0.18, 0.0, -0.1],
	])
	return kit.build()


## Wide, flat head with two bulging eyes.
func _head_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[-0.1, 0.16, 0.16],
		[0.02, 0.24, 0.2],
		[0.14, 0.22, 0.17],
		[0.2, 0.12, 0.1],
	])
	kit.add_box(Vector3(-0.15, 0.2, -0.06), Vector3(0.1, 0.1, 0.1))
	kit.add_box(Vector3(0.15, 0.2, -0.06), Vector3(0.1, 0.1, 0.1))
	return kit.build()


## Resin spots on the back, three small cones.
func _spots_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	var back := Basis(Vector3.RIGHT, deg_to_rad(60.0))
	kit.add_cone(Vector3(0.0, 0.0, 0.0), 0.07, 0.14, 5, back)
	kit.add_cone(Vector3(-0.1, -0.12, 0.02), 0.05, 0.1, 5, back)
	kit.add_cone(Vector3(0.1, -0.12, 0.02), 0.05, 0.1, 5, back)
	return kit.build()


## Huge hind leg: a fat thigh tapering to the shin, hanging from the hips.
func _thigh_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.18, 0.2, 0.0, 0.0],
		[-0.2, 0.22, 0.26, 0.0, 0.04],
		[-0.45, 0.14, 0.16, 0.0, 0.0],
		[-0.75, 0.07, 0.08, 0.0, -0.06],
	])
	return kit.build()


## Long webbed foot, flat on the floor.
func _foot_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.04, -0.06), Vector3(0.2, 0.08, 0.4))
	kit.add_wedge(Vector3(0.0, 0.04, -0.34), Vector3(0.24, 0.08, 0.18))
	return kit.build()


func _hand_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_prism(Vector3(0.0, -0.11, 0.0), 0.14, 0.14, 0.22, 5)
	return kit.build()


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"spots": ^"Flinch/Hips/Torso/Spots", &"thigh_l": ^"Flinch/Hips/ThighL", &"thigh_r": ^"Flinch/Hips/ThighR",
			&"foot_l": ^"Flinch/Hips/FootL", &"foot_r": ^"Flinch/Hips/FootR"},
		{&"hips": HIPS_REST, &"foot_l": FOOT_L_REST, &"foot_r": FOOT_R_REST},
		[&"hips"],
		[&"Splash"])
	var library := AnimationLibrary.new()
	var rest := {"torso": Vector3(-8, 0, 0), "head": Vector3(4, 0, 0)}
	var breathe := {"hips:p": Vector3(0, -0.03, 0), "hips:s": Vector3(1.02, 0.97, 1.02), "torso": Vector3(-10, 0, 0), "head": Vector3(6, 2, 0), "spots": Vector3(4, 0, 0)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, rest], [0.5, breathe], [1.0, rest]], true, OVERLAP))
	var walk: Array = EnemyClipKit.gait_keys({
		"stride": 0.35, "lift": 0.14, "bob": 0.05, "sway": 0.03, "hip_twist": 3.0, "torso_twist": 3.0,
		"pitch": -8.0, "dip": 3.0, "head_pitch": 4.0}, [
			{"thigh_l": Vector3(-25, 0, 0), "thigh_r": Vector3(25, 0, 0)}, {},
			{"thigh_l": Vector3(25, 0, 0), "thigh_r": Vector3(-25, 0, 0)}, {}])
	library.add_animation(CLIP_WALK, kit.make_clip(walk, true, OVERLAP))
	# Windup: it compresses like a spring (hips scale Y 0.72) and vibrates.
	var squash := {
		"hips:p": Vector3(0, -0.27, 0), "hips:s": Vector3(1.12, 0.72, 1.12), "torso": Vector3(-30, 0, 0), "head": Vector3(20, 0, 0),
		"thigh_l": Vector3(60, 0, 0), "thigh_r": Vector3(60, 0, 0), "spots": Vector3(15, 0, 0)}
	var shake_left := squash.duplicate()
	shake_left["torso"] = Vector3(-30, 0, 4)
	var shake_right := squash.duplicate()
	shake_right["torso"] = Vector3(-30, 0, -4)
	library.add_animation(CLIP_WINDUP, kit.make_clip([
		[0.0, rest], [0.4, squash], [0.55, shake_left], [0.7, shake_right], [0.85, shake_left], [1.0, squash]], false, OVERLAP))
	# Airborne: stretched, the legs trailing behind.
	var stretch := {
		"hips:p": Vector3(0, 0.29, 0), "hips:s": Vector3(0.9, 1.2, 0.9), "torso": Vector3(-10, 0, 0), "head": Vector3(-5, 0, 0),
		"thigh_l": Vector3(-40, 0, 0), "thigh_r": Vector3(-40, 0, 0), "foot_l:p": Vector3(0, 0, 0.5), "foot_r:p": Vector3(0, 0, 0.5)}
	library.add_animation(&"airborne", kit.make_clip([[0.0, squash], [0.6, stretch], [1.0, stretch]], false, OVERLAP))
	# Strike: it lands squashed and splashes resin.
	var land := {
		"hips:p": Vector3(0, -0.24, 0), "hips:s": Vector3(1.2, 0.75, 1.2), "torso": Vector3(-20, 0, 0), "head": Vector3(12, 0, 0),
		"thigh_l": Vector3(70, 0, 0), "thigh_r": Vector3(70, 0, 0), "emit:Splash": true}
	library.add_animation(CLIP_STRIKE, kit.make_clip([[0.0, stretch], [0.3, land], [1.0, land]], false, OVERLAP))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, land], [1.0, rest]], false, OVERLAP))
	return library
