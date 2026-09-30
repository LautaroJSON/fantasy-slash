extends GdUnitTestSuite
## Model of the King (docs/specs/boss-king.md AC1261-AC1264, boss-king-rework.md AC1266 and
## AC1271-AC1282). The shared rules (budgets, joints, tracks, hands) are checked for every
## type in test/assets/enemy_models_test.gd, where "king" is listed.

const KING: EnemyStats = preload("res://data/enemies/king_stats.tres")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const CHALLENGE: BossChallengeData = preload("res://data/enemies/boss_challenges/king.tres")
const BOSS: BossConfig = preload("res://data/enemies/configs/king_boss.tres")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const METAL_SHADER: Shader = preload("res://shaders/enemies/king_metal.gdshader")
const MATERIALS_DIR: String = "res://materials/enemies/"
## Tones a body may not use (color-registry.md) and the margin in degrees.
const RESERVED: Array[Color] = [Color(1.0, 0.3, 0.1), Color(0.9, 0.1, 0.1), Color(0.95, 0.78, 0.25), Color(0.62, 0.52, 0.4)]
const ARMOR: Array[String] = ["king_steel_material.tres", "king_gold_material.tres"]
const MATTE: Array[String] = ["king_leather_material.tres", "king_tabard_material.tres", "king_cape_material.tres"]
const TORSO: NodePath = ^"Flinch/Hips/Torso:rotation"
const HIPS: NodePath = ^"Flinch/Hips:rotation"


func _model() -> KingModel:
	var model: KingModel = auto_free((KING.model as PackedScene).instantiate()) as KingModel
	add_child(model)
	return model


func _enemy(stats: EnemyStats) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, 30.0), null)
	return enemy


## Every attack of the King's repertoire, with its move.
func _attacks() -> Array[EnemyAttackData]:
	var attacks: Array[EnemyAttackData] = []
	for move: BossMoveData in BOSS.moves:
		if move is ComboMoveData:
			attacks.append_array((move as ComboMoveData).steps)
			attacks.append_array((move as ComboMoveData).phase_two_extra_steps)
		else:
			attacks.append(move.get("attack") as EnemyAttackData)
	return attacks


## World position of the tip of the greatsword (the mesh ends at y = 1.0).
func _tip(enemy: Enemy) -> Vector3:
	var hand: Node3D = enemy.get_hands().get_node("RightHand") as Node3D
	return hand.global_transform * Vector3(0.0, 1.0, 0.0)


## Direction of the blade in world space.
func _blade(enemy: Enemy) -> Vector3:
	var hand: Node3D = enemy.get_hands().get_node("RightHand") as Node3D
	return (hand.global_basis * Vector3.UP).normalized()


func _flat_distance(enemy: Enemy, point: Vector3) -> float:
	return Vector2(point.x - enemy.global_position.x, point.z - enemy.global_position.z).length()


## Values of one Vector3 track of a clip, in degrees.
func _degrees(model: KingModel, clip: StringName, path: NodePath) -> Array[Vector3]:
	var animation: Animation = model.get_motion_player().get_animation(clip)
	var track: int = animation.find_track(path, Animation.TYPE_VALUE)
	var values: Array[Vector3] = []
	for key: int in animation.track_get_key_count(track):
		values.append((animation.track_get_key_value(track, key) as Vector3) * (180.0 / PI))
	return values


## Value farthest from the first one along `axis` (0 x, 1 y, 2 z), and its time.
func _extreme(model: KingModel, clip: StringName, path: NodePath, axis: int) -> Array[float]:
	var animation: Animation = model.get_motion_player().get_animation(clip)
	var track: int = animation.find_track(path, Animation.TYPE_VALUE)
	var first: float = (animation.track_get_key_value(track, 0) as Vector3)[axis] * (180.0 / PI)
	var best: float = 0.0
	var best_time: float = 0.0
	var best_value: float = first
	for key: int in animation.track_get_key_count(track):
		var value: float = (animation.track_get_key_value(track, key) as Vector3)[axis] * (180.0 / PI)
		if absf(value - first) > best:
			best = absf(value - first)
			best_time = animation.track_get_key_time(track, key)
			best_value = value
	return [best_value, best_time]


func _last(model: KingModel, clip: StringName, path: NodePath, axis: int) -> float:
	var values: Array[Vector3] = _degrees(model, clip, path)
	return values[values.size() - 1][axis]


func _color_of(material: Material) -> Color:
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter(&"albedo")
	return (material as StandardMaterial3D).albedo_color


func test_ac1266_the_king_is_called_the_king() -> void:
	assert_str(KING.display_name).is_equal("The King")
	assert_str(CHALLENGE.title).is_equal("The King")


func test_ac1271_the_greatsword_rests_planted_point_down_unlike_the_verdugo() -> void:
	var king: Enemy = _enemy(KING)
	assert_float(_blade(king).dot(Vector3.DOWN)).is_greater(cos(deg_to_rad(10.0)))
	assert_float(_tip(king).y - king.global_position.y).is_between(-0.15, 0.15)
	var hands: EnemyHands = king.get_hands()
	var right: Vector3 = hands.get_hand_global_position(false)
	var left: Vector3 = hands.get_hand_global_position(true)
	assert_float(right.distance_to(left)).is_less(0.8)
	var verdugo: Enemy = _enemy(VERDUGO)
	assert_float(_blade(verdugo).dot(Vector3.DOWN)).is_less(0.3)


func test_ac1272_the_tip_reaches_about_as_far_as_the_blow_at_the_strike() -> void:
	var enemy: Enemy = _enemy(KING)
	var hands: EnemyHands = enemy.get_hands()
	var checked: int = 0
	for attack: EnemyAttackData in _attacks():
		if attack.model_clip == &"thrust" or attack.model_clip == &"oath":
			continue
		hands.play_windup(attack, 0.0)
		hands.play_strike(attack, 0.0)
		var reach: float = _flat_distance(enemy, _tip(enemy))
		assert_float(reach).override_failure_message("%s: the tip is %s m away, the blow reaches %s" % [attack.model_clip, reach, attack.hit_range]) \
			.is_between(attack.hit_range * 0.5, attack.hit_range * 1.4)
		if attack.model_clip != &"spin":
			assert_float(_tip(enemy).z - enemy.global_position.z).override_failure_message("%s: the tip is behind" % attack.model_clip).is_less(0.0)
		checked += 1
	assert_int(checked).is_greater_equal(6)


func test_ac1273_the_greatsword_turns_between_the_windup_and_the_strike() -> void:
	var enemy: Enemy = _enemy(KING)
	var hands: EnemyHands = enemy.get_hands()
	for attack: EnemyAttackData in _attacks():
		if attack.model_clip == &"thrust":
			continue
		hands.play_windup(attack, 0.0)
		var wound: Vector3 = _blade(enemy)
		hands.play_strike(attack, 0.0)
		var struck: Vector3 = _blade(enemy)
		assert_float(rad_to_deg(wound.angle_to(struck))).override_failure_message(String(attack.model_clip)).is_greater_equal(40.0)


func test_ac1274_more_detail_within_the_boss_budget() -> void:
	var model: KingModel = _model()
	var triangles: int = 0
	var meshes: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		triangles += (node as MeshInstance3D).mesh.get_faces().size() / 3
		meshes += 1
	assert_int(triangles).is_between(1500, 6000)
	assert_int(meshes).is_less_equal(20)
	assert_int(model.get_emitters().size()).is_equal(2)
	var particles: int = 0
	for emitter: CPUParticles3D in model.get_emitters():
		particles += emitter.amount
	assert_int(particles).is_less_equal(16)
	assert_int(_triangles_of(KING.model)).is_greater(1500)


func _triangles_of(scene: PackedScene) -> int:
	var model: Node = auto_free(scene.instantiate())
	add_child(model)
	var total: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		total += (node as MeshInstance3D).mesh.get_faces().size() / 3
	return total


func test_ac1275_meshes_and_materials_are_shared_and_flat() -> void:
	var first: KingModel = _model()
	var second: KingModel = _model()
	assert_object(first.get_shared_data()).is_same(second.get_shared_data())
	var seen: Array[Material] = []
	for node: Node in first.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = node as MeshInstance3D
		var twin: MeshInstance3D = second.find_child(String(part.name), true, false) as MeshInstance3D
		assert_object(part.mesh).is_same(twin.mesh)
		var materials: Array[Material] = []
		if part.material_override != null:
			materials.append(part.material_override)
		else:
			for surface: int in part.mesh.get_surface_count():
				materials.append(part.mesh.surface_get_material(surface))
		for material: Material in materials:
			assert_object(material).is_not_null()
			assert_str(material.resource_path).starts_with(MATERIALS_DIR + "king_")
			if not seen.has(material):
				seen.append(material)
	for material: Material in seen:
		if material is StandardMaterial3D:
			var standard: StandardMaterial3D = material as StandardMaterial3D
			assert_object(standard.albedo_texture).is_null()
			assert_object(standard.normal_texture).is_null()
	assert_int(seen.size()).is_less_equal(7)


func test_ac1276_the_armor_is_polished_metal_and_the_rest_is_matte() -> void:
	for file: String in ARMOR:
		var material: ShaderMaterial = load(MATERIALS_DIR + file) as ShaderMaterial
		assert_object(material).is_not_null()
		assert_object(material.shader).is_same(METAL_SHADER)
		assert_float(material.get_shader_parameter(&"metallic")).is_greater_equal(0.85)
		assert_float(material.get_shader_parameter(&"reflection")).is_greater(0.0)
	for file: String in MATTE:
		var material: StandardMaterial3D = load(MATERIALS_DIR + file) as StandardMaterial3D
		assert_object(material).is_not_null()
		assert_float(material.metallic).is_equal_approx(0.0, 0.0001)
		assert_float(material.roughness).is_greater_equal(0.85)
	# Each part uses the right kind: the cape, the plume and the tabard are cloth.
	var model: KingModel = _model()
	for joint: StringName in [&"Cape", &"CapeTail", &"Plume"]:
		var cloth: MeshInstance3D = model.get_joint(joint) as MeshInstance3D
		assert_object(cloth.material_override).is_same(load(MATERIALS_DIR + "king_cape_material.tres"))
	var tabard: MeshInstance3D = model.get_joint(&"Tabard") as MeshInstance3D
	assert_object(tabard.mesh.surface_get_material(0)).is_same(load(MATERIALS_DIR + "king_tabard_material.tres"))
	for joint: StringName in [&"Torso", &"Head", &"Shoulders", &"Tassets", &"FootL"]:
		var plate: MeshInstance3D = model.get_joint(joint) as MeshInstance3D
		assert_object(plate.mesh.surface_get_material(0)).is_same(load(MATERIALS_DIR + "king_steel_material.tres"))


func test_ac1277_the_metal_shader_has_no_textures() -> void:
	assert_str(METAL_SHADER.code).is_not_empty()
	assert_bool(METAL_SHADER.code.contains("sampler2D")).is_false()
	assert_bool(METAL_SHADER.code.contains("instance uniform float glow")).is_true()
	var names: Array[String] = []
	for uniform: Dictionary in METAL_SHADER.get_shader_uniform_list():
		names.append(String(uniform["name"]))
	assert_bool(names.has("albedo") and names.has("reflection") and names.has("roughness")).is_true()


func test_ac1278_only_the_gold_and_its_glow_break_the_reserved_hues() -> void:
	var breakers: Array[String] = []
	var dir: DirAccess = DirAccess.open(MATERIALS_DIR)
	for file: String in dir.get_files():
		if not file.begins_with("king_") or not file.ends_with(".tres"):
			continue
		var material: Material = load(MATERIALS_DIR + file)
		var colors: Array[Color] = [_color_of(material)]
		if material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled:
			colors.append((material as StandardMaterial3D).emission)
		for color: Color in colors:
			assert_bool(color.s >= 0.1).override_failure_message("%s is grey" % file).is_true()
			if color.s <= 0.3:
				continue
			for reserved: Color in RESERVED:
				var distance: float = absf(color.h - reserved.h) * 360.0
				if minf(distance, 360.0 - distance) <= 20.0 and not breakers.has(file):
					breakers.append(file)
	breakers.sort()
	assert_array(breakers).is_equal(["king_glow_material.tres", "king_gold_material.tres"])


func test_ac1279_the_king_has_its_joints_and_the_clips_of_every_attack() -> void:
	var model: KingModel = _model()
	for joint: StringName in [&"Plume", &"Cape", &"CapeTail", &"Tabard", &"Tassets"]:
		assert_object(model.get_joint(joint)).override_failure_message(String(joint)).is_not_null()
	for clip_name: StringName in [&"idle", &"walk", &"windup", &"strike", &"recover", &"transition"]:
		assert_bool(model.has_clip(clip_name)).override_failure_message(String(clip_name)).is_true()
	for attack: EnemyAttackData in _attacks():
		for phase: StringName in [&"windup", &"strike"]:
			var clip_name := StringName("%s_%s" % [attack.model_clip, phase])
			assert_bool(model.has_clip(clip_name)).override_failure_message(String(clip_name)).is_true()


func test_ac1280_the_clips_twist_and_lean_hard() -> void:
	var model: KingModel = _model()
	for slash: StringName in [&"slash_a", &"slash_b", &"slash_d"]:
		var back: Array[float] = _extreme(model, StringName("%s_windup" % slash), TORSO, 1)
		assert_float(absf(back[0])).override_failure_message("%s windup yaw" % slash).is_greater_equal(55.0)
		var wound: float = _last(model, StringName("%s_windup" % slash), TORSO, 1)
		var through: Array[float] = _extreme(model, StringName("%s_strike" % slash), TORSO, 1)
		assert_float(absf(through[0] - wound)).override_failure_message("%s strike swing" % slash).is_greater_equal(70.0)
	var chop_back: Array[float] = _extreme(model, &"slash_c_windup", TORSO, 0)
	assert_float(chop_back[0]).is_greater_equal(35.0)
	var chop: Array[float] = _extreme(model, &"slash_c_strike", TORSO, 0)
	assert_float(absf(chop[0] - _last(model, &"slash_c_windup", TORSO, 0))).is_greater_equal(70.0)
	var thrust: Array[float] = _extreme(model, &"thrust_strike", TORSO, 0)
	assert_float(thrust[0]).is_less_equal(-35.0)
	var coil: Array[float] = _extreme(model, &"spin_windup", TORSO, 1)
	var whirl: Array[float] = _extreme(model, &"spin_strike", TORSO, 1)
	assert_float(absf(whirl[0] - coil[0])).is_greater_equal(300.0)
	assert_float(_extreme(model, &"judgment_windup", TORSO, 0)[0]).is_greater_equal(30.0)
	assert_float(_extreme(model, &"judgment_strike", TORSO, 0)[0]).is_less_equal(-50.0)


func test_ac1281_the_cape_and_the_plume_lag_behind_the_torso() -> void:
	var model: KingModel = _model()
	var torso: float = _extreme(model, &"idle", TORSO, 0)[1]
	var cape: float = _extreme(model, &"idle", ^"Flinch/Hips/Torso/Cape:rotation", 0)[1]
	var tail: float = _extreme(model, &"idle", ^"Flinch/Hips/Torso/Cape/CapeTail:rotation", 0)[1]
	assert_float(cape).is_greater(torso)
	assert_float(tail).is_greater(cape)


func test_ac1282_phase_two_lights_the_gem_the_motes_and_the_blade() -> void:
	var enemy: Enemy = _enemy(KING)
	var model: KingModel = enemy.get_model() as KingModel
	var hand: GeometryInstance3D = enemy.get_hands().get_node("RightHand") as GeometryInstance3D
	assert_float(hand.get_instance_shader_parameter(&"glow")).is_equal_approx(0.0, 0.0001)
	enemy.get_hands().announce_phase(2)
	assert_bool(model.is_alert()).is_true()
	assert_bool(model.get_emitters()[1].emitting).is_true()
	assert_float(hand.get_instance_shader_parameter(&"glow")).is_equal_approx(KingModel.BLADE_GLOW, 0.0001)
	enemy.activate(Vector3(0.0, 0.0, 30.0), null)
	assert_bool(model.is_alert()).is_false()
	assert_bool(model.get_emitters()[1].emitting).is_false()
	assert_float(hand.get_instance_shader_parameter(&"glow")).is_equal_approx(0.0, 0.0001)
