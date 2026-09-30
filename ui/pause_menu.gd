class_name PauseMenu
extends Control
## Pause modal with tabs (docs/specs/sandbox-arena-control.md): game mode
## (top-left corner), the run line and
## - Personaje: the upgradeable player stats (two columns and a block below,
##   laid out by StatDisplayTable), the active buffs and the held Afflictions;
## - Mejoras: the upgrades by section (editable in sandbox, the taken ones in normal);
## - Enemigos (sandbox only): what to summon.
## Toggled with the `pause` action; ignored while choosing an upgrade, a ban or
## the ability, and on Game Over. `pause_tab_prev`/`pause_tab_next` cycle the
## tabs. "Menú principal" leaves the run. "Reanudar" takes the focus when it
## opens (gamepad); `ui_cancel` resumes too.

const ACTION_PAUSE: StringName = &"pause"
const ACTION_BACK: StringName = &"ui_cancel"
const ACTION_TAB_PREV: StringName = &"pause_tab_prev"
const ACTION_TAB_NEXT: StringName = &"pause_tab_next"

## Tab indices (children order of Tabs).
enum Tab {
	CHARACTER,
	UPGRADES,
	ENEMIES,
}

@export var player: Player
@export var run_state: RunState
@export var display_table: StatDisplayTable
@export var config: PauseMenuConfig
@export var sandbox_config: SandboxConfig
@export var prompts: InputPromptConfig
@export var picker: UpgradePicker
@export var ability_picker: AbilityPicker
@export var ban_picker: UpgradeBanPicker
@export var game_over: GameOverScreen
## Source of the card pool, the sandbox roster and the summons.
@export var wave_manager: WaveManager
@export_file("*.tscn") var main_menu_path: String

## One value label per display row, built once in _ready.
var _value_labels: Dictionary[int, Label] = {}

@onready var _left_grid: GridContainer = %LeftGrid
@onready var _right_grid: GridContainer = %RightGrid
@onready var _bottom_grid: GridContainer = %BottomGrid
@onready var _name_template: Label = %NameTemplate
@onready var _value_template: Label = %ValueTemplate
@onready var _run_label: Label = %RunLabel
@onready var _buffs_label: Label = %BuffsLabel
@onready var _afflictions_label: Label = %AfflictionsLabel
@onready var _mode_label: Label = %ModeLabel
@onready var _tabs: TabContainer = %Tabs
@onready var _tab_hint: Label = %TabHint
@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MainMenuButton
@onready var _upgrade_panel: UpgradePanel = %Mejoras
@onready var _enemy_panel: SandboxEnemyPanel = %Enemigos
@onready var _device_monitor: InputDeviceMonitor = %InputDeviceMonitor
@onready var _frame: MarginContainer = %Frame


func _ready() -> void:
	hide()
	_apply_screen_margin()
	_build_rows()
	_resume_button.pressed.connect(close)
	_menu_button.pressed.connect(go_to_main_menu)
	_upgrade_panel.upgrades_changed.connect(_refresh)
	_enemy_panel.spawn_requested.connect(_on_spawn_requested)
	_enemy_panel.clear_requested.connect(_on_clear_requested)
	_tabs.tab_changed.connect(_on_tab_changed)
	_device_monitor.device_changed.connect(_show_tab_hint)


func _unhandled_input(event: InputEvent) -> void:
	_handle_pause_input(event)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if not _can_open():
		return
	_setup_tabs()
	_refresh()
	get_tree().paused = true
	PointerMode.release_for_ui()
	show()
	_show_tab_hint(_device_monitor.get_device())
	_resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	PointerMode.capture_for_gameplay()


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_path)


func is_open() -> bool:
	return visible


## Next (`step` 1) or previous (-1) visible tab, wrapping around.
func cycle_tab(step: int) -> void:
	var count: int = _tabs.get_tab_count()
	var index: int = _tabs.current_tab
	for i: int in count:
		index = posmod(index + step, count)
		if not _tabs.is_tab_hidden(index):
			_tabs.current_tab = index
			return


func select_tab(tab: Tab) -> void:
	_tabs.current_tab = tab


func get_tab() -> int:
	return _tabs.current_tab


func get_visible_tab_count() -> int:
	var count: int = 0
	for i: int in _tabs.get_tab_count():
		if not _tabs.is_tab_hidden(i):
			count += 1
	return count


func get_tab_bar_height() -> float:
	return _tabs.get_tab_bar().get_minimum_size().y


func get_stat_row_count() -> int:
	return _value_labels.size()


func get_value_text(stat: PlayerStats.Stat) -> String:
	return _value_labels[stat].text


func get_run_text() -> String:
	return _run_label.text


func get_mode_text() -> String:
	return _mode_label.text


func get_buffs_text() -> String:
	return _buffs_label.text


func get_afflictions_text() -> String:
	return _afflictions_label.text


func get_tab_hint_text() -> String:
	return _tab_hint.text


func get_upgrade_panel() -> UpgradePanel:
	return _upgrade_panel


func get_enemy_panel() -> SandboxEnemyPanel:
	return _enemy_panel


func get_device_monitor() -> InputDeviceMonitor:
	return _device_monitor


## `pause` first: Esc is also `ui_cancel`, and must toggle only once.
func _handle_pause_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_PAUSE):
		toggle()
		get_viewport().set_input_as_handled()
	elif not visible:
		return
	elif event.is_action_pressed(ACTION_BACK):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_TAB_NEXT):
		cycle_tab(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_TAB_PREV):
		cycle_tab(-1)
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	return not picker.is_open() and not ability_picker.is_open() and not ban_picker.is_open() and not game_over.visible


## The enemy tab only exists in sandbox; the upgrade tab is editable there.
func _setup_tabs() -> void:
	var sandbox: bool = Session.is_sandbox()
	_tabs.set_tab_hidden(Tab.ENEMIES, not sandbox)
	if _tabs.is_tab_hidden(_tabs.current_tab):
		_tabs.current_tab = Tab.CHARACTER
	_upgrade_panel.setup(player, wave_manager.get_card_pool(), sandbox)
	if sandbox:
		_enemy_panel.setup(wave_manager.get_roster(), Session.get_sandbox_request(sandbox_config), wave_manager.config, wave_manager.registry, config)


## Keyboard or gamepad prompts; none on touch (the tabs are tapped).
func _show_tab_hint(device: InputDeviceMonitor.Device) -> void:
	var prev: String = prompts.get_prompt(ACTION_TAB_PREV, device)
	var next: String = prompts.get_prompt(ACTION_TAB_NEXT, device)
	_tab_hint.visible = not prev.is_empty() and not next.is_empty()
	_tab_hint.text = config.tab_hint_format % [prev, next]


## Gamepad focus goes to the first control of the tab, or to "Reanudar". One
## frame later: a tab that was hidden has no layout yet, and the upgrade list
## would scroll to a wrong place (docs/specs/pause-fullscreen-max-upgrades.md).
func _on_tab_changed(_tab: int) -> void:
	if not visible:
		return
	await get_tree().process_frame
	if visible:
		_focus_current_tab()


func _focus_current_tab() -> void:
	_upgrade_panel.get_scroll().scroll_vertical = 0
	var first: Control = _first_focus_of_current_tab()
	if first != null:
		first.grab_focus()
	else:
		_resume_button.grab_focus()


func _first_focus_of_current_tab() -> Control:
	match _tabs.current_tab:
		Tab.UPGRADES:
			return _upgrade_panel.get_first_focus()
		Tab.ENEMIES:
			return _enemy_panel.get_first_focus()
	return null


func _on_spawn_requested() -> void:
	wave_manager.spawn_sandbox(Session.get_sandbox_request(sandbox_config))
	close()


func _on_clear_requested() -> void:
	wave_manager.clear_arena()


func _build_rows() -> void:
	_build_group(display_table.left_column, _left_grid)
	_build_group(display_table.right_column, _right_grid)
	_build_group(display_table.bottom_rows, _bottom_grid)


func _build_group(rows: Array[StatDisplay], grid: GridContainer) -> void:
	for row: StatDisplay in rows:
		var name_label: Label = _name_template.duplicate() as Label
		name_label.text = row.label
		name_label.visible = true
		var value_label: Label = _value_template.duplicate() as Label
		value_label.visible = true
		grid.add_child(name_label)
		grid.add_child(value_label)
		_value_labels[row.stat] = value_label


func _refresh() -> void:
	_refresh_group(display_table.left_column)
	_refresh_group(display_table.right_column)
	_refresh_group(display_table.bottom_rows)
	_run_label.text = _run_text()
	_mode_label.text = "Modo de juego: %s" % Session.get_mode_name()
	_buffs_label.text = _buffs_text()
	_afflictions_label.text = _afflictions_text()


## The wave does not advance in sandbox: only the kills.
func _run_text() -> String:
	if Session.is_sandbox():
		return config.sandbox_run_format % run_state.kills
	return "Oleada %d · %d enemigos eliminados" % [run_state.wave, run_state.kills]


func _refresh_group(rows: Array[StatDisplay]) -> void:
	for row: StatDisplay in rows:
		_value_labels[row.stat].text = row.format_value(player.stats.get_stat(row.stat))


## "Buffs activos" and one line per buff: title, stacks and seconds left.
func _buffs_text() -> String:
	var lines: PackedStringArray = PackedStringArray([config.buffs_title])
	var active: Array[BuffComponent.ActiveBuff] = player.buffs.get_active()
	if active.is_empty():
		lines.append(config.no_buffs_text)
	for buff: BuffComponent.ActiveBuff in active:
		lines.append(config.buff_entry_format % [buff.data.title, buff.stacks, buff.time_left])
	return "\n".join(lines)


## "Aflicciones 2/3" and one line per card: Affliction, source and level
## (docs/specs/affliction.md).
func _afflictions_text() -> String:
	var loadout: AfflictionLoadout = player.afflictions
	var affliction_config: AfflictionConfig = loadout.config
	var lines: PackedStringArray = PackedStringArray([affliction_config.pause_title_format % [loadout.get_type_count(), affliction_config.max_types]])
	for i: int in loadout.get_card_count():
		var card: AfflictionUpgradeData = loadout.get_card(i)
		lines.append(affliction_config.pause_entry_format % [card.affliction.title, affliction_config.source_names[card.source], loadout.get_card_level(i)])
	return "\n".join(lines)


## Full-screen panel (docs/specs/pause-fullscreen-max-upgrades.md): the same
## gap from every screen edge.
func _apply_screen_margin() -> void:
	var margin: int = roundi(config.screen_margin)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_frame.add_theme_constant_override(side, margin)


func get_panel() -> Control:
	return _frame.get_child(0) as Control
