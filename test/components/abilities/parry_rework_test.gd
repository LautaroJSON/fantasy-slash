extends GdUnitTestSuite
## docs/specs/parry-riposte-rework.md (AC1017–AC1032): the Parry's name, its
## snapping, growing shield, the thrust of every block, Contragolpe's
## empowered riposte (world freeze and 360° basic strike), Duel and Triumph,
## and Represalia gone.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const CONFIG: ParryConfig = preload("res://data/abilities/parry/parry_config.tres")
const RIPOSTE: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/riposte.tres")
const DUEL: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/duel.tres")
const CHALLENGED: DebuffData = preload("res://data/debuffs/challenged.tres")
const TRIUMPH: BuffData = preload("res://data/buffs/triumph.tres")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const TOLERANCE: float = 0.001
const SCALE_TOLERANCE: float = 0.02
const HIT: float = 20.0
const LETHAL: float = 100000.0
const FRAME: float = 1.0 / 60.0
## AC1018: farthest the shield may be from the block pose on the first frame,
## and least distance of the block pose from the rest pose, in meters.
const SNAP_GAP: float = 0.10
const REST_GAP: float = 0.30
## AC1019: least overshoot of the shield ahead of its settled pose, in meters.
const OVERSHOOT: float = 0.05
const OVERSHOOT_END: float = 0.06
const SETTLED_AT: float = 0.15
## AC1020: the hand holds the grip, in meters.
const GRIP_TOLERANCE: float = 0.001
## AC1026: an enemy just inside and one just outside the strike's radius.
const INSIDE: float = 0.2
const OUTSIDE: float = 0.3
## AC1029: wind-up hand and body, and the sweep, in meters and degrees.
const WINDUP_TIME: float = 0.2
const WINDUP_HAND_X: float = -0.05
const WINDUP_HAND_Y: float = 1.1
const WINDUP_LEAN: float = 20.0
const WINDUP_HEAD_DOWN: float = 15.0
const SWEEP_DEGREES: float = 200.0
const SWEEP_HEIGHT: float = 0.3
const TIP_Z: float = -1.26
const JOINT_DEGREES: float = 0.5
## AC1031: Retado and Triumph.
const CHALLENGED_SECONDS: float = 10.0
const TRIUMPH_STACKS: int = 5
const TRIUMPH_SECONDS: float = 15.0

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _humanoid: LowPolyHumanoid
var _to_visual: Transform3D


func before_test() -> void:
	Session.character_class = WARRIOR
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_player.health.setup(1000.0, 0.0)
	_ability = _player.basic_ability
	_ability.equip(PARRY)
	_ability.set_physics_process(false)
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	await _frames(10)
	_to_visual = (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()


func after_test() -> void:
	Session.character_class = null


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _spawn(at: Vector3, stats: EnemyStats = GRUNT) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	enemy.health.setup(1000.0, 0.0)
	return enemy


func _behavior() -> ParryAbility:
	return _ability.get_behavior() as ParryAbility


func _guard() -> ShieldGuard:
	return _player.get_node("ShieldGuard") as ShieldGuard


func _shield_point(marker: String) -> Vector3:
	return _to_visual * (_player.get_shield().get_node(marker) as Node3D).global_position


## Poses the humanoid on a clip, by hand, with the weapon mounted.
func _pose(clip: StringName, time: float) -> void:
	_humanoid.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	(_player.get_node("PlayerAnimator") as PlayerAnimator).set_physics_process(false)
	_humanoid.anim.play(clip, 0.0)
	_humanoid.anim.seek(time, true)
	(_player.get_node("WeaponMount") as WeaponMount).update(1.0)


## Casts the parry with Contragolpe and blocks `attacker`: the empowered riposte starts.
func _empowered_by(attacker: Enemy) -> void:
	_player.apply_upgrade(RIPOSTE)
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)


# --- Name

func test_ac1017_the_ability_is_called_parry() -> void:
	assert_str(PARRY.title).is_equal("Parry")
	var found := PackedStringArray()
	_files("res://data", found)
	for path: String in found:
		var text: String = FileAccess.get_file_as_string(path)
		assert_bool(text.contains("Parada") or text.contains("Represalia")).override_failure_message(path).is_false()


func _files(dir_path: String, found: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_files(dir_path.path_join(sub), found)
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "tres":
			found.append(dir_path.path_join(file))


# --- The shield

func test_ac1018_the_shield_snaps_in_front() -> void:
	_pose(&"idle", 0.0)
	var rest: Vector3 = _shield_point("Center")
	_pose(CONFIG.parry_body_clip, CONFIG.shield_settle_time)
	var block: Vector3 = _shield_point("Center")
	assert_float(rest.distance_to(block)).is_greater(REST_GAP)
	# The animator enters the window's clip without blending.
	_pose(&"idle", 0.0)
	assert_bool(_ability.try_cast()).is_true()
	assert_float(_player.get_body_clip_blend()).is_equal_approx(CONFIG.parry_enter_blend, TOLERANCE)
	(_player.get_node("PlayerAnimator") as PlayerAnimator).update()
	_humanoid.anim.advance(FRAME)
	(_player.get_node("WeaponMount") as WeaponMount).update(FRAME)
	assert_str(String(_humanoid.anim.current_animation)).is_equal(String(CONFIG.parry_body_clip))
	assert_float(_shield_point("Center").distance_to(block)).is_less_equal(SNAP_GAP)


func test_ac1019_the_shield_overshoots_then_settles() -> void:
	_pose(CONFIG.parry_body_clip, SETTLED_AT)
	var settled: float = _shield_point("Center").z
	var ahead: float = 0.0
	var time: float = 0.0
	while time <= OVERSHOOT_END:
		_pose(CONFIG.parry_body_clip, time)
		ahead = maxf(ahead, settled - _shield_point("Center").z)
		time += FRAME
	assert_float(ahead).is_greater_equal(OVERSHOOT)


func test_ac1020_the_shield_grows_and_shrinks_back() -> void:
	var guard: ShieldGuard = _guard()
	guard.set_process(false)
	assert_bool(_ability.try_cast()).is_true()
	guard.advance_shield(CONFIG.shield_pop_time)
	assert_float(guard.get_shield_scale()).is_equal_approx(CONFIG.shield_pop_scale, SCALE_TOLERANCE)
	guard.advance_shield(CONFIG.shield_settle_time - CONFIG.shield_pop_time)
	assert_float(guard.get_shield_scale()).is_equal_approx(CONFIG.shield_hold_scale, SCALE_TOLERANCE)
	_pose(CONFIG.parry_body_clip, SETTLED_AT)
	var hand: MeshInstance3D = _humanoid.get_hand_mesh(LowPolyHumanoid.Hand.LEFT)
	var grip: Node3D = _player.get_shield().get_node("Grip") as Node3D
	assert_float(hand.global_position.distance_to(grip.global_position)).is_less_equal(GRIP_TOLERANCE)
	_ability.advance(PARRY.cast_duration)  # the window ends: the shield lowers
	assert_bool(guard.is_raised()).is_false()
	guard.advance_shield(CONFIG.shield_shrink_time)
	assert_float(guard.get_shield_scale()).is_equal_approx(1.0, TOLERANCE)
	# A dash that cuts the window also shrinks it.
	_ability.advance(CONFIG.whiff_recovery)
	_ability.reset_cooldown()
	assert_bool(_ability.try_cast()).is_true()
	guard.advance_shield(CONFIG.shield_settle_time)
	_ability.cut_cast_by_dash()
	guard.advance_shield(CONFIG.shield_shrink_time)
	assert_float(guard.get_shield_scale()).is_equal_approx(1.0, TOLERANCE)


func test_ac1021_the_size_does_not_change_the_block() -> void:
	var guard: ShieldGuard = _guard()
	guard.set_process(false)
	var edge: float = deg_to_rad(CONFIG.guard_arc_degrees * 0.5 + 10.0)
	var outside: Enemy = _spawn(Vector3(-sin(edge), 0.0, -cos(edge)) * 2.0)
	var front: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	assert_bool(_ability.try_cast()).is_true()
	guard.advance_shield(CONFIG.shield_settle_time)
	assert_float(guard.get_shield_scale()).is_equal_approx(CONFIG.shield_hold_scale, SCALE_TOLERANCE)
	assert_float(_player.health.receive_hit_from(HIT, outside)).is_equal_approx(HIT, TOLERANCE)
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal(0.0)


# --- The thrust of every block

func test_ac1022_every_block_thrusts_as_an_ability() -> void:
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	var ability_hits: Array[Enemy] = []
	var basic_hits: Array[Enemy] = []
	_ability.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: ability_hits.append(enemy))
	_player.attack.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: basic_hits.append(enemy))
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	assert_int(_behavior().get_state()).is_equal(ParryAbility.State.RIPOSTE)
	assert_bool(_player.health.is_invulnerable).is_true()
	assert_float(_ability.get_cooldown_remaining()).is_equal_approx(CONFIG.success_cooldown, TOLERANCE)
	_ability.advance(CONFIG.riposte_hit_time)
	assert_array(ability_hits).contains([attacker])
	assert_array(basic_hits).is_empty()


func test_ac1023_no_more_shield_push() -> void:
	assert_bool(ParryAbility.State.keys().has("SUCCESS")).is_false()
	assert_bool(_humanoid.anim.has_animation(&"shield_parry_success")).is_false()


# --- The empowered riposte

func test_ac1024_contragolpe_renews_the_cooldown_and_makes_the_player_immortal() -> void:
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	var behind: Enemy = _spawn(Vector3(0.0, 0.0, 4.0))
	_empowered_by(attacker)
	assert_float(_ability.get_cooldown_remaining()).is_equal(0.0)
	assert_int(_behavior().get_state()).is_equal(ParryAbility.State.EMPOWERED)
	assert_str(String(_ability.get_body_clip())).is_equal(String(CONFIG.empowered_body_clip))
	assert_float(_ability.get_cast_remaining()).is_equal_approx(CONFIG.empowered_duration, TOLERANCE)
	var step: float = 0.1
	var elapsed: float = 0.0
	while elapsed < CONFIG.empowered_duration - step:
		_ability.advance(step)
		elapsed += step
		assert_float(_player.health.receive_hit_from(HIT, behind)).override_failure_message("at %.1f s" % elapsed).is_equal(0.0)
	# A dash cannot cut it until the strike is over, then it can.
	_ability.reset_cooldown()
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	assert_bool(_ability.dash_cancels_cast()).is_false()
	_ability.advance(CONFIG.empowered_dash_lock)
	assert_bool(_ability.dash_cancels_cast()).is_true()
	_ability.advance(CONFIG.empowered_duration)
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_player.health.is_invulnerable).is_false()


func test_ac1025_the_world_freezes_without_time_scale() -> void:
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	var chaser: Enemy = _spawn(Vector3(0.0, 0.0, 8.0))
	chaser.activate(Vector3(0.0, 0.0, 8.0), _player)
	var boss: Enemy = _spawn(Vector3(6.0, 0.0, 0.0), VERDUGO)
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	await _frames(20)  # the chaser starts moving
	_empowered_by(attacker)
	var at: Vector3 = chaser.global_position
	for enemy: Enemy in [attacker, chaser, boss]:
		assert_bool(enemy.is_time_frozen()).is_true()
	assert_float(camera.get_fov()).is_less(camera.get_base_fov())
	assert_float(camera.get_shake_strength()).is_greater(0.0)
	assert_float(Engine.time_scale).is_equal(1.0)
	await _frames(roundi(CONFIG.empowered_freeze * 60.0) - 3)
	assert_bool(chaser.is_time_frozen()).is_true()
	assert_float(chaser.global_position.distance_to(at)).is_less(TOLERANCE)
	await _frames(6)
	assert_bool(chaser.is_time_frozen()).is_false()


func test_ac1026_the_strike_hits_all_around() -> void:
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	var radius: float = _player.stats.get_stat(PlayerStats.Stat.ATTACK_RANGE) * CONFIG.empowered_range_scale
	var near: Array[Enemy] = [
		_spawn(Vector3(-(radius - INSIDE), 0.0, 0.0)),
		_spawn(Vector3(0.0, 0.0, radius - INSIDE)),
		_spawn(Vector3(radius - INSIDE, 0.0, 0.0)),
	]
	var far: Enemy = _spawn(Vector3(0.0, 0.0, -(radius + OUTSIDE)))
	var hits: Array[Enemy] = []
	_player.attack.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: hits.append(enemy))
	_empowered_by(attacker)
	_ability.advance(CONFIG.empowered_hit_time)
	for enemy: Enemy in near:
		assert_int(hits.count(enemy)).is_equal(1)
	assert_int(hits.count(attacker)).is_equal(1)
	assert_int(hits.count(far)).is_equal(0)
	_ability.advance(CONFIG.empowered_duration - CONFIG.empowered_hit_time)
	assert_int(hits.size()).is_equal(4)


func test_ac1027_the_strike_counts_as_a_basic_attack() -> void:
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	var ability_hits: Array[Enemy] = []
	var applied: Array[float] = []
	var strikes: Array[int] = []
	_ability.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: ability_hits.append(enemy))
	_player.attack.enemy_hit.connect(func(_e: Enemy, amount: float, _c: bool) -> void: applied.append(amount))
	_player.attack.attacked.connect(func(count: int, _t: float, _c: bool) -> void: strikes.append(count))
	_player.health.receive_hit(300.0)
	_empowered_by(attacker)
	var health_before: float = _player.health.current_health
	_ability.advance(CONFIG.empowered_hit_time)
	var stats: StatsComponent = _player.stats
	var base: float = CONFIG.empowered_damage_multiplier * DamageMath.outgoing(
		stats.get_stat(PlayerStats.Stat.DAMAGE), stats.get_stat(PlayerStats.Stat.DAMAGE_BONUS), false, stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	var crit: float = CONFIG.empowered_damage_multiplier * DamageMath.outgoing(
		stats.get_stat(PlayerStats.Stat.DAMAGE), stats.get_stat(PlayerStats.Stat.DAMAGE_BONUS), true, stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	assert_int(applied.size()).is_equal(1)
	assert_bool(is_equal_approx(applied[0], base) or is_equal_approx(applied[0], crit)).override_failure_message("%f vs %f / %f" % [applied[0], base, crit]).is_true()
	assert_array(strikes).is_equal([1])
	assert_array(ability_hits).is_empty()
	var lifesteal: float = stats.get_stat(PlayerStats.Stat.LIFESTEAL)
	assert_float(_player.health.current_health - health_before).is_equal_approx(applied[0] * lifesteal, TOLERANCE)


func test_ac1028_duel_marks_the_struck_and_a_kill_grants_triumph() -> void:
	_player.apply_upgrade(DUEL)
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	var bystander: Enemy = _spawn(Vector3(1.5, 0.0, 0.0))
	var weak: Enemy = _spawn(Vector3(-1.5, 0.0, 0.0))
	weak.health.setup(1.0, 0.0)
	_empowered_by(attacker)
	_ability.advance(CONFIG.empowered_hit_time)
	assert_bool(bystander.debuffs.has_debuff(CHALLENGED.id)).is_true()
	assert_bool(weak.health.is_dead()).is_true()
	assert_int(_ability.buffs.get_stacks(TRIUMPH.id)).is_equal(1)


func test_ac1029_the_strike_animation() -> void:
	var clip: StringName = CONFIG.empowered_body_clip
	_pose(clip, WINDUP_TIME)
	var hand: Vector3 = _to_visual * _humanoid.get_hand_mesh(LowPolyHumanoid.Hand.RIGHT).global_position
	assert_float(hand.x).is_less(WINDUP_HAND_X)
	assert_float(hand.y).is_greater_equal(WINDUP_HAND_Y)
	var torso: Basis = (_to_visual.basis * _humanoid.get_joint("torso").global_basis).orthonormalized()
	assert_float(rad_to_deg(torso.y.angle_to(Vector3.UP))).is_greater_equal(WINDUP_LEAN)
	var gaze: Vector3 = -(_to_visual.basis * _humanoid.get_joint("neck").global_basis).orthonormalized().z
	assert_float(rad_to_deg(-asin(gaze.y))).is_greater_equal(WINDUP_HEAD_DOWN)
	# The sweep: the tip turns around the body at a steady height.
	var pivot: Node3D = _player.get_node("Visual/SwordPivot") as Node3D
	var turned: float = 0.0
	var last: float = NAN
	var low: float = INF
	var high: float = -INF
	var time: float = CONFIG.empowered_trail_start
	while time <= CONFIG.empowered_trail_end + TOLERANCE:
		_pose(clip, time)
		var tip: Vector3 = _to_visual * (pivot.global_transform * Vector3(0.0, 0.0, TIP_Z))
		var azimuth: float = rad_to_deg(atan2(tip.x, -tip.z))
		if not is_nan(last):
			turned += wrapf(azimuth - last, -180.0, 180.0)
		last = azimuth
		low = minf(low, tip.y)
		high = maxf(high, tip.y)
		time += FRAME
	assert_float(turned).is_greater_equal(SWEEP_DEGREES)
	assert_float(high - low).is_less_equal(SWEEP_HEIGHT * 2.0)
	# Ends in the rest pose.
	_pose(&"idle", 0.0)
	var rest: Vector3 = _humanoid.get_joint("shoulder_r").rotation_degrees
	_pose(clip, _humanoid.anim.get_animation(clip).length)
	var end: Vector3 = _humanoid.get_joint("shoulder_r").rotation_degrees
	assert_float((end - rest).length()).is_less_equal(JOINT_DEGREES)


func test_ac1029_the_trail_only_while_sweeping() -> void:
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	_empowered_by(attacker)
	assert_bool(_behavior().trails_while_casting(_ability)).is_false()
	_ability.advance(CONFIG.empowered_trail_start + FRAME)
	assert_bool(_behavior().trails_while_casting(_ability)).is_true()
	_ability.advance(CONFIG.empowered_trail_end - CONFIG.empowered_trail_start)
	assert_bool(_behavior().trails_while_casting(_ability)).is_false()


func test_ac1030_the_circular_slash_vfx() -> void:
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	var vfx: CircleSlashVfx = _behavior().get_slash_vfx()
	vfx.set_process(false)
	assert_bool(vfx.is_playing()).is_false()
	_empowered_by(attacker)
	_ability.advance(CONFIG.empowered_trail_start + FRAME)
	assert_bool(vfx.is_playing()).is_true()
	vfx.advance(vfx.config.sweep_duration)
	assert_float(vfx.get_head_degrees()).is_equal_approx(360.0, TOLERANCE)
	assert_float(vfx.config.head_alpha).is_less_equal(0.5)
	var material: StandardMaterial3D = vfx.config.material
	assert_int(material.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_that(material.albedo_color).is_equal(Color(1, 1, 1))
	assert_str(material.resource_path).is_not_empty()
	vfx.advance(vfx.config.fade_duration)
	assert_bool(vfx.is_playing()).is_false()


# --- Duel data and cleanup

func test_ac1031_duel_and_triumph_values() -> void:
	assert_float(CHALLENGED.duration).is_equal_approx(CHALLENGED_SECONDS, TOLERANCE)
	assert_int(TRIUMPH.max_stacks).is_equal(TRIUMPH_STACKS)
	assert_float(TRIUMPH.stack_duration).is_equal_approx(TRIUMPH_SECONDS, TOLERANCE)
	for i: int in TRIUMPH_STACKS + 1:
		_ability.buffs.add_stack(TRIUMPH)
	assert_int(_ability.buffs.get_stacks(TRIUMPH.id)).is_equal(TRIUMPH_STACKS)
	_ability.buffs.advance(TRIUMPH_SECONDS + 0.1)
	assert_int(_ability.buffs.get_stacks(TRIUMPH.id)).is_equal(0)


func test_ac1032_represalia_is_gone() -> void:
	assert_bool(FileAccess.file_exists("res://data/abilities/parry/unique/retribution.tres")).is_false()
	var ids: Array[StringName] = []
	for unique: AbilityUniqueUpgradeData in PARRY.unique_upgrades:
		ids.append(unique.id)
	assert_array(ids).is_equal([&"riposte", &"duel"])
	var code: String = FileAccess.get_file_as_string("res://components/abilities/parry_ability.gd")
	assert_bool(code.contains("retribution") or code.contains("RETRIBUTION")).is_false()
