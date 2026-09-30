extends GdUnitTestSuite
## Every enemy model against the shared rules of docs/specs/enemy-models.md
## (AC1201–AC1208). Add a type by listing its stats in TYPES (and in COMMON when
## it is not a boss); the rules apply to it without further changes.

const TYPES: Dictionary = {
	"bruto": "res://data/enemies/grunt_stats.tres",
	"shieldbearer": "res://data/enemies/shieldbearer_stats.tres",
	"charger": "res://data/enemies/charger_stats.tres",
	"leaper": "res://data/enemies/leaper_stats.tres",
	"harasser": "res://data/enemies/harasser_stats.tres",
	"fodder": "res://data/enemies/fodder_stats.tres",
	"verdugo": "res://data/enemies/verdugo_stats.tres",
	"titan": "res://data/enemies/titan_stats.tres",
	"colmena": "res://data/enemies/colmena_stats.tres",
	"king": "res://data/enemies/king_stats.tres",
}
## Types that are not bosses (their tones must differ by more than 30°).
const COMMON: Array[String] = ["bruto", "shieldbearer", "charger", "leaper", "harasser", "fodder"]
## Poses each type's behaviors emit besides the generic ones.
const POSES: Dictionary = {
	"bruto": [],
	"shieldbearer": [&"guard_down"],
	"charger": [&"stunned"],
	"leaper": [&"airborne"],
	"harasser": [],
	"fodder": [],
	"verdugo": [&"transition"],
	"titan": [&"stunned", &"transition"],
	"colmena": [&"exposed", &"transition"],
	"king": [&"transition"],
}
const REQUIRED_CLIPS: Array[StringName] = [&"idle", &"walk", &"windup", &"strike", &"recover"]
const LOOPING: Array[StringName] = [&"idle", &"walk", &"strafe_l", &"strafe_r"]
const BASE_HEIGHT: float = 1.8
const BASE_DIAMETER: float = 0.8
const TRIANGLES: Dictionary = {"common": 800, "boss": 6000}
const MESHES: Dictionary = {"common": 8, "boss": 16}
const MATERIALS: Dictionary = {"common": 3, "boss": 4}
const EMITTERS: Dictionary = {"common": 1, "boss": 2}
const PARTICLES: Dictionary = {"common": 8, "boss": 16}
## Colors a body may not use (docs/color-registry.md), with the hue margin in degrees.
const RESERVED: Array[Color] = [Color(1.0, 0.3, 0.1), Color(0.9, 0.1, 0.1), Color(0.95, 0.78, 0.25), Color(0.62, 0.52, 0.4)]
const HUE_MARGIN: float = 20.0
const SATURATION_LIMIT: float = 0.3
const GREY_LIMIT: float = 0.1
const TONE_GAP: float = 30.0
## Materials that break the reserved-hue rule on purpose (color-registry.md, boss-king.md): the gold of the King.
const HUE_EXEMPT: Array[String] = ["res://materials/enemies/king_gold_material.tres", "res://materials/enemies/king_glow_material.tres"]
## Types that need more materials than their kind allows (the King: steel, gold, leather, tabard and cape).
const MATERIALS_OF: Dictionary = {"king": 7}





func _stats(type_id: String) -> EnemyStats:
	return load(TYPES[type_id]) as EnemyStats


func _model(type_id: String) -> EnemyModel:
	var model: EnemyModel = auto_free((_stats(type_id).model as PackedScene).instantiate()) as EnemyModel
	add_child(model)
	return model


func _kind(type_id: String) -> String:
	return "common" if COMMON.has(type_id) else "boss"


## Meshes of the body (the hands and the particles are not children of the model's joints).
func _parts(model: EnemyModel) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		parts.append(node as MeshInstance3D)
	return parts


func _triangles(mesh: Mesh) -> int:
	return mesh.get_faces().size() / 3


func _materials(model: EnemyModel) -> Array[Material]:
	var found: Array[Material] = []
	for part: MeshInstance3D in _parts(model):
		if part.material_override != null and not found.has(part.material_override):
			found.append(part.material_override)
		for surface: int in part.mesh.get_surface_count():
			var surface_material: Material = part.mesh.surface_get_material(surface)
			if surface_material != null and not found.has(surface_material):
				found.append(surface_material)
	for emitter: CPUParticles3D in model.get_emitters():
		var material: Material = (emitter.mesh as PrimitiveMesh).material
		if material != null and not found.has(material):
			found.append(material)
	return found


func _hue_distance(a: float, b: float) -> float:
	var distance: float = absf(a - b) * 360.0
	return minf(distance, 360.0 - distance)


func _dominant_hue(model: EnemyModel) -> float:
	return (model.get_shared_data().materials[EnemyModel.MATERIAL_BODY] as StandardMaterial3D).albedo_color.h


func test_ac1201_every_model_has_its_joints_and_clips() -> void:
	for type_id: String in TYPES:
		var model: EnemyModel = _model(type_id)
		for joint: StringName in [&"Flinch", &"Hips", &"Torso", &"Head"]:
			assert_object(model.get_joint(joint)).override_failure_message("%s: joint %s" % [type_id, joint]).is_not_null()
		for clip_name: StringName in REQUIRED_CLIPS:
			assert_bool(model.has_clip(clip_name)).override_failure_message("%s: clip %s" % [type_id, clip_name]).is_true()


func test_ac1201_every_attack_and_pose_of_the_type_has_a_clip() -> void:
	for type_id: String in TYPES:
		var model: EnemyModel = _model(type_id)
		for attack: EnemyAttackData in _attacks_of(_stats(type_id)):
			for phase: StringName in [&"windup", &"strike"]:
				var specific := StringName("%s_%s" % [attack.model_clip, phase])
				assert_bool(model.has_clip(specific) or model.has_clip(phase)).is_true()
		for pose: StringName in POSES[type_id]:
			assert_bool(model.has_clip(pose)).override_failure_message("%s: pose %s" % [type_id, pose]).is_true()


func test_ac1202_every_model_fits_its_budgets() -> void:
	for type_id: String in TYPES:
		var model: EnemyModel = _model(type_id)
		var kind: String = _kind(type_id)
		var parts: Array[MeshInstance3D] = _parts(model)
		var triangles: int = 0
		for part: MeshInstance3D in parts:
			triangles += _triangles(part.mesh)
		assert_int(triangles).override_failure_message("%s: triangles" % type_id).is_less_equal(TRIANGLES[kind])
		assert_int(parts.size()).override_failure_message("%s: mesh instances" % type_id).is_less_equal(MESHES[kind])
		var material_limit: int = MATERIALS_OF.get(type_id, MATERIALS[kind])
		assert_int(_materials(model).size()).override_failure_message("%s: materials" % type_id).is_less_equal(material_limit)
		assert_int(model.get_emitters().size()).is_less_equal(EMITTERS[kind])
		var particles: int = 0
		for emitter: CPUParticles3D in model.get_emitters():
			particles += emitter.amount
		assert_int(particles).is_less_equal(PARTICLES[kind])


func test_ac1203_the_model_is_about_as_big_as_the_capsule() -> void:
	for type_id: String in TYPES:
		var model: EnemyModel = _model(type_id)
		var box := AABB()
		var first: bool = true
		for part: MeshInstance3D in _parts(model):
			var bounds: AABB = model.global_transform.affine_inverse() * (part.global_transform * part.mesh.get_aabb())
			box = bounds if first else box.merge(bounds)
			first = false
		assert_float(box.size.y).override_failure_message("%s: height %s" % [type_id, box.size.y]).is_between(BASE_HEIGHT * 0.9, BASE_HEIGHT * 1.3)
		assert_float(maxf(box.size.x, box.size.z)).override_failure_message("%s: width %s" % [type_id, box.size]).is_less_equal(BASE_DIAMETER * 1.5)


func test_ac1204_instances_share_meshes_materials_and_clips() -> void:
	for type_id: String in TYPES:
		var first: EnemyModel = _model(type_id)
		var second: EnemyModel = _model(type_id)
		assert_object(first.get_shared_data()).is_same(second.get_shared_data())
		var first_parts: Array[MeshInstance3D] = _parts(first)
		var second_parts: Array[MeshInstance3D] = _parts(second)
		assert_int(first_parts.size()).is_equal(second_parts.size())
		for index: int in first_parts.size():
			assert_object(first_parts[index].mesh).is_same(second_parts[index].mesh)
			assert_object(first_parts[index].material_override).is_same(second_parts[index].material_override)
			assert_int(first_parts[index].cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_object(first.get_motion_player().get_animation(&"idle")).is_same(second.get_motion_player().get_animation(&"idle"))


func test_ac1205_no_material_is_white_grey_or_a_reserved_tone() -> void:
	for type_id: String in TYPES:
		for material: Material in _materials(_model(type_id)):
			assert_str(material.resource_path).override_failure_message("%s: material must be a shared .tres" % type_id).starts_with("res://materials/enemies/")
			var colors: Array[Color] = []
			var standard: StandardMaterial3D = material as StandardMaterial3D
			if standard != null:
				colors.append(standard.albedo_color)
				if standard.emission_enabled:
					colors.append(standard.emission)
			else:
				# A shader material (the King's metal): its flat color is the `albedo` parameter.
				var shader_material: ShaderMaterial = material as ShaderMaterial
				assert_object(shader_material).is_not_null()
				colors.append(shader_material.get_shader_parameter(&"albedo"))
			for color: Color in colors:
				assert_bool(color.s >= GREY_LIMIT).override_failure_message("%s: %s is grey or white" % [type_id, color]).is_true()
				if color.s <= SATURATION_LIMIT or HUE_EXEMPT.has(material.resource_path):
					continue
				for reserved: Color in RESERVED:
					assert_float(_hue_distance(color.h, reserved.h)).override_failure_message("%s: %s is too close to %s" % [type_id, color, reserved]).is_greater(HUE_MARGIN)


func test_ac1206_common_types_have_distinct_dominant_tones() -> void:
	for a: String in COMMON:
		for b: String in COMMON:
			if a >= b:
				continue
			var distance: float = _hue_distance(_dominant_hue(_model(a)), _dominant_hue(_model(b)))
			assert_float(distance).override_failure_message("%s and %s: %s°" % [a, b, distance]).is_greater(TONE_GAP)


func test_ac1207_loops_holds_and_nominal_duration() -> void:
	for type_id: String in TYPES:
		var player: AnimationPlayer = _model(type_id).get_motion_player()
		for clip_name: StringName in player.get_animation_list():
			var animation: Animation = player.get_animation(clip_name)
			var expected: int = Animation.LOOP_LINEAR if LOOPING.has(clip_name) else Animation.LOOP_NONE
			assert_int(animation.loop_mode).override_failure_message("%s: loop of %s" % [type_id, clip_name]).is_equal(expected)
			assert_float(animation.length).override_failure_message("%s: length of %s" % [type_id, clip_name]).is_equal_approx(1.0, 0.0001)


func test_ac1208_no_track_leaves_the_model() -> void:
	for type_id: String in TYPES:
		var model: EnemyModel = _model(type_id)
		for player: AnimationPlayer in [model.get_motion_player(), model.get_overlay_player()]:
			for clip_name: StringName in player.get_animation_list():
				var animation: Animation = player.get_animation(clip_name)
				for track: int in animation.get_track_count():
					var path: NodePath = animation.track_get_path(track)
					assert_object(model.get_node_or_null(NodePath(path.get_concatenated_names()))).override_failure_message("%s: %s → %s" % [type_id, clip_name, path]).is_not_null()
					assert_str(String(path)).not_contains("..")


## Types whose hand is a weapon, not a fist: how many hand radii long the mesh may be.
const LONG_HANDS: Dictionary = {"harasser": 6.0, "verdugo": 9.0, "king": 9.0}
const HAND_SLACK: float = 1.5
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")


func test_ac1218_hands_respect_hand_scale_and_hand_radius() -> void:
	for type_id: String in TYPES:
		var stats: EnemyStats = _stats(type_id)
		var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
		enemy.stats = stats
		add_child(enemy)
		var config: EnemyHandsConfig = stats.hands_config if stats.hands_config != null else enemy.get_hands().config
		var allowed: float = config.hand_radius * HAND_SLACK * LONG_HANDS.get(type_id, 1.0)
		for hand_name: String in ["LeftHand", "RightHand"]:
			var hand: MeshInstance3D = enemy.get_hands().get_node(hand_name) as MeshInstance3D
			assert_float(hand.scale.x).override_failure_message("%s: %s scale" % [type_id, hand_name]).is_equal_approx(config.hand_scale, 0.0001)
			var size: Vector3 = hand.mesh.get_aabb().size
			var longest: float = maxf(size.x, maxf(size.y, size.z)) * 0.5
			assert_float(longest).override_failure_message("%s: %s is %s long" % [type_id, hand_name, longest]).is_less_equal(allowed)


## Attacks of a type: its own list and the ones of the moves of its boss repertoire.
func _attacks_of(stats: EnemyStats) -> Array[EnemyAttackData]:
	var attacks: Array[EnemyAttackData] = []
	attacks.append_array(stats.attacks)
	var config: BossConfig = stats.behavior_config as BossConfig
	if config != null:
		if config.get("summon_attack") is EnemyAttackData:
			attacks.append(config.get("summon_attack") as EnemyAttackData)
		for move: BossMoveData in config.moves:
			var combo: ComboMoveData = move as ComboMoveData
			if combo != null:
				attacks.append_array(combo.steps)
				attacks.append_array(combo.phase_two_extra_steps)
			elif move.get("attack") is EnemyAttackData:
				attacks.append(move.get("attack") as EnemyAttackData)
	return attacks
