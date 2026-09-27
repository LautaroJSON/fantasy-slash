extends GdUnitTestSuite
## The Spin's body, weapon, vortex and impact feedback, and the white area of
## the abilities on the ground (docs/specs/spin-visual-rework.md AC971–AC987).
## Poses are measured in the Visual's space (-Z forward, +X to the right).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const HUMANOID_SCENE: PackedScene = preload("res://entities/player/humanoid.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const SPIN_CONFIG: SpinConfig = preload("res://data/abilities/spin/spin_config.tres")
const VORTEX_CONFIG: SpinVortexConfig = preload("res://data/abilities/spin/spin_vortex_config.tres")
const RANGE_UPGRADE: AbilityUpgradeData = preload("res://data/abilities/spin/upgrades/range.tres")
const ANIMATION_CONFIG: PlayerAnimationConfig = preload("res://data/player/player_animation_config.tres")
const AREA_MATERIAL: StandardMaterial3D = preload("res://materials/attack_indicator_material.tres")
const SHEATHE_INDICATOR: AbilityIndicatorConfig = preload("res://data/abilities/sheathe/sheathe_indicator_config.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
const AIR_SLASH_INDICATOR: AbilityIndicatorConfig = preload("res://data/classes/berserker/air_slash_indicator_config.tres")
const ENEMY_HEALTH: float = 10000.0
const STEP: float = 0.05
const TOLERANCE: float = 0.0001
## AC972: pivot on the hand pose, in meters.
const GRIP_TOLERANCE: float = 0.001
## AC974: blade height band, torso capsule radius (as AC751) and sampling.
const BLADE_LOW: float = 0.6
const BLADE_HIGH: float = 1.4
const TORSO_RADIUS: float = 0.16
const SAMPLE_STEP: float = 0.05
## AC977: same comparison as AC786.
const LINK_DEGREES: float = 2.0
const LINK_METERS: float = 0.01
## AC979 / AC986: most opaque the area may be at rest and in a pulse.
const MAX_REST_ALPHA: float = 0.3
const MAX_PULSE_ALPHA: float = 0.5
## Sideways offset of the enemies in the dash path, so their bodies do not
## stop the dash; still well inside the slash band.
const IN_PATH_X: float = 0.8

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _spin: SpinAbility
var _humanoid: LowPolyHumanoid


func before_test() -> void:
	Input.action_release(&"dash")
	Input.action_release(&"move_forward")
	Session.character_class = BERSERKER
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_ability.equip(SPIN)
	_spin = _ability.get_behavior() as SpinAbility
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	await _physics_frames(20)


func after_test() -> void:
	Session.character_class = null
	Input.action_release(&"dash")
	Input.action_release(&"move_forward")


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Idle, very tough enemy (no target) at `offset` from the player.
func _spawn_idle_enemy(offset: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(_player.global_position + offset, null)
	enemy.health.setup(ENEMY_HEALTH, 0.0)
	return enemy


## Drives the cast by hand (the slot's own physics step is off) for determinism.
func _cast_by_hand() -> void:
	_ability.set_physics_process(false)
	assert_bool(_ability.try_cast()).is_true()


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


func _start_dash() -> void:
	Input.action_press(&"dash")
	await _physics_frames(2)
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()


func _wait_dash_end() -> void:
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await get_tree().physics_frame


func _clip() -> String:
	return String(_humanoid.anim.current_animation)


func _animator() -> PlayerAnimator:
	return _player.get_node("PlayerAnimator") as PlayerAnimator


func _mount() -> WeaponMount:
	return _player.get_node("WeaponMount") as WeaponMount


func _pivot() -> Node3D:
	return _player.get_node("Visual/SwordPivot") as Node3D


func _camera() -> ThirdPersonCamera:
	return _player.get_node("CameraRig") as ThirdPersonCamera


## Values of every value track of `animation` at `time`, by path (as AC786).
func _track_pose(animation: Animation, time: float) -> Dictionary:
	var pose: Dictionary = {}
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_VALUE:
			continue
		pose[String(animation.track_get_path(track))] = animation.value_track_interpolate(track, time)
	return pose


# --- Body and weapon

func test_ac971_the_berserker_has_the_spin_clips() -> void:
	var probe: LowPolyHumanoid = auto_free(HUMANOID_SCENE.instantiate() as LowPolyHumanoid)
	add_child(probe)
	var library: AnimationLibrary = probe.get_profile_library(&"berserker")
	assert_bool(library.has_animation(SPIN_CONFIG.body_clip)).is_true()
	assert_bool(library.has_animation(SPIN_CONFIG.dash_slash_body_clip)).is_true()
	var spin: Animation = library.get_animation(SPIN_CONFIG.body_clip)
	assert_int(spin.loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_int(library.get_animation(SPIN_CONFIG.dash_slash_body_clip).loop_mode).is_equal(Animation.LOOP_NONE)
	var time: float = 0.0
	while time <= spin.length:
		var pose: Dictionary = _track_pose(spin, time)
		assert_float(float(pose[".:left_hand_grip_weight"])).override_failure_message("left_grip at %.2f s" % time).is_equal_approx(1.0, TOLERANCE)
		time += SAMPLE_STEP


func test_ac972_the_body_spins_with_the_weapon_in_its_hands() -> void:
	assert_bool(_ability.try_cast()).is_true()
	await _physics_frames(int(ceil(ANIMATION_CONFIG.weapon_mount_blend * Engine.physics_ticks_per_second)) + 2)
	assert_str(_clip()).is_equal(String(SPIN_CONFIG.body_clip))
	assert_bool(_player.is_weapon_in_hand_cast()).is_true()
	await get_tree().process_frame
	var hand: Transform3D = _mount().get_hand_pose()
	assert_float(_pivot().global_position.distance_to(hand.origin)).is_less_equal(GRIP_TOLERANCE)


func test_ac973_swordswing_no_longer_holds_the_weapon() -> void:
	assert_bool(_ability.try_cast()).is_true()
	await _physics_frames(5)
	assert_bool(_player.sword_swing.is_active()).is_false()
	var names: PackedStringArray = PackedStringArray()
	for property: Dictionary in SPIN_CONFIG.get_property_list():
		names.append(property.name)
	for gone: String in ["blade_position", "blade_rotation", "dash_slash_arc_degrees", "dash_slash_sweep_duration"]:
		assert_bool(names.has(gone)).override_failure_message(gone).is_false()


func test_ac974_the_blade_is_level_outwards_and_clear_of_the_torso() -> void:
	_humanoid.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator().set_physics_process(false)
	var to_visual: Transform3D = (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()
	var sword: Node3D = _pivot().get_child(0) as Node3D
	var spin: Animation = _humanoid.anim.get_animation(SPIN_CONFIG.body_clip)
	var time: float = 0.0
	while time <= spin.length:
		_humanoid.anim.play(SPIN_CONFIG.body_clip, 0.0)
		_humanoid.anim.seek(time, true)
		_mount().update(1.0)
		var base: Vector3 = to_visual * (sword.get_node("TrailBase") as Node3D).global_position
		var tip: Vector3 = to_visual * (sword.get_node("TrailTip") as Node3D).global_position
		var grip: Vector3 = to_visual * _pivot().global_position
		var hips: Vector3 = to_visual * _humanoid.get_joint("hips").global_position
		var neck: Vector3 = to_visual * _humanoid.get_joint("neck").global_position
		var label: String = "spin at %.2f s" % time
		for point: Vector3 in [base, (base + tip) / 2.0, tip]:
			assert_float(point.y).override_failure_message(label).is_between(BLADE_LOW, BLADE_HIGH)
			assert_float(_segment_distance(point, hips, neck)).override_failure_message(label).is_greater(TORSO_RADIUS)
		assert_float(Vector2(tip.x, tip.z).length()).override_failure_message(label).is_greater(Vector2(grip.x, grip.z).length())
		time += SAMPLE_STEP


func test_ac975_out_of_the_spin_the_body_blends_back_slowly() -> void:
	_cast_by_hand()
	await _physics_frames(2)
	assert_str(_clip()).is_equal(String(SPIN_CONFIG.body_clip))
	assert_bool(_animator().get("_in_strike_pose")).is_true()
	_advance(_ability.get_stat(AbilityData.Stat.CAST_DURATION) + STEP)
	assert_bool(_ability.is_casting()).is_false()
	await _physics_frames(2)
	assert_str(_clip()).is_equal("idle")
	assert_bool(_animator().get("_in_strike_pose")).is_false()


# --- Dash slash

func test_ac976_the_dash_slash_plays_its_clip_with_the_weapon_in_hand() -> void:
	_cast_by_hand()
	await _start_dash()
	assert_str(_clip()).is_equal(String(SPIN_CONFIG.dash_slash_body_clip))
	var clip: Animation = _humanoid.anim.get_animation(SPIN_CONFIG.dash_slash_body_clip)
	assert_float(_humanoid.anim.speed_scale).is_equal_approx(clip.length / _player.dash.get_duration(), 0.001)
	assert_bool(_mount().is_hand_free()).is_true()
	await _wait_dash_end()
	await _start_dash_after_cooldown()
	assert_str(_clip()).is_equal(String(BERSERKER.dash.clip))


func _start_dash_after_cooldown() -> void:
	_player.dash.reset_cooldown()
	await _start_dash()


func test_ac977_the_dash_slash_ends_on_the_sprint_first_frame() -> void:
	var library: AnimationLibrary = _humanoid.get_profile_library(&"berserker")
	var slash: Animation = library.get_animation(SPIN_CONFIG.dash_slash_body_clip)
	var last: Dictionary = _track_pose(slash, slash.length)
	var first: Dictionary = _track_pose(library.get_animation(&"sprint"), 0.0)
	for path: String in first:
		var a: Variant = last.get(path)
		var b: Variant = first[path]
		var message: String = "%s: %s vs %s" % [path, a, b]
		if path.ends_with(":rotation"):
			var delta: Vector3 = ((a as Vector3) - (b as Vector3)).abs()
			assert_float(rad_to_deg(maxf(delta.x, maxf(delta.y, delta.z)))).override_failure_message(message).is_less_equal(LINK_DEGREES)
		elif path.ends_with(":position"):
			assert_float(((a as Vector3) - (b as Vector3)).length()).override_failure_message(message).is_less_equal(LINK_METERS)
		else:
			assert_float(float(a)).override_failure_message(message).is_equal_approx(float(b), 0.001)


func test_ac978_the_trail_follows_the_spin_and_its_dash_slash() -> void:
	var trail: WeaponTrail = _player.get_node("WeaponTrail") as WeaponTrail
	assert_bool(trail.is_emitting()).is_false()
	_cast_by_hand()
	assert_bool(trail.is_emitting()).is_true()
	await _start_dash()
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_spin.is_dash_slashing()).is_true()
	assert_bool(trail.is_emitting()).is_true()
	await _wait_dash_end()
	assert_bool(_spin.is_dash_slashing()).is_false()
	assert_bool(trail.is_emitting()).is_false()


# --- Area, pulse and dust

func test_ac979_the_white_area_shows_the_reach_and_follows_the_player() -> void:
	var vortex: SpinVortexVfx = _spin.get_vortex()
	assert_bool(vortex.is_showing()).is_false()
	assert_bool(vortex.visible).is_false()
	assert_object(vortex.area_material).is_same(AREA_MATERIAL)
	assert_object(AREA_MATERIAL.albedo_color).is_equal(Color(1, 1, 1, 1))
	assert_float(VORTEX_CONFIG.area_alpha).is_less_equal(MAX_REST_ALPHA)
	_cast_by_hand()
	assert_bool(vortex.is_showing()).is_true()
	assert_float(vortex.get_area_radius()).is_equal_approx(SPIN.hit_range, TOLERANCE)
	vortex.advance(VORTEX_CONFIG.area_fade_in)
	assert_float(vortex.get_area_alpha()).is_equal_approx(VORTEX_CONFIG.area_alpha, TOLERANCE)
	_player.global_position += Vector3(1.5, 0.0, -2.0)
	vortex.advance(0.01)
	assert_float(vortex.global_position.x).is_equal_approx(_player.global_position.x, TOLERANCE)
	assert_float(vortex.global_position.z).is_equal_approx(_player.global_position.z, TOLERANCE)
	_ability.add_upgrade(RANGE_UPGRADE)
	_advance(STEP)
	assert_float(vortex.get_area_radius()).is_equal_approx(SPIN.hit_range + RANGE_UPGRADE.amount, TOLERANCE)
	_advance(_ability.get_stat(AbilityData.Stat.CAST_DURATION) + STEP)
	assert_bool(_ability.is_casting()).is_false()
	vortex.advance(VORTEX_CONFIG.area_fade_out / 2.0)
	assert_bool(vortex.is_showing()).is_true()
	assert_float(vortex.get_area_alpha()).is_less(VORTEX_CONFIG.area_alpha)
	vortex.advance(VORTEX_CONFIG.area_fade_out)
	assert_bool(vortex.is_showing()).is_false()


func test_ac980_one_pulse_per_completed_turn_with_or_without_enemies() -> void:
	var vortex: SpinVortexVfx = _spin.get_vortex()
	var pulses: Array[int] = [0]
	vortex.pulsed.connect(func() -> void: pulses[0] += 1)
	assert_float(VORTEX_CONFIG.pulse_alpha).is_less_equal(MAX_PULSE_ALPHA)
	_cast_by_hand()
	var brightest: float = 0.0
	var left: float = _ability.get_stat(AbilityData.Stat.CAST_DURATION)
	while _ability.is_casting():
		_ability.advance(STEP)
		vortex.advance(STEP)
		brightest = maxf(brightest, vortex.get_area_alpha())
	var turns: int = floori(left / _ability.get_stat(AbilityData.Stat.TICK_INTERVAL) + TOLERANCE)
	assert_int(pulses[0]).is_equal(turns)
	assert_int(pulses[0]).is_equal(_spin.get_turns_done())
	assert_float(brightest).is_less_equal(MAX_PULSE_ALPHA)
	# 4 s at 0.8 s a turn: 5 pulses (the spec's example, with today's data).
	assert_float(SPIN.cast_duration).is_equal_approx(4.0, TOLERANCE)
	assert_float(SPIN.tick_interval).is_equal_approx(0.8, TOLERANCE)
	assert_int(pulses[0]).is_equal(5)


func test_ac981_the_dust_rises_only_while_spinning() -> void:
	var vortex: SpinVortexVfx = _spin.get_vortex()
	assert_bool(vortex.is_dust_emitting()).is_false()
	_cast_by_hand()
	assert_bool(vortex.is_dust_emitting()).is_true()
	_advance(_ability.get_stat(AbilityData.Stat.CAST_DURATION) + STEP)
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(vortex.is_dust_emitting()).is_false()


# --- Impact feedback

func test_ac982_a_turn_that_hits_shakes_the_camera_and_the_enemies() -> void:
	var tick: float = _ability.get_stat(AbilityData.Stat.TICK_INTERVAL)
	_cast_by_hand()
	_camera().stop_shake()
	_advance(tick + STEP)
	assert_float(_camera().get_shake_strength()).is_equal(0.0)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(2.0, 0.0, 0.0))
	_advance(tick)
	assert_float(_camera().get_shake_strength()).is_equal_approx(SPIN_CONFIG.turn_shake, TOLERANCE)
	assert_bool(enemy.is_in_hitlag()).is_true()


func test_ac983_the_player_never_pauses_during_the_turns() -> void:
	_spawn_idle_enemy(Vector3(2.0, 0.0, 0.0))
	var visual: Node3D = _player.get_node("Visual") as Node3D
	_cast_by_hand()
	await _physics_frames(2)
	var tick: float = _ability.get_stat(AbilityData.Stat.TICK_INTERVAL)
	_advance(tick + STEP)
	assert_bool(_spin.get_turns_done() == 1).is_true()
	assert_float(_humanoid.anim.speed_scale).is_greater(0.0)
	var yaw: float = visual.rotation.y
	_advance(STEP)
	assert_float(absf(angle_difference(yaw, visual.rotation.y))).is_equal_approx(TAU * STEP / tick, 0.001)


func test_ac984_the_dash_slash_shakes_and_pauses_the_clip_once() -> void:
	var enemies: Array[Enemy] = []
	for i: int in 3:
		enemies.append(_spawn_idle_enemy(Vector3(IN_PATH_X * (1 if i % 2 == 0 else -1), 0.0, -1.0 - i * 0.6)))
	_cast_by_hand()
	var held_frames: Array[int] = [0]
	var strongest: Array[float] = [0.0]
	await _start_dash()
	while _player.dash.is_dashing():
		if _animator().is_dash_clip_held():
			held_frames[0] += 1
		strongest[0] = maxf(strongest[0], _camera().get_shake_strength())
		await get_tree().physics_frame
	for enemy: Enemy in enemies:
		assert_bool(enemy.health.current_health < ENEMY_HEALTH).is_true()
	assert_float(strongest[0]).is_equal_approx(SPIN_CONFIG.dash_slash_shake, TOLERANCE)
	var frame: float = 1.0 / Engine.physics_ticks_per_second
	assert_float(held_frames[0] * frame).is_less_equal(SPIN_CONFIG.dash_slash_hitlag + frame)
	assert_float(held_frames[0] * frame).is_greater_equal(SPIN_CONFIG.dash_slash_hitlag - 2.0 * frame)


func test_ac984_every_slashed_enemy_freezes() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(IN_PATH_X, 0.0, -1.5))
	_cast_by_hand()
	await _start_dash()
	while _player.dash.is_dashing() and enemy.health.current_health >= ENEMY_HEALTH:
		await get_tree().physics_frame
	assert_bool(enemy.is_in_hitlag()).is_true()


func test_ac985_the_pause_does_not_change_the_dash() -> void:
	var start: Vector3 = _player.global_position
	await _start_dash_and_wait_from(start)
	var plain: float = _flat(_player.global_position - start)
	_spawn_idle_enemy(Vector3(IN_PATH_X, 0.0, -1.5))
	start = _player.global_position
	_player.dash.reset_cooldown()
	_cast_by_hand()
	var frames: Array[int] = [0]
	var ended_on_last_frame: Array[bool] = [false]
	await _start_dash()
	while _player.dash.is_dashing():
		frames[0] += 1
		var clip_left: float = _humanoid.anim.current_animation_length - _humanoid.anim.current_animation_position
		ended_on_last_frame[0] = clip_left <= 2.0 / Engine.physics_ticks_per_second * _humanoid.anim.speed_scale + 0.01
		await get_tree().physics_frame
	assert_float(_flat(_player.global_position - start)).is_equal_approx(plain, 0.15)
	assert_bool(ended_on_last_frame[0]).is_true()


func _start_dash_and_wait_from(_start: Vector3) -> void:
	await _start_dash()
	await _wait_dash_end()


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


# --- Indicators and text

func test_ac986_the_ability_areas_are_a_white_fill() -> void:
	assert_object(AREA_MATERIAL.albedo_color).is_equal(Color(1, 1, 1, 1))
	assert_int(AREA_MATERIAL.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_int(AREA_MATERIAL.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	var indicator: AbilityRectIndicator = auto_free(AbilityRectIndicator.new())
	indicator.config = SHEATHE_INDICATOR
	indicator.material = AREA_MATERIAL
	add_child(indicator)
	assert_int(indicator.get_child_count()).is_equal(1)
	indicator.show_rect(Vector3.ZERO, 0.0, 4.0, 1.5)
	assert_float(indicator.get_length()).is_equal_approx(4.0, TOLERANCE)
	assert_float(indicator.get_width()).is_equal_approx(1.5, TOLERANCE)
	assert_float(-indicator.get_fill().position.z).is_equal_approx(2.0, TOLERANCE)
	for config: AbilityIndicatorConfig in [SHEATHE_INDICATOR, AIR_SLASH_INDICATOR]:
		assert_float(1.0 - config.start_transparency).is_less_equal(MAX_REST_ALPHA)
		assert_float(1.0 - config.pulse_transparency).is_less_equal(MAX_PULSE_ALPHA)
	assert_float(1.0 - SHEATHE_CONFIG.full_charge_transparency).is_less_equal(MAX_PULSE_ALPHA)


func test_ac987_the_spin_text_matches_its_data() -> void:
	var text: String = SPIN.description
	var cooldown: float = maxf(SPIN.cooldown, SPIN.min_cooldown)
	assert_str(text).contains("%d s" % roundi(SPIN.cast_duration))
	assert_str(text).contains("una cada %s s" % str(SPIN.tick_interval))
	assert_str(text).contains("%d %% de tu daño" % roundi(SPIN.attack_scaling * 100.0))
	assert_float(SPIN.base_damage).is_equal(0.0)
	assert_str(text).contains("Radio: %s m" % str(SPIN.hit_range))
	assert_str(text).contains("Enfriamiento: %d s" % roundi(cooldown))


## Distance from a point to the segment a–b.
func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
