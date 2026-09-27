extends GdUnitTestSuite
## Basic attack: the sector hitbox (AC8-AC10, adapted to the combo) and the
## combo itself (docs/specs/humanoid-player-model.md, AC596-AC602, AC609).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const COMBO: AttackComboConfig = preload("res://data/player/attack_combo_config.tres")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const TestWorld := preload("res://test/helpers/test_world.gd")
## A roll that never produces a critical hit (base crit chance is 0.15).
const NO_CRIT_ROLL: float = 0.99
const TOLERANCE: float = 0.0001
const FRAME: float = 1.0 / 60.0

var _registry: EnemyRegistry
var _player: Player
var _attack: AttackComponent
var _humanoid: LowPolyHumanoid


func before_test() -> void:
	Session.character_class = WARRIOR
	_spawn_player()


func after_test() -> void:
	Session.character_class = null


func _spawn_player() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_attack = _player.get_node("AttackComponent") as AttackComponent
	_humanoid = ComboDriver.humanoid_of(_player)
	ComboDriver.drive_by_hand(_player)
	# These tests check the nearest-enemy auto-aim; the default aim is now the
	# camera assist (docs/specs/bdo-combat-feel.md §6).
	_attack.combo = _with_nearest_enemy_aim(_attack.combo)


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _upgrade(stat: PlayerStats.Stat, amount: float) -> void:
	var upgrade := UpgradeData.new()
	upgrade.stat = stat
	upgrade.amount = amount
	_player.stats.add_upgrade(upgrade)


## Advances the clip in course by `seconds` of clip time, frame by frame.
func _advance_clip(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var step: float = minf(FRAME, left)
		_humanoid.anim.advance(step)
		_attack.advance(step)
		(_player.get_node("Hitstop") as HitstopComponent).advance(step)
		left -= step


func _wait_for_combo_window() -> void:
	ComboDriver.advance_until(_player, func() -> bool: return _attack.get_state() == AttackComponent.ComboState.CHAIN_OPEN)


# --- Sector hitbox (AC8-AC10). A unit combo keeps one strike = one old swing.

func test_ac8_hit_deals_damage_and_heals_by_lifesteal() -> void:
	ComboDriver.use_unit_combo(_player)
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_upgrade(PlayerStats.Stat.LIFESTEAL, 0.1)
	_player.health.receive_hit(20.0)
	var health_before: float = _player.health.current_health
	assert_bool(ComboDriver.strike(_player, NO_CRIT_ROLL)).is_true()
	assert_float(enemy.health.current_health).is_equal_approx(25.0, TOLERANCE)
	assert_float(_player.health.current_health).is_equal_approx(health_before + 1.5, TOLERANCE)


## Adapted: the cooldown is gone; a second strike cannot start mid-strike.
func test_ac8_second_attack_during_a_strike_is_rejected() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	assert_bool(_attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_bool(_attack.try_attack_with_roll(NO_CRIT_ROLL)).is_false()


func test_ac8_attack_turns_the_player_towards_the_nearest_enemy() -> void:
	_spawn_enemy(Vector3(1.5, 0.0, 0.0))
	_attack.try_attack_with_roll(NO_CRIT_ROLL)
	var visual: Node3D = _player.get_node("Visual") as Node3D
	assert_float(visual.rotation.y).is_equal_approx(-PI / 2.0, 0.01)


func test_ac9_enemy_out_of_range_takes_no_damage() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -3.0))
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	assert_float(enemy.health.current_health).is_equal_approx(40.0, TOLERANCE)


func test_ac9_enemy_behind_the_target_is_outside_the_arc() -> void:
	ComboDriver.use_unit_combo(_player)
	var target: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.2))
	var behind: Enemy = _spawn_enemy(Vector3(0.0, 0.0, 1.5))
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	assert_float(target.health.current_health).is_equal_approx(25.0, TOLERANCE)
	assert_float(behind.health.current_health).is_equal_approx(40.0, TOLERANCE)


func test_ac9_range_upgrades_extend_the_hitbox() -> void:
	ComboDriver.use_unit_combo(_player)
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.5))
	for i: int in 3:
		_upgrade(PlayerStats.Stat.ATTACK_RANGE, 0.3)
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	assert_float(enemy.health.current_health).is_equal_approx(25.0, TOLERANCE)


func test_ac10_enemy_dies_after_three_hits_and_leaves_the_registry() -> void:
	ComboDriver.use_unit_combo(_player)
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var kills: Array[int] = [0]
	enemy.killed.connect(func(_e: Enemy) -> void: kills[0] += 1)
	for i: int in 3:
		assert_bool(ComboDriver.strike_and_finish(_player, NO_CRIT_ROLL)).is_true()
	assert_bool(enemy.health.is_dead()).is_true()
	assert_int(kills[0]).is_equal(1)
	assert_bool(enemy.visible).is_false()
	assert_int(_registry.alive_count()).is_equal(0)


# --- Combo (docs/specs/humanoid-player-model.md)

func test_ac596_taps_in_the_combo_window_chain_the_three_strikes_and_loop() -> void:
	var steps: Array[int] = []
	_attack.step_started.connect(func(index: int) -> void: steps.append(index))
	_attack.request_attack()
	for i: int in 3:
		_wait_for_combo_window()
		_attack.request_attack()
	assert_array(steps).is_equal([0, 1, 2, 0])
	assert_str(String(_humanoid.anim.current_animation)).is_equal("attack_1")


func test_ac596_without_a_tap_the_strike_ends_and_the_combo_starts_over() -> void:
	var ended: Array[int] = [0]
	_attack.step_ended.connect(func() -> void: ended[0] += 1)
	_attack.request_attack()
	_wait_for_combo_window()
	ComboDriver.finish(_player)
	assert_bool(_attack.is_attacking()).is_false()
	assert_int(ended[0]).is_equal(1)
	assert_int(_attack.get_step_index()).is_equal(-1)
	_attack.request_attack()
	assert_str(String(_humanoid.anim.current_animation)).is_equal("attack_1")


func test_ac597_a_tap_within_the_buffer_before_the_window_chains() -> void:
	_attack.request_attack()
	# attack_1 opens its combo window at 0.24 s (clip speed 1 for the warrior).
	_advance_clip(0.24 - COMBO.input_buffer + 0.02)
	_attack.request_attack()
	_wait_for_combo_window()
	_advance_clip(FRAME)
	assert_str(String(_humanoid.anim.current_animation)).is_equal("attack_2")


func test_ac597_a_tap_too_early_is_forgotten() -> void:
	_attack.request_attack()
	_advance_clip(0.24 - 0.2)
	_attack.request_attack()
	_wait_for_combo_window()
	_advance_clip(FRAME)
	assert_str(String(_humanoid.anim.current_animation)).is_equal("attack_1")


func test_ac597_holding_the_button_strikes_once() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(20.0))
	add_child(floor_body)
	_humanoid.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	(_player.get_node("PlayerAnimator") as PlayerAnimator).set_physics_process(true)
	_attack.set_physics_process(true)
	var strikes: Array[int] = [0]
	_attack.step_started.connect(func(_i: int) -> void: strikes[0] += 1)
	await await_idle_frame()
	Input.action_press(&"attack")
	for i: int in 90:
		await get_tree().physics_frame
	Input.action_release(&"attack")
	assert_int(strikes[0]).is_equal(1)


func test_ac599_damage_lands_when_the_hit_window_opens_once_per_strike() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var hits: Array[int] = [0]
	_attack.enemy_hit.connect(func(_e: Enemy, _a: float, _c: bool) -> void: hits[0] += 1)
	_attack.try_attack_with_roll(NO_CRIT_ROLL)
	# attack_1 opens its hit window at 0.12 s.
	_advance_clip(0.1)
	assert_float(enemy.health.current_health).is_equal_approx(40.0, TOLERANCE)
	ComboDriver.finish(_player)
	assert_int(hits[0]).is_equal(1)
	var expected: float = 40.0 - 15.0 * COMBO.steps[0].damage_multiplier
	assert_float(enemy.health.current_health).is_equal_approx(expected, TOLERANCE)


func test_ac599_each_strike_applies_its_damage_multiplier() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var applied: Array[float] = []
	_attack.enemy_hit.connect(func(_e: Enemy, amount: float, _c: bool) -> void: applied.append(amount))
	_attack.try_attack_with_roll(NO_CRIT_ROLL)
	for i: int in 2:
		_wait_for_combo_window()
		_attack.try_attack_with_roll(NO_CRIT_ROLL)
	ComboDriver.finish(_player)
	assert_int(applied.size()).is_equal(3)
	for i: int in 3:
		# The enemy's defense is 0 at level 1: applied == outgoing.
		assert_float(applied[i]).is_equal_approx(15.0 * COMBO.steps[i].damage_multiplier, TOLERANCE)


func test_ac600_clip_speed_follows_attack_speed() -> void:
	assert_float(_attack.get_clip_speed()).is_equal_approx(1.0, TOLERANCE)
	_upgrade(PlayerStats.Stat.ATTACK_SPEED, 0.6)
	assert_float(_attack.get_clip_speed()).is_equal_approx(1.5, TOLERANCE)
	_attack.request_attack()
	assert_float(_humanoid.anim.speed_scale).is_equal_approx(1.5, TOLERANCE)


func test_ac600_berserker_is_slower_and_samurai_faster() -> void:
	Session.character_class = BERSERKER
	_spawn_player()
	assert_float(_attack.get_clip_speed()).is_equal_approx(0.5, TOLERANCE)
	Session.character_class = SAMURAI
	_spawn_player()
	assert_float(_attack.get_clip_speed()).is_equal_approx(1.6 / 1.2, TOLERANCE)


func test_ac601_full_combo_dps_matches_the_old_cadence() -> void:
	for character_class: CharacterClassData in [WARRIOR, BERSERKER, SAMURAI]:
		Session.character_class = character_class
		_spawn_player()
		# Clip cadence only: the hit lag (bdo-combat-feel.md) pauses the clips on
		# top of it, so it is left out here.
		_attack.combo = _without_hitlag(_attack.combo)
		var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
		enemy.health.setup(100000.0, 0.0)
		var damage: Array[float] = [0.0]
		_attack.enemy_hit.connect(func(_e: Enemy, amount: float, _c: bool) -> void: damage[0] += amount)
		var elapsed: float = 0.0
		_attack.try_attack_with_roll(NO_CRIT_ROLL)
		# Two full cycles, chaining at every combo window.
		for i: int in 6:
			while _attack.get_state() != AttackComponent.ComboState.CHAIN_OPEN:
				_advance_clip(FRAME)
				elapsed += FRAME
			_attack.try_attack_with_roll(NO_CRIT_ROLL)
		var stats: PlayerStats = character_class.base_stats
		var old_dps: float = stats.attack_speed * stats.damage
		# The clips play at the attack speed: elapsed is real time.
		var dps: float = damage[0] / elapsed
		assert_float(dps).is_between(old_dps * 0.9, old_dps * 1.1)


func test_ac602_cancel_before_the_hit_window_deals_no_damage_and_resets() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_attack.request_attack()
	_advance_clip(0.05)
	_attack.cancel()
	ComboDriver.advance_until(_player, func() -> bool: return false)
	assert_float(enemy.health.current_health).is_equal_approx(40.0, TOLERANCE)
	assert_bool(_attack.is_attacking()).is_false()
	assert_int(_attack.get_step_index()).is_equal(-1)


func test_ac602_dash_cancels_the_strike() -> void:
	_attack.request_attack()
	await await_idle_frame()
	Input.action_press(&"dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_bool(_attack.is_attacking()).is_false()


func test_ac602_hold_and_cast_cancel_the_strike() -> void:
	_attack.request_attack()
	_player.begin_hold(0.5)
	assert_bool(_attack.is_attacking()).is_false()
	_player.end_hold()
	_attack.request_attack()
	assert_bool(_attack.is_attacking()).is_true()
	_player.basic_ability.cast_started.emit()
	assert_bool(_attack.is_attacking()).is_false()


func test_ac609_attack_performed_on_every_strike_start() -> void:
	var performed: Array[int] = [0]
	_player.attack_performed.connect(func() -> void: performed[0] += 1)
	_attack.request_attack()
	_wait_for_combo_window()
	_attack.request_attack()
	assert_int(performed[0]).is_equal(2)


func _without_hitlag(source: AttackComboConfig) -> AttackComboConfig:
	var combo: AttackComboConfig = source.duplicate(true) as AttackComboConfig
	for step: AttackComboStep in combo.steps:
		step.hitlag = 0.0
	return combo


func _with_nearest_enemy_aim(source: AttackComboConfig) -> AttackComboConfig:
	var combo: AttackComboConfig = source.duplicate(true) as AttackComboConfig
	combo.aim_mode = AttackComboConfig.AimMode.NEAREST_ENEMY
	return combo
