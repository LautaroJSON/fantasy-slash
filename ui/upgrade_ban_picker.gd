class_name UpgradeBanPicker
extends Control
## Sub-menu opened by the red card: choose one upgrade that will not be offered
## again this run. "Volver" goes back to the offer without banning anything.
## The game stays paused until an upgrade is banned.
## The first card (or "Volver" when there is none) takes the focus; `ui_cancel` = "Volver".

signal ban_chosen(card: UpgradeCard)
signal ban_cancelled

const ACTION_BACK: StringName = &"ui_cancel"

@export var config: UpgradePickerConfig

var _offered: Array[UpgradeCard] = []
## Built once in _ready and shared by every ability card.
var _ability_style: CardStyle
var _unique_style: CardStyle
var _affliction_style: CardStyle

@onready var _title: Label = %Title
@onready var _cards: GridContainer = %Cards
@onready var _card_template: Button = %CardTemplate
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	hide()
	_ability_style = CardStyle.new(config.ability_card_color, config.ability_card_hover_color, config.ability_card_font_color, config)
	_unique_style = CardStyle.new(config.unique_card_color, config.unique_card_hover_color, config.unique_card_font_color, config)
	_affliction_style = CardStyle.new(config.affliction_card_color, config.affliction_card_hover_color, config.affliction_card_font_color, config)
	_back_button.pressed.connect(cancel)


func _unhandled_input(event: InputEvent) -> void:
	_handle_back_input(event)


func show_choices(cards: Array[UpgradeCard], bans_used: int, max_bans: int) -> void:
	_offered = cards
	_title.text = "Elegí una mejora para bloquear (%d/%d)" % [bans_used + 1, max_bans]
	_rebuild_cards()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	_focus_first_card()


## Called by the card buttons (and by tests). Resumes the game.
func choose(card: UpgradeCard) -> void:
	hide()
	_offered = []
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ban_chosen.emit(card)


## Called by "Volver" (and by tests). Keeps the pause for the offer.
func cancel() -> void:
	hide()
	_offered = []
	ban_cancelled.emit()


func is_open() -> bool:
	return visible


func get_offered() -> Array[UpgradeCard]:
	return _offered


func _rebuild_cards() -> void:
	for card: Node in _cards.get_children():
		card.queue_free()
	for upgrade: UpgradeCard in _offered:
		_cards.add_child(_make_card(upgrade))


func _make_card(upgrade: UpgradeCard) -> Button:
	var card: Button = _card_template.duplicate() as Button
	card.text = "%s\n%s" % [upgrade.title, upgrade.description]
	card.visible = true
	card.pressed.connect(choose.bind(upgrade))
	if upgrade is AbilityUpgradeData:
		_ability_style.apply_to(card)
	elif upgrade is AbilityUniqueUpgradeData:
		_unique_style.apply_to(card)
	elif upgrade is AfflictionUpgradeData:
		_affliction_style.apply_to(card)
	return card


func _handle_back_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(ACTION_BACK):
		cancel()
		get_viewport().set_input_as_handled()


func _focus_first_card() -> void:
	for card: Node in _cards.get_children():
		if not card.is_queued_for_deletion():
			(card as Button).grab_focus()
			return
	_back_button.grab_focus()
