extends GdUnitTestSuite
## Humanoid clips from the player's state (docs/specs/humanoid-player-model.md):
## AC593-AC595, AC598, AC605 and AC608.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const CONFIG: PlayerAnimationConfig = preload("res://data/player/player_animation_config.tres")
const ACTIONS: Array[StringName] = [&"attack", &"dash", &"jump", &"move_forward", &"move_right"]

var _registry: EnemyRegistry
var _player: Player
var _humanoid: LowPolyHumanoid


func before_test() -> void:
	Session.character_class = WARRIOR


func after_test() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)
	Session.character_class = null


func _spawn_player() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	await _physics_frames(10)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _clip() -> String:
	return String(_humanoid.anim.current_animation)


func _next(current: PlayerAnimator.Locomotion, on_floor: bool, speed: float, rising: bool, finished: bool) -> PlayerAnimator.Locomotion:
	return PlayerAnimator.next_locomotion(current, on_floor, speed, rising, finished, CONFIG)


# --- Pure state logic

func test_ac593_run_above_the_threshold_idle_below() -> void:
	assert_int(_next(PlayerAnimator.Locomotion.IDLE, true, CONFIG.run_speed_threshold + 0.1, false, false)).is_equal(PlayerAnimator.Locomotion.RUN)
	assert_int(_next(PlayerAnimator.Locomotion.IDLE, true, CONFIG.run_speed_threshold - 0.1, false, false)).is_equal(PlayerAnimator.Locomotion.IDLE)


func test_ac593_stopping_after_running_plays_run_stop_then_idle() -> void:
	assert_int(_next(PlayerAnimator.Locomotion.RUN, true, 0.0, false, false)).is_equal(PlayerAnimator.Locomotion.RUN_STOP)
	assert_int(_next(PlayerAnimator.Locomotion.RUN_STOP, true, 0.0, false, false)).is_equal(PlayerAnimator.Locomotion.RUN_STOP)
	assert_int(_next(PlayerAnimator.Locomotion.RUN_STOP, true, 0.0, false, true)).is_equal(PlayerAnimator.Locomotion.IDLE)
	assert_int(_next(PlayerAnimator.Locomotion.RUN_STOP, true, CONFIG.run_speed_threshold + 1.0, false, false)).is_equal(PlayerAnimator.Locomotion.RUN)


func test_ac594_jump_start_air_land() -> void:
	assert_int(_next(PlayerAnimator.Locomotion.RUN, false, 5.0, true, false)).is_equal(PlayerAnimator.Locomotion.JUMP_START)
	assert_int(_next(PlayerAnimator.Locomotion.JUMP_START, false, 5.0, true, false)).is_equal(PlayerAnimator.Locomotion.JUMP_START)
	assert_int(_next(PlayerAnimator.Locomotion.JUMP_START, false, 5.0, true, true)).is_equal(PlayerAnimator.Locomotion.AIR)
	assert_int(_next(PlayerAnimator.Locomotion.AIR, true, 0.0, false, false)).is_equal(PlayerAnimator.Locomotion.LAND)
	assert_int(_next(PlayerAnimator.Locomotion.LAND, true, 0.0, false, true)).is_equal(PlayerAnimator.Locomotion.IDLE)
	assert_int(_next(PlayerAnimator.Locomotion.LAND, true, 5.0, false, false)).is_equal(PlayerAnimator.Locomotion.RUN)


func test_ac594_falling_off_a_ledge_goes_straight_to_air() -> void:
	assert_int(_next(PlayerAnimator.Locomotion.RUN, false, 5.0, false, false)).is_equal(PlayerAnimator.Locomotion.AIR)


# --- In the game loop

func test_ac593_running_and_stopping_in_game() -> void:
	await _spawn_player()
	assert_str(_clip()).is_equal("idle")
	Input.action_press(&"move_forward")
	await _physics_frames(20)
	assert_str(_clip()).is_equal("run")
	Input.action_release(&"move_forward")
	await _physics_frames(10)
	assert_str(_clip()).is_equal("run_stop")
	await _physics_frames(40)
	assert_str(_clip()).is_equal("idle")


func test_ac594_jumping_in_game() -> void:
	await _spawn_player()
	var seen: Array[String] = []
	Input.action_press(&"jump")
	for i: int in 120:
		await get_tree().physics_frame
		if seen.is_empty() or seen.back() != _clip():
			seen.append(_clip())
	Input.action_release(&"jump")
	assert_array(seen).contains_exactly(["idle", "jump_start", "jump_air", "jump_land", "idle"])


func test_ac595_only_the_visual_turns_towards_the_movement() -> void:
	await _spawn_player()
	var visual: Node3D = _player.get_node("Visual") as Node3D
	var camera_forward: Vector3 = _player.get_node("CameraRig").to_world_direction(Vector2(1.0, 0.0))
	Input.action_press(&"move_right")
	await _physics_frames(1)
	var first_yaw: float = visual.rotation.y
	await _physics_frames(60)
	var target_yaw: float = atan2(-camera_forward.x, -camera_forward.z)
	assert_float(absf(angle_difference(first_yaw, target_yaw))).is_greater(0.01)
	assert_float(absf(angle_difference(visual.rotation.y, target_yaw))).is_less(0.01)
	assert_vector(_humanoid.rotation).is_equal(Vector3.ZERO)
	assert_vector(_player.rotation).is_equal(Vector3.ZERO)


func test_ac598_no_locomotion_clip_during_a_strike() -> void:
	await _spawn_player()
	Input.action_press(&"move_forward")
	await _physics_frames(10)
	_player.attack.request_attack()
	var clips: Array[String] = []
	while _player.attack.is_attacking():
		clips.append(_clip())
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	for clip: String in clips:
		assert_str(clip).is_equal("attack_1")
	assert_bool(clips.is_empty()).is_false()


func test_ac605_damage_plays_hit() -> void:
	await _spawn_player()
	_player.health.receive_hit(5.0)
	await _physics_frames(2)
	assert_str(_clip()).is_equal("hit")
	await _physics_frames(40)
	assert_str(_clip()).is_equal("idle")


func test_ac605_no_hit_clip_during_a_strike_or_when_invulnerable() -> void:
	await _spawn_player()
	_player.attack.request_attack()
	_player.health.receive_hit(5.0)
	await _physics_frames(2)
	assert_str(_clip()).is_equal("attack_1")
	while _player.attack.is_attacking():
		await get_tree().physics_frame
	await _physics_frames(2)
	_player.health.is_invulnerable = true
	_player.health.receive_hit(5.0)
	await _physics_frames(2)
	assert_str(_clip()).is_equal("idle")


func test_ac608_berserker_air_attack_is_the_air_slash() -> void:
	Session.character_class = BERSERKER
	await _spawn_player()
	var strikes: Array[int] = [0]
	_player.attack.step_started.connect(func(_i: int) -> void: strikes[0] += 1)
	Input.action_press(&"jump")
	await _physics_frames(8)
	Input.action_release(&"jump")
	Input.action_press(&"attack")
	await _physics_frames(3)
	assert_bool(_player.air_slash.is_active()).is_true()
	assert_int(strikes[0]).is_equal(0)


func test_ac608_warrior_strikes_in_the_air_and_returns_to_jump_air() -> void:
	await _spawn_player()
	Input.action_press(&"jump")
	await _physics_frames(4)
	Input.action_release(&"jump")
	_player.attack.request_attack()
	await _physics_frames(1)
	assert_str(_clip()).is_equal("attack_1")
	while _player.attack.is_attacking():
		await get_tree().physics_frame
	await _physics_frames(2)
	if not _player.is_on_floor():
		assert_str(_clip()).is_equal("jump_air")
