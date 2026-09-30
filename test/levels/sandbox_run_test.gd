extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const RULES: CombatRules = preload("res://data/combat/combat_rules.tres")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const CONCUSSIVE: AbilityUniqueUpgradeData = preload("res://data/abilities/shield_charge/unique/concussive.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const CRIT_UPGRADE: UpgradeData = preload("res://data/upgrades/crit_chance.tres")
const LETHAL_HIT: float = 100000.0

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _picker: UpgradePicker
var _pause: PauseMenu
var _game_over: GameOverScreen
var _wave_manager: WaveManager
var _panel: UpgradePanel


func before_test() -> void:
	Session.mode = GameSession.Mode.SANDBOX
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	preload("res://test/helpers/test_world.gd").without_horde(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_pause = _arena.get_node("UI/PauseMenu") as PauseMenu
	_game_over = _arena.get_node("UI/GameOverScreen") as GameOverScreen
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	_panel = _pause.get_upgrade_panel()
	get_tree().paused = true
	await get_tree().process_frame
	var ability_picker: AbilityPicker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	ability_picker.choose(SHIELD_CHARGE)


func after_test() -> void:
	Session.mode = GameSession.Mode.NORMAL
	Session.sandbox_request = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		# boss-colmena: a shielded boss (the Colmena) must die too.
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


## Replaces AC110 (sandbox-arena-control.md): no cards and no next wave; the
## group only comes back through Respawn (AC1332).
func test_ac1333_cleared_groups_skip_the_cards_and_the_waves() -> void:
	var cleared: Array[bool] = [false]
	_wave_manager.stage_cleared.connect(func() -> void: cleared[0] = true)
	_kill_all_active()
	assert_bool(_picker.is_open()).is_false()
	await get_tree().process_frame
	assert_int(_run_state.wave).is_equal(1)
	assert_bool(cleared[0]).is_false()


func test_ac111_the_player_cannot_die() -> void:
	_player.health.receive_hit(LETHAL_HIT)
	assert_float(_player.health.current_health).is_equal_approx(RULES.protected_min_health, 0.0001)
	assert_bool(_player.health.is_dead()).is_false()
	assert_bool(_game_over.visible).is_false()


func test_ac112_pause_lists_the_whole_pool() -> void:
	_pause.open()
	assert_bool(_panel.is_editable()).is_true()
	assert_int(_panel.get_row_count()).is_equal(_wave_manager.get_card_pool().size())


func test_ac113_plus_and_minus_change_the_stats() -> void:
	_pause.open()
	assert_bool(_panel.is_minus_enabled(DAMAGE_UPGRADE)).is_false()
	_panel.add(DAMAGE_UPGRADE)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(PLAYER_STATS.damage + DAMAGE_UPGRADE.amount, 0.0001)
	# Adapted (sandbox-arena-control.md): read from the warrior data, not a fixed value.
	assert_str(_pause.get_value_text(PlayerStats.Stat.DAMAGE)).is_equal("%.1f" % (PLAYER_STATS.damage + DAMAGE_UPGRADE.amount))
	assert_str(_panel.get_count_text(DAMAGE_UPGRADE)).is_equal("1/%d" % DAMAGE_UPGRADE.max_stacks)
	assert_bool(_panel.is_minus_enabled(DAMAGE_UPGRADE)).is_true()
	_panel.remove(DAMAGE_UPGRADE)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(PLAYER_STATS.damage, 0.0001)
	assert_bool(_panel.is_minus_enabled(DAMAGE_UPGRADE)).is_false()


func test_ac114_unique_upgrades_stop_at_their_max_level() -> void:
	_pause.open()
	for i: int in CONCUSSIVE.max_level:
		_panel.add(CONCUSSIVE)
	assert_str(_panel.get_count_text(CONCUSSIVE)).is_equal("%d/%d" % [CONCUSSIVE.max_level, CONCUSSIVE.max_level])
	assert_bool(_panel.is_plus_enabled(CONCUSSIVE)).is_false()
	_panel.add(CONCUSSIVE)
	assert_int(_player.basic_ability.get_unique_level(CONCUSSIVE.id)).is_equal(CONCUSSIVE.max_level)
	_panel.remove(CONCUSSIVE)
	assert_int(_player.basic_ability.get_unique_level(CONCUSSIVE.id)).is_equal(CONCUSSIVE.max_level - 1)
	assert_bool(_panel.is_plus_enabled(CONCUSSIVE)).is_true()


func test_ac115_reset_returns_to_the_base_build() -> void:
	_pause.open()
	_panel.add(DAMAGE_UPGRADE)
	_panel.add(SHIELD_CHARGE.upgrades[0])
	_panel.add(CONCUSSIVE)
	_panel.reset_all()
	assert_int(_player.stats.get_upgrades().size()).is_equal(0)
	assert_int(_player.basic_ability.get_upgrades().size()).is_equal(0)
	assert_int(_player.basic_ability.get_unique_level(CONCUSSIVE.id)).is_equal(0)
	assert_float(_player.basic_ability.get_stat(AbilityData.Stat.BASE_DAMAGE)).is_equal_approx(SHIELD_CHARGE.base_damage, 0.0001)
	assert_str(_pause.get_value_text(PlayerStats.Stat.DAMAGE)).is_equal("%.1f" % PLAYER_STATS.damage)


func test_ac121_stat_cards_stop_at_their_cap() -> void:
	_pause.open()
	var crit: UpgradeData = CRIT_UPGRADE
	for i: int in crit.max_stacks:
		_panel.add(crit)
	assert_str(_panel.get_count_text(crit)).is_equal("%d/%d" % [crit.max_stacks, crit.max_stacks])
	assert_bool(_panel.is_plus_enabled(crit)).is_false()
	_panel.add(crit)
	assert_int(_player.count_upgrade(crit)).is_equal(crit.max_stacks)


func test_ac122_rows_show_base_and_current_values() -> void:
	_pause.open()
	var charge_damage: AbilityUpgradeData = SHIELD_CHARGE.upgrades[AbilityData.Stat.BASE_DAMAGE]
	assert_str(_panel.get_value_text(charge_damage)).is_equal("(12 → 12)")
	for i: int in 5:
		_panel.add(charge_damage)
		_panel.add(CRIT_UPGRADE)
	assert_str(_panel.get_value_text(charge_damage)).is_equal("(12 → 32)")
	assert_str(_panel.get_value_text(CRIT_UPGRADE)).is_equal("(5 % → 30 %)")


func test_ac123_unique_rows_show_their_effect() -> void:
	_pause.open()
	assert_str(_panel.get_value_text(CONCUSSIVE)).is_equal("(—)")
	_panel.add(CONCUSSIVE)
	_panel.add(CONCUSSIVE)
	assert_str(_panel.get_value_text(CONCUSSIVE)).is_equal("(2.0 s)")


func test_ac124_name_tooltip_summarises_the_card() -> void:
	_pause.open()
	var tooltip: String = _panel.get_name_tooltip(DAMAGE_UPGRADE)
	assert_str(tooltip).contains(DAMAGE_UPGRADE.description)
	assert_str(tooltip).contains(str(DAMAGE_UPGRADE.max_stacks))
	assert_str(_panel.get_name_tooltip(CONCUSSIVE)).contains("Nv 2")


## Replaces AC116 (the HUD label): the mode is shown in the pause menu.
func test_ac168_pause_shows_the_sandbox_mode() -> void:
	_pause.open()
	assert_str(_pause.get_mode_text()).is_equal("Modo de juego: Sandbox")


func test_ac117_main_menu_buttons_point_to_an_existing_scene() -> void:
	assert_bool(ResourceLoader.exists(_pause.main_menu_path)).is_true()
	assert_bool(ResourceLoader.exists(_game_over.main_menu_path)).is_true()


## docs/specs/affliction.md (AC897): the violet cards are in the sandbox panel
## and add, level and remove Afflictions like any card.
func test_ac897_affliction_cards_are_in_the_sandbox_panel() -> void:
	var catalog: AfflictionCatalog = load("res://data/afflictions/affliction_catalog.tres")
	var poison: AfflictionUpgradeData = load("res://data/afflictions/cards/poison_basic_attack.tres")
	_pause.open()
	var pool: Array[UpgradeCard] = _wave_manager.get_card_pool()
	for card: AfflictionUpgradeData in catalog.cards:
		assert_bool(pool.has(card)).is_true()
	assert_int(_panel.get_row_count()).is_equal(pool.size())
	assert_str(_panel.get_value_text(poison)).is_equal("(—)")
	_panel.add(poison)
	assert_int(_player.afflictions.get_type_count()).is_equal(1)
	assert_str(_panel.get_count_text(poison)).is_equal("1/3")
	assert_str(_panel.get_value_text(poison)).is_equal("(20)")
	assert_str(_pause.get_afflictions_text()).is_equal("Aflicciones 1/3\nVeneno (básicos) nv. 1")
	_panel.add(poison)
	_panel.add(poison)
	assert_bool(_panel.is_plus_enabled(poison)).is_false()
	_panel.remove(poison)
	assert_str(_panel.get_value_text(poison)).is_equal("(30)")


## docs/specs/affliction.md (AC898): the pause panel fits the default window
## (1152 × 648) in sandbox, so every "+" button can be reached.
func test_ac898_the_sandbox_pause_fits_the_window() -> void:
	var window := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	_pause.open()
	await get_tree().process_frame
	var panel: Control = _pause.get_node("Frame/Panel") as Control
	# Adapted (pause-fullscreen-max-upgrades.md): the panel now stretches over the
	# whole viewport, so what must fit is the size its content needs.
	assert_float(panel.get_combined_minimum_size().x).is_less_equal(window.x)
	assert_float(panel.get_combined_minimum_size().y).is_less_equal(window.y)


func test_ac898_affliction_rows_name_their_source() -> void:
	var poison: AfflictionUpgradeData = load("res://data/afflictions/cards/poison_basic_attack.tres")
	var frost: AfflictionUpgradeData = load("res://data/afflictions/cards/frost_ability.tres")
	_pause.open()
	assert_str(_panel.row_name(poison)).is_equal("Veneno (básicos)")
	assert_str(_panel.row_name(frost)).is_equal("Escarcha (habilidad)")
	assert_str(_panel.row_name(DAMAGE_UPGRADE)).is_equal(DAMAGE_UPGRADE.title)
