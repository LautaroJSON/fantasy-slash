extends GdUnitTestSuite
## Each class fights with its own animation profile, combo and hit lag
## (docs/specs/class-combat-identity.md, AC639–AC660 and AC678–AC682).

const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const KatanaParts := preload("res://test/helpers/katana_parts.gd")
const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
## Classes with their own profile (the spec lands one class at a time).
const CLASSES: Array[CharacterClassData] = [WARRIOR, BERSERKER, SAMURAI]
const LOOPING_CLIPS: Array[StringName] = [&"idle", &"run", &"jump_air"]
const NO_CRIT_ROLL: float = 0.99
const FRAME: float = 1.0 / 60.0
## Clip events vs step times (AC641).
const EVENT_TOLERANCE: float = 0.001
const TOLERANCE: float = 0.0001
## AC653: clip time between samples.
const SAMPLE_STEP: float = 1.0 / 30.0
## AC653: points checked along the blade (TrailBase → TrailTip).
const BLADE_SAMPLES: int = 12
## AC653: half size of the torso mesh in its joint's space (low_poly_humanoid.gd _torso()).
const TORSO_BOTTOM: float = -0.16
const TORSO_TOP: float = 0.372
const TORSO_HALF_WIDTH: float = 0.131
const TORSO_HALF_DEPTH: float = 0.08
## AC653: head center and radius in the neck joint's space.
const HEAD_CENTER: Vector3 = Vector3(0.0, 0.21, 0.0)
const HEAD_RADIUS: float = 0.2
## AC1240: how far the guard may sink into the (rough, spherical) head volume, in meters.
const GUARD_HEAD_GRAZE: float = 0.02
## AC678: the greatsword across the shoulders: its tip reaches this far to the
## left (m) and its blade rises at most this much (degrees) from horizontal.
const BERSERKER_TIP_LEFT: float = 1.0
const BERSERKER_BLADE_TILT: float = 30.0
## AC679: the left hand on the OffHand marker.
const HAND_ON_HILT: float = 0.001
## AC682: degrees the right wrist still is from the guard halfway through the exit blend.
const EXIT_BLEND_GAP: float = 5.0

## Designed identity per class (spec §3): strikes, idle and run periods, and
## the seconds from the start of attack_1 to its cancel point.
## Steps (clips) of each combo; the samurai finisher is two steps (auto_chain).
const STRIKES: Dictionary[String, int] = {"Guerrero": 4, "Berserker": 3, "Samurái": 5}
const IDLE_PERIOD: Dictionary[String, float] = {"Guerrero": 2.0, "Berserker": 1.0, "Samurái": 3.0}
const RUN_PERIOD: Dictionary[String, float] = {"Guerrero": 0.6, "Berserker": 0.72, "Samurái": 0.56}
const FIRST_CANCEL: Dictionary[String, float] = {"Guerrero": 0.22, "Berserker": 0.62, "Samurái": 0.22}

var _registry: EnemyRegistry
var _player: Player


func after_test() -> void:
	Session.character_class = null


func _spawn_player(character_class: CharacterClassData) -> void:
	Session.character_class = character_class
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


func _humanoid() -> LowPolyHumanoid:
	return ComboDriver.humanoid_of(_player)


func _library(character_class: CharacterClassData) -> AnimationLibrary:
	return _humanoid().get_profile_library(character_class.animation_profile)


## Copy of the class combo with only the strike `index`: no lunge, no hit lag.
func _single_strike_combo(character_class: CharacterClassData, index: int) -> AttackComboConfig:
	var combo: AttackComboConfig = character_class.combo.duplicate(true) as AttackComboConfig
	var step: AttackComboStep = combo.steps[index]
	step.lunge_distance = 0.0
	step.hitlag = 0.0
	combo.steps = [step]
	return combo


## Times of the method-track events of a clip, by event name.
func _events(clip: Animation) -> Dictionary[String, float]:
	var found: Dictionary[String, float] = {}
	for track: int in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key: int in clip.track_get_key_count(track):
			var args: Array = clip.method_track_get_params(track, key)
			found[String(args[0])] = clip.track_get_key_time(track, key)
	return found


## Vertical travel of the hips in a clip, in the humanoid's local meters.
func _hips_amplitude(clip: Animation, humanoid: LowPolyHumanoid) -> float:
	var path: String = String(humanoid.get_path_to(humanoid.get_joint("hips"))) + ":position"
	var track: int = clip.find_track(NodePath(path), Animation.TYPE_VALUE)
	var lowest: float = INF
	var highest: float = -INF
	for key: int in clip.track_get_key_count(track):
		var y: float = (clip.track_get_key_value(track, key) as Vector3).y
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
	return highest - lowest


func _advance_clip(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var step: float = minf(FRAME, left)
		_humanoid().anim.advance(step)
		_player.attack.advance(step)
		(_player.get_node("Hitstop") as HitstopComponent).advance(step)
		left -= step


# --- Asset and data

func test_ac639_every_profile_has_its_clips() -> void:
	_spawn_player(WARRIOR)
	for character_class: CharacterClassData in CLASSES:
		var library: AnimationLibrary = _library(character_class)
		assert_object(library).is_not_null()
		var clips: Array[StringName] = LowPolyHumanoid.LOCOMOTION_CLIPS.duplicate()
		for i: int in character_class.combo.steps.size():
			clips.append(StringName("attack_%d" % (i + 1)))
		for clip: StringName in clips:
			assert_bool(library.has_animation(clip)).override_failure_message("%s lacks %s" % [character_class.title, clip]).is_true()
			var looping: bool = library.get_animation(clip).loop_mode != Animation.LOOP_NONE
			assert_bool(looping).is_equal(clip in LOOPING_CLIPS)


func test_ac640_every_step_references_a_clip_of_its_profile() -> void:
	_spawn_player(WARRIOR)
	for character_class: CharacterClassData in CLASSES:
		for step: AttackComboStep in character_class.combo.steps:
			assert_bool(_library(character_class).has_animation(step.animation)).is_true()


func test_ac641_clip_events_match_the_step_times() -> void:
	_spawn_player(WARRIOR)
	for character_class: CharacterClassData in CLASSES:
		for step: AttackComboStep in character_class.combo.steps:
			var clip: Animation = _library(character_class).get_animation(step.animation)
			var events: Dictionary[String, float] = _events(clip)
			var label: String = "%s %s" % [character_class.title, step.animation]
			assert_float(events["hit_on"]).override_failure_message(label + " hit_on").is_equal_approx(step.hit_start, EVENT_TOLERANCE)
			assert_float(events["hit_off"]).override_failure_message(label + " hit_off").is_equal_approx(step.hit_end, EVENT_TOLERANCE)
			assert_float(events["combo"]).override_failure_message(label + " combo").is_equal_approx(step.cancel_point, EVENT_TOLERANCE)
			assert_float(events["end"]).override_failure_message(label + " end").is_equal_approx(step.end_time, EVENT_TOLERANCE)
			assert_float(clip.length).override_failure_message(label + " length").is_equal_approx(step.end_time, EVENT_TOLERANCE)
			assert_float(step.hit_start).is_greater(0.0)
			assert_float(step.hit_end).is_greater(step.hit_start)
			assert_float(step.cancel_point).is_greater_equal(step.hit_end)
			assert_float(step.end_time).is_greater(step.cancel_point)
			assert_float(step.lunge_end).override_failure_message(label + " lunge").is_less_equal(step.hit_start)


func test_ac642_the_libraries_are_built_once() -> void:
	_spawn_player(WARRIOR)
	var humanoid: LowPolyHumanoid = _humanoid()
	var built: Dictionary[StringName, AnimationLibrary] = {}
	for id: StringName in LowPolyHumanoid.PROFILES:
		built[id] = humanoid.get_profile_library(id)
	for i: int in 2:
		for character_class: CharacterClassData in [WARRIOR, BERSERKER, SAMURAI]:
			humanoid.set_profile(character_class.animation_profile)
			assert_object(humanoid.anim.get_animation_library(&"")).is_same(built[character_class.animation_profile])
	for id: StringName in LowPolyHumanoid.PROFILES:
		assert_int(humanoid.get_library_build_count(id)).is_equal(1)
		assert_object(humanoid.get_profile_library(id)).is_same(built[id])


func test_ac643_each_class_uses_its_profile_combo_and_hitstop() -> void:
	for character_class: CharacterClassData in [WARRIOR, BERSERKER, SAMURAI]:
		_spawn_player(character_class)
		assert_str(String(_humanoid().get_profile())).is_equal(String(character_class.animation_profile))
		assert_object(_humanoid().anim.get_animation_library(&"")).is_same(_library(character_class))
		assert_object(_player.attack.combo).is_same(character_class.combo)
		assert_object((_player.get_node("Hitstop") as HitstopComponent).config).is_same(character_class.hitstop)


## Taps the combo needs for a full cycle: one per step that does not chain on its own.
func _chain_points(combo: AttackComboConfig) -> int:
	var points: int = 0
	for step: AttackComboStep in combo.steps:
		if not step.auto_chain:
			points += 1
	return points


func _wait_for_combo_window() -> void:
	ComboDriver.advance_until(_player, func() -> bool: return _player.attack.get_state() == AttackComponent.ComboState.CHAIN_OPEN)


func test_ac644_each_combo_has_its_strikes_and_loops() -> void:
	for character_class: CharacterClassData in CLASSES:
		assert_int(character_class.combo.steps.size()).is_equal(STRIKES[character_class.title])
		_spawn_player(character_class)
		ComboDriver.drive_by_hand(_player)
		var started: Array[int] = []
		_player.attack.step_started.connect(func(index: int) -> void: started.append(index))
		_player.attack.request_attack()
		for i: int in _chain_points(character_class.combo):
			_wait_for_combo_window()
			_player.attack.request_attack()
		var expected: Array[int] = []
		for i: int in character_class.combo.steps.size():
			expected.append(i)
		expected.append(0)
		assert_array(started).override_failure_message(character_class.title).is_equal(expected)


func test_ac645_locomotion_differs_per_class() -> void:
	_spawn_player(WARRIOR)
	for character_class: CharacterClassData in CLASSES:
		var library: AnimationLibrary = _library(character_class)
		assert_float(library.get_animation(&"idle").length).is_equal_approx(IDLE_PERIOD[character_class.title], TOLERANCE)
		assert_float(library.get_animation(&"run").length).is_equal_approx(RUN_PERIOD[character_class.title], TOLERANCE)
		assert_float(_hips_amplitude(library.get_animation(&"idle"), _humanoid())).is_greater(0.0)
	# Breathing: the berserker heaves, the warrior breathes evenly, the samurai barely moves.
	var berserker: float = _hips_amplitude(_library(BERSERKER).get_animation(&"idle"), _humanoid())
	var warrior: float = _hips_amplitude(_library(WARRIOR).get_animation(&"idle"), _humanoid())
	var samurai: float = _hips_amplitude(_library(SAMURAI).get_animation(&"idle"), _humanoid())
	assert_float(berserker).is_greater(warrior)
	assert_float(warrior).is_greater(samurai)


# --- Strike gameplay

func test_ac646_the_step_times_drive_the_strike() -> void:
	_spawn_player(WARRIOR)
	ComboDriver.drive_by_hand(_player)
	var combo: AttackComboConfig = _single_strike_combo(WARRIOR, 0)
	var step: AttackComboStep = combo.steps[0]
	var clip_hit: float = step.hit_start
	step.hit_start += 0.05
	_player.attack.combo = combo
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var full: float = enemy.health.current_health
	_player.attack.try_attack_with_roll(NO_CRIT_ROLL)
	_advance_clip(clip_hit + FRAME)
	assert_float(enemy.health.current_health).is_equal_approx(full, TOLERANCE)
	_advance_clip(step.hit_start - clip_hit)
	assert_float(enemy.health.current_health).is_less(full)
	assert_bool(_player.attack.is_committed()).is_equal(_humanoid().anim.current_animation_position < step.cancel_point)
	_advance_clip(step.cancel_point - _humanoid().anim.current_animation_position + FRAME)
	assert_bool(_player.attack.is_committed()).is_false()
	assert_bool(_player.attack.is_attacking()).is_true()
	_advance_clip(step.end_time - _humanoid().anim.current_animation_position + FRAME)
	assert_bool(_player.attack.is_attacking()).is_false()


## Hits of strike `index` of the warrior against enemies at `positions`.
func _warrior_hits(index: int, positions: Array[Vector3], range_upgrade: float = 0.0) -> int:
	_spawn_player(WARRIOR)
	ComboDriver.drive_by_hand(_player)
	_player.attack.combo = _single_strike_combo(WARRIOR, index)
	if range_upgrade > 0.0:
		var upgrade := UpgradeData.new()
		upgrade.stat = PlayerStats.Stat.ATTACK_RANGE
		upgrade.amount = range_upgrade
		_player.stats.add_upgrade(upgrade)
	for position: Vector3 in positions:
		_spawn_enemy(position)
	var hits: Array[int] = [0]
	_player.attack.attacked.connect(func(count: int, _t: float, _c: bool) -> void: hits[0] = count)
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	return hits[0]


func test_ac647_the_thrust_reaches_farther_and_the_slash_wider() -> void:
	var slash: int = 1
	var finisher: int = WARRIOR.combo.steps.size() - 1
	# One enemy ahead (the aim), one at 30° off the front.
	var off_axis: Vector3 = Vector3(sin(deg_to_rad(30.0)), 0.0, -cos(deg_to_rad(30.0))) * 1.6
	var pair: Array[Vector3] = [Vector3(0.0, 0.0, -1.2), off_axis]
	assert_int(_warrior_hits(slash, pair)).is_equal(2)
	assert_int(_warrior_hits(finisher, pair)).is_equal(1)
	# Farther than ATTACK_RANGE (× 1.0) but inside ATTACK_RANGE × 1.2.
	# A base-size enemy has no hit padding (Enemy.get_hit_padding()).
	var padding: float = 0.0
	var attack_range: float = WARRIOR.base_stats.attack_range
	var far: Array[Vector3] = [Vector3(0.0, 0.0, -(attack_range * 1.1 + padding))]
	assert_int(_warrior_hits(slash, far)).is_equal(0)
	assert_int(_warrior_hits(finisher, far)).is_equal(1)
	# Out of reach of the finisher until an ATTACK_RANGE card.
	var farther: Array[Vector3] = [Vector3(0.0, 0.0, -(attack_range * 1.25 + padding))]
	assert_int(_warrior_hits(finisher, farther)).is_equal(0)
	assert_int(_warrior_hits(finisher, farther, 0.5)).is_equal(1)


func test_ac648_each_finisher_lunges_its_distance() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	for character_class: CharacterClassData in CLASSES:
		_spawn_player(character_class)
		var last: int = character_class.combo.steps.size() - 1
		var combo: AttackComboConfig = character_class.combo.duplicate(true) as AttackComboConfig
		combo.steps = [combo.steps[last]]
		_player.attack.combo = combo
		for i: int in 10:
			await get_tree().physics_frame
		var start: Vector3 = _player.global_position
		_player.attack.request_attack()
		var frames: int = 0
		while _player.attack.is_attacking() and frames < 240:
			await get_tree().physics_frame
			frames += 1
		var moved: float = Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()
		var expected: float = combo.steps[0].lunge_distance
		assert_float(moved).override_failure_message(character_class.title).is_equal_approx(expected, expected * 0.05)


func test_ac649_the_finisher_hit_lag_and_shake_come_from_its_step() -> void:
	for character_class: CharacterClassData in CLASSES:
		_spawn_player(character_class)
		ComboDriver.drive_by_hand(_player)
		var last: int = character_class.combo.steps.size() - 1
		var combo: AttackComboConfig = character_class.combo.duplicate(true) as AttackComboConfig
		combo.steps = [combo.steps[last]]
		combo.steps[0].lunge_distance = 0.0
		_player.attack.combo = combo
		var step: AttackComboStep = combo.steps[0]
		var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
		var hitstop: HitstopComponent = _player.get_node("Hitstop") as HitstopComponent
		var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
		ComboDriver.strike(_player, NO_CRIT_ROLL)
		hitstop.set_physics_process(false)
		assert_bool(hitstop.is_active()).is_true()
		assert_float(_humanoid().anim.speed_scale).is_equal(0.0)
		assert_float(camera.get_shake_strength()).is_equal_approx(step.shake_strength, TOLERANCE)
		# ComboDriver.strike already advanced the hit lag by one frame.
		hitstop.advance(step.hitlag - 2.0 * FRAME)
		assert_bool(hitstop.is_active()).is_true()
		hitstop.advance(2.0 * FRAME)
		assert_bool(hitstop.is_active()).is_false()
		# The enemy shakes with the class amplitude.
		var body: Node3D = enemy.get_node("Body") as Node3D
		var rest_x: float = body.position.x
		var widest: float = 0.0
		for i: int in 10:
			enemy._physics_process(0.005)
			widest = maxf(widest, absf(body.position.x - rest_x))
		var amplitude: float = character_class.hitstop.enemy_shake_amplitude
		assert_float(widest).is_greater(0.0)
		assert_float(widest).is_less_equal(amplitude + TOLERANCE)


func test_ac650_clips_play_at_speed_one_with_base_stats() -> void:
	for character_class: CharacterClassData in CLASSES:
		_spawn_player(character_class)
		assert_float(_player.attack.get_clip_speed()).is_equal_approx(1.0, TOLERANCE)
		var upgrade := UpgradeData.new()
		upgrade.stat = PlayerStats.Stat.ATTACK_SPEED
		upgrade.amount = 0.3
		_player.stats.add_upgrade(upgrade)
		assert_float(_player.attack.get_clip_speed()).is_greater(1.0)


func test_ac652_each_class_commits_its_first_strike() -> void:
	for character_class: CharacterClassData in CLASSES:
		_spawn_player(character_class)
		ComboDriver.drive_by_hand(_player)
		_player.attack.combo = _single_strike_combo(character_class, 0)
		_player.attack.request_attack()
		var elapsed: float = 0.0
		while _player.attack.is_committed() and elapsed < 2.0:
			_advance_clip(FRAME)
			elapsed += FRAME
		assert_float(elapsed).override_failure_message(character_class.title).is_equal_approx(FIRST_CANCEL[character_class.title], FRAME + TOLERANCE)


# --- Visual and regression

## Where the blade goes through the body ("torso" or "head", with the blade
## fraction from TrailBase), or "" when it stays outside.
func _blade_hits_body(humanoid: LowPolyHumanoid, base: Vector3, tip: Vector3) -> String:
	var to_torso: Transform3D = humanoid.get_joint("torso").global_transform.affine_inverse()
	var to_neck: Transform3D = humanoid.get_joint("neck").global_transform.affine_inverse()
	for i: int in BLADE_SAMPLES + 1:
		var fraction: float = float(i) / BLADE_SAMPLES
		var point: Vector3 = base.lerp(tip, fraction)
		var local: Vector3 = to_torso * point
		var ellipse: float = pow(local.x / TORSO_HALF_WIDTH, 2.0) + pow(local.z / TORSO_HALF_DEPTH, 2.0)
		if local.y >= TORSO_BOTTOM and local.y <= TORSO_TOP and ellipse < 1.0:
			return "torso at %.2f of the blade" % fraction
		if (to_neck * point).distance_to(HEAD_CENTER) < HEAD_RADIUS:
			return "head at %.2f of the blade" % fraction
	return ""


func test_ac653_the_weapon_never_goes_through_the_body() -> void:
	for character_class: CharacterClassData in CLASSES:
		_spawn_player(character_class)
		ComboDriver.drive_by_hand(_player)
		var humanoid: LowPolyHumanoid = _humanoid()
		var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
		var trail_base: Node3D = _player.get_node("Visual/SwordPivot").get_child(0).get_node("TrailBase") as Node3D
		var trail_tip: Node3D = _player.get_node("Visual/SwordPivot").get_child(0).get_node("TrailTip") as Node3D
		var library: AnimationLibrary = _library(character_class)
		for clip_name: StringName in library.get_animation_list():
			var clip: Animation = library.get_animation(clip_name)
			humanoid.anim.play(clip_name)
			var time: float = 0.0
			while time <= clip.length:
				# The charge crouch holds the katana in its sheath
				# (sheath-socket-hand-grip.md), and so does the frame of the
				# release (sheathe-release-animation.md: then it goes to the hand).
				# Adapted (sheathe-visual-rework.md): so do the deeper charge poses.
				var charging: bool = clip_name == SHEATHE_CONFIG.charge_body_clip or SHEATHE_CONFIG.charge_sink_clips.has(clip_name)
				var sheathed: bool = charging or (clip_name == SHEATHE_CONFIG.release_body_clip and is_zero_approx(time))
				mount.hold_in_sheath(sheathed)
				humanoid.anim.seek(time, true)
				mount.update(1.0)
				var inside: String = _blade_hits_body(humanoid, trail_base.global_position, trail_tip.global_position)
				assert_str(inside).override_failure_message("%s %s at %.2f s: the blade goes through the %s" % [character_class.title, clip_name, time, inside]).is_empty()
				time += SAMPLE_STEP


## AC1240 (docs/specs/katana-visual-rework.md): the tsuba and the seppa of the katana never go through
## the torso or the head in any clip of the Samurai (except the frames where the blade itself already does, AC653).
func test_ac1240_the_katana_guard_never_goes_through_the_body() -> void:
	_spawn_player(SAMURAI)
	ComboDriver.drive_by_hand(_player)
	var humanoid: LowPolyHumanoid = _humanoid()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	var model: MeshInstance3D = _player.get_node("Visual/SwordPivot").get_child(0).get_node("Model") as MeshInstance3D
	var guard: PackedVector3Array = KatanaParts.guard_points(model)
	var points: PackedVector3Array = guard
	var failures: Array[String] = []
	var library: AnimationLibrary = _library(SAMURAI)
	for clip_name: StringName in library.get_animation_list():
		var clip: Animation = library.get_animation(clip_name)
		humanoid.anim.play(clip_name)
		var time: float = 0.0
		while time <= clip.length:
			var charging: bool = clip_name == SHEATHE_CONFIG.charge_body_clip or SHEATHE_CONFIG.charge_sink_clips.has(clip_name)
			mount.hold_in_sheath(charging or (clip_name == SHEATHE_CONFIG.release_body_clip and is_zero_approx(time)))
			humanoid.anim.seek(time, true)
			mount.update(1.0)
			var to_torso: Transform3D = humanoid.get_joint("torso").global_transform.affine_inverse()
			var to_neck: Transform3D = humanoid.get_joint("neck").global_transform.affine_inverse()
			var trail_base: Node3D = model.get_parent().get_node("TrailBase") as Node3D
			var trail_tip: Node3D = model.get_parent().get_node("TrailTip") as Node3D
			if not _blade_hits_body(humanoid, trail_base.global_position, trail_tip.global_position).is_empty():
				time += SAMPLE_STEP
				continue
			for i: int in points.size():
				var world: Vector3 = (model.get_parent() as Node3D).global_transform * points[i]
				var local: Vector3 = to_torso * world
				var ellipse: float = pow(local.x / TORSO_HALF_WIDTH, 2.0) + pow(local.z / TORSO_HALF_DEPTH, 2.0)
				var in_torso: bool = local.y >= TORSO_BOTTOM and local.y <= TORSO_TOP and ellipse < 1.0
				var head_depth: float = HEAD_RADIUS - (to_neck * world).distance_to(HEAD_CENTER)
				var in_head: bool = head_depth > GUARD_HEAD_GRAZE
				if in_torso or in_head:
					failures.append("%s %.2f s: %s vertex %s in the %s" % [clip_name, time, "guard", points[i], "torso" if in_torso else "head (%.3f m deep)" % head_depth])
					break
			time += SAMPLE_STEP
	assert_array(failures).override_failure_message("%d frames: %s" % [failures.size(), "; ".join(failures.slice(0, 25))]).is_empty()


func test_ac654_the_trail_emits_during_every_strike() -> void:
	for character_class: CharacterClassData in CLASSES:
		_spawn_player(character_class)
		ComboDriver.drive_by_hand(_player)
		var trail: WeaponTrail = _player.get_node("WeaponTrail") as WeaponTrail
		var emitting: Array[bool] = [true]
		_player.attack.step_started.connect(func(_i: int) -> void: emitting[0] = emitting[0] and trail.is_emitting())
		_player.attack.request_attack()
		var taps: int = _chain_points(character_class.combo)
		for i: int in taps:
			assert_bool(trail.is_emitting()).is_true()
			_wait_for_combo_window()
			if i < taps - 1:
				_player.attack.request_attack()
		assert_bool(emitting[0]).is_true()
		ComboDriver.finish(_player)
		assert_bool(trail.is_emitting()).is_false()


func test_ac655_taking_damage_plays_the_class_hit_clip() -> void:
	for character_class: CharacterClassData in CLASSES:
		_spawn_player(character_class)
		_player.health.receive_hit(5.0)
		assert_str(String(_humanoid().anim.current_animation)).is_equal("hit")
		assert_object(_humanoid().anim.get_animation_library(&"")).is_same(_library(character_class))


# --- Samurai revision (AC659, AC660)

## A copy of the samurai combo with only its double finisher (attack_4 → attack_5).
func _double_finisher(auto_chain: bool) -> AttackComboConfig:
	var combo: AttackComboConfig = SAMURAI.combo.duplicate(true) as AttackComboConfig
	var rise: AttackComboStep = combo.steps[3]
	var fall: AttackComboStep = combo.steps[4]
	rise.auto_chain = auto_chain
	for step: AttackComboStep in [rise, fall]:
		step.lunge_distance = 0.0
		step.hitlag = 0.0
	combo.steps = [rise, fall]
	return combo


func test_ac659_an_auto_chained_strike_starts_the_next_one_alone() -> void:
	_spawn_player(SAMURAI)
	ComboDriver.drive_by_hand(_player)
	_player.attack.combo = _double_finisher(true)
	var started: Array[int] = []
	_player.attack.step_started.connect(func(index: int) -> void: started.append(index))
	var window_opened: Array[bool] = [false]
	_player.attack.request_attack()
	var elapsed: float = 0.0
	while started.size() < 2 and elapsed < 1.0:
		_advance_clip(FRAME)
		elapsed += FRAME
		window_opened[0] = window_opened[0] or _player.attack.get_state() == AttackComponent.ComboState.CHAIN_OPEN
	assert_array(started).is_equal([0, 1])
	assert_bool(window_opened[0]).is_false()
	assert_float(elapsed).is_equal_approx(_player.attack.combo.steps[0].cancel_point, FRAME + TOLERANCE)
	assert_bool(_player.attack.is_committed()).is_true()
	# The dash still cuts the second half.
	_player.attack.cancel()
	assert_bool(_player.attack.is_attacking()).is_false()


func test_ac659_without_auto_chain_the_combo_window_opens_as_always() -> void:
	_spawn_player(SAMURAI)
	ComboDriver.drive_by_hand(_player)
	_player.attack.combo = _double_finisher(false)
	var started: Array[int] = []
	_player.attack.step_started.connect(func(index: int) -> void: started.append(index))
	_player.attack.request_attack()
	_wait_for_combo_window()
	assert_array(started).is_equal([0])
	assert_int(_player.attack.get_state()).is_equal(AttackComponent.ComboState.CHAIN_OPEN)


func test_ac659_only_the_samurai_first_finisher_half_auto_chains() -> void:
	for character_class: CharacterClassData in [WARRIOR, BERSERKER, SAMURAI]:
		for i: int in character_class.combo.steps.size():
			var expected: bool = character_class == SAMURAI and i == 3
			assert_bool(character_class.combo.steps[i].auto_chain).is_equal(expected)


## Yaw of a joint's forward (-Z) relative to the player's Visual, in degrees.
func _yaw_from_front(joint: Node3D) -> float:
	var visual: Node3D = _player.get_node("Visual") as Node3D
	var forward: Vector3 = -joint.global_basis.z
	var front: Vector3 = -visual.global_basis.z
	return rad_to_deg(angle_difference(atan2(-front.x, -front.z), atan2(-forward.x, -forward.z)))


## Rewritten (docs/specs/samurai-rest-guard.md, AC735): the rest guard faces
## forward like the reference, no longer side-on.
func test_ac660_the_samurai_rests_facing_forward_looking_ahead() -> void:
	_spawn_player(SAMURAI)
	ComboDriver.drive_by_hand(_player)
	var humanoid: LowPolyHumanoid = _humanoid()
	humanoid.anim.play(&"idle")
	humanoid.anim.seek(0.0, true)
	assert_float(absf(_yaw_from_front(humanoid.get_joint("torso")))).is_less_equal(10.0)
	assert_float(absf(_yaw_from_front(humanoid.get_joint("neck")))).is_less_equal(10.0)


# --- Berserker revision (AC678–AC680)

## Weapon marker of the equipped class weapon (TrailBase, TrailTip, OffHand).
func _weapon_marker(marker: String) -> Node3D:
	return _player.get_node("Visual/SwordPivot").get_child(0).get_node(marker) as Node3D


func test_ac678_the_berserker_rests_the_greatsword_across_his_shoulders() -> void:
	_spawn_player(BERSERKER)
	ComboDriver.drive_by_hand(_player)
	var humanoid: LowPolyHumanoid = _humanoid()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	var to_visual: Transform3D = (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()
	for clip_name: StringName in [&"idle", &"run"]:
		var clip: Animation = humanoid.anim.get_animation(clip_name)
		humanoid.anim.play(clip_name)
		var time: float = 0.0
		while time <= clip.length:
			humanoid.anim.seek(time, true)
			mount.update(1.0)
			var label: String = "%s at %.2f s" % [clip_name, time]
			var hand: Vector3 = to_visual * (_player.get_node("Visual/SwordPivot") as Node3D).global_position
			var tip: Vector3 = to_visual * _weapon_marker("TrailTip").global_position
			var shoulder: Vector3 = to_visual * humanoid.get_joint("shoulder_r").global_position
			var neck: Vector3 = to_visual * humanoid.get_joint("neck").global_position
			# One-handed: the left hand has no target.
			assert_float(humanoid.left_hand_grip_weight).override_failure_message(label).is_zero()
			# The right hand is up by the head and the blade lies across the shoulders,
			# behind the neck, rising a little to the left (like the reference sketch).
			assert_float(hand.x).override_failure_message(label).is_greater(0.0)
			assert_float(hand.y - shoulder.y).override_failure_message(label).is_greater(0.1)
			assert_float(tip.x).override_failure_message(label).is_less(-BERSERKER_TIP_LEFT)
			var blade: Vector3 = tip - hand
			var tilt: float = rad_to_deg(atan2(blade.y, Vector2(blade.x, blade.z).length()))
			assert_float(tilt).override_failure_message(label).is_between(0.0, BERSERKER_BLADE_TILT)
			var behind: Vector3 = hand.lerp(tip, (neck.x - hand.x) / blade.x)
			assert_float(behind.z).override_failure_message(label).is_greater(neck.z)
			# The whole weapon, grip included, clears the head, the neck and the torso.
			var grip: Vector3 = (_player.get_node("Visual/SwordPivot") as Node3D).global_position
			assert_str(_blade_hits_body(humanoid, grip, _weapon_marker("TrailTip").global_position)).override_failure_message(label).is_empty()
			time += SAMPLE_STEP


func test_ac679_both_hands_hold_the_greatsword_at_every_impact() -> void:
	_spawn_player(BERSERKER)
	ComboDriver.drive_by_hand(_player)
	var humanoid: LowPolyHumanoid = _humanoid()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	var left: MeshInstance3D = humanoid.get_hand_mesh(LowPolyHumanoid.Hand.LEFT)
	for step: AttackComboStep in BERSERKER.combo.steps:
		humanoid.anim.play(step.animation)
		humanoid.anim.seek(step.hit_start, true)
		mount.update(1.0)
		var gap: float = left.global_position.distance_to(_weapon_marker("OffHand").global_position)
		assert_float(gap).override_failure_message("%s: the left hand is %.3f m from the hilt" % [step.animation, gap]).is_less_equal(HAND_ON_HILT)


func test_ac680_the_greatsword_never_goes_through_the_floor() -> void:
	_spawn_player(BERSERKER)
	ComboDriver.drive_by_hand(_player)
	var humanoid: LowPolyHumanoid = _humanoid()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	var to_visual: Transform3D = (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()
	for clip_name: StringName in humanoid.anim.get_animation_list():
		var clip: Animation = humanoid.anim.get_animation(clip_name)
		humanoid.anim.play(clip_name)
		var time: float = 0.0
		while time <= clip.length:
			humanoid.anim.seek(time, true)
			mount.update(1.0)
			var tip: Vector3 = to_visual * _weapon_marker("TrailTip").global_position
			assert_float(tip.y).override_failure_message("%s at %.2f s: the tip is %.2f m under the floor" % [clip_name, time, -tip.y]).is_greater_equal(0.0)
			time += SAMPLE_STEP


## Every track value of `clip` at `time`, keyed by track path.
func _pose_at(clip: Animation, time: float) -> Dictionary:
	var pose: Dictionary = {}
	for track: int in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_VALUE:
			pose[String(clip.track_get_path(track))] = clip.value_track_interpolate(track, time)
	return pose


func _assert_same_pose(a: Dictionary, b: Dictionary, label: String) -> void:
	for path: String in a:
		assert_bool(b.has(path)).override_failure_message("%s: %s missing" % [label, path]).is_true()
		var left: Variant = a[path]
		var right: Variant = b[path]
		var equal: bool = is_equal_approx(left, right) if left is float else (left as Vector3).is_equal_approx(right)
		assert_bool(equal).override_failure_message("%s: %s is %s and %s" % [label, path, left, right]).is_true()


func test_ac681_each_berserker_strike_ends_where_the_next_one_starts() -> void:
	_spawn_player(BERSERKER)
	var library: AnimationLibrary = _library(BERSERKER)
	var steps: Array[AttackComboStep] = BERSERKER.combo.steps
	for i: int in steps.size() - 1:
		var clip: Animation = library.get_animation(steps[i].animation)
		var next: Animation = library.get_animation(steps[i + 1].animation)
		var start: Dictionary = _pose_at(next, 0.0)
		# From the cancel point to the end of the clip the pose is the next strike's first frame.
		_assert_same_pose(_pose_at(clip, steps[i].cancel_point), start, "%s cancel point" % steps[i].animation)
		_assert_same_pose(_pose_at(clip, steps[i].end_time), start, "%s end" % steps[i].animation)


func test_ac682_leaving_a_strike_blends_slowly_into_the_guard() -> void:
	_spawn_player(BERSERKER)
	ComboDriver.drive_by_hand(_player)
	var humanoid: LowPolyHumanoid = _humanoid()
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	var animator: PlayerAnimator = _player.get_node("PlayerAnimator") as PlayerAnimator
	var to_visual: Transform3D = (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()
	var blend: float = animator.config.attack_exit_blend
	for step: AttackComboStep in BERSERKER.combo.steps:
		animator.play_attack(step.animation, 1.0)
		humanoid.anim.seek(step.end_time, true)
		var wrist_path: String = String(humanoid.get_path_to(humanoid.get_joint("wrist_r"))) + ":rotation"
		var strike_wrist: Vector3 = humanoid.get_joint("wrist_r").rotation
		var checked_halfway: bool = false
		animator.update()
		var guard_clip: Animation = humanoid.anim.get_animation(humanoid.anim.current_animation)
		assert_bool(PlayerAnimator.LOCOMOTION_CLIPS.has(humanoid.anim.current_animation)).is_true()
		# The finisher already ends in the guard: nothing to blend out of.
		checked_halfway = rad_to_deg(strike_wrist.distance_to(_pose_at(guard_clip, 0.0)[wrist_path])) <= EXIT_BLEND_GAP
		# The blend is slow and never drives the blade through the body or the floor.
		var time: float = 0.0
		while time < blend:
			humanoid.anim.advance(SAMPLE_STEP)
			mount.update(1.0)
			time += SAMPLE_STEP
			var label: String = "%s exit at %.2f s" % [step.animation, time]
			assert_str(_blade_hits_body(humanoid, _weapon_marker("TrailBase").global_position, _weapon_marker("TrailTip").global_position)).override_failure_message(label).is_empty()
			assert_float((to_visual * _weapon_marker("TrailTip").global_position).y).override_failure_message(label).is_greater_equal(0.0)
			if not checked_halfway and time >= blend * 0.5:
				# Halfway through the blend the hand is still far from the guard.
				checked_halfway = true
				var guard: Vector3 = _pose_at(guard_clip, time)[wrist_path]
				assert_float(rad_to_deg(humanoid.get_joint("wrist_r").rotation.distance_to(guard))).override_failure_message(label).is_greater(EXIT_BLEND_GAP)
		humanoid.anim.stop()
