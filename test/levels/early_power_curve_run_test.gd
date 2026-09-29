extends GdUnitTestSuite
## Two picks after the first waves (docs/specs/early-power-curve.md, AC1124-AC1127).

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const HEALTH_UPGRADE: UpgradeData = preload("res://data/upgrades/max_health.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const LETHAL_HIT: float = 100000.0

var _arena: Node3D
var _registry: EnemyRegistry
var _run_state: RunState
var _picker: UpgradePicker
var _ban_picker: UpgradeBanPicker
var _wave_manager: WaveManager
var _player: Player


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	preload("res://test/helpers/test_world.gd").without_horde(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_ban_picker = _arena.get_node("UI/UpgradeBanPicker") as UpgradeBanPicker
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	_player = _arena.get_node("Player") as Player
	get_tree().paused = true
	await get_tree().process_frame
	(_arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHIELD_CHARGE)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


func test_ac1124_wave_1_gives_two_picks_before_wave_2() -> void:
	assert_int(_registry.alive_count()).is_equal(4)
	_kill_all_active()
	assert_bool(_picker.is_open()).is_true()
	var first_offer: Array[UpgradeCard] = _picker.get_offered().duplicate()
	_picker.choose(DAMAGE_UPGRADE)
	assert_int(_run_state.wave).is_equal(1)
	assert_bool(_picker.is_open()).is_true()
	assert_int(_picker.get_offered().size()).is_greater(0)
	assert_bool(get_tree().paused).is_true()
	assert_int(_player.stats.get_upgrades().size()).is_equal(1)
	assert_bool(first_offer.is_empty()).is_false()
	_picker.choose(HEALTH_UPGRADE)
	assert_int(_run_state.wave).is_equal(2)
	assert_int(_registry.alive_count()).is_equal(5)
	assert_int(_player.stats.get_upgrades().size()).is_equal(2)
	assert_bool(_picker.is_open()).is_false()


func test_ac1125_wave_4_gives_a_single_pick() -> void:
	for i: int in 3:
		_run_state.next_wave()
	_kill_all_active()
	_picker.choose(DAMAGE_UPGRADE)
	assert_int(_run_state.wave).is_equal(5)
	assert_bool(_picker.is_open()).is_false()
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_for_wave(5))


func test_ac1126_banning_spends_a_pick_and_the_extra_offer_has_no_red_card() -> void:
	for i: int in 2:
		_run_state.next_wave()
	_kill_all_active()
	assert_int(_run_state.wave).is_equal(3)
	assert_bool(_picker.has_ban_card()).is_true()
	_picker.request_ban()
	_ban_picker.choose(HEALTH_UPGRADE)
	assert_int(_run_state.wave).is_equal(3)
	assert_bool(_picker.is_open()).is_true()
	assert_bool(_picker.has_ban_card()).is_false()
	assert_bool(_picker.get_offered().has(HEALTH_UPGRADE)).is_false()
	_picker.choose(DAMAGE_UPGRADE)
	assert_int(_run_state.wave).is_equal(4)


func test_ac1127_an_empty_second_offer_advances_without_rage() -> void:
	_kill_all_active()
	assert_bool(_picker.is_open()).is_true()
	_wave_manager.get_card_pool().clear()
	_picker.choose(DAMAGE_UPGRADE)
	assert_int(_run_state.wave).is_equal(2)
	assert_bool(_picker.is_open()).is_false()
	assert_int(_run_state.get_rage_level()).is_equal(0)
