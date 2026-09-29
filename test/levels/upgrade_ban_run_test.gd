extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const RULES: CardBanRules = preload("res://data/upgrades/card_ban_rules.tres")
const PICKER_CONFIG: UpgradePickerConfig = preload("res://data/ui/upgrade_picker_config.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const HEALTH_UPGRADE: UpgradeData = preload("res://data/upgrades/max_health.tres")
const LETHAL_HIT: float = 100000.0

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _picker: UpgradePicker
var _ban_picker: UpgradeBanPicker
var _pause: PauseMenu
var _wave_manager: WaveManager


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	preload("res://test/helpers/test_world.gd").without_horde(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_ban_picker = _arena.get_node("UI/UpgradeBanPicker") as UpgradeBanPicker
	_pause = _arena.get_node("UI/PauseMenu") as PauseMenu
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
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


## Clears waves 1 and 2 (choosing damage) and wave 3, leaving its offer open.
func _reach_third_offer() -> void:
	for i: int in 2:
		_kill_all_active()
		assert_bool(_picker.has_ban_card()).is_false()
		assert_int(_picker.get_card_buttons().size()).is_equal(WAVE_CONFIG.cards_per_offer)
		_picker.choose(DAMAGE_UPGRADE)
	_kill_all_active()


func test_ac69_red_card_appears_only_after_the_third_wave() -> void:
	_reach_third_offer()
	assert_int(_run_state.wave).is_equal(3)
	assert_bool(_picker.is_open()).is_true()
	assert_int(_picker.get_card_buttons().size()).is_equal(WAVE_CONFIG.cards_per_offer)
	assert_bool(_picker.has_ban_card()).is_true()
	var style: StyleBoxFlat = _picker.get_ban_button().get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_that(style.bg_color).is_equal(PICKER_CONFIG.ban_card_color)


func test_ac70_red_card_opens_the_ban_menu_and_back_returns_to_the_offer() -> void:
	_reach_third_offer()
	var offer: Array[UpgradeCard] = _picker.get_offered().duplicate()
	_picker.request_ban()
	assert_bool(_picker.is_open()).is_false()
	assert_bool(_ban_picker.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(_ban_picker.get_offered().size()).is_equal(_wave_manager.get_card_pool().size())
	_pause.toggle()
	assert_bool(_pause.is_open()).is_false()
	_ban_picker.cancel()
	assert_bool(_ban_picker.is_open()).is_false()
	assert_bool(_picker.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_array(_picker.get_offered()).is_equal(offer)
	assert_bool(_picker.has_ban_card()).is_true()


func test_ac71_banning_replaces_the_upgrade_and_removes_the_card() -> void:
	_reach_third_offer()
	var damage_before: float = _player.stats.get_stat(PlayerStats.Stat.DAMAGE)
	var upgrades_before: int = _player.stats.get_upgrades().size()
	_picker.request_ban()
	_ban_picker.choose(HEALTH_UPGRADE)
	assert_bool(_run_state.is_banned(HEALTH_UPGRADE)).is_true()
	assert_int(_run_state.ban_count()).is_equal(1)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal(damage_before)
	assert_int(_player.stats.get_upgrades().size()).is_equal(upgrades_before)
	assert_float(_player.health.max_health).is_equal_approx(PLAYER_STATS.max_health, 0.0001)
	assert_int(_run_state.wave).is_equal(4)
	assert_bool(get_tree().paused).is_false()
	# Wave 4 is a boss challenge (docs/specs/boss-challenge.md): it still starts.
	assert_bool(_run_state.is_boss_wave()).is_true()
	assert_int(_registry.alive_count()).is_greater(0)
	assert_bool(_wave_manager.get_available_pool().has(HEALTH_UPGRADE)).is_false()
	assert_int(_wave_manager.get_available_pool().size()).is_equal(_wave_manager.get_card_pool().size() - 1)


func test_ac71_banned_card_is_missing_from_the_next_ban_menu() -> void:
	_run_state.ban(HEALTH_UPGRADE)
	_reach_third_offer()
	_picker.request_ban()
	assert_bool(_ban_picker.get_offered().has(HEALTH_UPGRADE)).is_false()
	assert_int(_ban_picker.get_offered().size()).is_equal(_wave_manager.get_card_pool().size() - 1)


func test_ac72_no_red_card_after_the_cap() -> void:
	var pool: Array[UpgradeCard] = _wave_manager.get_card_pool()
	for i: int in RULES.max_bans:
		_run_state.ban(pool[pool.size() - 1 - i])
	_reach_third_offer()
	assert_bool(_picker.is_open()).is_true()
	assert_bool(_picker.has_ban_card()).is_false()


func test_ac73_a_new_run_has_no_bans() -> void:
	assert_int(_run_state.ban_count()).is_equal(0)
	assert_int(_wave_manager.get_available_pool().size()).is_equal(_wave_manager.get_card_pool().size())
