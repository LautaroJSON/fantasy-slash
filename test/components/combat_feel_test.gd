extends GdUnitTestSuite
## Commitment, lunge and aim of the basic attack combo
## (docs/specs/bdo-combat-feel.md, AC611–AC618, AC624–AC626, AC628–AC634 and AC636–AC638). The hit lag
## (AC619–AC623) lives in hitstop_test.gd.

const TestWorld := preload("res://test/helpers/test_world.gd")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const COMBO: AttackComboConfig = preload("res://data/player/attack_combo_config.tres")
const ACTIONS: Array[StringName] = [&"attack", &"dash", &"jump", &"move_forward", &"move_right"]
const NO_CRIT_ROLL: float = 0.99
const STILL: float = 0.01
const DEGREE: float = PI / 180.0

var _registry: EnemyRegistry
var _player: Player
var _visual: Node3D


func before_test() -> void:
	_release_all()
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	Session.character_class = WARRIOR
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_visual = _player.get_node("Visual") as Node3D
	_use_iteration_one_combo()
	await _physics_frames(10)


func after_test() -> void:
	_release_all()
	Session.character_class = null


func _release_all() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	Input.action_release(action)


func _spawn_idle_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


## The player's own copy of the combo (made in before_test), so a test can tune it.
func _own_combo() -> AttackComboConfig:
	return _player.attack.combo


## Iteration 1 behavior (docs/specs/bdo-combat-feel.md §2): nearest enemy aim
## steered by the movement input, and moving cuts the recovery. The iteration 2
## tests switch to the defaults they check.
func _use_iteration_one_combo() -> void:
	var combo: AttackComboConfig = COMBO.duplicate(true) as AttackComboConfig
	combo.aim_mode = AttackComboConfig.AimMode.NEAREST_ENEMY
	combo.windup_input_steering = true
	combo.recovery_move = AttackComboConfig.RecoveryMove.CANCEL
	_player.attack.combo = combo


func _flat(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


func _moved_from(start: Vector3) -> float:
	return _flat(_player.global_position).distance_to(_flat(start))


func _wait_committed_end() -> void:
	var frames: int = 0
	while _player.attack.is_committed() and frames < 120:
		await get_tree().physics_frame
		frames += 1


func _wait_strike_end() -> void:
	var frames: int = 0
	while _player.attack.is_attacking() and frames < 120:
		await get_tree().physics_frame
		frames += 1


# --- A. Commitment ---

func test_ac611_a_committed_strike_ignores_the_movement_input() -> void:
	for step: AttackComboStep in _own_combo().steps:
		step.lunge_distance = 0.0
	await _tap(&"attack")
	assert_bool(_player.attack.is_committed()).is_true()
	var start: Vector3 = _player.global_position
	Input.action_press(&"move_forward")
	while _player.attack.is_committed():
		await get_tree().physics_frame
		assert_float(_moved_from(start)).is_less_equal(STILL)


func test_ac612_moving_in_the_recovery_cuts_the_strike() -> void:
	await _tap(&"attack")
	await _wait_committed_end()
	assert_int(_player.attack.get_state()).is_equal(AttackComponent.ComboState.CHAIN_OPEN)
	var start: Vector3 = _player.global_position
	Input.action_press(&"move_forward")
	await get_tree().physics_frame
	assert_bool(_player.attack.is_attacking()).is_false()
	assert_float(_moved_from(start)).is_greater(0.0)
	Input.action_release(&"move_forward")
	await _tap(&"attack")
	assert_int(_player.attack.get_step_index()).is_equal(0)


func test_ac613_an_attack_tap_with_movement_chains_instead_of_cutting() -> void:
	await _tap(&"attack")
	await _wait_committed_end()
	# A pressed action reads as just pressed on the next physics frame, so the
	# movement is pressed one frame later to land on the same frame as the tap.
	Input.action_press(&"attack")
	await get_tree().physics_frame
	Input.action_press(&"move_forward")
	await _physics_frames(2)
	Input.action_release(&"attack")
	assert_bool(_player.attack.is_attacking()).is_true()
	assert_int(_player.attack.get_step_index()).is_equal(1)


func test_ac614_jump_is_ignored_while_committed_and_cuts_the_recovery() -> void:
	await _tap(&"attack")
	assert_bool(_player.attack.is_committed()).is_true()
	await _tap(&"jump")
	assert_float(_player.velocity.y).is_less_equal(STILL)
	await _wait_committed_end()
	await _tap(&"jump")
	assert_bool(_player.attack.is_attacking()).is_false()
	assert_float(_player.velocity.y).is_greater(0.0)


func test_ac615_the_dash_cuts_a_committed_strike() -> void:
	await _tap(&"attack")
	assert_bool(_player.attack.is_committed()).is_true()
	await _tap(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_bool(_player.attack.is_attacking()).is_false()


func test_ac615_the_dash_cuts_the_recovery() -> void:
	await _tap(&"attack")
	await _wait_committed_end()
	assert_bool(_player.attack.is_attacking()).is_true()
	await _tap(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_bool(_player.attack.is_attacking()).is_false()


# --- B. Lunge ---

func test_ac616_the_lunge_covers_its_distance_forward() -> void:
	var start: Vector3 = _player.global_position
	var forward: Vector3 = _player.get_facing()
	await _tap(&"attack")
	await _wait_strike_end()
	var moved: Vector3 = _player.global_position - start
	var expected: float = COMBO.steps[0].lunge_distance
	assert_float(_flat(moved).length()).is_equal_approx(expected, expected * 0.05)
	assert_float(Vector3(moved.x, 0.0, moved.z).normalized().dot(forward)).is_greater(0.99)


func test_ac616_a_faster_clip_covers_the_same_distance() -> void:
	var combo: AttackComboConfig = _own_combo()
	combo.reference_attack_speed = COMBO.reference_attack_speed / 2.0
	assert_float(_player.attack.get_clip_speed()).is_equal_approx(2.0 * _player.stats.get_stat(PlayerStats.Stat.ATTACK_SPEED) / COMBO.reference_attack_speed, 0.0001)
	var start: Vector3 = _player.global_position
	await _tap(&"attack")
	await _wait_strike_end()
	var expected: float = COMBO.steps[0].lunge_distance
	assert_float(_moved_from(start)).is_equal_approx(expected, expected * 0.05)


func test_ac617_an_enemy_right_ahead_stops_the_lunge() -> void:
	_spawn_idle_enemy(Vector3(0.0, 0.0, -1.0))
	await _physics_frames(2)
	var start: Vector3 = _player.global_position
	await _tap(&"attack")
	await _wait_committed_end()
	assert_float(_moved_from(start)).is_less_equal(STILL)


func test_ac617_an_enemy_behind_does_not_stop_the_lunge() -> void:
	_own_combo().aim_mode = AttackComboConfig.AimMode.CAMERA
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	var behind: Vector3 = -camera.to_world_direction(Vector2(0.0, -1.0))
	_spawn_idle_enemy(Vector3(behind.x, 0.0, behind.z).normalized())
	await _physics_frames(2)
	var start: Vector3 = _player.global_position
	await _tap(&"attack")
	await _wait_committed_end()
	var expected: float = COMBO.steps[0].lunge_distance
	assert_float(_moved_from(start)).is_equal_approx(expected, expected * 0.05)


func test_ac618_a_dash_cuts_the_lunge() -> void:
	var combo: AttackComboConfig = _own_combo()
	combo.steps[0].lunge_end = 0.3
	await _tap(&"attack")
	await _tap(&"dash")
	assert_bool(_player.attack.is_attacking()).is_false()
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await _physics_frames(10)
	var rest: Vector3 = _player.global_position
	await _physics_frames(5)
	assert_float(_moved_from(rest)).is_less_equal(STILL)


# --- D. Aim (clips driven by hand) ---

func test_ac624_camera_aim_faces_the_camera_not_the_enemy() -> void:
	ComboDriver.drive_by_hand(_player)
	_own_combo().aim_mode = AttackComboConfig.AimMode.CAMERA
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	var camera_forward: Vector3 = camera.to_world_direction(Vector2(0.0, -1.0))
	var side: Vector3 = camera_forward.cross(Vector3.UP).normalized() * 2.0
	_spawn_idle_enemy(side)
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	var flat_forward := Vector3(camera_forward.x, 0.0, camera_forward.z).normalized()
	assert_float(_player.get_facing().dot(flat_forward)).is_greater(0.999)


func test_ac625_the_movement_input_steers_the_windup_at_a_limited_speed() -> void:
	ComboDriver.drive_by_hand(_player)
	_spawn_idle_enemy(Vector3(0.0, 0.0, -3.0))
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	var start_yaw: float = _visual.rotation.y
	var delta: float = 0.05
	_player.attack.move_body(delta, Vector3.RIGHT)
	var turned: float = absf(angle_difference(start_yaw, _visual.rotation.y))
	assert_float(turned).is_equal_approx(deg_to_rad(COMBO.windup_turn_speed) * delta, DEGREE)
	var landed: Array[bool] = [false]
	_player.attack.attacked.connect(func(_h: int, _t: float, _c: bool) -> void: landed[0] = true)
	ComboDriver.advance_until(_player, func() -> bool: return landed[0])
	var fixed_yaw: float = _visual.rotation.y
	_player.attack.move_body(delta, Vector3.RIGHT)
	assert_float(absf(angle_difference(fixed_yaw, _visual.rotation.y))).is_less(0.0001)


func test_ac626_nearest_enemy_aim_follows_the_enemy_without_input() -> void:
	ComboDriver.drive_by_hand(_player)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(2.0, 0.0, -2.0))
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_float(_player.get_facing().dot(Vector3(1.0, 0.0, -1.0).normalized())).is_greater(0.999)
	enemy.global_position = Vector3(-2.0, 0.0, -2.0)
	for i: int in 20:
		_player.attack.move_body(0.05, Vector3.ZERO)
	var to_enemy: Vector3 = enemy.global_position - _player.global_position
	assert_float(_player.get_facing().dot(Vector3(to_enemy.x, 0.0, to_enemy.z).normalized())).is_greater(0.999)


# --- Iteration 2: camera assist and strafe (§6) ---

func _camera() -> ThirdPersonCamera:
	return _player.get_node("CameraRig") as ThirdPersonCamera


func _camera_forward() -> Vector3:
	var forward: Vector3 = _camera().to_world_direction(Vector2(0.0, -1.0))
	return Vector3(forward.x, 0.0, forward.z).normalized()


## Point `distance` meters away, `degrees` off the camera forward.
func _off_camera(degrees: float, distance: float) -> Vector3:
	return _player.global_position + _camera_forward().rotated(Vector3.UP, deg_to_rad(degrees)) * distance


func _faces(point: Vector3) -> bool:
	var to_point: Vector3 = point - _player.global_position
	return _player.get_facing().dot(Vector3(to_point.x, 0.0, to_point.z).normalized()) > 0.999


func _use_camera_assist() -> void:
	ComboDriver.drive_by_hand(_player)
	_own_combo().aim_mode = AttackComboConfig.AimMode.CAMERA_ASSIST


func test_ac628_camera_assist_ignores_an_enemy_outside_the_cone() -> void:
	_use_camera_assist()
	_spawn_idle_enemy(_off_camera(90.0, 2.0))
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_float(_player.get_facing().dot(_camera_forward())).is_greater(0.999)


func test_ac629_camera_assist_pulls_to_the_enemy_closest_in_angle() -> void:
	_use_camera_assist()
	var near_in_angle: Vector3 = _off_camera(5.0, 4.5)
	_spawn_idle_enemy(_off_camera(25.0, 2.0))
	_spawn_idle_enemy(near_in_angle)
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_bool(_faces(near_in_angle)).is_true()


func test_ac629_camera_assist_pulls_to_an_enemy_inside_the_cone() -> void:
	_use_camera_assist()
	var enemy_at: Vector3 = _off_camera(20.0, 3.0)
	_spawn_idle_enemy(enemy_at)
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_bool(_faces(enemy_at)).is_true()


func test_ac630_camera_assist_ignores_an_enemy_beyond_its_range() -> void:
	_use_camera_assist()
	_spawn_idle_enemy(_off_camera(20.0, COMBO.assist_range + 1.0))
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_float(_player.get_facing().dot(_camera_forward())).is_greater(0.999)


func test_ac631_camera_assist_ignores_the_movement_input_and_follows_the_camera() -> void:
	_use_camera_assist()
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	var start_yaw: float = _visual.rotation.y
	var delta: float = 0.05
	_player.attack.move_body(delta, Vector3.RIGHT)
	assert_float(absf(angle_difference(start_yaw, _visual.rotation.y))).is_less(0.0001)
	_camera().rotate_camera(PI / 2.0, 0.0)
	_player.attack.move_body(delta, Vector3.ZERO)
	var turned: float = absf(angle_difference(start_yaw, _visual.rotation.y))
	assert_float(turned).is_equal_approx(deg_to_rad(COMBO.windup_turn_speed) * delta, DEGREE)


func test_ac632_strafe_slides_slowly_in_the_recovery_without_turning() -> void:
	_own_combo().recovery_move = AttackComboConfig.RecoveryMove.STRAFE
	await _tap(&"attack")
	await _wait_committed_end()
	var start: Vector3 = _player.global_position
	var yaw: float = _visual.rotation.y
	var frames: int = 5
	Input.action_press(&"move_right")
	await _physics_frames(frames)
	assert_bool(_player.attack.is_attacking()).is_true()
	var max_distance: float = COMBO.recovery_strafe_factor * _player.stats.get_stat(PlayerStats.Stat.MOVE_SPEED) * frames / Engine.physics_ticks_per_second
	assert_float(_moved_from(start)).is_greater(0.0)
	assert_float(_moved_from(start)).is_less_equal(max_distance + STILL)
	assert_float(absf(angle_difference(yaw, _visual.rotation.y))).is_less(0.0001)


func test_ac633_strafe_still_chains_and_the_dash_still_cuts() -> void:
	_own_combo().recovery_move = AttackComboConfig.RecoveryMove.STRAFE
	await _tap(&"attack")
	await _wait_committed_end()
	Input.action_press(&"move_right")
	await _tap(&"attack")
	assert_int(_player.attack.get_step_index()).is_equal(1)
	await _wait_committed_end()
	await _tap(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_bool(_player.attack.is_attacking()).is_false()


func test_ac634_a_strike_with_nothing_to_aim_at_locks_the_facing() -> void:
	ComboDriver.drive_by_hand(_player)
	var movement: MovementComponent = _player.get_node("MovementComponent") as MovementComponent
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_bool(movement.face_direction_locked).is_true()
	ComboDriver.finish(_player)
	assert_bool(movement.face_direction_locked).is_false()


# --- Iteration 3: nearest enemy aim, the camera only looks (§7) ---

func _use_default_combo() -> void:
	ComboDriver.drive_by_hand(_player)
	_player.attack.combo = COMBO.duplicate(true) as AttackComboConfig


func test_ac636_by_default_the_strike_faces_the_nearest_enemy_not_the_camera() -> void:
	_use_default_combo()
	assert_int(COMBO.aim_mode).is_equal(AttackComboConfig.AimMode.NEAREST_ENEMY)
	var enemy_at: Vector3 = _off_camera(120.0, 2.0)
	_spawn_idle_enemy(enemy_at)
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_bool(_faces(enemy_at)).is_true()


func test_ac637_without_input_steering_the_movement_does_not_turn_the_windup() -> void:
	_use_default_combo()
	assert_bool(COMBO.windup_input_steering).is_false()
	var enemy_at: Vector3 = Vector3(0.0, 0.0, -3.0)
	_spawn_idle_enemy(enemy_at)
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	for i: int in 5:
		_player.attack.move_body(0.05, Vector3.RIGHT)
	assert_bool(_faces(enemy_at)).is_true()


func test_ac638_without_enemies_the_strike_keeps_its_facing() -> void:
	_use_default_combo()
	_camera().rotate_camera(PI / 2.0, 0.0)
	var facing: Vector3 = _player.get_facing()
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	for i: int in 5:
		_player.attack.move_body(0.05, Vector3.ZERO)
	assert_float(_player.get_facing().dot(facing)).is_greater(0.999)
