extends GdUnitTestSuite
## docs/specs/sandbox-arena-control.md: summoning from the pause menu, the
## group options (immortal, dummy, respawn) and the enemy tab.

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const SANDBOX: SandboxConfig = preload("res://data/sandbox/sandbox_config.tres")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const RULES: CombatRules = preload("res://data/combat/combat_rules.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const SHIELDBEARER: EnemyStats = preload("res://data/enemies/shieldbearer_stats.tres")
const COLMENA_CONFIG: ColmenaConfig = preload("res://data/enemies/configs/colmena_boss.tres")
const BURST: AfflictionData = preload("res://data/afflictions/burst.tres")
const BLEEDING: DebuffData = preload("res://data/debuffs/bleeding.tres")
const LETHAL_HIT: float = 100000.0
const HIT: float = 50.0
const ENTRY_GRUNT: int = 0
const ENTRY_SHIELDBEARER: int = 4
const REGULAR_TITLES: Array[String] = ["Bruto", "Embestidor", "Hostigador", "Saltador", "Escudero", "Esbirro"]
const BOSS_TITLES: Array[String] = ["Titán", "Colmena", "Verdugo", "The King"]

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _pause: PauseMenu
var _wave_manager: WaveManager
var _numbers: DamageNumberPool


func before_test() -> void:
	Session.mode = GameSession.Mode.SANDBOX
	Session.sandbox_request = null
	await _load_arena()


func after_test() -> void:
	Session.mode = GameSession.Mode.NORMAL
	Session.sandbox_request = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _load_arena() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_pause = _arena.get_node("UI/PauseMenu") as PauseMenu
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	_numbers = _arena.get_node("DamageNumberPool") as DamageNumberPool
	await get_tree().process_frame
	(_arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHIELD_CHARGE)


func _request(entry: int, count: int, level: int) -> SandboxSpawnRequest:
	var request: SandboxSpawnRequest = Session.get_sandbox_request(SANDBOX)
	request.entry = entry
	request.count = count
	request.level = level
	return request


func _active() -> Array[Enemy]:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	return active


func _kill_all_active() -> void:
	for enemy: Enemy in _active():
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _seconds_to_frames(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _boss_index(title: String) -> int:
	var roster: SandboxRoster = _wave_manager.get_roster()
	for i: int in roster.size():
		if roster.get_entry(i).title == title:
			return i
	return -1


## Only the first enemy, out of its spawn-in (so it can act at once).
func _spawn_one(entry: int, immortal: bool, dummy: bool) -> Enemy:
	var request: SandboxSpawnRequest = _request(entry, 1, 1)
	request.immortal = immortal
	request.dummy = dummy
	_wave_manager.spawn_sandbox(request)
	var enemy: Enemy = _active()[0]
	await _physics_frames(_seconds_to_frames(1.2))
	return enemy


# --- Summoning --------------------------------------------------------------

func test_ac1326_the_sandbox_starts_with_the_default_group() -> void:
	var active: Array[Enemy] = _active()
	assert_int(active.size()).is_equal(SANDBOX.default_count)
	assert_object(active[0].stats).is_same(GRUNT)
	assert_int(active[0].level).is_equal(SANDBOX.default_level)
	assert_int(_wave_manager.get_horde_remaining()).is_equal(0)


func test_ac1327_a_request_sets_type_count_and_level() -> void:
	_wave_manager.spawn_sandbox(_request(ENTRY_SHIELDBEARER, 4, 9))
	var scaled: EnemyStats = SHIELDBEARER.duplicate() as EnemyStats
	SHIELDBEARER.write_scaled(9, scaled)
	var active: Array[Enemy] = _active()
	assert_int(active.size()).is_equal(4)
	for enemy: Enemy in active:
		assert_object(enemy.stats).is_same(SHIELDBEARER)
		assert_int(enemy.level).is_equal(9)
		assert_float(enemy.health.max_health).is_equal_approx(scaled.max_health, 0.001)


func test_ac1328_summoning_replaces_the_group_without_kills() -> void:
	_wave_manager.spawn_sandbox(_request(ENTRY_GRUNT, 5, 1))
	var grunt_pool: EnemyPool = _wave_manager.get_roster().get_entry(ENTRY_GRUNT).pool
	_wave_manager.spawn_sandbox(_request(ENTRY_SHIELDBEARER, 2, 1))
	assert_int(_run_state.kills).is_equal(0)
	assert_int(_active().size()).is_equal(2)
	for enemy: Enemy in _active():
		assert_object(enemy.stats).is_same(SHIELDBEARER)
	assert_int(grunt_pool.available_count()).is_equal(grunt_pool.get_size())


func test_ac1329_clear_arena_removes_everyone_without_kills() -> void:
	_wave_manager.spawn_sandbox(_request(ENTRY_GRUNT, 6, 3))
	_wave_manager.clear_arena()
	assert_int(_registry.alive_count()).is_equal(0)
	assert_int(_run_state.kills).is_equal(0)


func test_ac1330_pools_grow_to_the_sandbox_caps() -> void:
	var roster: SandboxRoster = _wave_manager.get_roster()
	for i: int in roster.size():
		var entry: SandboxRoster.Entry = roster.get_entry(i)
		var cap: int = SANDBOX.max_boss_count if entry.is_boss else SANDBOX.max_regular_count
		assert_int(entry.max_count).is_equal(cap)
		assert_int(entry.pool.get_size()).is_greater_equal(cap)
	_wave_manager.spawn_sandbox(_request(ENTRY_GRUNT, SANDBOX.max_regular_count, 1))
	assert_int(_registry.alive_count()).is_equal(SANDBOX.max_regular_count)


func test_ac1331_a_boss_gets_its_bar_and_title() -> void:
	var started: Array[int] = [0]
	_wave_manager.boss_wave_started.connect(func(bosses: Array[Enemy]) -> void: started[0] = bosses.size())
	_wave_manager.spawn_sandbox(_request(_boss_index("Titán"), 2, 4))
	assert_int(started[0]).is_equal(2)
	assert_str(_run_state.challenge_title).is_equal("Titán")
	_wave_manager.spawn_sandbox(_request(ENTRY_GRUNT, 1, 1))
	assert_str(_run_state.challenge_title).is_empty()


func test_ac1332_respawn_brings_the_same_group_back_after_the_delay() -> void:
	var request: SandboxSpawnRequest = _request(ENTRY_SHIELDBEARER, 3, 5)
	request.respawn = true
	_wave_manager.spawn_sandbox(request)
	_kill_all_active()
	assert_int(_registry.alive_count()).is_equal(0)
	await _physics_frames(_seconds_to_frames(SANDBOX.respawn_delay) - 5)
	assert_int(_registry.alive_count()).is_equal(0)
	await _physics_frames(10)
	var active: Array[Enemy] = _active()
	assert_int(active.size()).is_equal(3)
	assert_object(active[0].stats).is_same(SHIELDBEARER)
	assert_int(active[0].level).is_equal(5)


func test_ac1332_without_respawn_the_arena_stays_empty() -> void:
	var request: SandboxSpawnRequest = _request(ENTRY_GRUNT, 2, 1)
	request.respawn = false
	_wave_manager.spawn_sandbox(request)
	_kill_all_active()
	await _physics_frames(_seconds_to_frames(SANDBOX.respawn_delay) + 10)
	assert_int(_registry.alive_count()).is_equal(0)
	assert_bool(_wave_manager.is_sandbox_respawn_scheduled()).is_false()


func test_ac1334_retry_keeps_the_request() -> void:
	var request: SandboxSpawnRequest = _request(ENTRY_SHIELDBEARER, 3, 7)
	_wave_manager.spawn_sandbox(request)
	remove_child(_arena)
	_arena.free()
	await _load_arena()
	var active: Array[Enemy] = _active()
	assert_int(active.size()).is_equal(3)
	assert_object(active[0].stats).is_same(SHIELDBEARER)
	assert_int(active[0].level).is_equal(7)


# --- Options ----------------------------------------------------------------

func test_ac1335_an_immortal_enemy_stays_at_the_floor() -> void:
	var enemy: Enemy = await _spawn_one(ENTRY_GRUNT, true, false)
	var killed: Array[bool] = [false]
	enemy.killed.connect(func(_e: Enemy) -> void: killed[0] = true)
	enemy.health.receive_hit(LETHAL_HIT)
	assert_float(enemy.health.current_health).is_equal_approx(RULES.protected_min_health, 0.0001)
	assert_bool(enemy.health.is_dead()).is_false()
	assert_bool(killed[0]).is_false()
	assert_int(_run_state.kills).is_equal(0)


func test_ac1336_hits_on_the_floor_show_their_full_damage() -> void:
	var enemy: Enemy = await _spawn_one(ENTRY_GRUNT, true, false)
	enemy.health.receive_hit(LETHAL_HIT)
	var applied: float = enemy.health.receive_hit(HIT)
	var full: String = str(roundi(enemy.health.last_full_damage))
	assert_float(applied).is_equal(0.0)
	assert_float(enemy.health.last_full_damage).is_greater(0.0)
	_player.attack.enemy_hit.emit(enemy, applied, false)
	assert_str(_numbers.get_last_spawned().get_text()).is_equal(full)
	_player.basic_ability.enemy_hit.emit(enemy, applied, false)
	assert_str(_numbers.get_last_spawned().get_text()).is_equal(full)
	_player.afflictions.burst_hit.emit(enemy, applied, BURST)
	assert_str(_numbers.get_last_spawned().get_text()).is_equal(full)
	# Ticks report the damage before the floor (DebuffComponent.ticked).
	enemy.debuffs.ticked.emit(enemy, HIT, BLEEDING)
	assert_str(_numbers.get_last_spawned().get_text()).is_equal(str(roundi(HIT)))


func test_ac1337_a_dummy_neither_moves_nor_attacks_and_faces_the_player() -> void:
	var enemy: Enemy = await _spawn_one(ENTRY_GRUNT, false, true)
	var start: Vector3 = enemy.global_position
	for i: int in _seconds_to_frames(2.0):
		await get_tree().physics_frame
		assert_bool(enemy.get_behavior().is_attacking()).is_false()
	var moved := Vector2(enemy.global_position.x - start.x, enemy.global_position.z - start.z)
	assert_float(moved.length()).is_less(0.01)
	var to_player: Vector3 = _player.global_position - enemy.global_position
	to_player.y = 0.0
	assert_float(enemy.get_facing().dot(to_player.normalized())).is_greater(0.95)


func test_ac1338_a_dummy_is_still_pushed() -> void:
	var enemy: Enemy = await _spawn_one(ENTRY_GRUNT, false, true)
	var start: Vector3 = enemy.global_position
	enemy.apply_knockback(Vector3.RIGHT, 8.0)
	await _physics_frames(_seconds_to_frames(1.5))
	var pushed: Vector3 = enemy.global_position
	assert_float(Vector2(pushed.x - start.x, pushed.z - start.z).length()).is_greater(0.3)
	assert_bool(enemy.is_knocked_back()).is_false()
	await _physics_frames(30)
	assert_float(Vector2(enemy.global_position.x - pushed.x, enemy.global_position.z - pushed.z).length()).is_less(0.01)


func test_ac1339_a_dummy_colmena_calls_no_minions() -> void:
	await _spawn_one(_boss_index("Colmena"), false, true)
	await _physics_frames(_seconds_to_frames(4.0))
	assert_int(_registry.alive_count()).is_equal(1)


func test_ac1339_colmena_minions_inherit_immortal_but_not_dummy() -> void:
	var colmena: Enemy = await _spawn_one(_boss_index("Colmena"), true, true)
	colmena.summon_requested.emit(colmena, COLMENA_CONFIG.summon_phase_one)
	var minions: Array[Enemy] = _active()
	minions.erase(colmena)
	assert_int(minions.size()).is_greater(0)
	for minion: Enemy in minions:
		assert_bool(minion.health.death_protected).is_true()
		assert_bool(minion.dummy).is_false()
		assert_int(minion.level).is_equal(1)


func test_ac1340_activate_clears_the_options() -> void:
	var enemy: Enemy = await _spawn_one(ENTRY_GRUNT, true, true)
	enemy.return_to_pool()
	enemy.activate(Vector3.ZERO, _player, 1)
	assert_bool(enemy.dummy).is_false()
	assert_bool(enemy.health.death_protected).is_false()
	enemy.health.receive_hit(LETHAL_HIT)
	assert_bool(enemy.health.is_dead()).is_true()


# --- Enemy tab --------------------------------------------------------------

func test_ac1341_the_enemy_tab_lists_every_type_and_boss() -> void:
	_pause.open()
	var panel: SandboxEnemyPanel = _pause.get_enemy_panel()
	var expected: PackedStringArray = PackedStringArray(REGULAR_TITLES + BOSS_TITLES)
	assert_array(Array(panel.get_type_titles())).is_equal(Array(expected))
	assert_bool(panel.has_boss_separator()).is_true()


func test_ac1342_count_stops_at_the_caps_of_the_type() -> void:
	_pause.open()
	var panel: SandboxEnemyPanel = _pause.get_enemy_panel()
	panel.select_entry(ENTRY_GRUNT)
	panel.step_count(-5)
	assert_int(panel.get_count()).is_equal(1)
	assert_bool(panel.is_count_minus_enabled()).is_false()
	for i: int in SANDBOX.max_regular_count + 3:
		panel.step_count(1)
	assert_int(panel.get_count()).is_equal(SANDBOX.max_regular_count)
	assert_bool(panel.is_count_plus_enabled()).is_false()
	panel.step_count(-2)
	assert_int(panel.get_count()).is_equal(8)
	panel.select_entry(_boss_index("Titán"))
	assert_int(panel.get_count()).is_equal(SANDBOX.max_boss_count)


func test_ac1343_level_range_and_equivalent_wave() -> void:
	_pause.open()
	var panel: SandboxEnemyPanel = _pause.get_enemy_panel()
	panel.step_level(-10)
	assert_int(panel.get_level()).is_equal(1)
	for i: int in WAVE_CONFIG.max_enemy_level + 5:
		panel.step_level(1)
	assert_int(panel.get_level()).is_equal(WAVE_CONFIG.max_enemy_level)
	panel.step_level(5 - WAVE_CONFIG.max_enemy_level)
	assert_int(WAVE_CONFIG.waves_per_enemy_level).is_equal(2)
	assert_str(panel.get_wave_hint_text()).is_equal("≈ oleada 9")
	assert_int(WAVE_CONFIG.enemy_level_for(9)).is_equal(5)


func test_ac1344_controls_write_the_request_and_only_invocar_summons() -> void:
	_pause.open()
	var panel: SandboxEnemyPanel = _pause.get_enemy_panel()
	panel.select_entry(ENTRY_SHIELDBEARER)
	panel.step_count(2)
	panel.step_level(3)
	panel.set_immortal(true)
	panel.set_dummy(true)
	var request: SandboxSpawnRequest = Session.sandbox_request
	assert_int(request.entry).is_equal(ENTRY_SHIELDBEARER)
	assert_int(request.count).is_equal(3)
	assert_int(request.level).is_equal(4)
	assert_bool(request.immortal).is_true()
	assert_bool(request.dummy).is_true()
	assert_object(_active()[0].stats).is_same(GRUNT)
	panel.press_spawn()
	assert_bool(_pause.is_open()).is_false()
	var active: Array[Enemy] = _active()
	assert_int(active.size()).is_equal(3)
	assert_bool(active[0].dummy).is_true()
	assert_bool(active[0].health.death_protected).is_true()
	_pause.open()
	panel.press_clear()
	assert_int(_registry.alive_count()).is_equal(0)
	assert_bool(_pause.is_open()).is_true()


func test_ac1345_alive_count_is_shown() -> void:
	_wave_manager.spawn_sandbox(_request(ENTRY_GRUNT, 4, 1))
	_pause.open()
	var panel: SandboxEnemyPanel = _pause.get_enemy_panel()
	assert_str(panel.get_alive_text()).is_equal("Activos: 4")
	panel.press_clear()
	assert_str(panel.get_alive_text()).is_equal("Activos: 0")
