class_name TitanModel
extends EnemyModel
## El Titán of La Plaga: a giant of cracked slate with dark chitin shoulders and
## enormous floating hands (the hands are separate nodes; this is the body that
## leans, twists and stomps around them). Its cracks glow acid lime while a hand
## rests on the floor (the weak point) and while it is stunned (docs/specs/enemy-models.md).
## The enemy is scaled to 3.5 by EnemyStats.body_scale.
##
## Joints (lower-case in the poses): hips → torso → head ; hips → foot_l, foot_r.
## The cracks are the glow part; Rubble is the emitter (dust and debris on impacts).

const BODY_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/titan_body_material.tres")
const ACCENT_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/titan_accent_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/titan_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.8, 0.0)
const TORSO_REST := Vector3(0.0, 0.05, 0.0)
const HEAD_REST := Vector3(0.0, 0.95, -0.1)
const SHOULDERS_AT := Vector3(0.0, 0.78, 0.0)
const CRACKS_AT := Vector3(0.0, 0.5, -0.34)
const FOOT_L_REST := Vector3(-0.3, -0.8, 0.0)
const FOOT_R_REST := Vector3(0.3, -0.8, 0.0)
const RUBBLE_AT := Vector3(0.0, 0.1, -0.7)
const OVERLAP: Dictionary = {&"torso": 0.07, &"head": 0.13}

@export var rubble: EnemyParticlesConfig


func _type_id() -> StringName:
	return &"titan"


## The cracks light up with a hand resting on the floor and while stunned.
func _alerts_on_windup() -> bool:
	return false


func _alert_for_pose(pose: StringName) -> bool:
	return pose == &"stunned"


func on_strike(clip: StringName, duration: float) -> void:
	super.on_strike(clip, duration)
	if clip == &"slam":
		set_alert(true)


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = BODY_MATERIAL
	shared.materials[&"accent"] = ACCENT_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	shared.materials[MATERIAL_GLOW_OFF] = ACCENT_MATERIAL
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _head_mesh()
	shared.meshes[&"shoulders"] = _shoulders_mesh()
	shared.meshes[&"cracks"] = _cracks_mesh()
	shared.meshes[&"foot"] = _foot_mesh()
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE
	chunk.material = BODY_MATERIAL
	shared.meshes[&"chunk"] = chunk
	shared.hand_right = _fist_mesh()
	shared.hand_left = shared.hand_right
	shared.motion = _motion_library()
	shared.overlay = _standard_overlay(0.3)


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], BODY_MATERIAL, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	_joints[JOINT_HEAD] = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], BODY_MATERIAL, HEAD_REST)
	_joints[&"Shoulders"] = _add_part(torso, &"Shoulders", shared.meshes[&"shoulders"], ACCENT_MATERIAL, SHOULDERS_AT)
	_joints[&"Cracks"] = _add_glow_part(torso, &"Cracks", shared.meshes[&"cracks"], CRACKS_AT)
	_joints[&"FootL"] = _add_part(hips, &"FootL", shared.meshes[&"foot"], BODY_MATERIAL, FOOT_L_REST)
	_joints[&"FootR"] = _add_part(hips, &"FootR", shared.meshes[&"foot"], BODY_MATERIAL, FOOT_R_REST)
	_add_fx_root()
	if rubble != null:
		_add_emitter(&"Rubble", rubble, shared.meshes[&"chunk"], RUBBLE_AT)


# --- Meshes ------------------------------------------------------------------

## A slab of a torso, broad at the shoulders and cut into steps.
func _torso_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.4, 0.32],
		[0.3, 0.5, 0.38],
		[0.62, 0.56, 0.4, 0.0, -0.03],
		[0.84, 0.5, 0.32, 0.0, -0.05],
		[0.92, 0.3, 0.22, 0.0, -0.05],
	], 6)
	kit.add_box(Vector3(0.0, 0.45, 0.32), Vector3(0.6, 0.5, 0.16))
	return kit.build()


## Small, square head sunk between the shoulders.
func _head_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.05, 0.0), Vector3(0.3, 0.3, 0.3))
	kit.add_box(Vector3(0.0, 0.16, -0.1), Vector3(0.34, 0.08, 0.14))
	return kit.build()


## Dark chitin plates over the shoulders, with spikes.
func _shoulders_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	for side: float in [-1.0, 1.0]:
		kit.add_box(Vector3(side * 0.5, 0.0, 0.0), Vector3(0.2, 0.16, 0.4))
		kit.add_cone(Vector3(side * 0.5, 0.08, 0.0), 0.08, 0.28, 4)
		kit.add_cone(Vector3(side * 0.5, 0.08, -0.14), 0.05, 0.18, 4)
	return kit.build()


## A jagged crack across the chest: three thin slabs at angles.
func _cracks_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.1, 0.0), Vector3(0.05, 0.4, 0.03), Basis(Vector3.BACK, deg_to_rad(15.0)))
	kit.add_box(Vector3(0.12, -0.05, 0.0), Vector3(0.22, 0.05, 0.03), Basis(Vector3.BACK, deg_to_rad(-25.0)))
	kit.add_box(Vector3(-0.12, 0.2, 0.0), Vector3(0.2, 0.05, 0.03), Basis(Vector3.BACK, deg_to_rad(30.0)))
	return kit.build()


func _foot_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3(0.0, 0.1, 0.03), Vector3(0.34, 0.2, 0.4))
	kit.add_wedge(Vector3(0.0, 0.1, -0.3), Vector3(0.3, 0.2, 0.2))
	return kit.build()


## An enormous hand of stone: a block with four knuckles.
func _fist_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3.ZERO, Vector3(0.34, 0.3, 0.34))
	for x: float in [-0.12, -0.04, 0.04, 0.12]:
		kit.add_box(Vector3(x, 0.02, -0.2), Vector3(0.07, 0.1, 0.1))
	return kit.build()


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"foot_l": ^"Flinch/Hips/FootL", &"foot_r": ^"Flinch/Hips/FootR"},
		{&"hips": HIPS_REST, &"foot_l": FOOT_L_REST, &"foot_r": FOOT_R_REST},
		[&"hips"],
		[&"Rubble"])
	var library := AnimationLibrary.new()
	var rest := {"torso": Vector3(-2, 0, 0), "head": Vector3(3, 0, 0)}
	var breathe := {"hips:p": Vector3(0, -0.02, 0), "torso": Vector3(-3, 1, 0), "head": Vector3(4, 0, 0)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, rest], [0.5, breathe], [1.0, rest]], true, OVERLAP))
	library.add_animation(CLIP_WALK, kit.make_clip(EnemyClipKit.gait_keys({
		"stride": 0.3, "lift": 0.08, "bob": 0.04, "sway": 0.04, "hip_twist": 3.0, "torso_twist": 3.0,
		"pitch": -2.0, "dip": 2.0, "head_pitch": 3.0}), true, OVERLAP))
	# Slam: it leans back with the hand raised, then throws its weight forward.
	var raise := {
		"hips:p": Vector3(0, 0.05, 0.1), "torso": Vector3(16, 0, 0), "head": Vector3(-8, 0, 0)}
	var crash := {
		"hips:p": Vector3(0, -0.15, -0.25), "torso": Vector3(-24, 0, 0), "head": Vector3(12, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.1), "emit:Rubble": true}
	library.add_animation(&"slam_windup", kit.make_clip([[0.0, rest], [0.5, raise], [1.0, raise]], false, OVERLAP))
	library.add_animation(&"slam_strike", kit.make_clip([[0.0, raise], [0.35, crash], [1.0, crash]], false, OVERLAP))
	# Sweep: the trunk winds up sideways and swings through low.
	var wind := {
		"hips:p": Vector3(0, -0.1, 0.05), "hips": Vector3(0, 25, 0), "torso": Vector3(-8, 45, 0), "head": Vector3(4, -20, 0)}
	var swing := {
		"hips:p": Vector3(0, -0.14, -0.1), "hips": Vector3(0, -25, 0), "torso": Vector3(-14, -50, 0), "head": Vector3(6, 20, 0), "emit:Rubble": true}
	library.add_animation(&"sweep_windup", kit.make_clip([[0.0, rest], [0.5, wind], [1.0, wind]], false, OVERLAP))
	library.add_animation(&"sweep_strike", kit.make_clip([[0.0, wind], [0.3, swing], [1.0, swing]], false, OVERLAP))
	# Stomp: a foot is lifted high, the trunk rises, then it comes down with its whole weight.
	var lifted := {
		"hips:p": Vector3(0, 0.2, 0), "torso": Vector3(10, 0, 4), "head": Vector3(-6, 0, 0), "foot_r:p": Vector3(0, 0.55, -0.1)}
	var stamped := {
		"hips:p": Vector3(0, -0.18, -0.1), "torso": Vector3(-12, 0, 0), "head": Vector3(8, 0, 0), "emit:Rubble": true}
	library.add_animation(&"stomp_windup", kit.make_clip([[0.0, rest], [0.6, lifted], [1.0, lifted]], false, OVERLAP))
	library.add_animation(&"stomp_strike", kit.make_clip([[0.0, lifted], [0.3, stamped], [1.0, stamped]], false, OVERLAP))
	library.add_animation(CLIP_WINDUP, library.get_animation(&"slam_windup"))
	library.add_animation(CLIP_STRIKE, library.get_animation(&"slam_strike"))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, crash], [1.0, rest]], false, OVERLAP))
	# Stunned: the body slumps forward, the cracks glow.
	var slumped := {
		"hips:p": Vector3(0, -0.3, -0.15), "torso": Vector3(-50, 0, 0), "head": Vector3(30, 0, 0), "foot_l:p": Vector3(0, 0, 0.1)}
	library.add_animation(&"stunned", kit.make_clip([[0.0, crash], [0.5, slumped], [1.0, slumped]], false, OVERLAP))
	# Transition: it rears back and shakes, the stone groaning.
	var rear := {
		"hips:p": Vector3(0, 0.06, 0.1), "torso": Vector3(20, 0, 0), "head": Vector3(-22, 0, 0)}
	var tremble := rear.duplicate()
	tremble["torso"] = Vector3(18, 3, 2)
	var tremble_other := rear.duplicate()
	tremble_other["torso"] = Vector3(18, -3, -2)
	library.add_animation(&"transition", kit.make_clip([
		[0.0, rest], [0.3, rear], [0.45, tremble], [0.6, tremble_other], [0.75, tremble], [1.0, rear]], false, OVERLAP))
	return library
