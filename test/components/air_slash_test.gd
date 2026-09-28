extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const CONFIG: AirSlashConfig = preload("res://data/classes/berserker/air_slash_config.tres")
const LIFESTEAL: UpgradeData = preload("res://data/upgrades/lifesteal.tres")
## Tough enough that no slash kills it.
const ENEMY_HEALTH: float = 10000.0
const TOLERANCE: float = 0.0001
## Height the player is lifted to before each air slash, in meters.
const LIFT: float = 2.0

var _registry: EnemyRegistry
var _player: Player
var _air: AirSlashComponent
var _swings: Array[int] = [0]
var _strikes: Array[bool] = []


func before_test() -> void:
	# Another suite may leave these held: a held action never reads as just pressed.
	for action: StringName in [&"attack", &"dash", &"jump", &"ability_basic", &"move_forward"]:
		Input.action_release(action)
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_swings[0] = 0
	_strikes.clear()


func after_test() -> void:
	Session.character_class = null
	for action: StringName in [&"attack", &"dash", &"jump", &"ability_basic", &"move_forward"]:
		Input.action_release(action)


func _spawn_player(character_class: CharacterClassData = BERSERKER) -> void:
	Session.character_class = character_class
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_air = _player.air_slash
	_player.attack.attacked.connect(func(_h: int, _t: float, _c: bool) -> void: _swings[0] += 1)
	_air.struck.connect(func(_h: int, _t: float, was_crit: bool) -> void: _strikes.append(was_crit))
	await _physics_frames(20)


func _spawn_enemy(offset: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	var feet: Vector3 = _player.global_position
	enemy.activate(Vector3(feet.x, 0.0, feet.z) + offset, null)
	enemy.health.setup(ENEMY_HEALTH, 0.0)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Puts the player LIFT meters up, in the air.
func _lift() -> void:
	_player.global_position.y += LIFT
	_player.velocity = Vector3.ZERO
	await _physics_frames(2)
	assert_bool(_player.is_on_floor()).is_false()


## Lifts the player and holds attack until the suspension starts.
func _start_hover() -> void:
	await _lift()
	Input.action_press(&"attack")
	# The press is read on the next physics step after it.
	await _physics_frames(2)
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.HOVER)


func _wait_idle() -> void:
	var frames: int = 0
	while _air.is_active() and frames < 300:
		frames += 1
		await get_tree().physics_frame


func _basic_damage(is_crit: bool) -> float:
	var stats: StatsComponent = _player.stats
	return DamageMath.outgoing(
		stats.get_stat(PlayerStats.Stat.DAMAGE),
		stats.get_stat(PlayerStats.Stat.DAMAGE_BONUS),
		is_crit,
		stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))


func _flat_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func test_ac578_air_slash_data() -> void:
	assert_float(CONFIG.hover_duration).is_equal(2.0)
	assert_float(CONFIG.hover_move_speed_factor).is_equal_approx(0.15, TOLERANCE)
	assert_float(CONFIG.min_damage_factor).is_equal(1.5)
	assert_float(CONFIG.max_damage_factor).is_equal(3.5)
	assert_float(CONFIG.hit_length).is_equal(4.0)
	assert_float(CONFIG.hit_width).is_equal(2.0)
	assert_float(CONFIG.dive_speed).is_equal(20.0)
	assert_float(CONFIG.max_dive_duration).is_equal(1.0)
	assert_float(CONFIG.landing_lock).is_equal_approx(0.25, TOLERANCE)
	assert_object(BERSERKER.air_slash).is_same(CONFIG)
	assert_object(WARRIOR.air_slash).is_null()
	assert_object(SAMURAI.air_slash).is_null()


func test_ac579_attack_in_the_air_suspends_with_the_weapon_raised() -> void:
	await _spawn_player()
	await _start_hover()
	assert_int(_swings[0]).is_equal(0)
	var height: float = _player.global_position.y
	await _physics_frames(60)
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.HOVER)
	assert_float(_player.velocity.y).is_equal(0.0)
	assert_float(_player.global_position.y).is_equal_approx(height, 0.02)
	# Adapted (docs/specs/air-slash-visual-rework.md): the weapon is raised by
	# the charge clip in the hands, no longer at a fixed pivot pose.
	var humanoid: LowPolyHumanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	assert_str(String(humanoid.anim.current_animation)).is_equal(String(CONFIG.charge_body_clip))
	assert_bool(_player.is_weapon_in_hand_cast()).is_true()
	assert_bool(_air.get_indicator().is_showing()).is_true()
	assert_int(_swings[0]).is_equal(0)


func test_ac580_suspended_moves_very_slowly() -> void:
	await _spawn_player()
	await _start_hover()
	Input.action_press(&"move_forward")
	await _physics_frames(40)
	var expected: float = _player.stats.get_stat(PlayerStats.Stat.MOVE_SPEED) * CONFIG.hover_move_speed_factor
	assert_float(_flat_speed()).is_equal_approx(expected, expected * 0.05)


func test_ac581_an_early_release_hits_with_the_minimum_factor() -> void:
	await _spawn_player()
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.0))
	await _start_hover()
	Input.action_release(&"attack")
	await _physics_frames(2)
	assert_float(_air.get_damage_factor()).is_equal_approx(CONFIG.min_damage_factor, 0.05)
	await _wait_idle()
	assert_int(_strikes.size()).is_equal(1)
	var expected: float = _basic_damage(_strikes[0]) * _air.get_damage_factor()
	assert_float(ENEMY_HEALTH - enemy.health.current_health).is_equal_approx(expected, 0.01)


func test_ac581_one_second_of_charge_is_the_middle_factor() -> void:
	await _spawn_player()
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.0))
	await _start_hover()
	await _physics_frames(58)
	Input.action_release(&"attack")
	await _physics_frames(2)
	assert_float(_air.get_damage_factor()).is_equal_approx(2.5, 0.05)
	await _wait_idle()
	var expected: float = _basic_damage(_strikes[0]) * _air.get_damage_factor()
	assert_float(ENEMY_HEALTH - enemy.health.current_health).is_equal_approx(expected, 0.01)


func test_ac581_holding_two_seconds_releases_with_the_maximum_factor() -> void:
	await _spawn_player()
	await _start_hover()
	await _physics_frames(ceili(CONFIG.hover_duration * Engine.physics_ticks_per_second) + 2)
	assert_int(_air.get_phase()).is_not_equal(AirSlashComponent.Phase.HOVER)
	assert_float(_air.get_damage_factor()).is_equal_approx(CONFIG.max_damage_factor, TOLERANCE)
	await _wait_idle()
	assert_int(_strikes.size()).is_equal(1)


func test_ac582_only_the_band_in_front_is_hit() -> void:
	await _spawn_player()
	var inside: Enemy = _spawn_enemy(Vector3(0.5, 0.0, -3.0))
	var behind: Enemy = _spawn_enemy(Vector3(0.0, 0.0, 2.0))
	var aside: Enemy = _spawn_enemy(Vector3(3.0, 0.0, -2.0))
	await _start_hover()
	Input.action_release(&"attack")
	await _wait_idle()
	assert_float(inside.health.current_health).is_less(ENEMY_HEALTH)
	assert_float(behind.health.current_health).is_equal(ENEMY_HEALTH)
	assert_float(aside.health.current_health).is_equal(ENEMY_HEALTH)


func test_ac583_crit_lifesteal_and_push() -> void:
	await _spawn_player()
	for i: int in LIFESTEAL.max_stacks:
		_player.apply_upgrade(LIFESTEAL)
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.0))
	_player.health.receive_true_damage(_player.health.max_health / 2.0)
	var health_before: float = _player.health.current_health
	_air.strike_with_roll(0.0)
	assert_array(_strikes).is_equal([true])
	var applied: float = ENEMY_HEALTH - enemy.health.current_health
	assert_float(applied).is_equal_approx(_basic_damage(true) * _air.get_damage_factor(), 0.01)
	var healed: float = applied * _player.stats.get_stat(PlayerStats.Stat.LIFESTEAL)
	assert_float(_player.health.current_health - health_before).is_equal_approx(minf(healed, _player.health.max_health - health_before), 0.01)
	assert_float(enemy.get_knockback_velocity().length()).is_equal_approx(CONFIG.knockback_speed, TOLERANCE)
	assert_float(enemy.get_knockback_velocity().z).is_less(0.0)


func test_ac584_once_per_jump() -> void:
	await _spawn_player()
	await _lift()
	assert_bool(_air.try_start()).is_true()
	_air.cancel()
	assert_bool(_air.try_start()).is_false()
	await _wait_idle()
	while not _player.is_on_floor():
		await get_tree().physics_frame
	await _physics_frames(2)
	assert_bool(_air.is_used_this_jump()).is_false()
	Input.action_press(&"attack")
	await _physics_frames(2)
	Input.action_release(&"attack")
	assert_int(_swings[0]).is_greater(0)
	assert_bool(_air.is_active()).is_false()
	await _physics_frames(30)
	await _lift()
	assert_bool(_air.try_start()).is_true()


func test_ac585_nothing_else_while_suspended_and_still_on_landing() -> void:
	await _spawn_player()
	_player.basic_ability.equip(SPIN)
	await _start_hover()
	Input.action_press(&"dash")
	Input.action_press(&"jump")
	Input.action_press(&"ability_basic")
	await _physics_frames(3)
	assert_bool(_player.dash.is_dashing()).is_false()
	assert_bool(_player.basic_ability.is_casting()).is_false()
	assert_float(_player.velocity.y).is_equal(0.0)
	assert_int(_swings[0]).is_equal(0)
	Input.action_release(&"dash")
	Input.action_release(&"jump")
	Input.action_release(&"ability_basic")
	Input.action_release(&"attack")
	while _air.get_phase() != AirSlashComponent.Phase.LANDING:
		await get_tree().physics_frame
	Input.action_press(&"move_forward")
	var landed: Vector3 = _player.global_position
	await _physics_frames(floori(CONFIG.landing_lock * Engine.physics_ticks_per_second) - 2)
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.LANDING)
	assert_float(Vector2(_player.global_position.x - landed.x, _player.global_position.z - landed.z).length()).is_less(0.01)
	await _physics_frames(6)
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.IDLE)


func test_ac586_the_warrior_attacks_normally_in_the_air() -> void:
	await _assert_normal_attack_in_the_air(WARRIOR)


func test_ac586_the_samurai_attacks_normally_in_the_air() -> void:
	await _assert_normal_attack_in_the_air(SAMURAI)


func _assert_normal_attack_in_the_air(character_class: CharacterClassData) -> void:
	await _spawn_player(character_class)
	assert_bool(_air.is_enabled()).is_false()
	await _lift()
	Input.action_press(&"attack")
	await _physics_frames(3)
	Input.action_release(&"attack")
	assert_int(_swings[0]).is_greater(0)
	assert_bool(_air.is_active()).is_false()


func test_ac587_sweep_trail_wind_cut_shake_and_reused_nodes() -> void:
	await _spawn_player()
	var trail: WeaponTrail = _player.get_node("WeaponTrail") as WeaponTrail
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	var nodes: int = _air.get_child_count() + _air.get_wind_cut().get_child_count() + _air.get_indicator().get_child_count()
	await _start_hover()
	await _physics_frames(58)
	Input.action_release(&"attack")
	await _physics_frames(2)
	# Adapted (docs/specs/air-slash-visual-rework.md): the dive clip sweeps the
	# weapon in the hands; the trail follows the dive instead of SwordSwing.
	assert_int(_air.get_phase()).is_equal(AirSlashComponent.Phase.DIVE)
	assert_bool(_player.sword_swing.is_swinging()).is_false()
	assert_bool(trail.is_emitting()).is_true()
	while _air.get_phase() != AirSlashComponent.Phase.LANDING:
		await get_tree().physics_frame
	assert_bool(_air.get_wind_cut().is_playing()).is_true()
	assert_float(camera.get_shake_strength()).is_equal_approx(CONFIG.impact_shake, 0.05)
	await _physics_frames(12)
	var wind_config: WindCutConfig = _air.get_wind_cut().config
	# Adapted (docs/specs/sheathe-visual-rework.md): the walls are segments; the
	# air slash draws a single one per side.
	assert_float(_air.get_wind_cut().get_segment(WindCutVfx.WallSide.LEFT, 0).scale.y).is_equal_approx(wind_config.max_height * _air.get_charge_ratio(), 0.05)
	await _physics_frames(30)
	assert_bool(_air.get_indicator().is_showing()).is_false()
	await _wait_idle()
	await _physics_frames(5)
	await _start_hover()
	var after: int = _air.get_child_count() + _air.get_wind_cut().get_child_count() + _air.get_indicator().get_child_count()
	assert_int(after).is_equal(nodes)


func test_ac588_a_boss_grab_drops_the_slash_without_a_hit() -> void:
	await _spawn_player()
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.0))
	await _start_hover()
	var height: float = _player.global_position.y
	_player.begin_hold(0.5)
	assert_bool(_air.is_active()).is_false()
	await _physics_frames(30)
	assert_float(_player.global_position.y).is_less(height)
	assert_bool(_air.get_indicator().is_showing()).is_false()
	assert_array(_strikes).is_empty()
	assert_float(enemy.health.current_health).is_equal(ENEMY_HEALTH)
