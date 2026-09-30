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
## Shop mode (docs/specs/gold-system.md): a card was bought (the shop stays
## open), the reroll or heal buttons were pressed, or the shop was closed.
signal upgrade_bought(upgrade: UpgradeCard)
signal reroll_requested
signal heal_requested
signal shop_closed

@export var config: UpgradePickerConfig
@export var ban_rules: CardBanRules
## Tells which level a unique upgrade card grants. Optional: level 1 without it.
@export var player: Player
## Quality tiers of the white cards: their name and color on the card.
@export var rolls: RollConfig

const TITLE_FREE: String = "¡Oleada superada! Elegí una mejora"
const TITLE_SHOP: String = "¡Oleada superada! Tienda"
const ICON_UNIQUE: Texture2D = preload("res://assets/icons/cards/unique.svg")
const ICON_ABILITY: Texture2D = preload("res://assets/icons/cards/ability.svg")
const ICON_BAN: Texture2D = preload("res://assets/icons/cards/ban.svg")
const ICON_REROLL: Texture2D = preload("res://assets/icons/cards/reroll.svg")
const ICON_HEAL: Texture2D = preload("res://assets/icons/cards/heal.svg")
## Inner space between the frame of a shop button and its content, in pixels.
const SHOP_BUTTON_PADDING: float = 22.0

## Icon of each UpgradeData.Category.
const CATEGORY_ICONS: Array[Texture2D] = [
	preload("res://assets/icons/cards/sword.svg"),
	preload("res://assets/icons/cards/shield.svg"),
	preload("res://assets/icons/cards/upgrade.svg"),
]

var _offered: Array[UpgradeCard] = []
var _with_ban: bool = false
var _ban_button: Button = null
## Shop mode: price of each offered card (same order), the gold in the wallet,
## and the price of each extra button (-1 = not available).
var _shop: bool = false
var _prices: Array[int] = []
var _gold: int = 0
var _reroll_price: int = -1
var _heal_price: int = -1
var _ban_price: int = -1
## Cards on screen in order (the ban card last), for the entrance and the focus animation.
var _views: Array[UpgradeCardView] = []
## True while the cards ignore presses (see UpgradePickerConfig.card_lock_duration).
var _locked: bool = false
var _lock_id: int = 0

@onready var _cards: HBoxContainer = %Cards
@onready var _title: Label = %Title
@onready var _shop_bar: HBoxContainer = %ShopBar
@onready var _gold_panel: PanelContainer = %GoldPanel
@onready var _gold_icon: TextureRect = %GoldIcon
@onready var _gold_label: Label = %GoldLabel
@onready var _reroll_button: Button = %RerollButton
@onready var _heal_button: Button = %HealButton
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	hide()
	_title.add_theme_font_override(&"font", UpgradeCardView.title_font(700.0))
	_dress_gold_panel()
	_dress_shop_button(_reroll_button, ICON_REROLL, "Cambiar oferta", config.card_price_color)
	_dress_shop_button(_heal_button, ICON_HEAL, "Curar", config.heal_color)
	_dress_shop_button(_continue_button, null, "Continuar", config.card_body_color)
	_reroll_button.pressed.connect(_unless_locked.bind(request_reroll))
	_heal_button.pressed.connect(_unless_locked.bind(request_heal))
	_continue_button.pressed.connect(_unless_locked.bind(close_shop))


func show_offer(upgrades: Array[UpgradeCard], with_ban: bool) -> void:
	_offered = upgrades
	_with_ban = with_ban
	_shop = false
	_shop_bar.hide()
	_title.text = TITLE_FREE
	_rebuild_cards()
	_open()


## Shop mode (docs/specs/gold-system.md): the cards show their `prices` (same
## order as `upgrades`) and a bought card does not close the modal. A price of
## -1 on the reroll, heal or ban button hides it; `ban_price` >= 0 adds the red card.
## `heal_amount` is the health the heal button gives, shown next to its price.
func show_shop(upgrades: Array[UpgradeCard], prices: Array[int], gold: int, reroll_price: int, heal_price: int, ban_price: int, heal_amount: int = 0) -> void:
	var opening: bool = not visible
	_offered = upgrades
	_prices = prices
	_gold = gold
	_reroll_price = reroll_price
	_heal_price = heal_price
	_ban_price = ban_price
	_with_ban = ban_price >= 0
	_shop = true
	_title.text = TITLE_SHOP
	_gold_label.text = "%d" % gold
	_reroll_button.visible = reroll_price >= 0
	_set_shop_price(_reroll_button, "Cambiar oferta", reroll_price)
	_reroll_button.disabled = gold < reroll_price
	_reroll_button.modulate.a = 0.5 if _reroll_button.disabled else 1.0
	_heal_button.visible = heal_price >= 0
	_set_shop_price(_heal_button, "Curar", heal_price)
	_set_heal_amount(heal_price, heal_amount)
	_heal_button.disabled = gold < heal_price
	_heal_button.modulate.a = 0.5 if _heal_button.disabled else 1.0
	_shop_bar.show()
	_rebuild_cards(opening)
	_open()


func is_shop() -> bool:
	return _shop


## Called by the card buttons in shop mode (and by tests). Ignored without the gold.
func buy(upgrade: UpgradeCard) -> void:
	var index: int = _offered.find(upgrade)
	if index < 0 or _prices[index] > _gold:
		return
	upgrade_bought.emit(upgrade)


func request_reroll() -> void:
	reroll_requested.emit()


func request_heal() -> void:
	heal_requested.emit()


## Closes the shop (the "Continuar" button and tests).
func close_shop() -> void:
	hide()
	_offered = []
	_shop = false
	get_tree().paused = false
	PointerMode.capture_for_gameplay()
	shop_closed.emit()


func get_price_of(upgrade: UpgradeCard) -> int:
	var index: int = _offered.find(upgrade)
	return _prices[index] if index >= 0 and _shop else 0


func get_reroll_button() -> Button:
	return _reroll_button


func get_heal_button() -> Button:
	return _heal_button


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
	for card: UpgradeCardView in _views:
		if is_instance_valid(card) and not card.is_queued_for_deletion() and card != _ban_button:
			buttons.append(card)
	return buttons


func _open() -> void:
	get_tree().paused = true
	PointerMode.release_for_ui()
	show()
	_focus_first_card()


## `animate`: the cards make their entrance and stay locked until it ends; false
## when the shop refreshes after a purchase (the cards just replace the old ones).
func _rebuild_cards(animate: bool = true) -> void:
	for slot: Node in _cards.get_children():
		slot.queue_free()
	_ban_button = null
	_views.clear()
	_lock_id += 1
	_locked = false
	for upgrade: UpgradeCard in _offered:
		_add_view(_make_card(upgrade))
	if _with_ban:
		_ban_button = _make_ban_card()
		_add_view(_ban_button)
	if animate:
		_animate_entrance()


## Each card sits in a slot of its own size, so its position can be animated
## while the container lays the slots out.
func _add_view(card: UpgradeCardView) -> void:
	var slot: Control = Control.new()
	slot.custom_minimum_size = card.custom_minimum_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(card)
	card.size = card.custom_minimum_size
	card.pivot_offset = card.custom_minimum_size * 0.5
	_cards.add_child(slot)
	_views.append(card)
	if card.disabled:
		# A card that cannot be bought takes no hover, focus or highlight.
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	card.focus_entered.connect(_highlight.bind(card))
	card.mouse_entered.connect(_highlight.bind(card))


func _make_card(upgrade: UpgradeCard) -> UpgradeCardView:
	var data: CardViewData = _view_of(upgrade)
	var card: UpgradeCardView = _new_card(data)
	if _shop:
		card.pressed.connect(_when_accepted.bind(card, buy.bind(upgrade)))
		card.disabled = not data.affordable
	else:
		card.pressed.connect(_when_accepted.bind(card, choose.bind(upgrade)))
	return card


## What `upgrade` shows: white cards by category and roll, blue by ability,
## gold unique with their level, violet Affliction with their level and source.
func _view_of(upgrade: UpgradeCard) -> CardViewData:
	var data: CardViewData = CardViewData.new()
	var stat_card: UpgradeData = upgrade as UpgradeData
	var ability_card: AbilityUpgradeData = upgrade as AbilityUpgradeData
	var unique: AbilityUniqueUpgradeData = upgrade as AbilityUniqueUpgradeData
	var affliction: AfflictionUpgradeData = upgrade as AfflictionUpgradeData
	if stat_card != null:
		_fill_stat_card(data, stat_card)
	elif ability_card != null:
		_fill_ability_card(data, ability_card)
	elif unique != null:
		var level: int = player.next_unique_level(unique) if player != null else 1
		data.title = unique.title
		data.badge = "Nv %d" % level
		data.body = unique.get_description(level)
		data.icon = ICON_UNIQUE
		data.shimmer = true
		_set_colors(data, config.unique_card_color, config.unique_card_hover_color)
	elif affliction != null:
		var next: int = player.count_upgrade(affliction) + 1 if player != null else 1
		data.title = "Aflicción: %s" % affliction.affliction.title
		data.badge = "Nv %d" % next
		data.body = _affliction_body(affliction, next)
		data.icon = _affliction_icon(affliction)
		_set_colors(data, config.affliction_card_color, config.affliction_card_hover_color)
	if _shop:
		data.price = _prices[_offered.find(upgrade)]
		data.affordable = data.price <= _gold
	data.plain_text = _plain_text(data)
	return data


## Title (with its badge) and description, without BBCode.
func _plain_text(data: CardViewData) -> String:
	var title: String = data.title if data.badge.is_empty() else "%s (%s)" % [data.title, data.badge]
	return "%s\n%s" % [title, _strip_bbcode(data.body)]


func _fill_stat_card(data: CardViewData, card: UpgradeData) -> void:
	var taken: int = player.count_upgrade(card) if player != null else 0
	data.title = card.title
	data.icon = CATEGORY_ICONS[card.category]
	_set_colors(data, config.common_card_color, config.common_card_hover_color)
	var tier_color: Color = Color.WHITE
	if rolls != null and card.roll_tier >= 0:
		tier_color = rolls.color_of(card.roll_tier)
		data.badge = rolls.name_of(card.roll_tier)
		data.badge_color = tier_color
	var value: float = card.amount_for_copy(taken)
	data.body = "%s %s" % [_highlight_bb(card.value_format.format_value(value), tier_color), card.value_label]
	if taken >= card.max_stacks:
		var ascension: int = taken - card.max_stacks + 1
		data.badge = "Ascensión %d" % ascension
		data.badge_color = config.unique_card_color
		data.body += "\n\n(bono al %d %%)" % roundi(value / card.amount * 100.0)


## Blue card: the ability is the title, the stat it improves goes first in the text.
func _fill_ability_card(data: CardViewData, card: AbilityUpgradeData) -> void:
	var ability_name: String = card.title
	var stat_name: String = ""
	var parts: PackedStringArray = card.title.split(": ", true, 1)
	if parts.size() == 2:
		ability_name = parts[0]
		stat_name = parts[1]
	if player != null and player.ability_for(card).get_data() != null:
		ability_name = player.ability_for(card).get_data().title
	data.title = "Habilidad: %s" % ability_name
	data.icon = ICON_ABILITY
	data.body = card.description if stat_name.is_empty() else "%s\n%s" % [_highlight_bb(stat_name.capitalize(), config.ability_card_color), card.description]
	_set_colors(data, config.ability_card_color, config.ability_card_hover_color)


func _set_colors(data: CardViewData, frame: Color, hover: Color) -> void:
	data.frame_color = frame
	data.hover_color = hover
	if data.badge_color == Color.WHITE:
		data.badge_color = frame


## Violet card text: "Tus golpes|habilidades acumulan <Aflicción>." (source in the card color,
## the Affliction in its bar color) and then the level text without its own first line,
## which says the same.
func _affliction_body(card: AfflictionUpgradeData, level: int) -> String:
	var source: String = "golpes" if card.source == AfflictionUpgradeData.Source.BASIC_ATTACK else "habilidades"
	var kind_color: Color = config.affliction_card_color
	if card.affliction.bar_material != null:
		kind_color = card.affliction.bar_material.albedo_color
	var header: String = "Tus %s acumulan %s." % [
		_highlight_bb(source, config.affliction_card_color.lightened(0.45)),
		_highlight_bb(card.affliction.title, kind_color.lightened(0.2)),
	]
	var lines: PackedStringArray = card.get_description(level).split("\n")
	if lines.size() < 2:
		return header
	return "%s\n%s" % [header, "\n".join(lines.slice(1))]


func _affliction_icon(card: AfflictionUpgradeData) -> Texture2D:
	if card.affliction.debuff != null and card.affliction.debuff.icon != null:
		return card.affliction.debuff.icon
	return ICON_ABILITY


func _highlight_bb(value: String, color: Color) -> String:
	return "[b][color=#%s]%s[/color][/b]" % [color.to_html(false), value]


func _strip_bbcode(text: String) -> String:
	var tags: RegEx = RegEx.create_from_string("\\[[^\\]]*\\]")
	return tags.sub(text, "", true)


func _make_ban_card() -> UpgradeCardView:
	var data: CardViewData = CardViewData.new()
	data.title = ban_rules.title
	data.body = ban_rules.description
	data.icon = ICON_BAN
	_set_colors(data, config.ban_card_color, config.ban_card_hover_color)
	if _shop:
		data.price = _ban_price
		data.affordable = _gold >= _ban_price
	data.plain_text = "%s\n%s" % [data.title, data.body]
	var card: UpgradeCardView = _new_card(data)
	card.pressed.connect(_when_accepted.bind(card, request_ban))
	card.disabled = _shop and _gold < _ban_price
	return card


func _new_card(data: CardViewData) -> UpgradeCardView:
	var card: UpgradeCardView = UpgradeCardView.new()
	card.setup(data, config)
	return card


## Entrance: the cards rise from below, tilted in a fan, and land one after another.
## The whole entrance lasts card_enter_total; until the last card lands the cards
## are locked (no hover, no press) so a click spammed during the fight picks nothing.
func _animate_entrance() -> void:
	var count: int = _views.size()
	if count == 0 or config.card_enter_total <= 0.0:
		return
	_locked = true
	_lock_id += 1
	var lock_id: int = _lock_id
	for card: UpgradeCardView in _views:
		card.set_locked(true)
	var duration: float = maxf(config.card_enter_total - config.card_enter_stagger * (count - 1), 0.1)
	var half: float = maxf((count - 1) / 2.0, 1.0)
	var last: Tween = null
	for i: int in count:
		var card: UpgradeCardView = _views[i]
		var fan: float = (i - (count - 1) / 2.0) / half
		card.position = Vector2(0.0, config.card_enter_rise)
		card.rotation = deg_to_rad(config.card_enter_tilt * fan)
		card.scale = Vector2(0.7, 0.7)
		card.modulate.a = 0.0
		var tween: Tween = card.create_tween().set_parallel()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_ignore_time_scale(true)
		var delay: float = config.card_enter_stagger * i
		tween.tween_property(card, "modulate:a", 1.0, minf(0.3, duration)).set_delay(delay)
		tween.tween_property(card, "position:y", 0.0, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "rotation", 0.0, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last = tween
	last.finished.connect(_unlock_cards.bind(lock_id))


## The last card landed: the cards can be hovered and pressed.
func _unlock_cards(lock_id: int) -> void:
	if lock_id != _lock_id or not _locked:
		return
	_locked = false
	for card: UpgradeCardView in _views:
		if is_instance_valid(card):
			card.set_locked(false)
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is UpgradeCardView and _views.has(focused):
		_highlight(focused as UpgradeCardView)


func is_locked() -> bool:
	return _locked


## The card under the focus or the mouse stays lit; the others dim.
func _highlight(focused: UpgradeCardView) -> void:
	if _locked or not is_instance_valid(focused) or focused.is_queued_for_deletion():
		return
	for card: UpgradeCardView in _views:
		if not is_instance_valid(card):
			continue
		var chosen: bool = card == focused
		var brightness: float = card.base_brightness * (1.0 if chosen else config.card_unfocused_brightness)
		var tween: Tween = card.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_method(_set_brightness.bind(card), card.modulate.r, brightness, 0.12)


## Dims the card without touching its alpha.
func _set_brightness(value: float, card: UpgradeCardView) -> void:
	if is_instance_valid(card):
		card.modulate = Color(value, value, value, card.modulate.a)


func _focus_first_card() -> void:
	for button: Button in get_card_buttons():
		if not button.disabled:
			button.grab_focus()
			return
	if _shop:
		_continue_button.grab_focus()
	elif _ban_button != null:
		_ban_button.grab_focus()


## Runs a card's action unless the card is locked or the press began while it was.
func _when_accepted(card: UpgradeCardView, action: Callable) -> void:
	if card.accepts_press():
		action.call()


## The shop buttons that spend gold also wait for the entrance to end.
func _unless_locked(action: Callable) -> void:
	if not _locked:
		action.call()


## The gold counter: a gold pill (round, no frame) with the coin and the amount,
## so it does not look like the framed buttons next to it.
func _dress_gold_panel() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(config.unique_card_color, 0.18)
	style.set_corner_radius_all(32)
	style.content_margin_left = 20.0
	style.content_margin_right = 26.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_gold_panel.add_theme_stylebox_override(&"panel", style)
	_gold_icon.modulate = config.card_price_color
	_gold_label.add_theme_font_override(&"font", UpgradeCardView.title_font(700.0))
	_gold_label.add_theme_color_override(&"font_color", config.card_price_color)


## A shop button drawn like the cards: framed panel (in `accent`) with an icon, its
## name and, when it costs gold, the coin and the price. The Button keeps its own
## text for screen readers.
func _dress_shop_button(button: Button, icon: Texture2D, caption: String, accent: Color) -> void:
	button.text = caption
	button.clip_text = true
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		button.add_theme_color_override(color_name, Color(0.0, 0.0, 0.0, 0.0))
	var normal: StyleBoxFlat = _shop_button_style(Color(0.16, 0.13, 0.23, 1.0), accent)
	var hover: StyleBoxFlat = _shop_button_style(Color(0.25, 0.2, 0.35, 1.0), accent.lightened(0.25))
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = config.focus_border_color
	focus.set_border_width_all(config.focus_border_width)
	focus.set_corner_radius_all(12)
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", hover)
	button.add_theme_stylebox_override(&"disabled", normal)
	button.add_theme_stylebox_override(&"focus", focus)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = SHOP_BUTTON_PADDING
	row.offset_right = -SHOP_BUTTON_PADDING
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	if icon != null:
		row.add_child(_shop_icon(icon, "Icon", 30.0, accent.lightened(0.3)))
	row.add_child(_shop_label("Name", 18, config.card_title_color, caption))
	row.add_child(_shop_label("Amount", 18, config.heal_color, ""))
	row.add_child(_shop_icon(preload("res://assets/icons/cards/coin.svg"), "Coin", 22.0, config.card_price_color))
	row.add_child(_shop_label("Price", 19, config.card_price_color, ""))
	button.add_child(row)
	for hidden: String in ["Amount", "Coin", "Price"]:
		(row.get_node(hidden) as Control).hide()
	UiNav.bind_focus_frame(button)


func _shop_button_style(color: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style


func _shop_label(node_name: String, size: int, color: Color, text: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", UpgradeCardView.title_font(700.0))
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _shop_icon(texture: Texture2D, node_name: String, size: float, color: Color) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = node_name
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	return icon


## Price of a shop button: coin and amount next to its name; -1 hides them.
func _set_shop_price(button: Button, caption: String, price: int) -> void:
	button.text = caption if price < 0 else "%s (%d)" % [caption, price]
	var coin: Control = button.find_child("Coin", true, false) as Control
	var price_label: Label = button.find_child("Price", true, false) as Label
	coin.visible = price >= 0
	price_label.visible = price >= 0
	price_label.text = str(price)


## Health the heal button gives ("+60"), shown in green before its price.
func _set_heal_amount(price: int, amount: int) -> void:
	var amount_label: Label = _heal_button.find_child("Amount", true, false) as Label
	amount_label.visible = price >= 0 and amount > 0
	amount_label.text = "+%d" % amount
	if amount > 0:
		_heal_button.text = "Curar +%d de vida (%d)" % [amount, price]
