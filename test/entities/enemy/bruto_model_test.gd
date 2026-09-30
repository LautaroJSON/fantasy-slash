extends GdUnitTestSuite
## Model of the Bruto (docs/specs/enemy-models.md, AC1209): the trunk and the
## fist go back on the windup and forward on the strike.

const TestWorld := preload("res://test/helpers/test_world.gd")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const GRUNT_PUNCH: EnemyAttackData = preload("res://data/enemies/attacks/grunt_punch.tres")


func _model() -> BrutoModel:
	var model: BrutoModel = auto_free((GRUNT_STATS.model as PackedScene).instantiate()) as BrutoModel
	add_child(model)
	return model


## Plays `clip` and jumps to `at` (a fraction of its length), applying the pose at once.
func _pose(model: BrutoModel, clip: StringName, at: float) -> void:
	var player: AnimationPlayer = model.get_motion_player()
	player.play(clip, 0.0)
	player.seek(at * player.current_animation_length, true)


func _head_z(model: BrutoModel) -> float:
	return (model.global_transform.affine_inverse() * model.get_joint(&"Head").global_position).z


func _torso_pitch(model: BrutoModel) -> float:
	return model.get_joint(&"Torso").rotation.x


func test_ac1209_the_trunk_goes_back_on_the_windup_and_forward_on_the_strike() -> void:
	var model: BrutoModel = _model()
	_pose(model, &"idle", 0.0)
	var idle_head: float = _head_z(model)
	var idle_pitch: float = _torso_pitch(model)
	_pose(model, &"windup", 1.0)
	assert_float(_head_z(model)).is_greater(idle_head + 0.1)
	assert_float(_torso_pitch(model)).is_greater(idle_pitch)
	var windup_head: float = _head_z(model)
	_pose(model, &"strike", 1.0)
	assert_float(_head_z(model)).is_less(windup_head - 0.2)
	assert_float(_torso_pitch(model)).is_less(idle_pitch)


func test_ac1209_the_fist_goes_back_on_the_windup_and_forward_on_the_strike() -> void:
	var world: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(world)
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = GRUNT_STATS
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, 30.0), null)
	var hands: EnemyHands = enemy.get_hands()
	hands.play_windup(GRUNT_PUNCH, 0.5)
	hands.advance(1.0)
	var left: bool = not hands.get_left_position().is_equal_approx(hands.get_left_rest())
	var rest_z: float = (hands.get_left_rest() if left else hands.get_right_rest()).z
	var windup_z: float = (hands.get_left_position() if left else hands.get_right_position()).z
	assert_float(windup_z).is_greater(rest_z)
	hands.play_strike(GRUNT_PUNCH, 0.15)
	hands.advance(1.0)
	var strike_z: float = (hands.get_left_position() if left else hands.get_right_position()).z
	assert_float(strike_z).is_less(rest_z)


func test_the_bud_lights_up_during_the_windup_and_goes_out_on_rest() -> void:
	var model: BrutoModel = _model()
	assert_bool(model.is_alert()).is_false()
	model.on_windup(&"attack", 0.5)
	assert_bool(model.is_alert()).is_true()
	model.on_strike(&"attack", 0.15)
	assert_bool(model.is_alert()).is_true()
	model.on_rest()
	assert_bool(model.is_alert()).is_false()


func test_spores_come_out_only_while_walking() -> void:
	var model: BrutoModel = _model()
	var spores: CPUParticles3D = model.get_emitters()[0]
	assert_bool(spores.emitting).is_false()
	model.set_locomotion(Vector3(0.0, 0.0, -3.5))
	_advance(model, 0.5)
	assert_bool(spores.emitting).is_true()
	model.on_windup(&"attack", 0.5)
	_advance(model, 0.5)
	assert_bool(spores.emitting).is_false()


## Advances the clips in frame-sized steps, as the engine does: a crossfade
## applies its weights step by step, not in one jump.
func _advance(model: BrutoModel, seconds: float) -> void:
	for step: int in roundi(seconds / 0.05):
		model.get_motion_player().advance(0.05)
