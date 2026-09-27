class_name UpgradePicker
extends Control
## Modal with the upgrade cards offered after a wave. Pauses the game while open.
## Ability upgrade cards are light blue, unique ability upgrades gold (with the
## level they grant). Some offers add a red last card that trades this wave's
## upgrade for banning one (see CardBanRules).
## The first card takes the focus when it opens or reopens (gamepad).

signal upgrade_chosen(upgrade: UpgradeCard)
## The red card was chosen. The game stays paused for the ban sub-menu.
signal ban_requested

@export var config: UpgradePickerConfig
@export var ban_rules: CardBanRules
## Tells which level a unique upgrade card grants. Optional: level 1 without it.
@export var player: Player

var _offered: Array[UpgradeCard] = []
var _with_ban: bool = false
var _ban_button: Button = null
## Built once in _ready and shared by every card of their kind.
var _ability_style: CardStyle
var _unique_style: CardStyle
var _ban_style: CardStyle

@onready var _cards: HBoxContainer = %Cards
@onready var _card_template: Button = %CardTemplate


func _ready() -> void:
	hide()
	_ability_style = CardStyle.new(config.ability_card_color, config.ability_card_hover_color, config.ability_card_font_color, config)
	_unique_style = CardStyle.new(config.unique_card_color, config.unique_card_hover_color, config.unique_card_font_color, config)
	_ban_style = CardStyle.new(config.ban_card_color, config.ban_card_hover_color, config.ban_card_font_color, config)


func show_offer(upgrades: Array[UpgradeCard], with_ban: bool) -> void:
	_offered = upgrades
	_with_ban = with_ban
	_rebuild_cards()
	_open()


## Shows the last offer again (after backing out of the ban sub-menu).
func reopen() -> void:
	_open()


## Called by the card buttons (and by tests).
func choose(upgrade: UpgradeCard) -> void:
	hide()
	_offered = []
	get_tree().paused = false
	PointerMode.capture_for_gameplay()
	upgrade_chosen.emit(upgrade)


## Called by the red card (and by tests). Keeps the pause and the offer.
func request_ban() -> void:
	hide()
	ban_requested.emit()


func is_open() -> bool:
	return visible


func get_offered() -> Array[UpgradeCard]:
	return _offered


func has_ban_card() -> bool:
	return _ban_button != null


func get_ban_button() -> Button:
	return _ban_button


## Upgrade card buttons in the order they are shown (without the ban card).
func get_card_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for card: Node in _cards.get_children():
		if not card.is_queued_for_deletion() and card != _ban_button:
			buttons.append(card as Button)
	return buttons


func _open() -> void:
	get_tree().paused = true
	PointerMode.release_for_ui()
	show()
	_focus_first_card()


func _rebuild_cards() -> void:
	for card: Node in _cards.get_children():
		card.queue_free()
	_ban_button = null
	for upgrade: UpgradeCard in _offered:
		_cards.add_child(_make_card(upgrade))
	if _with_ban:
		_ban_button = _make_ban_card()
		_cards.add_child(_ban_button)


func _make_card(upgrade: UpgradeCard) -> Button:
	var card: Button = _new_card(_card_text(upgrade))
	card.pressed.connect(choose.bind(upgrade))
	if upgrade is AbilityUpgradeData:
		_ability_style.apply_to(card)
	elif upgrade is AbilityUniqueUpgradeData:
		_unique_style.apply_to(card)
	return card


## Unique upgrades show the level they grant and that level's text.
func _card_text(upgrade: UpgradeCard) -> String:
	var unique: AbilityUniqueUpgradeData = upgrade as AbilityUniqueUpgradeData
	if unique == null:
		return "%s\n%s" % [upgrade.title, upgrade.description]
	var level: int = player.next_unique_level(unique) if player != null else 1
	return "%s (Nv %d)\n%s" % [unique.title, level, unique.get_description(level)]


func _make_ban_card() -> Button:
	var card: Button = _new_card("%s\n%s" % [ban_rules.title, ban_rules.description])
	card.pressed.connect(request_ban)
	_ban_style.apply_to(card)
	return card


func _new_card(text: String) -> Button:
	var card: Button = _card_template.duplicate() as Button
	card.text = text
	card.visible = true
	return card


func _focus_first_card() -> void:
	var buttons: Array[Button] = get_card_buttons()
	if not buttons.is_empty():
		buttons[0].grab_focus()
	elif _ban_button != null:
		_ban_button.grab_focus()
