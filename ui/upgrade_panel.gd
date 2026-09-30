class_name UpgradePanel
extends VBoxContainer
## Upgrades tab of the pause menu (docs/specs/sandbox-arena-control.md): the
## cards split in four sections (offensive, defensive, ability, Affliction).
## Editable (sandbox): every card of the run with − and +, to build and test
## any combination freely; cards stop at their cap. Read-only (normal): only
## the cards taken. Each row: name (tooltip with a short summary),
## (base → current value), taken/cap and, when editable, − and +.
## Rows are rebuilt only when the listed cards change (opening the pause).

signal upgrades_changed

@export var config: UpgradePickerConfig
@export var display_table: StatDisplayTable
@export var ability_formats: AbilityStatFormats
@export var pause_config: PauseMenuConfig

var _player: Player = null
var _editable: bool = true
## Every card that may be listed (the run's pool).
var _pool: Array[UpgradeCard] = []
## Cards listed now, in section order.
var _cards: Array[UpgradeCard] = []
## Reused to compute the cards to list.
var _listed: Array[UpgradeCard] = []
var _name_labels: Array[Label] = []
var _value_labels: Array[Label] = []
var _count_labels: Array[Label] = []
var _minus_buttons: Array[Button] = []
var _plus_buttons: Array[Button] = []
var _max_buttons: Array[Button] = []
## One title, grid and "empty" label per UpgradeCard.Group, built once in _ready.
var _section_titles: Array[Label] = []
## "Max" of each section; null where the section has none.
var _section_max_buttons: Array[Button] = []
var _grids: Array[GridContainer] = []
var _empty_labels: Array[Label] = []

@onready var _left_column: VBoxContainer = %LeftColumn
@onready var _right_column: VBoxContainer = %RightColumn
@onready var _header_template: HBoxContainer = %HeaderTemplate
@onready var _reset_button: Button = %ResetButton
@onready var _section_template: Label = %SectionTemplate
@onready var _grid_template: GridContainer = %GridTemplate
@onready var _cell_template: VBoxContainer = %CellTemplate
@onready var _name_template: Label = %NameTemplate
@onready var _value_template: Label = %ValueTemplate
@onready var _count_template: Label = %CountTemplate
@onready var _button_template: Button = %ButtonTemplate


func _ready() -> void:
	_build_sections()
	_rebuild_rows()
	_reset_button.pressed.connect(reset_all)


## `editable` lists the whole pool with − and +; otherwise only the cards taken.
func setup(player: Player, cards: Array[UpgradeCard], editable: bool) -> void:
	_player = player
	_pool.assign(cards)
	_reset_button.visible = editable
	_collect_listed(editable)
	if editable != _editable or _listed != _cards:
		_editable = editable
		_cards.assign(_listed)
		_rebuild_rows()
	refresh()


func add(card: UpgradeCard) -> void:
	if _player.is_maxed(card):
		return
	_player.apply_upgrade(card)
	_changed()


func remove(card: UpgradeCard) -> void:
	if _player.count_upgrade(card) <= 0:
		return
	_player.remove_upgrade(card)
	_changed()


func reset_all() -> void:
	_player.reset_upgrades()
	_changed()


## Takes `card` up to its cap (docs/specs/pause-fullscreen-max-upgrades.md).
func max_card(card: UpgradeCard) -> void:
	_fill(card)
	_changed()


## Takes every listed card of `group` up to its cap (golden ones included).
func max_group(group: UpgradeCard.Group) -> void:
	for card: UpgradeCard in _cards:
		if card.get_group() == group:
			_fill(card)
	_changed()


## Applies `card` until it is maxed. Stops when a pick does not count (e.g. the
## Affliction type cap is full), so the loop always ends.
func _fill(card: UpgradeCard) -> void:
	while not _player.is_maxed(card):
		var before: int = _player.count_upgrade(card)
		_player.apply_upgrade(card)
		if _player.count_upgrade(card) <= before:
			return


func refresh() -> void:
	for i: int in _cards.size():
		var card: UpgradeCard = _cards[i]
		var count: int = _player.count_upgrade(card)
		_value_labels[i].text = value_text(card)
		_count_labels[i].text = "%d/%d" % [count, _player.max_count(card)]
		if _editable:
			_minus_buttons[i].disabled = count <= 0
			_plus_buttons[i].disabled = _player.is_maxed(card)
			_max_buttons[i].disabled = _plus_buttons[i].disabled


## "(base → current)" for stat cards; the current effect for unique upgrades.
func value_text(card: UpgradeCard) -> String:
	if card is UpgradeData:
		return _player_stat_text(card as UpgradeData)
	if card is AbilityUpgradeData:
		return _ability_stat_text(card as AbilityUpgradeData)
	if card is AfflictionUpgradeData:
		return _affliction_text(card as AfflictionUpgradeData)
	return _unique_text(card as AbilityUniqueUpgradeData)


## Row name: the card title; Affliction cards show their Affliction and source
## instead ("Veneno (básicos)"), so the two cards of a type tell apart.
func row_name(card: UpgradeCard) -> String:
	var affliction: AfflictionUpgradeData = card as AfflictionUpgradeData
	if affliction == null:
		return card.title
	var affliction_config: AfflictionConfig = _player.afflictions.config
	return affliction_config.sandbox_name_format % [affliction.affliction.title, affliction_config.source_names[affliction.source]]


## Short summary shown on hover: what one pick gives and the cap.
func tooltip_text(card: UpgradeCard) -> String:
	var affliction: AfflictionUpgradeData = card as AfflictionUpgradeData
	if affliction != null:
		return _affliction_tooltip(affliction)
	var unique: AbilityUniqueUpgradeData = card as AbilityUniqueUpgradeData
	if unique == null:
		return "%s por mejora\nMáximo: %d" % [card.description, _player.max_count(card)]
	var lines: PackedStringArray = PackedStringArray()
	for level: int in range(1, unique.max_level + 1):
		lines.append("Nv %d: %s" % [level, unique.get_description(level).replace("\n", " ")])
	return "\n".join(lines)


func is_editable() -> bool:
	return _editable


func get_row_count() -> int:
	return _cards.size()


func has_row(card: UpgradeCard) -> bool:
	return _cards.has(card)


## Rows listed in the section of `group`.
func get_group_row_count(group: UpgradeCard.Group) -> int:
	var count: int = 0
	for card: UpgradeCard in _cards:
		if card.get_group() == group:
			count += 1
	return count


func get_section_title(group: UpgradeCard.Group) -> String:
	return _section_titles[group].text


## Whether the section of `group` shows the "no upgrades" text.
func is_section_empty_shown(group: UpgradeCard.Group) -> bool:
	return _empty_labels[group].visible


func get_empty_text(group: UpgradeCard.Group) -> String:
	return _empty_labels[group].text


func get_value_text(card: UpgradeCard) -> String:
	return _value_labels[_cards.find(card)].text


func get_count_text(card: UpgradeCard) -> String:
	return _count_labels[_cards.find(card)].text


func get_name_tooltip(card: UpgradeCard) -> String:
	return _name_labels[_cards.find(card)].tooltip_text


func is_plus_enabled(card: UpgradeCard) -> bool:
	return not _plus_buttons[_cards.find(card)].disabled


func is_minus_enabled(card: UpgradeCard) -> bool:
	return not _minus_buttons[_cards.find(card)].disabled


func is_max_enabled(card: UpgradeCard) -> bool:
	return not _max_buttons[_cards.find(card)].disabled


## Whether the section of `group` shows its "Max" button now.
func has_group_max_button(group: UpgradeCard.Group) -> bool:
	return _section_max_buttons[group] != null and _section_max_buttons[group].visible


## 0 = left column, 1 = right column.
func get_section_column(group: UpgradeCard.Group) -> int:
	return 1 if _section_titles[group].get_parent().get_parent() == _right_column else 0


func get_scroll() -> ScrollContainer:
	return %Scroll as ScrollContainer


## First control that takes the focus in this tab (gamepad): the "Max" of the
## first section (so its title stays in view), or "Reiniciar mejoras".
func get_first_focus() -> Control:
	if _editable:
		for button: Button in _section_max_buttons:
			if button != null:
				return button
	if _reset_button.visible:
		return _reset_button
	return null


func _player_stat_text(card: UpgradeData) -> String:
	var row: StatDisplay = display_table.find(card.stat)
	var base: float = _player.stats.base_stats.get_base(card.stat)
	return "(%s → %s)" % [row.format_value(base), row.format_value(_player.stats.get_stat(card.stat))]


func _ability_stat_text(card: AbilityUpgradeData) -> String:
	var slot: AbilityComponent = _player.ability_for(card)
	var base: float = slot.get_data().get_base(card.stat)
	var current: float = slot.get_stat(card.stat)
	return "(%s → %s)" % [ability_formats.format_value(card.stat, base), ability_formats.format_value(card.stat, current)]


func _unique_text(card: AbilityUniqueUpgradeData) -> String:
	var level: int = _player.count_upgrade(card)
	if card.value_format == null:
		return "(activo)" if level > 0 else "(inactivo)"
	if level == 0:
		return "(—)"
	return "(%s)" % card.value_format.format_value(card.get_value(level))


## Build-up per hit of the current level (docs/specs/affliction.md).
func _affliction_text(card: AfflictionUpgradeData) -> String:
	var level: int = _player.count_upgrade(card)
	if level == 0:
		return "(—)"
	return "(%s)" % card.value_format.format_value(card.get_value(level))


func _affliction_tooltip(card: AfflictionUpgradeData) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for level: int in range(1, card.max_level + 1):
		lines.append("Nv %d: %s" % [level, card.get_description(level).replace("\n", " ")])
	return "\n".join(lines)


## In normal mode a card leaving or entering the taken list rebuilds the rows.
func _changed() -> void:
	if not _editable:
		setup(_player, _pool, false)
	refresh()
	upgrades_changed.emit()


## The cards to list, grouped by section (pool order inside each one).
func _collect_listed(editable: bool) -> void:
	_listed.clear()
	for group: int in UpgradeCard.Group.size():
		for card: UpgradeCard in _pool:
			if card.get_group() == group and (editable or _player.count_upgrade(card) > 0):
				_listed.append(card)



## One header (title and, for some sections, "Max"), grid and "empty" label
## per UpgradeCard.Group, in the column of PauseMenuConfig.right_column_groups.
func _build_sections() -> void:
	for group: int in UpgradeCard.Group.size():
		var header: HBoxContainer = _header_template.duplicate() as HBoxContainer
		header.visible = true
		var title: Label = _section_template.duplicate() as Label
		title.text = pause_config.group_titles[group]
		title.visible = true
		header.add_child(title)
		var section_max: Button = null
		if pause_config.max_section_groups.has(group):
			section_max = _make_button(pause_config.max_button_text, max_group.bind(group))
			header.add_child(section_max)
		var grid: GridContainer = _grid_template.duplicate() as GridContainer
		grid.visible = true
		var empty: Label = _value_template.duplicate() as Label
		empty.text = pause_config.empty_group_text
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var column: VBoxContainer = _right_column if pause_config.right_column_groups.has(group) else _left_column
		for node: Control in [header, grid, empty]:
			column.add_child(node)
		_section_titles.append(title)
		_section_max_buttons.append(section_max)
		_grids.append(grid)
		_empty_labels.append(empty)


func _rebuild_rows() -> void:
	for grid: GridContainer in _grids:
		grid.columns = 5 if _editable else 2
		for child: Node in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	_name_labels.clear()
	_value_labels.clear()
	_count_labels.clear()
	_minus_buttons.clear()
	_plus_buttons.clear()
	_max_buttons.clear()
	for card: UpgradeCard in _cards:
		_add_row(card, _grids[card.get_group()])
	for group: int in UpgradeCard.Group.size():
		_empty_labels[group].visible = _grids[group].get_child_count() == 0
		if _section_max_buttons[group] != null:
			_section_max_buttons[group].visible = _editable


## The name and, under it, the value share one cell, so the name keeps the
## width of the column (docs/specs/pause-fullscreen-max-upgrades.md).
func _add_row(card: UpgradeCard, grid: GridContainer) -> void:
	var name_label: Label = _name_template.duplicate() as Label
	name_label.text = row_name(card)
	name_label.tooltip_text = tooltip_text(card)
	name_label.visible = true
	_tint(name_label, card)
	var value_label: Label = _value_template.duplicate() as Label
	value_label.visible = true
	var cell: VBoxContainer = _cell_template.duplicate() as VBoxContainer
	cell.visible = true
	cell.add_child(name_label)
	cell.add_child(value_label)
	var count_label: Label = _count_template.duplicate() as Label
	count_label.visible = true
	grid.add_child(cell)
	grid.add_child(count_label)
	_name_labels.append(name_label)
	_value_labels.append(value_label)
	_count_labels.append(count_label)
	if not _editable:
		return
	var minus: Button = _make_button("−", remove.bind(card))
	var plus: Button = _make_button("+", add.bind(card))
	var to_max: Button = _make_button(pause_config.max_button_text, max_card.bind(card))
	for button: Button in [minus, plus, to_max]:
		grid.add_child(button)
	_minus_buttons.append(minus)
	_plus_buttons.append(plus)
	_max_buttons.append(to_max)


func _make_button(text: String, action: Callable) -> Button:
	var button: Button = _button_template.duplicate() as Button
	button.text = text
	button.visible = true
	button.pressed.connect(action)
	return button


## Same color code as the cards: light blue for ability stats, gold for unique,
## violet for Afflictions.
func _tint(label: Label, card: UpgradeCard) -> void:
	if card is AbilityUpgradeData:
		label.add_theme_color_override(&"font_color", config.ability_card_color)
	elif card is AbilityUniqueUpgradeData:
		label.add_theme_color_override(&"font_color", config.unique_card_color)
	elif card is AfflictionUpgradeData:
		label.add_theme_color_override(&"font_color", config.affliction_card_color)
