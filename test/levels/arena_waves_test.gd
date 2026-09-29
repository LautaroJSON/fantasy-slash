extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const HEALTH_UPGRADE: UpgradeData = preload("res://data/upgrades/max_health.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const RAGE: RageConfig = preload("res://data/enemies/rage/rage_config.tres")
const PACE: EnemyPaceConfig = preload("res://data/enemies/enemy_pace_config.tres")
const LETHAL_HIT: float = 100000.0

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _picker: UpgradePicker
var _game_over: GameOverScreen


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	preload("res://test/helpers/test_world.gd").without_horde(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_game_over = _arena.get_node("UI/GameOverScreen") as GameOverScreen
	# The ability picker opens deferred, once the whole level is ready. The tree
	# is paused meanwhile so a slow first frame (catch-up physics steps) cannot
	# let anything move before the tests inspect it. Choosing the ability
	# unpauses and starts the first wave.
	get_tree().paused = true
	await get_tree().process_frame
	var ability_picker: AbilityPicker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	ability_picker.choose(SHIELD_CHARGE)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		# boss-colmena: a shielded boss (the Colmena) must die too.
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


func test_ac19_first_wave_spawns_exactly_five_enemies_away_from_the_player() -> void:
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)
	for enemy: Enemy in _registry.get_active():
		var offset := Vector2(enemy.global_position.x - _player.global_position.x, enemy.global_position.z - _player.global_position.z)
		assert_float(offset.length()).is_greater_equal(WAVE_CONFIG.min_spawn_distance)
		assert_float(absf(enemy.global_position.x)).is_less_equal(WAVE_CONFIG.spawn_half_extent)
		assert_float(absf(enemy.global_position.z)).is_less_equal(WAVE_CONFIG.spawn_half_extent)


func test_ac20_clearing_the_wave_pauses_and_offers_three_cards() -> void:
	assert_bool(_picker.is_open()).is_false()
	_kill_all_active()
	assert_int(_registry.alive_count()).is_equal(0)
	assert_bool(get_tree().paused).is_true()
	assert_bool(_picker.is_open()).is_true()
	assert_int(_picker.get_offered().size()).is_equal(WAVE_CONFIG.cards_per_offer)


func test_ac22_choosing_damage_applies_it_and_starts_the_next_wave() -> void:
	_kill_all_active()
	_picker.choose(DAMAGE_UPGRADE)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(19.0, 0.0001)
	assert_int(_player.stats.get_upgrades().size()).is_equal(1)
	assert_int(_run_state.wave).is_equal(2)
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)
	assert_bool(get_tree().paused).is_false()
	assert_bool(_picker.is_open()).is_false()


func test_ac134_wave_5_spawns_level_3_enemies() -> void:
	for enemy: Enemy in _registry.get_active():
		assert_int(enemy.level).is_equal(1)
	_kill_all_active()
	# Jump to wave 4: choosing a card advances to wave 5 and spawns it.
	for i: int in 3:
		_run_state.next_wave()
	_picker.choose(DAMAGE_UPGRADE)
	assert_int(_run_state.wave).is_equal(5)
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)
	for enemy: Enemy in _registry.get_active():
		assert_int(enemy.level).is_equal(3)
		assert_str(enemy.health_bar.get_level_text()).is_equal("lv. 3")


func test_ac23_choosing_health_raises_max_and_current_health() -> void:
	var before: float = _player.health.current_health
	_kill_all_active()
	_picker.choose(HEALTH_UPGRADE)
	assert_float(_player.health.max_health).is_equal_approx(120.0, 0.0001)
	assert_float(_player.health.current_health).is_equal_approx(before + 20.0, 0.0001)


func test_ac24_kills_accumulate_across_waves() -> void:
	_kill_all_active()
	_picker.choose(DAMAGE_UPGRADE)
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	active[0].health.receive_hit(LETHAL_HIT)
	active[1].health.receive_hit(LETHAL_HIT)
	assert_int(_run_state.kills).is_equal(WAVE_CONFIG.enemies_per_wave + 2)


## Empties the card pool: same as every card being maxed or banned.
func _exhaust_upgrades() -> void:
	var wave_manager: WaveManager = _arena.get_node("WaveManager") as WaveManager
	wave_manager.get_card_pool().clear()


func test_ac267_clearing_a_wave_without_upgrades_skips_the_picker() -> void:
	_exhaust_upgrades()
	_kill_all_active()
	assert_bool(_picker.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_ac268_without_upgrades_the_next_wave_starts_on_its_own() -> void:
	_exhaust_upgrades()
	_kill_all_active()
	await get_tree().process_frame
	assert_int(_run_state.wave).is_equal(2)
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)


func test_ac269_without_upgrades_boss_waves_still_come() -> void:
	_exhaust_upgrades()
	# Jump to wave 3: clearing it advances to wave 4, a boss wave.
	for i: int in 2:
		_run_state.next_wave()
	_kill_all_active()
	await get_tree().process_frame
	assert_int(_run_state.wave).is_equal(4)
	assert_bool(_run_state.is_boss_wave()).is_true()
	assert_int(_registry.alive_count()).is_greater(0)


## Grunt stats at `level` with `rage_level` of Rage on top.
## enemy-types: waves mix types, so the expectation uses each enemy's own stats.
func _raged(base: EnemyStats, level: int, rage_level: int) -> EnemyStats:
	var out := EnemyStats.new()
	base.write_scaled(level, out)
	RAGE.write_raged(rage_level, out)
	return out


func _rage_aura(enemy: Enemy) -> StatusAura:
	return enemy.get_node("Body/RageAura") as StatusAura


func test_ac341_with_upgrades_left_enemies_have_no_rage() -> void:
	_kill_all_active()
	_picker.choose(DAMAGE_UPGRADE)
	assert_int(_run_state.get_rage_level()).is_equal(0)
	for enemy: Enemy in _registry.get_active():
		assert_bool(enemy.debuffs.has_debuff(RAGE.status.id)).is_false()
		assert_bool(_rage_aura(enemy).visible).is_false()


func test_ac342_without_upgrades_the_next_wave_comes_enraged() -> void:
	_exhaust_upgrades()
	_kill_all_active()
	await get_tree().process_frame
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)
	for enemy: Enemy in _registry.get_active():
		assert_bool(enemy.debuffs.has_debuff(RAGE.status.id)).is_true()
		assert_float(enemy.debuffs.get_active()[0].potency).is_equal(1.0)
		assert_bool(_rage_aura(enemy).visible).is_true()
		var expected: EnemyStats = _raged(enemy.stats, WAVE_CONFIG.enemy_level_for(2), 1)
		var stats: EnemyStats = enemy.get_scaled_stats()
		assert_float(stats.damage).is_equal_approx(expected.damage, 0.0001)
		assert_float(stats.move_speed).is_equal_approx(expected.move_speed, 0.0001)
		assert_float(enemy.health.max_health).is_equal_approx(expected.max_health, 0.0001)
		assert_float(enemy.health.current_health).is_equal_approx(expected.max_health, 0.0001)
		assert_float(enemy.health.defense).is_equal_approx(expected.defense, 0.0001)


func test_ac343_rage_grows_one_level_per_wave() -> void:
	_exhaust_upgrades()
	_kill_all_active()
	await get_tree().process_frame
	_kill_all_active()
	await get_tree().process_frame
	assert_int(_run_state.wave).is_equal(3)
	for enemy: Enemy in _registry.get_active():
		assert_float(enemy.debuffs.get_active()[0].potency).is_equal(2.0)


func test_ac344_a_reused_enemy_without_rage_comes_back_clean() -> void:
	_exhaust_upgrades()
	_kill_all_active()
	await get_tree().process_frame
	var enemy: Enemy = _registry.get_active()[0]
	enemy.deactivate()
	enemy.activate(Vector3.ZERO, null, 1)
	var expected: EnemyStats = _raged(enemy.stats, 1, 0)
	assert_bool(enemy.debuffs.has_debuff(RAGE.status.id)).is_false()
	assert_bool(_rage_aura(enemy).visible).is_false()
	assert_float(enemy.health.max_health).is_equal_approx(expected.max_health, 0.0001)
	assert_float(enemy.get_scaled_stats().move_speed).is_equal_approx(expected.move_speed, 0.0001)


func test_ac25_player_death_shows_game_over_and_pauses() -> void:
	assert_bool(_game_over.visible).is_false()
	_player.health.receive_hit(LETHAL_HIT)
	assert_bool(_game_over.visible).is_true()
	assert_bool(get_tree().paused).is_true()


func test_ac25_a_new_run_starts_from_base_state() -> void:
	# Retry reloads the scene; a fresh arena must hold the base run state.
	assert_int(_run_state.wave).is_equal(1)
	assert_int(_run_state.kills).is_equal(0)
	assert_int(_player.stats.get_upgrades().size()).is_equal(0)
	assert_float(_player.health.current_health).is_equal_approx(PLAYER_STATS.max_health, 0.0001)
	for i: int in PlayerStats.Stat.size():
		var stat: PlayerStats.Stat = i as PlayerStats.Stat
		assert_float(_player.stats.get_stat(stat)).is_equal_approx(PLAYER_STATS.get_base(stat), 0.0001)


## Regular waves 1 to 8 (seeded): full size, only types already allowed and
## none over its max_per_wave (docs/specs/enemy-types.md).
func test_ac415_regular_waves_mix_the_allowed_types() -> void:
	var wave_manager: WaveManager = _arena.get_node("WaveManager") as WaveManager
	wave_manager.set_seed(415)
	for wave: int in range(1, 9):
		assert_int(_run_state.wave).is_equal(wave)
		if not _run_state.is_boss_wave():
			assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)
			for entry: EnemySpawnEntry in WAVE_CONFIG.enemy_types:
				var count: int = 0
				for enemy: Enemy in _registry.get_active():
					if enemy.stats == entry.stats:
						count += 1
				assert_int(count).is_less_equal(entry.max_per_wave)
				if wave < entry.first_wave:
					assert_int(count).is_equal(0)
		_kill_all_active()
		_picker.choose(DAMAGE_UPGRADE)


func test_ac456_wave_enemies_come_out_of_the_floor() -> void:
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)
	for enemy: Enemy in _registry.get_active():
		assert_bool(enemy.is_spawning_in()).is_true()
		assert_object(enemy.coordinator).is_not_null()


func _expected_interval(enemy: Enemy, scale: float) -> float:
	var out := EnemyStats.new()
	enemy.stats.write_scaled(enemy.level, out)
	return out.attack_interval * scale


## enemy-level-pace (AC560): the pace depends on the level (wave 1: level 1, ×1.8).
func test_ac524_ac560_wave_enemies_come_at_the_slow_pace() -> void:
	for enemy: Enemy in _registry.get_active():
		assert_float(enemy.get_windup_scale()).is_equal_approx(PACE.windup_scale_for(enemy.level, 0), 0.0001)
		assert_float(enemy.get_windup_scale()).is_equal_approx(1.8, 0.0001)
		assert_float(enemy.get_scaled_stats().attack_interval).is_equal_approx(_expected_interval(enemy, PACE.interval_scale_for(enemy.level, 0)), 0.0001)


func test_ac525_rage_speeds_up_the_pace_and_adds_attackers() -> void:
	var coordinator: AttackCoordinator = _arena.get_node("AttackCoordinator") as AttackCoordinator
	_exhaust_upgrades()
	_kill_all_active()
	await get_tree().process_frame
	_kill_all_active()
	await get_tree().process_frame
	assert_int(_run_state.get_rage_level()).is_equal(2)
	for enemy: Enemy in _registry.get_active():
		assert_float(enemy.get_windup_scale()).is_equal_approx(PACE.windup_scale_for(enemy.level, 2), 0.0001)
		assert_float(enemy.get_scaled_stats().attack_interval).is_equal_approx(_expected_interval(enemy, PACE.interval_scale_for(enemy.level, 2)), 0.0001)
	assert_int(coordinator.get_max_attackers()).is_equal(2)
	_kill_all_active()
	await get_tree().process_frame
	assert_int(_run_state.get_rage_level()).is_equal(3)
	assert_int(coordinator.get_max_attackers()).is_equal(3)
