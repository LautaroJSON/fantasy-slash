extends GdUnitTestSuite
## Charge and release of Sheathe with more visual weight
## (docs/specs/sheathe-visual-rework.md AC1034–AC1042, AC1048–AC1051).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
const CHARGE_UPGRADE: AbilityUpgradeData = preload("res://data/abilities/sheathe/upgrades/charge_speed.tres")
const FEEDBACK: ChargeFeedbackConfig = preload("res://data/player/charge_feedback_config.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/wind_cut_additive_material.tres")
const STEP: float = 0.05
## Small step to cross a threshold without reaching the next one.
const NUDGE: float = 0.01
const TOLERANCE: float = 0.0001
## AC1037: farthest the glow may be from the mouth of the sheath, in meters.
const GLOW_REACH: float = 0.05
## AC1038: farthest an ankle of a deeper pose may be from where the base
## charge pose has it, in meters; least drop of the hips between levels.
const FOOT_TOLERANCE: float = 0.02
const LEVEL_DROP: float = 0.01

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _sheathe: SheatheAbility
var _camera: ThirdPersonCamera
var _feedback: ChargeFeedbackComponent
var _humanoid: LowPolyHumanoid
var _unleashed: int = 0


func before_test() -> void:
	Session.character_class = SAMURAI
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	await get_tree().physics_frame
	_ability = _player.basic_ability
	_ability.set_physics_process(false)
	_ability.equip(SHEATHE)
	_sheathe = _ability.get_behavior() as SheatheAbility
	_camera = _player.get_node("CameraRig") as ThirdPersonCamera
	_camera.set_process(false)
	_feedback = _player.get_node("ChargeFeedback") as ChargeFeedbackComponent
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	_unleashed = 0
	_ability.charge_unleashed.connect(func() -> void: _unleashed += 1)
	_sheathe.get_wind_cut().set_process(false)
	_sheathe.get_charge_glow().set_process(false)


func after_test() -> void:
	Session.character_class = null


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


## Charges fully and releases; the camera shake of the charge is dropped so the
## burst's own shake can be read.
func _charge_and_release() -> void:
	_ability.try_cast()
	_advance(SHEATHE.charge_time + STEP)
	_camera.stop_shake()
	_ability.release_charge()


func _base_fov() -> float:
	return _camera.get_base_fov()


# --- A1 / A2: the view narrows on every milestone and kicks wide on the burst

func test_ac1034_the_view_narrows_more_on_every_milestone_and_holds() -> void:
	_ability.try_cast()
	_advance(1.0 + NUDGE)
	assert_float(_camera.get_fov_hold_target()).is_equal_approx(-3.0, TOLERANCE)
	_camera.advance_fov(FEEDBACK.zoom_blend)
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov() - 3.0, TOLERANCE)
	_advance(1.0)
	_camera.advance_fov(FEEDBACK.zoom_blend)
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov() - 6.0, TOLERANCE)
	_advance(1.0)
	_camera.advance_fov(FEEDBACK.zoom_blend)
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov() - 10.0, TOLERANCE)
	_advance(1.0)
	_camera.advance_fov(1.0)
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov() - 10.0, TOLERANCE)
	assert_bool(_feedback.is_zoom_held()).is_true()


func test_ac1035_a_faster_charge_narrows_to_three_then_ten() -> void:
	for i: int in CHARGE_UPGRADE.max_stacks:
		_ability.add_upgrade(CHARGE_UPGRADE)
	var targets: Array[float] = []
	_ability.charge_milestone_reached.connect(func(_index: int, _full: bool) -> void: targets.append(_camera.get_fov_hold_target()))
	_ability.try_cast()
	_advance(_ability.get_stat(AbilityData.Stat.CHARGE_TIME) + STEP)
	assert_float(_ability.get_stat(AbilityData.Stat.CHARGE_TIME)).is_equal_approx(SHEATHE.min_charge_time, TOLERANCE)
	assert_array(targets).is_equal([-3.0, -10.0])


func test_ac1036_a_cancelled_charge_eases_the_view_back_without_a_kick() -> void:
	_ability.try_cast()
	_advance(2.0 + NUDGE)
	_camera.advance_fov(FEEDBACK.zoom_blend)
	_ability.cancel_charge()
	assert_float(_camera.get_fov_hold_target()).is_equal(0.0)
	assert_bool(_feedback.is_zoom_held()).is_false()
	_camera.advance_fov(FEEDBACK.zoom_return / 2.0)
	assert_float(_camera.get_fov()).is_less(_base_fov())
	_camera.advance_fov(FEEDBACK.zoom_return / 2.0)
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov(), TOLERANCE)


# --- A3: the mouth of the sheath glows on every milestone

func test_ac1037_every_milestone_pulses_a_brighter_light_at_the_sheath() -> void:
	var glow: SheatheChargeGlow = _sheathe.get_charge_glow()
	var light: OmniLight3D = glow.get_light()
	assert_bool(light.visible).is_false()
	_ability.try_cast()
	var energies: Array[float] = []
	for i: int in 3:
		_advance(1.0 if i > 0 else 1.0 + NUDGE)
		assert_bool(glow.is_pulsing()).is_true()
		assert_bool(light.visible).is_true()
		energies.append(light.light_energy)
		var mouth: Vector3 = (_player.get_node("WeaponMount") as WeaponMount).pivot.global_position
		assert_float(glow.global_position.distance_to(mouth)).is_less_equal(GLOW_REACH)
		var duration: float = SHEATHE_CONFIG.glow_full_duration if i == 2 else SHEATHE_CONFIG.glow_duration
		glow.advance(duration - NUDGE)
		assert_bool(light.visible).is_true()
		glow.advance(NUDGE * 2.0)
		assert_bool(glow.is_pulsing()).is_false()
		assert_bool(light.visible).is_false()
		assert_bool(glow.get_sphere().visible).is_false()
	assert_float(energies[0]).is_equal_approx(SHEATHE_CONFIG.glow_energy_base, TOLERANCE)
	assert_float(energies[1]).is_greater(energies[0])
	assert_float(energies[2]).is_equal_approx(SHEATHE_CONFIG.glow_energy_full, TOLERANCE)
	assert_float(energies[2]).is_greater(energies[1])
	assert_float(SHEATHE_CONFIG.glow_full_duration).is_greater(SHEATHE_CONFIG.glow_duration)


# --- A6: the body sinks deeper on every milestone

func _pose_at(clip: StringName) -> void:
	_humanoid.anim.play(clip, 0.0)
	_humanoid.anim.seek(0.0, true)


func test_ac1038_the_body_sinks_deeper_on_every_milestone_with_the_feet_planted() -> void:
	var clips: Array[StringName] = []
	_ability.try_cast()
	clips.append(_player.get_body_clip())
	for i: int in 3:
		_advance(1.0 if i > 0 else 1.0 + NUDGE)
		clips.append(_player.get_body_clip())
	assert_array(clips).is_equal([&"sheathe_charge", &"sheathe_charge_1", &"sheathe_charge_2", &"sheathe_charge_full"])
	assert_float(_sheathe.get_body_clip_blend(_ability)).is_equal(SHEATHE_CONFIG.charge_sink_blend)
	_ability.release_charge()
	assert_float(_sheathe.get_body_clip_blend(_ability)).is_equal(SHEATHE_CONFIG.release_body_blend)
	_ability.cancel_cast()
	# Each level lower than the previous one, with both ankles where the base
	# charge pose has them.
	_pose_at(SHEATHE_CONFIG.charge_body_clip)
	var hips: float = _humanoid.get_joint("hips").global_position.y
	var ankle_l: Vector3 = _humanoid.get_joint("ankle_l").global_position
	var ankle_r: Vector3 = _humanoid.get_joint("ankle_r").global_position
	for clip: StringName in SHEATHE_CONFIG.charge_sink_clips:
		_pose_at(clip)
		var lower: float = _humanoid.get_joint("hips").global_position.y
		assert_float(hips - lower).override_failure_message(String(clip)).is_greater_equal(LEVEL_DROP)
		hips = lower
		assert_float(_humanoid.get_joint("ankle_l").global_position.distance_to(ankle_l)).override_failure_message(String(clip)).is_less_equal(FOOT_TOLERANCE)
		assert_float(_humanoid.get_joint("ankle_r").global_position.distance_to(ankle_r)).override_failure_message(String(clip)).is_less_equal(FOOT_TOLERANCE)


func test_ac1038_a_faster_charge_sinks_to_the_first_level_then_the_full_one() -> void:
	for i: int in CHARGE_UPGRADE.max_stacks:
		_ability.add_upgrade(CHARGE_UPGRADE)
	var clips: Array[StringName] = []
	_ability.charge_milestone_reached.connect(func(_index: int, _full: bool) -> void: clips.append(_player.get_body_clip()))
	_ability.try_cast()
	_advance(_ability.get_stat(AbilityData.Stat.CHARGE_TIME) + STEP)
	assert_array(clips).is_equal([&"sheathe_charge_1", &"sheathe_charge_full"])


# --- B8 / B7: line first, then the pause, then the burst

func test_ac1039_the_release_hits_at_once_and_only_draws_the_line() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.0))
	var health: float = enemy.health.current_health
	var wind_cut: WindCutVfx = _sheathe.get_wind_cut()
	_charge_and_release()
	assert_float(enemy.health.current_health).is_less(health)
	var line: MeshInstance3D = wind_cut.get_line()
	assert_bool(line.visible).is_true()
	assert_bool(wind_cut.is_bursting()).is_false()
	assert_bool(wind_cut.get_sparks().emitting).is_false()
	wind_cut.advance(SHEATHE_CONFIG.strike_pause_at)
	var length: float = SHEATHE.hit_range
	assert_float(line.scale.z).is_equal_approx(length, TOLERANCE)
	assert_float(line.position.z).is_equal_approx(-length / 2.0, TOLERANCE)
	assert_float(line.position.y).is_less_equal(0.03)
	assert_bool(wind_cut.get_segment(WindCutVfx.WallSide.LEFT, 0).visible).is_false()
	assert_bool(wind_cut.get_crescent().visible).is_false()
	assert_bool(wind_cut.get_echo().visible).is_false()
	assert_bool(wind_cut.get_crack_piece(0).visible).is_false()
	_advance(SHEATHE_CONFIG.burst_at - NUDGE)
	assert_bool(wind_cut.is_bursting()).is_false()
	assert_bool(line.visible).is_true()


func test_ac1040_the_draw_holds_and_freezes_the_enemies_hit() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.0))
	var hitstop: HitstopComponent = _player.get_node("Hitstop") as HitstopComponent
	hitstop.set_physics_process(false)
	_charge_and_release()
	_advance(SHEATHE_CONFIG.strike_pause_at - NUDGE)
	assert_bool(hitstop.is_active()).is_false()
	assert_bool(enemy.is_in_hitlag()).is_false()
	_advance(NUDGE * 2.0)
	assert_bool(hitstop.is_active()).is_true()
	assert_float(_humanoid.anim.speed_scale).is_equal(0.0)
	assert_bool(enemy.is_in_hitlag()).is_true()
	hitstop.advance(SHEATHE_CONFIG.release_feel.hitlag - NUDGE)
	assert_bool(hitstop.is_active()).is_true()
	hitstop.advance(NUDGE * 2.0)
	assert_bool(hitstop.is_active()).is_false()
	assert_float(_humanoid.anim.speed_scale).is_greater(0.0)
	# The cast keeps its commitment.
	_advance(SHEATHE.cast_duration - SHEATHE_CONFIG.strike_pause_at - NUDGE * 3.0)
	assert_bool(_ability.is_casting()).is_true()
	_advance(NUDGE * 4.0)
	assert_bool(_ability.is_casting()).is_false()


func test_ac1040_the_draw_holds_even_when_nothing_is_hit() -> void:
	var hitstop: HitstopComponent = _player.get_node("Hitstop") as HitstopComponent
	hitstop.set_physics_process(false)
	_charge_and_release()
	_advance(SHEATHE_CONFIG.strike_pause_at + NUDGE)
	assert_bool(hitstop.is_active()).is_true()
	assert_float(_humanoid.anim.speed_scale).is_equal(0.0)


func test_ac1041_the_cut_bursts_shakes_and_kicks_the_view_wide() -> void:
	var wind_cut: WindCutVfx = _sheathe.get_wind_cut()
	(_player.get_node("Hitstop") as HitstopComponent).set_physics_process(false)
	_charge_and_release()
	_camera.advance_fov(FEEDBACK.zoom_blend)
	_advance(SHEATHE_CONFIG.burst_at - NUDGE)
	assert_int(_unleashed).is_equal(0)
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov() - FEEDBACK.zoom_full_deg, TOLERANCE)
	_advance(NUDGE * 2.0)
	assert_bool(wind_cut.is_bursting()).is_true()
	assert_bool(wind_cut.get_line().visible).is_false()
	assert_int(_unleashed).is_equal(1)
	assert_float(_camera.get_shake_strength()).is_equal_approx(SHEATHE_CONFIG.burst_feel.shake_strength, TOLERANCE)
	assert_float(_camera.get_fov_hold()).is_equal(0.0)
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov() + FEEDBACK.unleash_kick_deg, TOLERANCE)
	_camera.advance_fov(FEEDBACK.unleash_kick_return / 2.0)
	assert_float(_camera.get_fov()).is_between(_base_fov(), _base_fov() + FEEDBACK.unleash_kick_deg)
	_camera.advance_fov(FEEDBACK.unleash_kick_return / 2.0)
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov(), TOLERANCE)
	_advance(1.0)
	assert_int(_unleashed).is_equal(1)
	assert_int(_sheathe.get_release_stage()).is_equal(SheatheAbility.ReleaseStage.IDLE)


func test_ac1041_an_unleash_without_a_charge_still_kicks_the_view() -> void:
	_ability.report_charge_unleashed()
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov() + FEEDBACK.unleash_kick_deg, TOLERANCE)


func test_ac1042_a_dash_before_the_pause_leaves_the_burst_only_drawn() -> void:
	var wind_cut: WindCutVfx = _sheathe.get_wind_cut()
	var hitstop: HitstopComponent = _player.get_node("Hitstop") as HitstopComponent
	hitstop.set_physics_process(false)
	_charge_and_release()
	_camera.advance_fov(FEEDBACK.zoom_blend)
	_advance(STEP)
	_ability.cut_cast_by_dash()
	assert_float(_camera.get_fov_hold_target()).is_equal(0.0)
	_advance(SHEATHE_CONFIG.burst_at)
	assert_bool(hitstop.is_active()).is_false()
	assert_bool(wind_cut.is_bursting()).is_true()
	assert_int(_unleashed).is_equal(0)
	assert_float(_camera.get_shake_strength()).is_equal(0.0)
	_camera.advance_fov(FEEDBACK.zoom_return)
	assert_float(_camera.get_fov()).is_equal_approx(_base_fov(), TOLERANCE)


# --- Rules

func test_ac1048_sparks_dust_and_flash_wait_for_the_burst() -> void:
	var wind_cut: WindCutVfx = _sheathe.get_wind_cut()
	_charge_and_release()
	assert_bool(wind_cut.get_sparks().emitting).is_false()
	assert_bool(wind_cut.get_dust().emitting).is_false()
	assert_bool(wind_cut.get_flash().visible).is_false()
	assert_bool(wind_cut.get_flash_light().visible).is_false()
	_advance(SHEATHE_CONFIG.burst_at + NUDGE)
	assert_bool(wind_cut.get_sparks().emitting).is_true()
	assert_bool(wind_cut.get_dust().emitting).is_true()
	assert_bool(wind_cut.get_flash().visible).is_true()
	assert_bool(wind_cut.get_flash_light().visible).is_true()


func test_ac1049_the_charge_glow_reuses_its_nodes() -> void:
	var glow: SheatheChargeGlow = _sheathe.get_charge_glow()
	var children: int = glow.get_child_count()
	var light: OmniLight3D = glow.get_light()
	_charge_and_release()
	_advance(SHEATHE.cast_duration + STEP)
	_ability.reset_cooldown()
	_charge_and_release()
	assert_int(glow.get_child_count()).is_equal(children)
	assert_object(glow.get_light()).is_same(light)


func test_ac1050_time_scale_is_never_touched() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -2.0))
	_ability.try_cast()
	for i: int in int((SHEATHE.charge_time + STEP) / STEP):
		_ability.advance(STEP)
		assert_float(Engine.time_scale).is_equal(1.0)
	_ability.release_charge()
	for i: int in int((SHEATHE.cast_duration + STEP) / STEP):
		_ability.advance(STEP)
		assert_float(Engine.time_scale).is_equal(1.0)


func test_ac1051_the_glow_uses_the_shared_white_material_and_no_shader() -> void:
	var sphere: MeshInstance3D = _sheathe.get_charge_glow().get_sphere()
	assert_object(sphere.mesh.surface_get_material(0)).is_same(GLOW_MATERIAL)
	assert_object(sphere.material_override).is_null()
