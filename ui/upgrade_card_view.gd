class_name UpgradeCardView
extends Button
## One upgrade card (docs/specs/upgrade-cards-redesign.md): a framed dark panel with
## the icon, title, rule, description and price strip. The root stays a Button, so
## it takes the focus, the mouse and the touch like before; its own text is hidden
## and only kept as plain text.

const TITLE_FONT: FontFile = preload("res://assets/fonts/Cinzel.ttf")
const BODY_FONT: FontFile = preload("res://assets/fonts/AlegreyaSans-Regular.ttf")
const BODY_BOLD_FONT: FontFile = preload("res://assets/fonts/AlegreyaSans-Medium.ttf")
const COIN_ICON: Texture2D = preload("res://assets/icons/cards/coin.svg")
## OpenType tag of the weight axis ("wght").
const WEIGHT_TAG: int = 2003265652
const CARD_SIZE: Vector2 = Vector2(208.0, 340.0)
const FRAME_WIDTH: int = 5
const INNER_MARGIN: int = 12
const CORNER_RADIUS: int = 14
const BODY_MIN_HEIGHT: float = 90.0
const UNAFFORDABLE_BRIGHTNESS: float = 0.55

## Brightness the card returns to when it is not dimmed; below 1 for cards that cannot be bought.
var base_brightness: float = 1.0
var _shimmer_tween: Tween
var _shimmers: bool = false
## While locked the card ignores presses; one that began locked is ignored on release too.
var locked: bool = false
var _press_began_locked: bool = false
var _normal_style: StyleBox
var _hover_style: StyleBox


func setup(data: CardViewData, config: UpgradePickerConfig) -> void:
	text = data.plain_text
	# The hidden text must not widen the card: only the panel inside is drawn.
	clip_text = true
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_ALL
	base_brightness = 1.0 if data.affordable else UNAFFORDABLE_BRIGHTNESS
	modulate = Color(base_brightness, base_brightness, base_brightness, 1.0)
	_style_frame(data, config)
	var panel: PanelContainer = _add_panel(config, data.frame_color)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_make_badge_row(data))
	column.add_child(_make_icon(data))
	column.add_child(_make_title(data, config))
	column.add_child(_make_rule(data))
	column.add_child(_make_body(data, config))
	if data.price >= 0:
		column.add_child(_make_price(data, config))
	_shimmers = data.shimmer
	button_down.connect(_on_button_down)
	UiNav.bind_focus_frame(self)


func _ready() -> void:
	if _shimmers:
		_start_shimmer()


## Locks or unlocks the card. Locked, it draws no hover or pressed look and ignores presses.
func set_locked(value: bool) -> void:
	locked = value
	var hover: StyleBox = _normal_style if value else _hover_style
	add_theme_stylebox_override(&"hover", hover)
	add_theme_stylebox_override(&"pressed", hover)


## True when a press should act: the card is unlocked and the press did not begin locked.
func accepts_press() -> bool:
	var accepted: bool = not locked and not _press_began_locked
	_press_began_locked = false
	return accepted


func _on_button_down() -> void:
	_press_began_locked = locked


func is_shimmering() -> bool:
	return _shimmer_tween != null and _shimmer_tween.is_valid()


func _style_frame(data: CardViewData, config: UpgradePickerConfig) -> void:
	var normal: StyleBoxFlat = _frame_style(data.frame_color)
	var hover: StyleBoxFlat = _frame_style(data.hover_color)
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = config.focus_border_color
	focus.set_border_width_all(config.focus_border_width)
	focus.set_corner_radius_all(CORNER_RADIUS)
	_normal_style = normal
	_hover_style = hover
	add_theme_stylebox_override(&"normal", normal)
	add_theme_stylebox_override(&"hover", hover)
	add_theme_stylebox_override(&"pressed", hover)
	add_theme_stylebox_override(&"disabled", normal)
	add_theme_stylebox_override(&"focus", focus)
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		add_theme_color_override(color_name, Color(0.0, 0.0, 0.0, 0.0))


func _frame_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(CORNER_RADIUS)
	return style


func _add_panel(config: UpgradePickerConfig, accent: Color) -> PanelContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, FRAME_WIDTH)
	add_child(margin)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = config.card_panel_color
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(accent, 0.35)
	style.set_content_margin_all(INNER_MARGIN)
	panel.add_theme_stylebox_override(&"panel", style)
	margin.add_child(panel)
	return panel


func _make_badge_row(data: CardViewData) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.custom_minimum_size.y = 24.0
	if data.badge.is_empty():
		return row
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(data.badge_color, 0.16)
	style.border_color = data.badge_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	pill.add_theme_stylebox_override(&"panel", style)
	var label: Label = Label.new()
	label.text = data.badge
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", title_font(500.0))
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", data.badge_color)
	pill.add_child(label)
	row.add_child(pill)
	return row


func _make_icon(data: CardViewData) -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circle: PanelContainer = PanelContainer.new()
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.custom_minimum_size = Vector2(64.0, 64.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.1, 1.0)
	style.border_color = data.frame_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(32)
	style.set_content_margin_all(14.0)
	circle.add_theme_stylebox_override(&"panel", style)
	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = data.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = data.frame_color.lightened(0.15)
	circle.add_child(icon)
	center.add_child(circle)
	return center


func _make_title(data: CardViewData, config: UpgradePickerConfig) -> Label:
	var label: Label = Label.new()
	label.text = data.title
	label.name = &"Title"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 40.0
	label.add_theme_font_override(&"font", title_font(700.0))
	label.add_theme_font_size_override(&"font_size", 19)
	label.add_theme_color_override(&"font_color", config.card_title_color)
	return label


func _make_rule(data: CardViewData) -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rule: ColorRect = ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(140.0, 1.0)
	rule.color = Color(data.frame_color, 0.7)
	center.add_child(rule)
	return center


## The text sits in a plain Control so a long description wraps instead of widening the card.
func _make_body(data: CardViewData, config: UpgradePickerConfig) -> Control:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = Vector2(0.0, BODY_MIN_HEIGHT)
	var body: RichTextLabel = RichTextLabel.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	# PASS: the wheel scrolls a long text and a click still reaches the card.
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.bbcode_enabled = true
	body.scroll_active = true
	body.add_theme_font_override(&"normal_font", BODY_FONT)
	body.add_theme_font_override(&"bold_font", BODY_BOLD_FONT)
	body.add_theme_font_size_override(&"normal_font_size", 15)
	body.add_theme_font_size_override(&"bold_font_size", 16)
	body.add_theme_color_override(&"default_color", config.card_body_color)
	body.text = data.body
	holder.add_child(body)
	return holder


func _make_price(data: CardViewData, config: UpgradePickerConfig) -> Control:
	var strip: PanelContainer = PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.1, 1.0)
	style.set_corner_radius_all(8)
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	strip.add_theme_stylebox_override(&"panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var color: Color = config.card_price_color if data.affordable else config.card_unaffordable_color
	var coin: TextureRect = TextureRect.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.texture = COIN_ICON
	coin.custom_minimum_size = Vector2(20.0, 20.0)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.modulate = color
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(data.price)
	label.add_theme_font_override(&"font", title_font(700.0))
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", color)
	row.add_child(coin)
	row.add_child(label)
	strip.add_child(row)
	return strip


static func title_font(weight: float) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = TITLE_FONT
	font.variation_opentype = {WEIGHT_TAG: weight}
	return font


## Golden cards brighten and dim their frame in a loop.
func _start_shimmer() -> void:
	_shimmer_tween = create_tween().set_loops()
	_shimmer_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_shimmer_tween.tween_property(self, "self_modulate", Color(1.35, 1.25, 1.0, 1.0), 1.4).set_trans(Tween.TRANS_SINE)
	_shimmer_tween.tween_property(self, "self_modulate", Color.WHITE, 1.4).set_trans(Tween.TRANS_SINE)
