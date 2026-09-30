extends GdUnitTestSuite
## docs/specs/sandbox-arena-control.md: the pause menu tabs (Personaje,
## Mejoras, Enemigos), the upgrade sections and the normal-mode pools.

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const CONFIG: PauseMenuConfig = preload("res://data/ui/pause_menu_config.tres")
const DISPLAY_TABLE: StatDisplayTable = preload("res://data/ui/stat_display_table.tres")
const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const AFFLICTION_CATALOG: AfflictionCatalog = preload("res://data/afflictions/affliction_catalog.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const BUFF: BuffData = preload("res://data/buffs/compensation.tres")
const GRUNT_SPAWN: EnemySpawnEntry = preload("res://data/enemies/spawn/grunt_spawn.tres")
const MIN_TOUCH_HEIGHT: float = 44.0
const OFFENSE_TITLES: Array[String] = ["Daño", "Bono de daño", "Crítico", "Daño crítico", "Velocidad de ataque", "Rango"]
const DEFENSE_TITLES: Array[String] = ["Vida", "Defensa", "Robo de vida", "Velocidad", "Imán"]
const AFFLICTION_TITLES: Array[String] = ["Acumulación de Aflicción"]

var _arena: Node3D
var _player: Player
var _pause: PauseMenu
var _wave_manager: WaveManager


func before_test() -> void:
	Session.sandbox_request = null
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_player = _arena.get_node("Player") as Player
	_pause = _arena.get_node("UI/PauseMenu") as PauseMenu
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	await get_tree().process_frame
	(_arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHIELD_CHARGE)


func after_test() -> void:
	Session.mode = GameSession.Mode.NORMAL
	Session.sandbox_request = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_pause._unhandled_input(event)


func _titles_of(group: UpgradeCard.Group) -> Array[String]:
	var titles: Array[String] = []
	for card: UpgradeData in CATALOG.upgrades:
		if card.get_group() == group:
			titles.append(card.title)
	return titles


# --- Tabs -------------------------------------------------------------------

func test_ac1346_normal_has_two_tabs_and_sandbox_three() -> void:
	_pause.open()
	assert_int(_pause.get_visible_tab_count()).is_equal(2)
	_pause.close()
	Session.mode = GameSession.Mode.SANDBOX
	_pause.open()
	assert_int(_pause.get_visible_tab_count()).is_equal(3)


func test_ac1347_tab_actions_cycle_the_visible_tabs() -> void:
	_pause.open()
	assert_int(_pause.get_tab()).is_equal(PauseMenu.Tab.CHARACTER)
	_press(&"pause_tab_next")
	assert_int(_pause.get_tab()).is_equal(PauseMenu.Tab.UPGRADES)
	_press(&"pause_tab_next")
	assert_int(_pause.get_tab()).is_equal(PauseMenu.Tab.CHARACTER)
	_press(&"pause_tab_prev")
	assert_int(_pause.get_tab()).is_equal(PauseMenu.Tab.UPGRADES)


func test_ac1347_tab_actions_have_keyboard_and_gamepad_bindings() -> void:
	for action: StringName in [&"pause_tab_prev", &"pause_tab_next"]:
		var has_key: bool = false
		var has_pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_pad = has_pad or event is InputEventJoypadButton
		assert_bool(has_key).override_failure_message("%s has no key" % action).is_true()
		assert_bool(has_pad).override_failure_message("%s has no gamepad button" % action).is_true()


func test_ac1348_reopens_on_the_last_tab_with_the_focus_on_resume() -> void:
	Session.mode = GameSession.Mode.SANDBOX
	_pause.open()
	_pause.select_tab(PauseMenu.Tab.ENEMIES)
	# The focus moves one frame after the tab change (pause-fullscreen-max-upgrades.md).
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(get_viewport().gui_get_focus_owner()).is_same(_pause.get_enemy_panel().get_first_focus())
	_pause.close()
	_pause.open()
	assert_int(_pause.get_tab()).is_equal(PauseMenu.Tab.ENEMIES)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(_pause.get_node("%ResumeButton"))
	_pause.select_tab(PauseMenu.Tab.CHARACTER)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(get_viewport().gui_get_focus_owner()).is_same(_pause.get_node("%ResumeButton"))


func test_ac1349_character_tab_shows_stats_and_afflictions() -> void:
	_pause.open()
	assert_int(_pause.get_stat_row_count()).is_equal(DISPLAY_TABLE.row_count())
	assert_str(_pause.get_value_text(PlayerStats.Stat.DAMAGE)).is_equal("%.1f" % PLAYER_STATS.damage)
	assert_str(_pause.get_afflictions_text()).starts_with("Aflicciones 0/")


func test_ac1350_active_buffs_are_listed() -> void:
	_pause.open()
	assert_str(_pause.get_buffs_text()).is_equal("%s\n%s" % [CONFIG.buffs_title, CONFIG.no_buffs_text])
	_pause.close()
	for i: int in 3:
		_player.buffs.add_stack(BUFF)
	_pause.open()
	var stacks: int = _player.buffs.get_stacks(BUFF.id)
	var line: String = CONFIG.buff_entry_format % [BUFF.title, stacks, _player.buffs.get_time_left(BUFF.id)]
	assert_str(_pause.get_buffs_text()).is_equal("%s\n%s" % [CONFIG.buffs_title, line])
	assert_str(line).contains("×%d" % stacks)


func test_ac1351_tab_prompts_follow_the_device() -> void:
	_pause.open()
	var monitor: InputDeviceMonitor = _pause.get_device_monitor()
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_A
	monitor.handle_event(key)
	assert_str(_pause.get_tab_hint_text()).is_equal("Q / E  Cambiar pestaña")
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	pad.button_index = JOY_BUTTON_A
	monitor.handle_event(pad)
	assert_str(_pause.get_tab_hint_text()).is_equal("LB / RB  Cambiar pestaña")


func test_ac1352_tab_headers_are_tall_enough_to_tap() -> void:
	_pause.open()
	await get_tree().process_frame
	assert_float(_pause.get_tab_bar_height()).is_greater_equal(MIN_TOUCH_HEIGHT)


# --- Upgrade tab ------------------------------------------------------------

func test_ac1353_every_card_belongs_to_its_section() -> void:
	assert_array(_titles_of(UpgradeCard.Group.OFFENSE)).contains_exactly_in_any_order(OFFENSE_TITLES)
	assert_array(_titles_of(UpgradeCard.Group.DEFENSE)).contains_exactly_in_any_order(DEFENSE_TITLES)
	assert_array(_titles_of(UpgradeCard.Group.AFFLICTION)).contains_exactly_in_any_order(AFFLICTION_TITLES)
	assert_int(CATALOG.upgrades.size()).is_equal(OFFENSE_TITLES.size() + DEFENSE_TITLES.size() + AFFLICTION_TITLES.size())
	for card: UpgradeCard in SHIELD_CHARGE.upgrades:
		assert_int(card.get_group()).is_equal(UpgradeCard.Group.ABILITY)
	for card: UpgradeCard in SHIELD_CHARGE.unique_upgrades:
		assert_int(card.get_group()).is_equal(UpgradeCard.Group.ABILITY)
	for card: UpgradeCard in AFFLICTION_CATALOG.cards:
		assert_int(card.get_group()).is_equal(UpgradeCard.Group.AFFLICTION)
	_pause.open()
	var panel: UpgradePanel = _pause.get_upgrade_panel()
	for group: int in UpgradeCard.Group.size():
		assert_str(panel.get_section_title(group)).is_equal(CONFIG.group_titles[group])
	assert_array(CONFIG.group_titles).is_equal(["Ofensivo", "Defensivo", "Habilidad", "Aflicción"])


func test_ac1354_sandbox_lists_the_whole_pool_by_section() -> void:
	Session.mode = GameSession.Mode.SANDBOX
	_pause.open()
	var panel: UpgradePanel = _pause.get_upgrade_panel()
	assert_bool(panel.is_editable()).is_true()
	var total: int = 0
	for group: int in UpgradeCard.Group.size():
		total += panel.get_group_row_count(group)
	assert_int(total).is_equal(_wave_manager.get_card_pool().size())
	assert_int(panel.get_group_row_count(UpgradeCard.Group.ABILITY)).is_equal(SHIELD_CHARGE.upgrades.size() + SHIELD_CHARGE.unique_upgrades.size())


func test_ac1355_normal_lists_only_the_cards_taken() -> void:
	_player.apply_upgrade(DAMAGE_UPGRADE)
	_player.apply_upgrade(DAMAGE_UPGRADE)
	_pause.open()
	var panel: UpgradePanel = _pause.get_upgrade_panel()
	assert_bool(panel.is_editable()).is_false()
	assert_int(panel.get_row_count()).is_equal(1)
	assert_int(panel.get_group_row_count(UpgradeCard.Group.OFFENSE)).is_equal(1)
	assert_str(panel.get_count_text(DAMAGE_UPGRADE)).is_equal("2/%d" % DAMAGE_UPGRADE.total_copies())
	assert_str(panel.get_value_text(DAMAGE_UPGRADE)).is_equal("(%.1f → %.1f)" % [PLAYER_STATS.damage, PLAYER_STATS.damage + 2.0 * DAMAGE_UPGRADE.amount])
	assert_bool(panel.is_section_empty_shown(UpgradeCard.Group.OFFENSE)).is_false()
	for group: UpgradeCard.Group in [UpgradeCard.Group.DEFENSE, UpgradeCard.Group.ABILITY, UpgradeCard.Group.AFFLICTION]:
		assert_bool(panel.is_section_empty_shown(group)).is_true()
		assert_str(panel.get_empty_text(group)).is_equal(CONFIG.empty_group_text)


func test_ac1356_upgrade_changes_refresh_the_character_tab() -> void:
	Session.mode = GameSession.Mode.SANDBOX
	_pause.open()
	_pause.get_upgrade_panel().add(DAMAGE_UPGRADE)
	assert_str(_pause.get_value_text(PlayerStats.Stat.DAMAGE)).is_equal("%.1f" % (PLAYER_STATS.damage + DAMAGE_UPGRADE.amount))


# --- Normal mode ------------------------------------------------------------

func test_ac1358_normal_pools_keep_their_size_and_enemies_have_no_options() -> void:
	var grunt_pool: EnemyPool = _wave_manager.get_roster().get_entry(0).pool
	assert_int(grunt_pool.get_size()).is_equal(GRUNT_SPAWN.max_per_wave)
	var registry: EnemyRegistry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	assert_int(registry.alive_count()).is_greater(0)
	for enemy: Enemy in registry.get_active():
		assert_bool(enemy.dummy).is_false()
		assert_bool(enemy.health.death_protected).is_false()


## AC898 for every tab (sandbox-arena-control.md): the panel, buttons
## included, fits the default window whatever tab is shown.
func test_ac1359_every_tab_fits_the_window() -> void:
	var window := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	Session.mode = GameSession.Mode.SANDBOX
	_pause.open()
	var panel: Control = _pause.get_node("Frame/Panel") as Control
	for tab: int in [PauseMenu.Tab.CHARACTER, PauseMenu.Tab.UPGRADES, PauseMenu.Tab.ENEMIES]:
		_pause.select_tab(tab)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_float(panel.get_combined_minimum_size().y).override_failure_message("tab %d is %.0f px tall" % [tab, panel.get_combined_minimum_size().y]).is_less_equal(window.y)
		assert_float(panel.get_combined_minimum_size().x).is_less_equal(window.x)
