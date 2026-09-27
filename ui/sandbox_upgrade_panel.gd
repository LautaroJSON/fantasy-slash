class_name SandboxUpgradePanel
extends VBoxContainer
## Sandbox-only list of every upgrade card of the run to build and test any
## combination freely. Each row: name (tooltip with a short summary),
## (base → current value), taken/cap, − and +. Cards stop at their cap.
## Rows are rebuilt only when the card pool changes (opening the pause).

signal upgrades_changed

@export var config: UpgradePickerConfig
@export var display_table: StatDisplayTable
@export var ability_formats: AbilityStatFormats

var _player: Player = null
var _cards: Array[UpgradeCard] = []
var _name_labels: Array[Label] = []
var _value_labels: Array[Label] = []
var _count_labels: Array[Label] = []
var _minus_buttons: Array[Button] = []
var _plus_buttons: Array[Button] = []

@onready var _grid: GridContainer = %Grid
@onready var _reset_button: Button = %ResetButton
@onready var _name_template: Label = %NameTemplate
@onready var _value_template: Label = %ValueTemplate
@onready var _count_template: Label = %CountTemplate
@onready var _button_template: Button = %ButtonTemplate


func _ready() -> void:
	_reset_button.pressed.connect(reset_all)


func setup(player: Player, cards: Array[UpgradeCard]) -> void:
	_player = player
	if cards != _cards:
		_cards.assign(cards)
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


func refresh() -> void:
	for i: int in _cards.size():
		var card: UpgradeCard = _cards[i]
		var count: int = _player.count_upgrade(card)
		_value_labels[i].text = value_text(card)
		_count_labels[i].text = "%d/%d" % [count, _player.max_count(card)]
		_minus_buttons[i].disabled = count <= 0
		_plus_buttons[i].disabled = _player.is_maxed(card)


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
	var config: AfflictionConfig = _player.afflictions.config
	return config.sandbox_name_format % [affliction.affliction.title, config.source_names[affliction.source]]


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


func get_row_count() -> int:
	return _cards.size()


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


func _changed() -> void:
	refresh()
	upgrades_changed.emit()


func _rebuild_rows() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	_name_labels.clear()
	_value_labels.clear()
	_count_labels.clear()
	_minus_buttons.clear()
	_plus_buttons.clear()
	for card: UpgradeCard in _cards:
		_add_row(card)


func _add_row(card: UpgradeCard) -> void:
	var name_label: Label = _name_template.duplicate() as Label
	name_label.text = row_name(card)
	name_label.tooltip_text = tooltip_text(card)
	name_label.visible = true
	_tint(name_label, card)
	var value_label: Label = _value_template.duplicate() as Label
	value_label.visible = true
	var count_label: Label = _count_template.duplicate() as Label
	count_label.visible = true
	var minus: Button = _make_button("−", remove.bind(card))
	var plus: Button = _make_button("+", add.bind(card))
	for cell: Control in [name_label, value_label, count_label, minus, plus]:
		_grid.add_child(cell)
	_name_labels.append(name_label)
	_value_labels.append(value_label)
	_count_labels.append(count_label)
	_minus_buttons.append(minus)
	_plus_buttons.append(plus)


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
