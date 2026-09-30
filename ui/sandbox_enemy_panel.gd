class_name SandboxEnemyPanel
extends VBoxContainer
## Enemies tab of the pause menu, sandbox only (docs/specs/sandbox-arena-control.md):
## pick what to summon (type, count, level and options). Every change is
## written to the session request; nothing is summoned until "Invocar".

## "Invocar": summon the request (the pause menu closes).
signal spawn_requested
## "Limpiar arena": send every enemy back to its pool.
signal clear_requested

var _roster: SandboxRoster
var _request: SandboxSpawnRequest
var _wave_config: WaveConfig
var _registry: EnemyRegistry
var _config: PauseMenuConfig

@onready var _type_option: OptionButton = %TypeOption
@onready var _count_minus: Button = %CountMinus
@onready var _count_label: Label = %CountLabel
@onready var _count_plus: Button = %CountPlus
@onready var _level_minus: Button = %LevelMinus
@onready var _level_label: Label = %LevelLabel
@onready var _level_plus: Button = %LevelPlus
@onready var _wave_hint: Label = %WaveHint
@onready var _immortal_check: CheckButton = %ImmortalCheck
@onready var _dummy_check: CheckButton = %DummyCheck
@onready var _respawn_check: CheckButton = %RespawnCheck
@onready var _alive_label: Label = %AliveLabel
@onready var _spawn_button: Button = %SpawnButton
@onready var _clear_button: Button = %ClearButton


func _ready() -> void:
	_type_option.item_selected.connect(_on_type_selected)
	_count_minus.pressed.connect(step_count.bind(-1))
	_count_plus.pressed.connect(step_count.bind(1))
	_level_minus.pressed.connect(step_level.bind(-1))
	_level_plus.pressed.connect(step_level.bind(1))
	_immortal_check.toggled.connect(set_immortal)
	_dummy_check.toggled.connect(set_dummy)
	_respawn_check.toggled.connect(set_respawn)
	_spawn_button.pressed.connect(spawn_requested.emit)
	_clear_button.pressed.connect(_on_clear_pressed)


## The type list is built only the first time (the roster never changes).
func setup(roster: SandboxRoster, request: SandboxSpawnRequest, wave_config: WaveConfig, registry: EnemyRegistry, config: PauseMenuConfig) -> void:
	if _roster != roster:
		_roster = roster
		_build_types()
	_request = request
	_wave_config = wave_config
	_registry = registry
	_config = config
	_request.entry = clampi(_request.entry, 0, _roster.size() - 1)
	_type_option.select(_type_option.get_item_index(_request.entry))
	_clamp_count()
	refresh()


func refresh() -> void:
	var cap: int = _roster.get_entry(_request.entry).max_count
	_count_label.text = str(_request.count)
	_count_minus.disabled = _request.count <= 1
	_count_plus.disabled = _request.count >= cap
	_level_label.text = str(_request.level)
	_level_minus.disabled = _request.level <= 1
	_level_plus.disabled = _request.level >= _wave_config.max_enemy_level
	_wave_hint.text = _config.wave_hint_format % _wave_config.first_wave_for_level(_request.level)
	_immortal_check.set_pressed_no_signal(_request.immortal)
	_dummy_check.set_pressed_no_signal(_request.dummy)
	_respawn_check.set_pressed_no_signal(_request.respawn)
	_alive_label.text = _config.alive_format % _registry.alive_count()


## `index` in the roster (not in the list, which has a separator before the bosses).
func select_entry(index: int) -> void:
	_request.entry = clampi(index, 0, _roster.size() - 1)
	_type_option.select(_type_option.get_item_index(_request.entry))
	_clamp_count()
	refresh()


func step_count(delta: int) -> void:
	_request.count += delta
	_clamp_count()
	refresh()


func step_level(delta: int) -> void:
	_request.level = clampi(_request.level + delta, 1, _wave_config.max_enemy_level)
	refresh()


func set_immortal(on: bool) -> void:
	_request.immortal = on


func set_dummy(on: bool) -> void:
	_request.dummy = on


func set_respawn(on: bool) -> void:
	_request.respawn = on


func get_count() -> int:
	return _request.count


func get_level() -> int:
	return _request.level


func get_wave_hint_text() -> String:
	return _wave_hint.text


func get_alive_text() -> String:
	return _alive_label.text


func is_count_minus_enabled() -> bool:
	return not _count_minus.disabled


func is_count_plus_enabled() -> bool:
	return not _count_plus.disabled


## Titles in list order, separator excluded.
func get_type_titles() -> PackedStringArray:
	var titles: PackedStringArray = PackedStringArray()
	for i: int in _type_option.item_count:
		if not _type_option.is_item_separator(i):
			titles.append(_type_option.get_item_text(i))
	return titles


func has_boss_separator() -> bool:
	var index: int = _roster.first_boss_index()
	return index < _roster.size() and _type_option.is_item_separator(_type_option.get_item_index(index) - 1)


func press_spawn() -> void:
	_spawn_button.pressed.emit()


func press_clear() -> void:
	_clear_button.pressed.emit()


## First control of this tab (gamepad focus).
func get_first_focus() -> Control:
	return _type_option


func _build_types() -> void:
	_type_option.clear()
	for i: int in _roster.size():
		if i == _roster.first_boss_index():
			_type_option.add_separator()
		_type_option.add_item(_roster.get_entry(i).title, i)


func _clamp_count() -> void:
	_request.count = clampi(_request.count, 1, _roster.get_entry(_request.entry).max_count)


func _on_type_selected(list_index: int) -> void:
	select_entry(_type_option.get_item_id(list_index))


func _on_clear_pressed() -> void:
	clear_requested.emit()
	refresh()
