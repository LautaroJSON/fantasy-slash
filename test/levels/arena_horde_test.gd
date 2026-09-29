extends GdUnitTestSuite
## Horde of fodder in the arena (docs/specs/fodder-minion.md, AC1150–AC1154).

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const HORDE: HordeConfig = preload("res://data/waves/horde_config.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const LETHAL_HIT: float = 100000.0

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _picker: UpgradePicker
var _waves: WaveManager


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_waves = _arena.get_node("WaveManager") as WaveManager
	# See arena_waves_test.gd: paused until the ability is chosen.
	get_tree().paused = true
	await get_tree().process_frame
	_player.health.is_invulnerable = true
	_waves.set_seed(1234)
	var ability_picker: AbilityPicker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	ability_picker.choose(SHIELD_CHARGE)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _fodder_alive() -> Array[Enemy]:
	var fodder: Array[Enemy] = []
	for enemy: Enemy in _registry.get_active():
		if enemy.stats == HORDE.entry.stats:
			fodder.append(enemy)
	return fodder


func _kill(enemies: Array[Enemy]) -> void:
	for enemy: Enemy in enemies:
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	_kill(active)


func test_ac1150_wave_one_has_the_normal_mix_plus_the_first_groups() -> void:
	var fodder: Array[Enemy] = _fodder_alive()
	var first_groups_max: int = mini(HORDE.initial_groups * HORDE.group_size_max, HORDE.total_for(1, false))
	var first_groups_min: int = HORDE.initial_groups * HORDE.group_size_min
	assert_int(fodder.size()).is_between(first_groups_min, first_groups_max)
	assert_int(_registry.alive_count() - fodder.size()).is_equal(WAVE_CONFIG.enemies_for_wave(1))
	assert_int(_waves.get_horde_alive()).is_equal(fodder.size())
	assert_int(_waves.get_horde_alive() + _waves.get_horde_remaining()).is_equal(HORDE.total_for(1, false))
	for enemy: Enemy in _registry.get_active():
		assert_float(absf(enemy.global_position.x)).is_less_equal(WAVE_CONFIG.spawn_half_extent)
		assert_float(absf(enemy.global_position.z)).is_less_equal(WAVE_CONFIG.spawn_half_extent)


func test_ac1151_a_new_group_comes_out_after_the_refill_delay() -> void:
	# Wave 19 (30 fodder) so the first groups never cover the whole total.
	_kill_all_active()
	_picker.hide()
	get_tree().paused = false
	_run_state.wave = 19
	_waves.start_wave()
	var fodder: Array[Enemy] = _fodder_alive()
	var to_kill: Array[Enemy] = []
	for i: int in fodder.size() - HORDE.refill_below:
		to_kill.append(fodder[i])
	var remaining_before: int = _waves.get_horde_remaining()
	assert_int(remaining_before).is_greater(0)
	_kill(to_kill)
	assert_int(_waves.get_horde_remaining()).is_equal(remaining_before)
	await _physics_frames(int(HORDE.refill_delay * 60.0) + 3)
	assert_int(_waves.get_horde_remaining()).is_less(remaining_before)
	assert_int(_waves.get_horde_alive()).is_less_equal(HORDE.max_alive)


func test_ac1152_exactly_the_wave_total_comes_out_and_alive_never_passes_the_cap() -> void:
	_kill_all_active()
	# Skip the cards of wave 1 by jumping to wave 19 (30 fodder; wave 20 is a boss wave).
	_picker.hide()
	get_tree().paused = false
	_run_state.wave = 19
	_waves.start_wave()
	var total: int = HORDE.total_for(19, false)
	assert_int(total).is_equal(30)
	var seen: int = _waves.get_horde_alive()
	for i: int in 3000:
		assert_int(_waves.get_horde_alive()).is_less_equal(HORDE.max_alive)
		var alive: Array[Enemy] = _fodder_alive()
		if alive.is_empty() and _waves.get_horde_remaining() == 0:
			break
		var before_remaining: int = _waves.get_horde_remaining()
		if i % 10 == 0 and not alive.is_empty():
			_kill([alive[0]])
		await get_tree().physics_frame
		seen += before_remaining - _waves.get_horde_remaining()
	assert_int(_waves.get_horde_remaining()).is_equal(0)
	assert_int(seen).is_equal(total)


func test_ac1153_cards_wait_until_the_whole_horde_has_come_out() -> void:
	var guard: int = 0
	while _waves.get_horde_remaining() > 0 and guard < 50:
		_kill_all_active()
		await get_tree().process_frame
		assert_bool(_picker.is_open()).is_false()
		guard += 1
	assert_int(_waves.get_horde_remaining()).is_equal(0)
	_kill_all_active()
	assert_bool(_picker.is_open()).is_true()


func test_ac1154_a_boss_wave_has_no_horde() -> void:
	_kill_all_active()
	_picker.hide()
	get_tree().paused = false
	_run_state.wave = WAVE_CONFIG.boss_wave_interval
	_waves.start_wave()
	assert_int(_waves.get_horde_remaining()).is_equal(0)
	assert_int(_fodder_alive().size()).is_equal(0)

