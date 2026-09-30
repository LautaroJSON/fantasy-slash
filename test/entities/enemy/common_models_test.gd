extends GdUnitTestSuite
## Models of the common types (docs/specs/enemy-models.md): AC1210 Embestidor,
## AC1211 Saltador, AC1212 Hostigador and AC1213 Escudero.

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CHARGER_STATS: EnemyStats = preload("res://data/enemies/charger_stats.tres")
const LEAPER_STATS: EnemyStats = preload("res://data/enemies/leaper_stats.tres")
const HARASSER_STATS: EnemyStats = preload("res://data/enemies/harasser_stats.tres")
const SHIELDBEARER_STATS: EnemyStats = preload("res://data/enemies/shieldbearer_stats.tres")
const CHARGE: ChargeAttackData = preload("res://data/enemies/attacks/charger_charge.tres")


func _model(stats: EnemyStats) -> EnemyModel:
	var model: EnemyModel = auto_free((stats.model as PackedScene).instantiate()) as EnemyModel
	add_child(model)
	return model


## Plays `clip` and jumps to `at` (a fraction of its length), applying the pose at once.
func _pose(model: EnemyModel, clip: StringName, at: float) -> void:
	var player: AnimationPlayer = model.get_motion_player()
	player.play(clip, 0.0)
	player.seek(at * player.current_animation_length, true)


## Position of a joint in the model's own space.
func _at(model: EnemyModel, joint: StringName) -> Vector3:
	return model.global_transform.affine_inverse() * model.get_joint(joint).global_position


func test_ac1210_the_charger_plants_its_head_when_stunned() -> void:
	var model: EnemyModel = _model(CHARGER_STATS)
	_pose(model, &"idle", 0.0)
	var idle_head: float = _at(model, &"Head").y
	_pose(model, &"stunned", 1.0)
	assert_float(_at(model, &"Head").y).is_less(idle_head - 0.3)


func test_ac1210_the_wall_stun_holds_the_stunned_pose_for_its_whole_time() -> void:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = CHARGER_STATS
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, 30.0), null)
	var hands: EnemyHands = enemy.get_hands()
	hands.play_pose(CHARGE.stun_hand_offset, hands.config.return_time, &"stunned")
	var model: EnemyModel = enemy.get_model()
	for step: int in roundi(CHARGE.wall_stun_time / 0.05):
		model.get_motion_player().advance(0.05)
		model.set_locomotion(Vector3(0.0, 0.0, -2.0))
	assert_str(String(model.get_current_clip())).override_failure_message("clip: %s" % model.get_current_clip()).is_equal("stunned")
	assert_bool(model.get_motion_player().is_playing()).override_failure_message("still playing at %s" % model.get_motion_player().current_animation_position).is_false()


func test_ac1211_the_leaper_compresses_and_stretches() -> void:
	var model: EnemyModel = _model(LEAPER_STATS)
	_pose(model, &"windup", 1.0)
	assert_float(model.get_joint(&"Hips").scale.y).is_less(0.85)
	_pose(model, &"airborne", 1.0)
	assert_float(model.get_joint(&"Hips").scale.y).is_greater(1.1)


func test_ac1212_the_harasser_has_a_blade_hand_pointing_forward() -> void:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = HARASSER_STATS
	add_child(enemy)
	var right: MeshInstance3D = enemy.get_hands().get_node("RightHand") as MeshInstance3D
	var size: Vector3 = right.mesh.get_aabb().size
	assert_float(size.y).is_greater(maxf(size.x, size.z) * 4.0)
	var tip: Vector3 = (right.transform.basis * Vector3.UP).normalized()
	assert_float(tip.z).is_less(-0.99)
	var model: EnemyModel = enemy.get_model()
	assert_bool(model.has_clip(&"strafe_l")).is_true()
	assert_bool(model.has_clip(&"strafe_r")).is_true()


func test_ac1213_the_shieldbearer_covers_its_front_with_the_shell() -> void:
	var model: EnemyModel = _model(SHIELDBEARER_STATS)
	for clip: StringName in [&"idle", &"walk"]:
		_pose(model, clip, 0.3)
		var shell: Vector3 = _at(model, &"Shell")
		assert_float(absf(shell.x)).is_less(0.1)
		assert_float(shell.z).is_less(_at(model, &"Torso").z - 0.3)


func test_ac1213_the_shell_opens_with_the_guard_down_and_the_interior_lights_up() -> void:
	var model: EnemyModel = _model(SHIELDBEARER_STATS)
	_pose(model, &"guard_down", 1.0)
	assert_float(absf(_at(model, &"Shell").x)).is_greater(0.4)
	model.on_windup(&"attack", 0.9)
	assert_bool(model.is_alert()).is_false()
	model.on_pose(&"guard_down", 0.3)
	assert_bool(model.is_alert()).is_true()
	model.on_rest()
	assert_bool(model.is_alert()).is_false()


func test_ac1214_the_minion_is_a_light_mass_without_continuous_emitters() -> void:
	var model: EnemyModel = _model(load("res://data/enemies/fodder_stats.tres") as EnemyStats)
	var triangles: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		triangles += ((node as MeshInstance3D).mesh.get_faces().size()) / 3
	assert_int(triangles).is_less_equal(300)
	assert_int(model.get_emitters().size()).is_equal(0)


# --- Bosses (AC1215–AC1217) --------------------------------------------------

const VERDUGO_STATS: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const TITAN_STATS: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const COLMENA_STATS: EnemyStats = preload("res://data/enemies/colmena_stats.tres")


func test_ac1215_the_verdugo_has_every_clip_of_its_repertoire() -> void:
	var model: EnemyModel = _model(VERDUGO_STATS)
	for slash: String in ["slash_a", "slash_b", "slash_c", "slash_d", "shockwave", "grab"]:
		assert_bool(model.has_clip(StringName("%s_windup" % slash))).override_failure_message(slash).is_true()
		assert_bool(model.has_clip(StringName("%s_strike" % slash))).override_failure_message(slash).is_true()
	assert_bool(model.has_clip(&"transition")).is_true()


func test_ac1215_the_verdugos_chest_lights_up_in_phase_two_and_stays_lit() -> void:
	var model: EnemyModel = _model(VERDUGO_STATS)
	assert_bool(model.is_alert()).is_false()
	model.on_windup(&"slash_a", 0.6)
	assert_bool(model.is_alert()).is_false()
	model.on_phase(2)
	assert_bool(model.is_alert()).is_true()
	model.on_rest()
	assert_bool(model.is_alert()).is_true()
	model.reset()
	assert_bool(model.is_alert()).is_false()


func test_ac1216_the_titan_has_its_clips_and_its_cracks_light_up_when_stunned() -> void:
	var model: EnemyModel = _model(TITAN_STATS)
	for clip: StringName in [&"slam_windup", &"slam_strike", &"sweep_windup", &"sweep_strike", &"stomp_windup", &"stomp_strike", &"stunned", &"transition"]:
		assert_bool(model.has_clip(clip)).override_failure_message(String(clip)).is_true()
	assert_bool(model.is_alert()).is_false()
	model.on_pose(&"stunned", 0.4)
	assert_bool(model.is_alert()).is_true()
	model.on_rest()
	assert_bool(model.is_alert()).is_false()
	model.on_strike(&"slam", 0.25)
	assert_bool(model.is_alert()).is_true()


func test_ac1216_a_broken_hand_is_not_shown() -> void:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = TITAN_STATS
	add_child(enemy)
	enemy.get_hands().set_hand_visible(true, false)
	assert_bool(enemy.get_hands().get_node("LeftHand").visible).is_false()
	assert_bool(enemy.get_hands().get_node("RightHand").visible).is_true()


func test_ac1217_the_colmena_opens_its_cells_and_keeps_its_shield_aura() -> void:
	var model: EnemyModel = _model(COLMENA_STATS)
	for clip: StringName in [&"summon_windup", &"summon_strike", &"pulse_windup", &"pulse_strike", &"exposed", &"transition"]:
		assert_bool(model.has_clip(clip)).override_failure_message(String(clip)).is_true()
	_pose(model, &"idle", 0.0)
	var closed: float = model.get_joint(&"Cells").scale.x
	_pose(model, &"summon_windup", 1.0)
	assert_float(model.get_joint(&"Cells").scale.x).is_greater(closed + 0.1)
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = COLMENA_STATS
	add_child(enemy)
	assert_object(enemy.get_body().get_node_or_null("ShieldAura")).is_not_null()
	assert_object(enemy.get_body().get_node_or_null("ShieldAura").get_parent()).is_equal(enemy.get_body())
