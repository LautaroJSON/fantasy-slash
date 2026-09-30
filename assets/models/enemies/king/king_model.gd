class_name KingModel
extends EnemyModel
## The King: a noble knight in polished steel and gold, with a long wine cape, an ivory
## tabard and an enormous two-handed greatsword (docs/specs/boss-king.md and
## boss-king-rework.md). Armor and blade are polished metal (the `king_metal` shader,
## flat colors); cloth, leather and mail are matte. The greatsword is the right hand
## mesh, held point down and planted at rest (EnemyHandsConfig.hand_rotation); the left
## hand is a gauntlet that follows it on the pommel (off_hand_follows). Every move of
## its repertoire has its own clips (slash_a to slash_d, thrust, spin, oath, judgment,
## transition). In phase 2 the chest gem stays lit, golden motes rise around it and the
## blade glows.
##
## Joints (lower-case in the poses): hips → torso → head → plume, torso → cape → cape_tail ;
## hips → tabard, tassets, foot_l, foot_r. The chest gem is the glow part; Sparks is the
## emitter of the sword driven into the floor and Motes the one of phase 2.

const STEEL: ShaderMaterial = preload("res://materials/enemies/king_steel_material.tres")
const GOLD: ShaderMaterial = preload("res://materials/enemies/king_gold_material.tres")
const LEATHER: StandardMaterial3D = preload("res://materials/enemies/king_leather_material.tres")
const TABARD_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/king_tabard_material.tres")
const CAPE_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/king_cape_material.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/enemies/king_glow_material.tres")

const HIPS_REST := Vector3(0.0, 0.85, 0.0)
const TORSO_REST := Vector3(0.0, 0.05, 0.0)
const HEAD_REST := Vector3(0.0, 0.88, -0.03)
const PLUME_AT := Vector3(0.0, 0.34, 0.03)
const SHOULDERS_AT := Vector3(0.0, 0.76, 0.0)
const GEM_AT := Vector3(0.0, 0.48, -0.325)
const CAPE_AT := Vector3(0.0, 0.8, 0.24)
const CAPE_TAIL_AT := Vector3(0.0, -0.8, 0.14)
const FOOT_L_REST := Vector3(-0.26, -0.85, 0.0)
const FOOT_R_REST := Vector3(0.26, -0.85, 0.0)
const SPARKS_AT := Vector3(0.0, 0.1, -1.1)
const MOTES_AT := Vector3(0.0, 1.1, 0.0)
const OVERLAP: Dictionary = {
	&"torso": 0.05, &"head": 0.1, &"plume": 0.22, &"cape": 0.14, &"cape_tail": 0.3, &"tabard": 0.1, &"tassets": 0.06}
## Glow of the greatsword in phase 2 (the `glow` instance parameter of king_metal).
const BLADE_GLOW: float = 0.7

@export var sparks: EnemyParticlesConfig
@export var motes: EnemyParticlesConfig

var _phase: int = 1
var _hands: EnemyHands = null


func _type_id() -> StringName:
	return &"king"


func bind_hands(hands: EnemyHands) -> void:
	_hands = hands
	_apply_blade_glow()


## Phase 2 keeps the gem lit, the motes rising and the blade glowing; phase 1 puts all out.
func on_phase(phase: int) -> void:
	_phase = phase
	set_alert(false)
	if _emitters.size() > 1:
		_emitters[1].emitting = phase >= 2
	_apply_blade_glow()


## 0 in phase 1, BLADE_GLOW in phase 2.
func get_blade_glow() -> float:
	return BLADE_GLOW if _phase >= 2 else 0.0


func _apply_blade_glow() -> void:
	if _hands == null:
		return
	var hand: GeometryInstance3D = _hands.get_node_or_null("RightHand") as GeometryInstance3D
	if hand != null:
		hand.set_instance_shader_parameter(&"glow", get_blade_glow())


func set_alert(on: bool) -> void:
	super.set_alert(on or _phase >= 2)


## Only phase 2 lights the gem, not the windups.
func _alerts_on_windup() -> bool:
	return false


func _alert_for_pose(_pose: StringName) -> bool:
	return false


func is_alert() -> bool:
	return _phase >= 2 and super.is_alert()


## The hand meshes bring their own materials (steel, gold, leather).
func get_hand_material() -> Material:
	return null


func _build_shared(shared: Shared) -> void:
	shared.materials[MATERIAL_BODY] = STEEL
	shared.materials[&"gold"] = GOLD
	shared.materials[&"leather"] = LEATHER
	shared.materials[&"tabard"] = TABARD_MATERIAL
	shared.materials[&"cape"] = CAPE_MATERIAL
	shared.materials[MATERIAL_GLOW_ON] = GLOW_MATERIAL
	shared.materials[MATERIAL_GLOW_OFF] = GOLD
	shared.meshes[&"torso"] = _torso_mesh()
	shared.meshes[&"head"] = _helm_mesh()
	shared.meshes[&"plume"] = _plume_mesh()
	shared.meshes[&"shoulders"] = _pauldrons_mesh()
	shared.meshes[&"gem"] = _gem_mesh()
	shared.meshes[&"tabard"] = _tabard_mesh()
	shared.meshes[&"tassets"] = _tassets_mesh()
	shared.meshes[&"cape"] = _cape_mesh()
	shared.meshes[&"cape_tail"] = _cape_tail_mesh()
	shared.meshes[&"foot"] = _foot_mesh()
	var spark := BoxMesh.new()
	spark.size = Vector3.ONE
	spark.material = GOLD
	shared.meshes[&"spark"] = spark
	var mote := BoxMesh.new()
	mote.size = Vector3.ONE
	mote.material = GOLD
	shared.meshes[&"mote"] = mote
	shared.hand_right = _greatsword_mesh()
	shared.hand_left = _gauntlet_mesh()
	shared.motion = _motion_library()
	shared.overlay = _standard_overlay(0.4)


func _build_tree(shared: Shared) -> void:
	var flinch: Node3D = _add_joint(self, JOINT_FLINCH, Vector3.ZERO)
	var hips: Node3D = _add_joint(flinch, JOINT_HIPS, HIPS_REST)
	var torso: MeshInstance3D = _add_part(hips, JOINT_TORSO, shared.meshes[&"torso"], null, TORSO_REST)
	_joints[JOINT_TORSO] = torso
	var head: MeshInstance3D = _add_part(torso, JOINT_HEAD, shared.meshes[&"head"], null, HEAD_REST)
	_joints[JOINT_HEAD] = head
	_joints[&"Plume"] = _add_part(head, &"Plume", shared.meshes[&"plume"], CAPE_MATERIAL, PLUME_AT)
	_joints[&"Shoulders"] = _add_part(torso, &"Shoulders", shared.meshes[&"shoulders"], null, SHOULDERS_AT)
	_joints[&"Gem"] = _add_glow_part(torso, &"Gem", shared.meshes[&"gem"], GEM_AT)
	var cape: MeshInstance3D = _add_part(torso, &"Cape", shared.meshes[&"cape"], CAPE_MATERIAL, CAPE_AT)
	_joints[&"Cape"] = cape
	_joints[&"CapeTail"] = _add_part(cape, &"CapeTail", shared.meshes[&"cape_tail"], CAPE_MATERIAL, CAPE_TAIL_AT)
	_joints[&"Tabard"] = _add_part(hips, &"Tabard", shared.meshes[&"tabard"], null)
	_joints[&"Tassets"] = _add_part(hips, &"Tassets", shared.meshes[&"tassets"], null)
	_joints[&"FootL"] = _add_part(hips, &"FootL", shared.meshes[&"foot"], null, FOOT_L_REST)
	_joints[&"FootR"] = _add_part(hips, &"FootR", shared.meshes[&"foot"], null, FOOT_R_REST)
	_add_fx_root()
	if sparks != null:
		_add_emitter(&"Sparks", sparks, shared.meshes[&"spark"], SPARKS_AT)
	if motes != null:
		_add_emitter(&"Motes", motes, shared.meshes[&"mote"], MOTES_AT)


# --- Meshes ------------------------------------------------------------------

## One mesh with a surface per kit: `parts` is a list of [MeshKit, Material]. Each surface
## keeps its shared material, so a part with steel, gold and leather is one MeshInstance3D.
func _surfaces(parts: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for part: Array in parts:
		var built: ArrayMesh = (part[0] as MeshKit).build()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built.surface_get_arrays(0))
		mesh.surface_set_material(mesh.get_surface_count() - 1, part[1] as Material)
	return mesh


## Studs (small cones) whose bases are `points`, pointing along `toward`.
func _studs(kit: MeshKit, points: Array, toward: Vector3, radius: float = 0.018, height: float = 0.03) -> void:
	var orient := Basis(Quaternion(Vector3.UP, toward.normalized()))
	for point: Vector3 in points:
		kit.add_cone(point, radius, height, 5, orient)


## Cuirass with a central ridge, lames at the waist, a gorget, gold trim and a belt.
func _torso_mesh() -> ArrayMesh:
	var steel := MeshKit.new()
	steel.add_loft([
		[0.08, 0.3, 0.22],
		[0.22, 0.35, 0.26],
		[0.42, 0.43, 0.3, 0.0, -0.02],
		[0.6, 0.46, 0.3, 0.0, -0.03],
		[0.74, 0.41, 0.26, 0.0, -0.02],
		[0.84, 0.25, 0.18],
	], 14)
	for i: int in 4:
		steel.add_box(Vector3(0.0, -0.09 + 0.05 * i, -0.01), Vector3(0.66 - 0.02 * i, 0.055, 0.46 - 0.01 * i))
	steel.add_box(Vector3(0.0, 0.5, -0.325), Vector3(0.05, 0.52, 0.06))
	steel.add_box(Vector3(0.0, 0.48, 0.3), Vector3(0.52, 0.52, 0.06))
	steel.add_box(Vector3(0.0, 0.48, 0.33), Vector3(0.06, 0.5, 0.03))
	steel.add_loft([[0.8, 0.22, 0.19], [0.9, 0.19, 0.16], [0.98, 0.16, 0.14]], 12)
	var gold := MeshKit.new()
	gold.add_box(Vector3(0.0, 0.48, -0.325), Vector3(0.26, 0.26, 0.03), Basis(Vector3.BACK, PI / 4.0))
	gold.add_box(Vector3(0.0, -0.005, -0.235), Vector3(0.3, 0.09, 0.05))
	gold.add_loft([[0.79, 0.235, 0.205], [0.835, 0.235, 0.205]], 12)
	gold.add_box(Vector3(0.0, 0.7, -0.3), Vector3(0.5, 0.025, 0.04))
	_studs(gold, [Vector3(-0.3, 0.3, -0.29), Vector3(-0.2, 0.3, -0.3), Vector3(0.2, 0.3, -0.3), Vector3(0.3, 0.3, -0.29),
		Vector3(-0.32, 0.62, -0.27), Vector3(0.32, 0.62, -0.27)], Vector3.FORWARD)
	var leather := MeshKit.new()
	leather.add_box(Vector3(0.0, -0.02, 0.0), Vector3(0.7, 0.06, 0.5))
	for side: float in [-1.0, 1.0]:
		leather.add_box(Vector3(side * 0.2, 0.6, -0.3), Vector3(0.05, 0.3, 0.02))
	leather.add_loft([[0.0, 0.32, 0.24], [-0.14, 0.34, 0.26]], 12)
	return _surfaces([[steel, STEEL], [gold, GOLD], [leather, LEATHER]])


## A great helm with a central ridge and a slit, a gold crest and brow.
func _helm_mesh() -> ArrayMesh:
	var steel := MeshKit.new()
	steel.add_loft([
		[-0.16, 0.14, 0.15],
		[-0.06, 0.19, 0.21],
		[0.08, 0.215, 0.235],
		[0.22, 0.2, 0.22],
		[0.32, 0.15, 0.16],
		[0.4, 0.07, 0.08],
	], 14)
	steel.add_box(Vector3(0.0, 0.08, -0.235), Vector3(0.03, 0.32, 0.05))
	steel.add_box(Vector3(0.0, -0.09, -0.185), Vector3(0.22, 0.13, 0.1))
	var gold := MeshKit.new()
	gold.add_box(Vector3(0.0, 0.44, 0.02), Vector3(0.035, 0.14, 0.36))
	gold.add_box(Vector3(0.0, 0.14, -0.22), Vector3(0.36, 0.03, 0.06))
	_studs(gold, [Vector3(-0.19, 0.0, -0.17), Vector3(-0.21, 0.16, -0.06)], Vector3.LEFT)
	_studs(gold, [Vector3(0.19, 0.0, -0.17), Vector3(0.21, 0.16, -0.06)], Vector3.RIGHT)
	var leather := MeshKit.new()
	leather.add_box(Vector3(0.0, 0.06, -0.24), Vector3(0.3, 0.045, 0.03))
	leather.add_box(Vector3(0.0, -0.03, -0.235), Vector3(0.05, 0.09, 0.03))
	return _surfaces([[steel, STEEL], [gold, GOLD], [leather, LEATHER]])


## The plume of the helm: three tapered feathers trailing back.
func _plume_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_cone(Vector3.ZERO, 0.05, 0.3, 5, Basis(Vector3.RIGHT, 1.15))
	kit.add_cone(Vector3.ZERO, 0.045, 0.26, 5, Basis(Vector3.BACK, 0.25) * Basis(Vector3.RIGHT, 1.4))
	kit.add_cone(Vector3.ZERO, 0.045, 0.26, 5, Basis(Vector3.BACK, -0.25) * Basis(Vector3.RIGHT, 1.4))
	return kit.build()


## Layered pauldrons: a dome, three lames, a gold rim, a spike and studs.
func _pauldrons_mesh() -> ArrayMesh:
	var steel := MeshKit.new()
	var gold := MeshKit.new()
	for side: float in [-1.0, 1.0]:
		steel.add_prism(Vector3(side * 0.34, -0.06, 0.0), 0.17, 0.2, 0.17, 12, Basis.IDENTITY, 0.5)
		for i: int in 3:
			steel.add_box(Vector3(side * (0.37 + 0.02 * i), -0.11 - 0.05 * i, 0.0), Vector3(0.3 - 0.02 * i, 0.04, 0.4 - 0.02 * i),
				Basis(Vector3.BACK, side * (0.08 + 0.05 * i)))
		gold.add_prism(Vector3(side * 0.34, -0.075, 0.0), 0.18, 0.21, 0.025, 12)
		gold.add_cone(Vector3(side * 0.34, 0.11, 0.0), 0.04, 0.18, 5)
		gold.add_box(Vector3(side * 0.44, -0.26, 0.0), Vector3(0.24, 0.02, 0.34), Basis(Vector3.BACK, side * 0.26))
		_studs(gold, [Vector3(side * 0.34, 0.02, -0.19), Vector3(side * 0.34, 0.02, 0.19), Vector3(side * 0.5, 0.0, 0.0)],
			Vector3.UP, 0.02, 0.035)
	return _surfaces([[steel, STEEL], [gold, GOLD]])


## A diamond on the chest (it lights up in phase 2).
func _gem_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_box(Vector3.ZERO, Vector3(0.15, 0.15, 0.05), Basis(Vector3.BACK, PI / 4.0))
	return kit.build()


## Tabard: ivory cloth with gold trim and tassels along the hem.
func _tabard_mesh() -> ArrayMesh:
	var cloth := MeshKit.new()
	cloth.add_box(Vector3(0.0, -0.26, -0.2), Vector3(0.42, 0.52, 0.04))
	cloth.add_box(Vector3(0.0, -0.26, -0.228), Vector3(0.03, 0.5, 0.02))
	for side: float in [-1.0, 1.0]:
		cloth.add_box(Vector3(side * 0.27, -0.22, -0.05), Vector3(0.05, 0.44, 0.3))
	cloth.add_box(Vector3(0.0, -0.22, 0.2), Vector3(0.42, 0.44, 0.04))
	var gold := MeshKit.new()
	gold.add_box(Vector3(0.0, -0.51, -0.222), Vector3(0.44, 0.022, 0.02))
	for side: float in [-1.0, 1.0]:
		gold.add_box(Vector3(side * 0.205, -0.26, -0.222), Vector3(0.02, 0.5, 0.02))
	for x: float in [-0.18, -0.09, 0.0, 0.09, 0.18]:
		gold.add_box(Vector3(x, -0.525, -0.222), Vector3(0.05, 0.03, 0.03))
		gold.add_cone(Vector3(x, -0.54, -0.222), 0.026, -0.15, 5)
	return _surfaces([[cloth, TABARD_MATERIAL], [gold, GOLD]])


## Plates of the hips, in a fan at each side of the tabard.
func _tassets_mesh() -> ArrayMesh:
	var steel := MeshKit.new()
	var gold := MeshKit.new()
	for side: float in [-1.0, 1.0]:
		for k: int in 4:
			var center := Vector3(side * (0.3 + 0.045 * k), -0.13 - 0.008 * k, -0.06 - 0.07 * (3 - k) * 0.5 + 0.02 * k)
			var orient := Basis(Vector3.BACK, -side * (0.08 + 0.05 * k)) * Basis(Vector3.UP, side * (0.15 - 0.05 * k))
			steel.add_box(center, Vector3(0.05, 0.27, 0.2), orient)
			gold.add_box(center + orient * Vector3(0.0, -0.135, 0.0), Vector3(0.055, 0.02, 0.21), orient)
	return _surfaces([[steel, STEEL], [gold, GOLD]])


func _cape_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.36, 0.05],
		[-0.28, 0.42, 0.06, 0.0, 0.04],
		[-0.55, 0.46, 0.06, 0.0, 0.1],
		[-0.8, 0.47, 0.06, 0.0, 0.14],
	], 6)
	return kit.build()


func _cape_tail_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_loft([
		[0.0, 0.47, 0.06],
		[-0.25, 0.5, 0.06, 0.0, 0.05],
		[-0.5, 0.5, 0.06, 0.0, 0.12],
		[-0.72, 0.45, 0.05, 0.0, 0.2],
	], 6)
	return kit.build()


## Sabaton, greave and a gold knee cop.
func _foot_mesh() -> ArrayMesh:
	var steel := MeshKit.new()
	steel.add_box(Vector3(0.0, 0.07, 0.03), Vector3(0.26, 0.14, 0.34))
	steel.add_wedge(Vector3(0.0, 0.07, -0.26), Vector3(0.24, 0.14, 0.2))
	steel.add_loft([[0.14, 0.11, 0.13], [0.35, 0.13, 0.15], [0.62, 0.15, 0.17]], 10, Vector3(0.0, 0.0, 0.03))
	var gold := MeshKit.new()
	gold.add_box(Vector3(0.0, 0.62, -0.1), Vector3(0.22, 0.16, 0.14))
	gold.add_box(Vector3(0.0, 0.2, 0.03), Vector3(0.28, 0.03, 0.3))
	gold.add_cone(Vector3(0.0, 0.62, -0.17), 0.04, 0.06, 4, Basis(Vector3.RIGHT, -PI / 2.0))
	return _surfaces([[steel, STEEL], [gold, GOLD]])


## The greatsword. The origin is the middle of the grip and the blade points along +Y
## (EnemyHandsConfig.hand_rotation turns it point down at rest): pommel and grip with gold
## rings and the right fist, a winged guard, and a long hexagonal blade with a tapered
## point. Unit: 1 = 1.5 m of the hand; the whole sword is about 1.2 units long.
func _greatsword_mesh() -> ArrayMesh:
	var steel := MeshKit.new()
	steel.add_loft([
		[0.2, 0.072, 0.02],
		[0.55, 0.078, 0.02],
		[0.82, 0.066, 0.018],
		[0.94, 0.036, 0.013],
		[1.0, 0.004, 0.004],
	], 6)
	steel.add_box(Vector3(0.0, 0.215, 0.0), Vector3(0.1, 0.05, 0.05))
	steel.add_box(Vector3(0.0, 0.07, 0.0), Vector3(0.1, 0.1, 0.1))
	var gold := MeshKit.new()
	gold.add_box(Vector3(0.0, 0.15, 0.0), Vector3(0.12, 0.05, 0.07))
	for side: float in [-1.0, 1.0]:
		gold.add_box(Vector3(side * 0.13, 0.165, 0.0), Vector3(0.14, 0.035, 0.05), Basis(Vector3.BACK, side * 0.22))
		gold.add_box(Vector3(side * 0.235, 0.2, 0.0), Vector3(0.08, 0.035, 0.05), Basis(Vector3.BACK, side * 0.6))
		gold.add_cone(Vector3(side * 0.27, 0.22, 0.0), 0.028, 0.1, 5, Basis(Vector3.BACK, -side * 0.9))
	gold.add_prism(Vector3(0.0, -0.13, 0.0), 0.034, 0.034, 0.018, 8)
	gold.add_prism(Vector3(0.0, 0.135, 0.0), 0.034, 0.034, 0.018, 8)
	gold.add_prism(Vector3(0.0, -0.22, 0.0), 0.05, 0.05, 0.07, 8, Basis.IDENTITY, 0.75)
	gold.add_cone(Vector3(0.0, -0.22, 0.0), 0.05, -0.05, 8)
	gold.add_box(Vector3(0.0, 0.3, -0.02), Vector3(0.05, 0.08, 0.02))
	var leather := MeshKit.new()
	leather.add_prism(Vector3(0.0, -0.15, 0.0), 0.027, 0.027, 0.3, 8)
	return _surfaces([[steel, STEEL], [gold, GOLD], [leather, LEATHER]])


## The free hand: a closed steel gauntlet with a gold cuff.
func _gauntlet_mesh() -> ArrayMesh:
	var steel := MeshKit.new()
	steel.add_box(Vector3(0.0, 0.0, 0.0), Vector3(0.11, 0.09, 0.1))
	for x: float in [-0.036, 0.0, 0.036]:
		steel.add_box(Vector3(x, 0.0, -0.06), Vector3(0.032, 0.05, 0.03))
	var gold := MeshKit.new()
	gold.add_box(Vector3(0.0, 0.065, 0.0), Vector3(0.13, 0.03, 0.12))
	return _surfaces([[steel, STEEL], [gold, GOLD]])


# --- Clips -------------------------------------------------------------------

func _motion_library() -> AnimationLibrary:
	var kit := EnemyClipKit.new(
		{&"hips": ^"Flinch/Hips", &"torso": ^"Flinch/Hips/Torso", &"head": ^"Flinch/Hips/Torso/Head",
			&"plume": ^"Flinch/Hips/Torso/Head/Plume", &"cape": ^"Flinch/Hips/Torso/Cape",
			&"cape_tail": ^"Flinch/Hips/Torso/Cape/CapeTail", &"tabard": ^"Flinch/Hips/Tabard",
			&"tassets": ^"Flinch/Hips/Tassets", &"foot_l": ^"Flinch/Hips/FootL", &"foot_r": ^"Flinch/Hips/FootR"},
		{&"hips": HIPS_REST, &"foot_l": FOOT_L_REST, &"foot_r": FOOT_R_REST},
		[&"hips"],
		[&"Sparks"])
	var library := AnimationLibrary.new()
	var rest := {"torso": Vector3(-1, 0, 0), "head": Vector3(2, 0, 0), "plume": Vector3(2, 0, 0)}
	# Idle: weight on the planted sword; a slow breath and the cape and the plume drifting.
	var inhale := {"hips:p": Vector3(0.0, 0.012, 0.0), "torso": Vector3(-2.5, 1.5, 0.6), "head": Vector3(1, -1.5, 0),
		"plume": Vector3(6, 0, 2), "cape": Vector3(2.5, 0, 1.5), "cape_tail": Vector3(6, 0, 3), "tabard": Vector3(1.5, 0, 0.6)}
	library.add_animation(CLIP_IDLE, kit.make_clip([[0.0, rest], [0.5, inhale], [1.0, rest]], true, OVERLAP))
	library.add_animation(CLIP_WALK, kit.make_clip(EnemyClipKit.gait_keys({
		"stride": 0.5, "lift": 0.11, "bob": 0.03, "sway": 0.03, "hip_twist": 6.0, "torso_twist": 8.0,
		"pitch": -2.0, "dip": 2.0, "head_pitch": 3.0}, [
			{"cape": Vector3(14, 0, 0), "cape_tail": Vector3(22, 0, 0), "tabard": Vector3(8, 0, 0), "tassets": Vector3(5, 0, 0), "plume": Vector3(10, 0, 0)},
			{"cape": Vector3(0, 0, 4), "cape_tail": Vector3(4, 0, 8), "plume": Vector3(-2, 0, 3)},
			{"cape": Vector3(14, 0, 0), "cape_tail": Vector3(22, 0, 0), "tabard": Vector3(8, 0, 0), "tassets": Vector3(5, 0, 0), "plume": Vector3(10, 0, 0)},
			{"cape": Vector3(0, 0, -4), "cape_tail": Vector3(4, 0, -8), "plume": Vector3(-2, 0, -3)}]), true, OVERLAP))
	# The four slashes: each pair of clips is a windup and a strike.
	# (yaw back, lean back, yaw through, lean through, lead foot)
	_add_slash(library, kit, &"slash_a", rest, 72.0, 10.0, -84.0, -16.0, 1.0)
	_add_slash(library, kit, &"slash_b", rest, -66.0, 8.0, 78.0, -14.0, -1.0)
	_add_slash(library, kit, &"slash_c", rest, 0.0, 42.0, 0.0, -52.0, 1.0)
	_add_slash(library, kit, &"slash_d", rest, -78.0, 4.0, 88.0, -8.0, -1.0)
	# Thrust: the weight goes back and the shoulder comes forward, a beat of tension, then a lunge.
	var counter := {
		"hips:p": Vector3(0, -0.05, -0.04), "torso": Vector3(2, -8, 0), "head": Vector3(1, 6, 0), "cape": Vector3(6, 0, 0)}
	var drawn := {
		"hips:p": Vector3(0, -0.12, 0.26), "hips": Vector3(0, 24, 0), "torso": Vector3(6, 38, -4), "head": Vector3(-2, -26, 0),
		"plume": Vector3(-10, 0, 0), "cape": Vector3(-14, 0, 0), "cape_tail": Vector3(-22, 0, 0), "tabard": Vector3(-6, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.22), "foot_r:p": Vector3(0, 0, 0.22)}
	var hold_drawn := drawn.duplicate()
	hold_drawn["torso"] = Vector3(7, 42, -4)
	var lunged := {
		"hips:p": Vector3(0, -0.24, -0.72), "hips": Vector3(-8, -14, 0), "torso": Vector3(-42, -16, 0), "head": Vector3(16, 10, 0),
		"plume": Vector3(34, 0, 0), "cape": Vector3(44, 0, 0), "cape_tail": Vector3(64, 0, 0), "tabard": Vector3(26, 0, 0),
		"tassets": Vector3(12, 0, 0), "foot_l:p": Vector3(0, 0.1, -0.48), "foot_r:p": Vector3(0, 0, 0.5)}
	var lunged_settled := lunged.duplicate()
	lunged_settled["torso"] = Vector3(-38, -14, 0)
	lunged_settled["cape_tail"] = Vector3(42, 0, 0)
	library.add_animation(&"thrust_windup", kit.make_clip([[0.0, rest], [0.16, counter], [0.6, drawn], [0.8, hold_drawn], [1.0, hold_drawn]], false, OVERLAP))
	library.add_animation(&"thrust_strike", kit.make_clip([[0.0, hold_drawn], [0.22, lunged], [1.0, lunged_settled]], false, OVERLAP))
	# Spin: a crouch and a twist back, then a whole turn of the body, hips first.
	var coiled := {
		"hips:p": Vector3(0, -0.2, 0.06), "hips": Vector3(0, -60, 0), "torso": Vector3(8, -84, 0), "head": Vector3(-4, 46, 0),
		"plume": Vector3(-8, 0, 0), "cape": Vector3(-10, 0, 0), "cape_tail": Vector3(-16, 0, 0), "tabard": Vector3(-6, 0, 0),
		"foot_l:p": Vector3(0, 0, 0.14), "foot_r:p": Vector3(0, 0, -0.14)}
	var coiled_hold := coiled.duplicate()
	coiled_hold["torso"] = Vector3(8, -92, 0)
	var whirl := {
		"hips:p": Vector3(0, -0.12, -0.12), "hips": Vector3(0, 220, 0), "torso": Vector3(-8, 250, 0), "head": Vector3(6, -110, 0),
		"plume": Vector3(20, 0, 24), "cape": Vector3(46, 0, 22), "cape_tail": Vector3(70, 0, 34), "tabard": Vector3(34, 0, 20),
		"tassets": Vector3(16, 0, 10), "foot_l:p": Vector3(0, 0, 0.12)}
	var whirl_settled := whirl.duplicate()
	whirl_settled["hips"] = Vector3(0, 210, 0)
	whirl_settled["torso"] = Vector3(-6, 236, 0)
	library.add_animation(&"spin_windup", kit.make_clip([[0.0, rest], [0.2, coiled], [0.7, coiled_hold], [1.0, coiled_hold]], false, OVERLAP))
	library.add_animation(&"spin_strike", kit.make_clip([[0.0, coiled_hold], [0.5, whirl], [1.0, whirl_settled]], false, OVERLAP))
	# Oath: the sword goes up over the head, the King arches back and drives it into the floor.
	var raised := {
		"hips:p": Vector3(0, 0.1, 0.12), "torso": Vector3(30, 0, 0), "head": Vector3(-18, 0, 0), "plume": Vector3(-14, 0, 0),
		"cape": Vector3(-16, 0, 0), "cape_tail": Vector3(-26, 0, 0), "tabard": Vector3(-8, 0, 0), "tassets": Vector3(-4, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.1), "foot_r:p": Vector3(0, 0, 0.1)}
	var raised_hold := raised.duplicate()
	raised_hold["torso"] = Vector3(34, 0, 0)
	var planted := {
		"hips:p": Vector3(0, -0.3, -0.34), "torso": Vector3(-48, 0, 0), "head": Vector3(22, 0, 0), "plume": Vector3(36, 0, 0),
		"cape": Vector3(40, 0, 0), "cape_tail": Vector3(62, 0, 0), "tabard": Vector3(22, 0, 0), "tassets": Vector3(10, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.26), "foot_r:p": Vector3(0, 0, 0.26), "emit:Sparks": true}
	var planted_settled := planted.duplicate()
	planted_settled["torso"] = Vector3(-42, 0, 0)
	planted_settled["cape_tail"] = Vector3(40, 0, 0)
	library.add_animation(&"oath_windup", kit.make_clip([[0.0, rest], [0.18, _crouch_pose(rest)], [0.7, raised], [0.85, raised_hold], [1.0, raised_hold]], false, OVERLAP))
	library.add_animation(&"oath_strike", kit.make_clip([[0.0, raised_hold], [0.22, planted], [1.0, planted_settled]], false, OVERLAP))
	# Judgment: a slow crouch and a climb of the sword through the whole windup, trembling with the strain, then it falls like a tower.
	var hoisted := {
		"hips:p": Vector3(0, 0.12, 0.2), "torso": Vector3(40, 0, 0), "head": Vector3(-24, 0, 0), "plume": Vector3(-18, 0, 0),
		"cape": Vector3(-22, 0, 0), "cape_tail": Vector3(-34, 0, 0), "tabard": Vector3(-12, 0, 0), "tassets": Vector3(-6, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.16), "foot_r:p": Vector3(0, 0, 0.16)}
	var shake_a := hoisted.duplicate()
	shake_a["torso"] = Vector3(42, 3, 1.5)
	var shake_b := hoisted.duplicate()
	shake_b["torso"] = Vector3(41, -3, -1.5)
	var cut := {
		"hips:p": Vector3(0, -0.36, -0.6), "hips": Vector3(-8, 0, 0), "torso": Vector3(-64, 0, 0), "head": Vector3(26, 0, 0),
		"plume": Vector3(44, 0, 0), "cape": Vector3(56, 0, 0), "cape_tail": Vector3(80, 0, 0), "tabard": Vector3(34, 0, 0),
		"tassets": Vector3(14, 0, 0), "foot_l:p": Vector3(0, 0, -0.34), "foot_r:p": Vector3(0, 0, 0.32), "emit:Sparks": true}
	var cut_settled := cut.duplicate()
	cut_settled["torso"] = Vector3(-56, 0, 0)
	cut_settled["cape_tail"] = Vector3(48, 0, 0)
	library.add_animation(&"judgment_windup", kit.make_clip([
		[0.0, rest], [0.3, _crouch_pose(rest)], [0.72, hoisted], [0.8, shake_a], [0.88, shake_b], [0.94, shake_a], [1.0, hoisted]], false, OVERLAP))
	library.add_animation(&"judgment_strike", kit.make_clip([[0.0, hoisted], [0.2, cut], [1.0, cut_settled]], false, OVERLAP))
	library.add_animation(CLIP_WINDUP, library.get_animation(&"slash_a_windup"))
	library.add_animation(CLIP_STRIKE, library.get_animation(&"slash_a_strike"))
	library.add_animation(CLIP_RECOVER, kit.make_clip([[0.0, cut_settled], [1.0, rest]], false, OVERLAP))
	# Transition (phase 2): the King rises and lifts the sword with both hands, the cape flaring.
	var glory := {
		"hips:p": Vector3(0, 0.14, 0.06), "torso": Vector3(24, 0, 0), "head": Vector3(-28, 0, 0), "plume": Vector3(-20, 0, 0),
		"cape": Vector3(-38, 0, 0), "cape_tail": Vector3(-56, 0, 0), "tabard": Vector3(-18, 0, 0), "tassets": Vector3(-8, 0, 0),
		"foot_l:p": Vector3(0, 0, -0.12), "foot_r:p": Vector3(0, 0, 0.12)}
	var stir := glory.duplicate()
	stir["cape"] = Vector3(-28, 0, 7)
	stir["cape_tail"] = Vector3(-44, 0, 12)
	var stir_other := glory.duplicate()
	stir_other["cape"] = Vector3(-42, 0, -7)
	stir_other["cape_tail"] = Vector3(-62, 0, -12)
	library.add_animation(&"transition", kit.make_clip([
		[0.0, rest], [0.2, _crouch_pose(rest)], [0.5, glory], [0.65, stir], [0.8, stir_other], [1.0, glory]], false, OVERLAP))
	return library


## A shallow crouch before a rise.
func _crouch_pose(rest: Dictionary) -> Dictionary:
	var crouch := rest.duplicate()
	crouch["hips:p"] = Vector3(0, -0.14, 0.05)
	crouch["torso"] = Vector3(-8, 0, 0)
	crouch["head"] = Vector3(4, 0, 0)
	crouch["cape"] = Vector3(-6, 0, 0)
	crouch["cape_tail"] = Vector3(-10, 0, 0)
	return crouch


## `<name>_windup` (a counter-move, then the body coils to `twist_back`° of yaw and
## `lean_back`° of pitch, overshoots a little and holds) and `<name>_strike` (the hips lead
## through to `twist_through` and `lean_through`, with the follow-through settling back).
## `lead` (±1) picks the foot that steps in.
func _add_slash(library: AnimationLibrary, kit: EnemyClipKit, slash: StringName, rest: Dictionary,
		twist_back: float, lean_back: float, twist_through: float, lean_through: float, lead: float) -> void:
	var front: String = "foot_l:p" if lead > 0.0 else "foot_r:p"
	var rear: String = "foot_r:p" if lead > 0.0 else "foot_l:p"
	var counter := {
		"hips:p": Vector3(0, -0.07, -0.02), "hips": Vector3(0, -twist_back * 0.1, 0),
		"torso": Vector3(-6, -twist_back * 0.2, 0), "head": Vector3(4, twist_back * 0.1, 0), "cape": Vector3(8, 0, 0), "cape_tail": Vector3(12, 0, 0)}
	var back := {
		"hips:p": Vector3(0, -0.12, 0.16), "hips": Vector3(0, twist_back * 0.45, 0), "torso": Vector3(lean_back, twist_back, twist_back * 0.05),
		"head": Vector3(-6, -twist_back * 0.4, 0), "plume": Vector3(-10, 0, 0), "cape": Vector3(-16, 0, 0), "cape_tail": Vector3(-26, 0, 0),
		"tabard": Vector3(-8, 0, 0), "tassets": Vector3(-4, 0, 0), front: Vector3(0, 0, -0.16), rear: Vector3(0, 0, 0.16)}
	var over := back.duplicate()
	over["torso"] = Vector3(lean_back + 3.0, twist_back * 1.13, twist_back * 0.05)
	over["hips"] = Vector3(0, twist_back * 0.5, 0)
	var hold := back.duplicate()
	hold["torso"] = Vector3(lean_back + 2.0, twist_back * 1.07, twist_back * 0.05)
	var through := {
		"hips:p": Vector3(0, -0.16, -0.46), "hips": Vector3(0, twist_through * 0.55, 0), "torso": Vector3(lean_through, twist_through, 0),
		"head": Vector3(8, -twist_through * 0.4, 0), "plume": Vector3(26, 0, 0), "cape": Vector3(34, 0, 0), "cape_tail": Vector3(52, 0, 0),
		"tabard": Vector3(18, 0, 0), "tassets": Vector3(10, 0, 0), front: Vector3(0, 0, -0.32), rear: Vector3(0, 0, 0.22)}
	var beyond := through.duplicate()
	beyond["torso"] = Vector3(lean_through * 1.06, twist_through * 1.06, 0)
	var settled := through.duplicate()
	settled["torso"] = Vector3(lean_through * 0.86, twist_through * 0.92, 0)
	settled["cape"] = Vector3(20, 0, 0)
	settled["cape_tail"] = Vector3(30, 0, 0)
	library.add_animation(StringName("%s_windup" % slash), kit.make_clip([
		[0.0, rest], [0.14, counter], [0.55, back], [0.78, over], [1.0, hold]], false, OVERLAP))
	library.add_animation(StringName("%s_strike" % slash), kit.make_clip([
		[0.0, hold], [0.22, through], [0.55, beyond], [1.0, settled]], false, OVERLAP))
