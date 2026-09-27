extends GdUnitTestSuite
## Sprint clips and locomotion (docs/specs/sprint-stamina.md): AC715-AC718.

const TestWorld := preload("res://test/helpers/test_world.gd")
const ProfileWithout := preload("res://test/helpers/profile_without.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const CATALOG: ClassCatalog = preload("res://data/classes/class_catalog.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const CONFIG: PlayerAnimationConfig = preload("res://data/player/player_animation_config.tres")
const L := PlayerAnimator.Locomotion

var _player: Player
var _humanoid: LowPolyHumanoid


func after_test() -> void:
	Input.action_release(&"move_forward")
	Session.character_class = null


func _spawn() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(200.0))
	add_child(floor_body)
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	Session.character_class = SAMURAI
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = registry
	add_child(_player)
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	await _physics_frames(10)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _next(current: PlayerAnimator.Locomotion, speed: float, finished: bool, sprinting: bool, move_input: bool = true) -> PlayerAnimator.Locomotion:
	return PlayerAnimator.next_locomotion(current, true, speed, false, finished, CONFIG, sprinting, move_input)


func test_ac715_every_class_has_its_sprint_clips() -> void:
	var probe: LowPolyHumanoid = auto_free(preload("res://entities/player/humanoid.tscn").instantiate() as LowPolyHumanoid)
	add_child(probe)
	for character_class: CharacterClassData in CATALOG.classes:
		var library: AnimationLibrary = probe.get_profile_library(character_class.animation_profile)
		var start: Animation = library.get_animation(&"sprint_start")
		var loop: Animation = library.get_animation(&"sprint")
		var stop: Animation = library.get_animation(&"sprint_stop")
		assert_int(start.loop_mode).is_equal(Animation.LOOP_NONE)
		assert_int(loop.loop_mode).is_equal(Animation.LOOP_LINEAR)
		assert_int(stop.loop_mode).is_equal(Animation.LOOP_NONE)
		assert_float(start.length).is_between(0.15, 0.35)
		assert_float(loop.length).is_between(0.35, 0.55)
		assert_float(stop.length).is_between(0.3, 0.6)
		assert_float(loop.length).is_less(library.get_animation(&"run").length)


func test_ac716_sprint_start_then_loop() -> void:
	var fast: float = CONFIG.run_speed_threshold + 1.0
	assert_int(_next(L.IDLE, 0.0, false, true)).is_equal(L.SPRINT_START)
	assert_int(_next(L.RUN, fast, false, true)).is_equal(L.SPRINT_START)
	assert_int(_next(L.RUN_START, fast, false, true)).is_equal(L.SPRINT_START)
	assert_int(_next(L.SPRINT_START, fast, false, true)).is_equal(L.SPRINT_START)
	assert_int(_next(L.SPRINT_START, fast, true, true)).is_equal(L.SPRINT)
	assert_int(_next(L.SPRINT, fast, true, true)).is_equal(L.SPRINT)


func test_ac716_out_of_a_dash_or_a_landing_straight_to_the_loop() -> void:
	assert_int(PlayerAnimator.settled_locomotion(true, 0.0, CONFIG, true)).is_equal(L.SPRINT)
	assert_int(PlayerAnimator.next_locomotion(L.AIR, true, 8.0, false, false, CONFIG, true)).is_equal(L.SPRINT)
	assert_int(PlayerAnimator.next_locomotion(L.AIR, true, 8.0, false, false, CONFIG, false)).is_equal(L.LAND)


func test_ac717_stopping_the_sprint() -> void:
	# The input, not the speed, decides: releasing forward still slides fast.
	var fast: float = CONFIG.run_speed_threshold + 5.0
	assert_int(_next(L.SPRINT, fast, false, false, true)).is_equal(L.RUN)
	assert_int(_next(L.SPRINT_START, fast, false, false, true)).is_equal(L.RUN)
	assert_int(_next(L.SPRINT, fast, false, false, false)).is_equal(L.SPRINT_STOP)
	assert_int(_next(L.SPRINT_STOP, fast, false, false, false)).is_equal(L.SPRINT_STOP)
	assert_int(_next(L.SPRINT_STOP, 0.0, true, false, false)).is_equal(L.IDLE)
	assert_int(_next(L.SPRINT_STOP, fast, false, false, true)).is_equal(L.RUN)


func test_ac716_the_player_plays_the_sprint_clips() -> void:
	await _spawn()
	_player.sprint.try_start(false)
	Input.action_press(&"move_forward")
	await _physics_frames(2)
	assert_str(String(_humanoid.anim.current_animation)).is_equal("sprint_start")
	await _physics_frames(ceili(_humanoid.anim.get_animation(&"sprint_start").length * Engine.physics_ticks_per_second) + 3)
	assert_str(String(_humanoid.anim.current_animation)).is_equal("sprint")
	_player.sprint.stop()
	Input.action_release(&"move_forward")
	var stopped: bool = false
	for i: int in 30:
		await get_tree().physics_frame
		stopped = stopped or _humanoid.anim.current_animation == &"sprint_stop"
	assert_bool(stopped).is_true()


func test_ac718_a_profile_without_sprint_clips_walks() -> void:
	await _spawn()
	ProfileWithout.use(_humanoid, &"warrior", [&"run_start", &"sprint_start", &"sprint", &"sprint_stop"])
	assert_bool(_humanoid.anim.has_animation(&"sprint")).is_false()
	_player.sprint.try_start(false)
	Input.action_press(&"move_forward")
	await _physics_frames(10)
	assert_bool(_player.is_sprinting()).is_true()
	assert_str(String(_humanoid.anim.current_animation)).is_equal("run")
