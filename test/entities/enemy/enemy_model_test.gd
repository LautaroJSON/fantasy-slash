extends GdUnitTestSuite
## Infrastructure of the enemy models (docs/specs/enemy-models.md, AC1191–AC1200):
## the model under Body, the signals of EnemyHands, the clips it plays and the
## reset. The Bruto is the type with a model (grunt_stats.tres).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const TITAN_STATS: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const GRUNT_PUNCH: EnemyAttackData = preload("res://data/enemies/attacks/grunt_punch.tres")
const HANDS_CONFIG: EnemyHandsConfig = preload("res://data/enemies/enemy_hands_config.tres")
const BASE_HEIGHT: float = 1.8
const BASE_RADIUS: float = 0.4
const POSE_BEHAVIORS: Dictionary = {
	"res://components/enemies/charger_behavior.gd": "stunned",
	"res://components/enemies/leaper_behavior.gd": "airborne",
	"res://components/enemies/shieldbearer_behavior.gd": "guard_down",
	"res://components/enemies/boss_behavior.gd": "transition",
}

var _registry: EnemyRegistry
var _player: Player
var _windups: Array = []
var _strikes: Array = []
var _poses: Array = []
var _rests: int = 0


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_windups.clear()
	_strikes.clear()
	_poses.clear()
	_rests = 0


func _spawn(stats: EnemyStats, at: Vector3 = Vector3(0.0, 0.0, 30.0)) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _without_model(stats: EnemyStats) -> EnemyStats:
	var copy: EnemyStats = stats.duplicate() as EnemyStats
	copy.model = null
	return copy


func _record(hands: EnemyHands) -> void:
	hands.windup_started.connect(func(clip: StringName, duration: float) -> void: _windups.append([clip, duration]))
	hands.strike_started.connect(func(clip: StringName, duration: float) -> void: _strikes.append([clip, duration]))
	hands.pose_started.connect(func(pose: StringName, duration: float) -> void: _poses.append([pose, duration]))
	hands.rested.connect(func() -> void: _rests += 1)


## Gives the model of `enemy` an extra clip (a copy of `source`) without touching the shared library.
func _add_clip(enemy: Enemy, clip_name: StringName, source: StringName) -> void:
	var player: AnimationPlayer = enemy.get_model().get_motion_player()
	var library: AnimationLibrary = player.get_animation_library(&"").duplicate() as AnimationLibrary
	library.add_animation(clip_name, library.get_animation(source).duplicate() as Animation)
	player.remove_animation_library(&"")
	player.add_animation_library(&"", library)


func test_ac1191_model_replaces_the_fallback_capsule() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS)
	assert_object(enemy.get_model()).is_not_null()
	assert_object(enemy.get_body().get_node_or_null("Fallback")).is_null()
	assert_object(enemy.get_model().get_parent()).is_equal(enemy.get_body())


func test_ac1191_without_model_the_capsule_stays() -> void:
	var enemy: Enemy = _spawn(_without_model(GRUNT_STATS))
	assert_object(enemy.get_model()).is_null()
	var fallback: MeshInstance3D = enemy.get_body().get_node_or_null("Fallback") as MeshInstance3D
	assert_object(fallback).is_not_null()
	assert_object(fallback.mesh).is_instanceof(CapsuleMesh)


func test_ac1192_a_model_changes_no_measure() -> void:
	var with_model: Enemy = _spawn(GRUNT_STATS)
	var without: Enemy = _spawn(_without_model(GRUNT_STATS))
	for enemy: Enemy in [with_model, without]:
		var capsule: CapsuleShape3D = (enemy.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
		assert_float(capsule.height).is_equal_approx(BASE_HEIGHT, 0.0001)
		assert_float(capsule.radius).is_equal_approx(BASE_RADIUS, 0.0001)
		assert_float(enemy.get_hit_padding()).is_equal_approx(0.0, 0.0001)
	assert_vector(with_model.get_body().scale).is_equal_approx(without.get_body().scale, Vector3.ONE * 0.0001)
	assert_vector(with_model.get_body().position).is_equal_approx(without.get_body().position, Vector3.ONE * 0.0001)
	assert_vector(with_model.get_hands().position).is_equal_approx(without.get_hands().position, Vector3.ONE * 0.0001)
	assert_float(with_model.get_model().global_position.y).is_equal_approx(with_model.global_position.y, 0.0001)


func test_ac1193_hands_announce_windup_strike_pose_and_rest() -> void:
	var enemy: Enemy = _spawn(_without_model(GRUNT_STATS))
	var hands: EnemyHands = enemy.get_hands()
	_record(hands)
	hands.play_windup(GRUNT_PUNCH, 0.5)
	hands.play_strike(GRUNT_PUNCH, 0.15)
	hands.play_pose(Vector3(0.0, -0.3, 0.0), 0.25, &"stunned")
	hands.return_to_rest()
	assert_array(_windups).is_equal([[&"attack", 0.5]])
	assert_array(_strikes).is_equal([[&"attack", 0.15]])
	assert_array(_poses).is_equal([[&"stunned", 0.25]])
	assert_int(_rests).is_equal(1)


func test_ac1193_hands_go_where_they_always_did() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS)
	var hands: EnemyHands = enemy.get_hands()
	hands.play_windup(GRUNT_PUNCH, 0.5)
	hands.advance(1.0)
	var used_left: bool = not hands.get_left_position().is_equal_approx(hands.get_left_rest())
	var hand_position: Vector3 = hands.get_left_position() if used_left else hands.get_right_position()
	var rest: Vector3 = hands.get_left_rest() if used_left else hands.get_right_rest()
	var offset: Vector3 = GRUNT_PUNCH.hand_windup_offset
	var expected: Vector3 = rest + (Vector3(-offset.x, offset.y, offset.z) if used_left else offset)
	assert_vector(hand_position).is_equal_approx(expected, Vector3.ONE * 0.0001)


func test_ac1194_the_windup_clip_lasts_the_real_windup() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS)
	for seconds: float in [0.5, 0.8, 0.28]:
		enemy.get_hands().play_windup(GRUNT_PUNCH, seconds)
		assert_float(enemy.get_model().get_clip_seconds()).is_equal_approx(seconds, seconds * 0.01)
		assert_str(enemy.get_model().get_current_clip()).is_equal("windup")


func test_ac1195_model_clip_picks_its_own_clips_or_the_generic_ones() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS)
	_add_clip(enemy, &"slash_b_windup", &"windup")
	_add_clip(enemy, &"slash_b_strike", &"strike")
	var attack: EnemyAttackData = GRUNT_PUNCH.duplicate() as EnemyAttackData
	attack.model_clip = &"slash_b"
	enemy.get_hands().play_windup(attack, 0.5)
	assert_str(enemy.get_model().get_current_clip()).is_equal("slash_b_windup")
	enemy.get_hands().play_strike(attack, 0.15)
	assert_str(enemy.get_model().get_current_clip()).is_equal("slash_b_strike")
	attack.model_clip = &"missing"
	enemy.get_hands().play_windup(attack, 0.5)
	assert_str(enemy.get_model().get_current_clip()).is_equal("windup")
	enemy.get_hands().play_strike(attack, 0.15)
	assert_str(enemy.get_model().get_current_clip()).is_equal("strike")


func test_ac1196_locomotion_follows_the_velocity() -> void:
	var model: EnemyModel = _spawn(GRUNT_STATS).get_model()
	model.set_locomotion(Vector3.ZERO)
	assert_str(model.get_current_clip()).is_equal("idle")
	model.set_locomotion(Vector3(0.0, 0.0, -model.walk_reference_speed))
	assert_str(model.get_current_clip()).is_equal("walk")
	assert_float(model.get_clip_speed()).is_equal_approx(1.0, 0.0001)
	model.set_locomotion(Vector3(0.0, 0.0, -model.walk_reference_speed * 0.5))
	assert_str(model.get_current_clip()).is_equal("walk")
	assert_float(model.get_clip_speed()).is_equal_approx(0.5, 0.0001)
	model.set_locomotion(Vector3.ZERO)
	assert_str(model.get_current_clip()).is_equal("idle")


func test_ac1196_sideways_movement_uses_strafe_clips_when_they_exist() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS)
	var model: EnemyModel = enemy.get_model()
	model.set_locomotion(Vector3(3.0, 0.0, -0.5))
	assert_str(model.get_current_clip()).is_equal("walk")
	_add_clip(enemy, &"strafe_l", &"walk")
	_add_clip(enemy, &"strafe_r", &"walk")
	model.set_locomotion(Vector3(3.0, 0.0, -0.5))
	assert_str(model.get_current_clip()).is_equal("strafe_r")
	model.set_locomotion(Vector3(-3.0, 0.0, -0.5))
	assert_str(model.get_current_clip()).is_equal("strafe_l")


func test_ac1196_an_action_holds_the_locomotion_until_the_body_recovers() -> void:
	var model: EnemyModel = _spawn(GRUNT_STATS).get_model()
	model.on_windup(&"attack", 0.5)
	model.set_locomotion(Vector3(0.0, 0.0, -3.0))
	assert_str(model.get_current_clip()).is_equal("windup")
	model.on_rest()
	assert_str(model.get_current_clip()).is_equal("recover")
	model.get_motion_player().advance(1.0)
	model.set_locomotion(Vector3(0.0, 0.0, -3.0))
	assert_str(model.get_current_clip()).is_equal("walk")


func test_ac1197_a_hit_plays_the_overlay_and_leaves_the_body_clip_alone() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS)
	var model: EnemyModel = enemy.get_model()
	enemy.get_hands().play_windup(GRUNT_PUNCH, 0.5)
	model.get_motion_player().advance(0.2)
	var position: float = model.get_motion_player().current_animation_position
	enemy.notify_hit(5.0, false)
	assert_str(model.get_overlay_player().current_animation).is_equal("hit")
	assert_str(model.get_current_clip()).is_equal("windup")
	assert_float(model.get_motion_player().current_animation_position).is_equal_approx(position, 0.0001)


func test_ac1197_the_overlay_only_touches_flinch() -> void:
	var model: EnemyModel = _spawn(GRUNT_STATS).get_model()
	var overlay: AnimationPlayer = model.get_overlay_player()
	for clip_name: StringName in overlay.get_animation_list():
		var animation: Animation = overlay.get_animation(clip_name)
		for track: int in animation.get_track_count():
			assert_str(String(animation.track_get_path(track).get_concatenated_names())).is_equal("Flinch")


func test_ac1198_deactivate_and_activate_mid_attack_restore_the_model() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS)
	var model: EnemyModel = enemy.get_model()
	enemy.get_hands().play_windup(GRUNT_PUNCH, 0.5)
	enemy.get_hands().advance(0.2)
	enemy.notify_hit(5.0, true)
	model.get_joint(&"Flinch").rotation = Vector3(0.3, 0.0, 0.0)
	assert_bool(model.is_alert()).is_true()
	enemy.deactivate()
	enemy.activate(Vector3(0.0, 0.0, 30.0), _player)
	assert_str(model.get_current_clip()).is_equal("idle")
	assert_bool(model.is_alert()).is_false()
	assert_bool(enemy.get_hands().is_at_rest()).is_true()
	assert_vector(model.get_joint(&"Flinch").rotation).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.0001)
	assert_vector(model.get_joint(&"Flinch").scale).is_equal_approx(Vector3.ONE, Vector3.ONE * 0.0001)
	for emitter: CPUParticles3D in model.get_emitters():
		assert_bool(emitter.emitting).is_false()


func test_ac1199_hand_radius_is_the_config_radius_times_the_global_scale() -> void:
	var grunt: Enemy = _spawn(GRUNT_STATS)
	assert_float(grunt.get_hands().get_hand_radius(true)).is_equal_approx(HANDS_CONFIG.hand_radius, 0.0001)
	assert_float(HANDS_CONFIG.hand_radius).is_equal_approx(0.2, 0.0001)
	var titan: Enemy = _spawn(TITAN_STATS)
	var expected: float = titan.stats.hands_config.hand_radius * titan.stats.hands_config.hand_scale * titan.stats.body_scale
	assert_float(titan.get_hands().get_hand_radius(false)).is_equal_approx(expected, 0.0001)


func test_ac1200_every_behavior_pose_passes_its_name() -> void:
	for path: String in POSE_BEHAVIORS:
		var source: String = FileAccess.get_file_as_string(path)
		var pattern := RegEx.create_from_string("play_pose\\([^\\n]*&\"%s\"[,)]" % POSE_BEHAVIORS[path])
		assert_object(pattern.search(source)).is_not_null()
	var hands: EnemyHands = _spawn(_without_model(GRUNT_STATS)).get_hands()
	_record(hands)
	hands.play_pose(Vector3.ZERO, 0.25)
	assert_array(_poses).is_equal([[&"pose", 0.25]])


func test_ac1200_the_model_plays_the_pose_it_has() -> void:
	var enemy: Enemy = _spawn(GRUNT_STATS)
	_add_clip(enemy, &"stunned", &"windup")
	enemy.get_hands().play_pose(Vector3.ZERO, 0.4, &"stunned")
	assert_str(enemy.get_model().get_current_clip()).is_equal("stunned")
	assert_float(enemy.get_model().get_clip_seconds()).is_equal_approx(0.4, 0.004)
