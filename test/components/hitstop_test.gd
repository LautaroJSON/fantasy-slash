extends GdUnitTestSuite
## Local hit lag of the combo (docs/specs/bdo-combat-feel.md, AC619–AC623).
## Replaces the global slowdown of humanoid-player-model.md (AC606).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const COMBO: AttackComboConfig = preload("res://data/classes/warrior/warrior_combo.tres")
const VERDUGO_STATS: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const NO_CRIT_ROLL: float = 0.99
const TOLERANCE: float = 0.0001
## Enemy step that lands mid-shake (30 Hz: 0.01 s is ~0.3 of a cycle).
const ENEMY_STEP: float = 0.01

var _registry: EnemyRegistry
var _player: Player
var _hitstop: HitstopComponent
var _anim: AnimationPlayer


func before_test() -> void:
	Input.action_release(&"dash")
	Session.character_class = WARRIOR
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	ComboDriver.drive_by_hand(_player)
	_hitstop = _player.get_node("Hitstop") as HitstopComponent
	_hitstop.set_physics_process(false)
	_anim = ComboDriver.humanoid_of(_player).anim


func after_test() -> void:
	Input.action_release(&"dash")
	Session.character_class = null


func _spawn_enemy(at: Vector3, stats: EnemyStats = null) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	if stats != null:
		enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	enemy.set_physics_process(false)
	return enemy


## Strike in course lands; keeps the hit lag from being advanced by real frames.
func _strike() -> void:
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	_hitstop.set_physics_process(false)


func _body_x(enemy: Enemy) -> float:
	return (enemy.get_node("Body") as Node3D).position.x


func test_ac619_a_landing_strike_pauses_only_the_player_clip() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_strike()
	var hitlag: float = COMBO.steps[0].hitlag
	assert_bool(_hitstop.is_active()).is_true()
	assert_float(_anim.speed_scale).is_equal(0.0)
	assert_float(Engine.time_scale).is_equal(1.0)
	# The driver already advanced the hit lag by up to one step.
	_hitstop.advance(hitlag * 0.5)
	assert_float(_anim.speed_scale).is_equal(0.0)
	_hitstop.advance(hitlag)
	assert_bool(_hitstop.is_active()).is_false()
	assert_float(_anim.speed_scale).is_equal_approx(_player.attack.get_clip_speed(), TOLERANCE)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_ac620_an_enemy_hit_freezes_and_shakes_then_is_pushed() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var rest_x: float = _body_x(enemy)
	_strike()
	assert_bool(enemy.is_in_hitlag()).is_true()
	assert_bool(enemy.is_knocked_back()).is_true()
	var frozen_at: Vector3 = enemy.global_position
	enemy._physics_process(ENEMY_STEP)
	assert_vector(enemy.global_position).is_equal_approx(frozen_at, Vector3.ONE * TOLERANCE)
	assert_float(absf(_body_x(enemy) - rest_x)).is_greater(0.0)
	var elapsed: float = ENEMY_STEP
	while elapsed < COMBO.steps[0].hitlag:
		enemy._physics_process(ENEMY_STEP)
		elapsed += ENEMY_STEP
	assert_bool(enemy.is_in_hitlag()).is_false()
	assert_float(_body_x(enemy)).is_equal_approx(rest_x, TOLERANCE)
	enemy._physics_process(ENEMY_STEP)
	assert_float(enemy.global_position.distance_to(frozen_at)).is_greater(0.0)


func test_ac621_a_strike_into_the_air_has_no_hit_lag() -> void:
	_strike()
	assert_bool(_hitstop.is_active()).is_false()
	assert_float(_anim.speed_scale).is_not_equal(0.0)


func test_ac621_the_camera_shakes_with_each_strike_strength() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	_strike()
	assert_float(camera.get_shake_strength()).is_equal_approx(COMBO.steps[0].shake_strength, TOLERANCE)
	var last: int = COMBO.steps.size() - 1
	for i: int in last:
		ComboDriver.advance_until(_player, func() -> bool: return _player.attack.get_state() == AttackComponent.ComboState.CHAIN_OPEN)
		_strike()
	assert_int(_player.attack.get_step_index()).is_equal(last)
	assert_float(camera.get_shake_strength()).is_equal_approx(COMBO.steps[last].shake_strength, TOLERANCE)
	assert_float(COMBO.steps[last].shake_strength).is_greater(COMBO.steps[0].shake_strength)
	assert_float(COMBO.steps[last].hitlag).is_greater(COMBO.steps[0].hitlag)


func test_ac622_a_dash_ends_the_hit_lag_at_once() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_strike()
	assert_bool(_hitstop.is_active()).is_true()
	Input.action_press(&"dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_bool(_player.attack.is_attacking()).is_false()
	assert_bool(_hitstop.is_active()).is_false()


func test_ac623_a_boss_only_shakes() -> void:
	assert_bool(VERDUGO_STATS.resists_hitlag).is_true()
	var boss: Enemy = _spawn_enemy(Vector3(3.0, 0.0, 0.0), VERDUGO_STATS)
	var grunt: Enemy = _spawn_enemy(Vector3(-3.0, 0.0, 0.0))
	var config: HitstopConfig = _hitstop.config
	boss.apply_hitlag(0.1, config)
	grunt.apply_hitlag(0.1, config)
	var boss_rest_x: float = _body_x(boss)
	assert_bool(boss._advance_hitlag(ENEMY_STEP)).is_false()
	assert_bool(grunt._advance_hitlag(ENEMY_STEP)).is_true()
	assert_bool(boss.is_in_hitlag()).is_true()
	assert_float(absf(_body_x(boss) - boss_rest_x)).is_greater(0.0)


## kill-feedback (docs/specs/kill-feedback.md, AC1160–AC1161). The driver may
## already have advanced the hit lag by one step, so the pause is read inside
## a one-step window.
const MULTI_KILL: MultiKillFeelConfig = preload("res://data/player/multi_kill_feel_config.tres")


## `total` enemies in a tight group ahead of the player; the first `kills` die to one hit.
func _spawn_group(total: int, kills: int) -> void:
	for i: int in total:
		var angle: float = deg_to_rad(lerpf(-10.0, 10.0, float(i) / float(maxi(total - 1, 1))))
		var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, angle) * 1.2)
		if i < kills:
			enemy.health.setup(1.0, 0.0)


func _assert_pause(expected: float) -> void:
	var step_time: float = ComboDriver.STEP
	assert_float(_hitstop._left).is_between(expected - step_time - TOLERANCE, expected + TOLERANCE)


func test_ac1160_a_strike_that_kills_several_pauses_and_shakes_more() -> void:
	var base: float = COMBO.steps[0].hitlag
	_spawn_group(1, 1)
	_strike()
	_assert_pause(base)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_ac1160_three_kills_add_the_third_bonus() -> void:
	_spawn_group(3, 3)
	_strike()
	_assert_pause(COMBO.steps[0].hitlag + MULTI_KILL.hitlag_bonus_for(3))
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	assert_float(camera.get_shake_strength()).is_equal_approx(COMBO.steps[0].shake_strength + MULTI_KILL.shake_bonus_for(3), TOLERANCE)


func test_ac1160_six_kills_use_the_last_bonus() -> void:
	_spawn_group(6, 6)
	_strike()
	_assert_pause(COMBO.steps[0].hitlag + MULTI_KILL.hitlag_bonus_for(6))
	assert_float(MULTI_KILL.hitlag_bonus_for(6)).is_equal_approx(0.05, TOLERANCE)


func test_ac1160_hitting_several_without_killing_adds_nothing() -> void:
	_spawn_group(3, 0)
	_strike()
	_assert_pause(COMBO.steps[0].hitlag)
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	assert_float(camera.get_shake_strength()).is_equal_approx(COMBO.steps[0].shake_strength, TOLERANCE)


func test_ac1161_an_ability_strike_with_two_dead_adds_the_bonus_without_touching_the_feel() -> void:
	var feel := StrikeFeel.new()
	feel.hitlag = 0.1
	feel.shake_strength = 0.2
	var dead: Array[Enemy] = []
	for i: int in 2:
		var enemy: Enemy = _spawn_enemy(Vector3(float(i), 0.0, -3.0))
		enemy.health.receive_hit(100000.0)
		dead.append(enemy)
	var ability: AbilityComponent = _player.get_node("BasicAbility") as AbilityComponent
	ability.struck.emit(feel, dead)
	assert_float(_hitstop._left).is_equal_approx(0.1 + MULTI_KILL.hitlag_bonus_for(2), TOLERANCE)
	assert_float(feel.hitlag).is_equal(0.1)
	assert_float(feel.shake_strength).is_equal(0.2)


func test_ac1161_a_strike_that_does_not_pause_gets_no_bonus() -> void:
	var feel := StrikeFeel.new()
	feel.hitlag = 0.0
	feel.shake_strength = 0.0
	var dead: Array[Enemy] = []
	for i: int in 2:
		var enemy: Enemy = _spawn_enemy(Vector3(float(i), 0.0, -3.0))
		enemy.health.receive_hit(100000.0)
		dead.append(enemy)
	var ability: AbilityComponent = _player.get_node("BasicAbility") as AbilityComponent
	ability.struck.emit(feel, dead)
	assert_bool(_hitstop.is_active()).is_false()
