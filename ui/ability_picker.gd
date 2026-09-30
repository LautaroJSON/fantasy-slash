class_name AbilityPicker
extends Control
## Modal shown before the first wave to choose the basic ability. Pauses the game while open.
## The first card takes the focus when it opens (gamepad).

signal ability_chosen(ability: AbilityData)

var _offered: Array[AbilityData] = []

@onready var _cards: HBoxContainer = %Cards
@onready var _card_template: Button = %CardTemplate


func _ready() -> void:
	hide()


func show_choices(abilities: Array[AbilityData]) -> void:
	_offered = abilities
	_rebuild_cards()
	get_tree().paused = true
	PointerMode.release_for_ui()
	show()
	_focus_first_card()


## Called by the card buttons (and by tests).
func choose(ability: AbilityData) -> void:
	hide()
	_offered = []
	get_tree().paused = false
	PointerMode.capture_for_gameplay()
	ability_chosen.emit(ability)


func is_open() -> bool:
	return visible


func get_offered() -> Array[AbilityData]:
	return _offered


func _rebuild_cards() -> void:
	for card: Node in _cards.get_children():
		card.queue_free()
	for ability: AbilityData in _offered:
		_cards.add_child(_make_card(ability))


func _make_card(ability: AbilityData) -> Button:
	var card: Button = _card_template.duplicate() as Button
	card.text = "%s\n\n%s" % [ability.title, ability.description]
	card.visible = true
	card.pressed.connect(choose.bind(ability))
	UiNav.bind_focus_frame(card)
	return card


func _focus_first_card() -> void:
	for card: Node in _cards.get_children():
		if not card.is_queued_for_deletion():
			(card as Button).grab_focus()
			return
