class_name PauseMenu
extends Control
## Pause modal: game mode (top-left corner), the upgradeable player stats (two
## columns and a block below, laid out by StatDisplayTable), current
## wave and kills. In sandbox it also shows the upgrade panel to add or remove
## any upgrade freely.
## Toggled with the `pause` action; ignored while choosing an upgrade, a ban or
## the ability, and on Game Over. "Menú principal" leaves the run.
## "Reanudar" takes the focus when it opens (gamepad); `ui_cancel` resumes too.

const ACTION_PAUSE: StringName = &"pause"
const ACTION_BACK: StringName = &"ui_cancel"

@export var player: Player
@export var run_state: RunState
@export var display_table: StatDisplayTable
@export var picker: UpgradePicker
@export var ability_picker: AbilityPicker
@export var ban_picker: UpgradeBanPicker
@export var game_over: GameOverScreen
## Source of the sandbox upgrade list.
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
@onready var _mode_label: Label = %ModeLabel
@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MainMenuButton
@onready var _sandbox_panel: SandboxUpgradePanel = %SandboxPanel


func _ready() -> void:
	hide()
	_build_rows()
	_resume_button.pressed.connect(close)
	_menu_button.pressed.connect(go_to_main_menu)
	_sandbox_panel.upgrades_changed.connect(_refresh)


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
	_refresh()
	_setup_sandbox_panel()
	get_tree().paused = true
	PointerMode.release_for_ui()
	show()
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


func get_stat_row_count() -> int:
	return _value_labels.size()


func get_value_text(stat: PlayerStats.Stat) -> String:
	return _value_labels[stat].text


func get_run_text() -> String:
	return _run_label.text


func get_mode_text() -> String:
	return _mode_label.text


func get_sandbox_panel() -> SandboxUpgradePanel:
	return _sandbox_panel


## `pause` first: Esc is also `ui_cancel`, and must toggle only once.
func _handle_pause_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_PAUSE):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(ACTION_BACK):
		close()
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	return not picker.is_open() and not ability_picker.is_open() and not ban_picker.is_open() and not game_over.visible


func _setup_sandbox_panel() -> void:
	_sandbox_panel.visible = Session.is_sandbox()
	if _sandbox_panel.visible:
		_sandbox_panel.setup(player, wave_manager.get_card_pool())


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
	_run_label.text = "Oleada %d · %d enemigos eliminados" % [run_state.wave, run_state.kills]
	_mode_label.text = "Modo de juego: %s" % Session.get_mode_name()


func _refresh_group(rows: Array[StatDisplay]) -> void:
	for row: StatDisplay in rows:
		_value_labels[row.stat].text = row.format_value(player.stats.get_stat(row.stat))
