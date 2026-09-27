extends GdUnitTestSuite
## Dash turn, clips and their link with the sprint (docs/specs/dash-feel.md):
## AC782-AC787.

const TestWorld := preload("res://test/helpers/test_world.gd")
const ProfileWithout := preload("res://test/helpers/profile_without.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const HUMANOID_SCENE: PackedScene = preload("res://entities/player/humanoid.tscn")
const CATALOG: ClassCatalog = preload("res://data/classes/class_catalog.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const CONFIG: PlayerAnimationConfig = preload("res://data/player/player_animation_config.tres")
const ACTIONS: Array[StringName] = [&"move_forward", &"move_right", &"dash"]
## Key fractions of the dash template (§2.2).
const KEY_FRACTIONS: Array[float] = [0.0, 0.35, 1.0]
const KEY_TOLERANCE: float = 0.08
## Link with the sprint (§2.3): degrees and meters.
const LINK_DEGREES: float = 2.0
const LINK_METERS: float = 0.01

var _player: Player
var _humanoid: LowPolyHumanoid


func after_test() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)
	Session.character_class = null


func _spawn(character_class: CharacterClassData = SAMURAI) -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(200.0))
	add_child(floor_body)
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	Session.character_class = character_class
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = registry
	add_child(_player)
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	await _physics_frames(10)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _tap_dash() -> void:
	Input.action_press(&"dash")
	await _physics_frames(2)
	Input.action_release(&"dash")


func _wait_dash_end() -> void:
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await get_tree().physics_frame


func _clip() -> String:
	return String(_humanoid.anim.current_animation)


func _visual() -> Node3D:
	return _player.get_node("Visual") as Node3D


## Pose of `clip` at `time`: joint rotations (radians) and hips position, read
## from the clip's tracks.
func _pose(animation: Animation, time: float) -> Dictionary:
	var pose: Dictionary = {}
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_VALUE:
			continue
		pose[String(animation.track_get_path(track))] = animation.value_track_interpolate(track, time)
	return pose


func test_ac782_the_body_turns_to_the_dash_direction() -> void:
	await _spawn()
	var before: float = _visual().rotation.y
	await _tap_dash()
	assert_float(_visual().rotation.y).is_equal_approx(before, 0.01)
	await _wait_dash_end()
	while _player.dash.get_cooldown_remaining() > 0.0:
		await get_tree().physics_frame
	Input.action_press(&"move_right")
	Input.action_press(&"dash")
	await _physics_frames(2)
	assert_bool(_player.dash.is_dashing()).is_true()
	var direction: Vector3 = _player.dash.get_direction()
	var facing: Vector3 = -_visual().global_basis.z
	assert_float(Vector3(facing.x, 0.0, facing.z).normalized().dot(direction)).is_greater(0.999)


func test_ac783_every_class_has_its_dash_clip() -> void:
	var probe: LowPolyHumanoid = auto_free(HUMANOID_SCENE.instantiate() as LowPolyHumanoid)
	add_child(probe)
	for character_class: CharacterClassData in CATALOG.classes:
		var library: AnimationLibrary = probe.get_profile_library(character_class.animation_profile)
		assert_bool(library.has_animation(&"dash")).override_failure_message(character_class.title).is_true()
		var clip: Animation = library.get_animation(&"dash")
		assert_int(clip.loop_mode).is_equal(Animation.LOOP_NONE)
		assert_float(clip.length).is_between(0.15, 0.35)
		var hips_track: int = clip.find_track(NodePath(String(probe.get_path_to(probe.get_joint("hips"))) + ":rotation"), Animation.TYPE_VALUE)
		assert_int(hips_track).is_not_equal(-1)
		for fraction: float in KEY_FRACTIONS:
			var found: bool = false
			for key: int in clip.track_get_key_count(hips_track):
				found = found or absf(clip.track_get_key_time(hips_track, key) / clip.length - fraction) <= KEY_TOLERANCE
			assert_bool(found).override_failure_message("%s: no key near %.2f" % [character_class.title, fraction]).is_true()


func test_ac784_the_dash_clip_fills_the_dash() -> void:
	await _spawn()
	await _tap_dash()
	assert_str(_clip()).is_equal("dash")
	var length: float = _humanoid.anim.get_animation(&"dash").length
	assert_float(_humanoid.anim.speed_scale).is_equal_approx(length / _player.dash.get_duration(), length / _player.dash.get_duration() * 0.01)
	await _wait_dash_end()
	var longer := UpgradeData.new()
	longer.stat = PlayerStats.Stat.DASH_DISTANCE
	longer.amount = 1.5
	_player.stats.add_upgrade(longer)
	while _player.dash.get_cooldown_remaining() > 0.0:
		await get_tree().physics_frame
	await _tap_dash()
	assert_float(_humanoid.anim.speed_scale).is_equal_approx(length / _player.dash.get_duration(), length / _player.dash.get_duration() * 0.01)


func test_ac785_a_profile_without_dash_plays_run() -> void:
	await _spawn()
	ProfileWithout.use(_humanoid, &"warrior", [_player.dash.get_clip()])
	await _tap_dash()
	assert_str(_clip()).is_equal("run")


func test_ac786_the_dash_ends_on_the_sprint_first_frame() -> void:
	var probe: LowPolyHumanoid = auto_free(HUMANOID_SCENE.instantiate() as LowPolyHumanoid)
	add_child(probe)
	for character_class: CharacterClassData in CATALOG.classes:
		var library: AnimationLibrary = probe.get_profile_library(character_class.animation_profile)
		var dash_clip: Animation = library.get_animation(&"dash")
		var last: Dictionary = _pose(dash_clip, dash_clip.length)
		var first: Dictionary = _pose(library.get_animation(&"sprint"), 0.0)
		for path: String in first:
			var a: Variant = last.get(path)
			var b: Variant = first[path]
			var message: String = "%s %s: %s vs %s" % [character_class.title, path, a, b]
			if path.ends_with(":rotation"):
				var delta: Vector3 = ((a as Vector3) - (b as Vector3)).abs()
				assert_float(rad_to_deg(maxf(delta.x, maxf(delta.y, delta.z)))).override_failure_message(message).is_less_equal(LINK_DEGREES)
			elif path.ends_with(":position"):
				assert_float(((a as Vector3) - (b as Vector3)).length()).override_failure_message(message).is_less_equal(LINK_METERS)
			else:
				assert_float(float(a)).override_failure_message(message).is_equal_approx(float(b), 0.001)


func test_ac787_a_dash_while_moving_goes_on_as_the_sprint_from_frame_zero() -> void:
	await _spawn()
	Input.action_press(&"move_forward")
	await _physics_frames(2)
	await _tap_dash()
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await get_tree().physics_frame
	assert_str(_clip()).is_equal("sprint")
	assert_float(_humanoid.anim.current_animation_position).is_less(2.0 / Engine.physics_ticks_per_second)


func test_ac787_a_dash_without_input_skids() -> void:
	await _spawn()
	await _tap_dash()
	await _wait_dash_end()
	assert_str(_clip()).is_equal("sprint_stop")


func test_ac787_winded_a_dash_while_moving_walks() -> void:
	await _spawn()
	_player.stamina.spend(_player.stamina.get_max())
	Input.action_press(&"move_forward")
	await _physics_frames(2)
	await _tap_dash()
	await _wait_dash_end()
	assert_bool(_player.is_sprinting()).is_false()
	assert_str(_clip()).is_equal("run")
