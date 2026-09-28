class_name StatusIconView
extends Control
## One buff or debuff icon, the same everywhere (LoL style): background and
## glyph tinted with the status color, the translucent cooldown clock covering
## the time still left, a red (debuff) or green (buff) frame and the stack count
## in the bottom-right corner. It can also be the "+" overflow slot of a row.
## Its five children are created once; showing a status only changes their
## look (docs/specs/status-icons.md).

enum Kind { DEBUFF, BUFF }

var config: StatusIconConfig
var _side: float = 0.0
var _is_overflow: bool = false
var _border_color: Color = Color.BLACK

var _background: ColorRect
var _glyph: TextureRect
var _clock: CooldownClock
var _border: Control
var _stack_label: Label


static func create(icon_config: StatusIconConfig, side: float) -> StatusIconView:
	var view := StatusIconView.new()
	view.config = icon_config
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view._build()
	view.set_side(side)
	return view


func set_side(side: float) -> void:
	_side = side
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	var margin: float = side * config.glyph_margin
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glyph.offset_left = margin
	_glyph.offset_top = margin
	_glyph.offset_right = -margin
	_glyph.offset_bottom = -margin
	_apply_label_font()
	_border.queue_redraw()


func get_side() -> float:
	return _side


## A status: its glyph, colors and frame, and the stack count when it stacks.
func show_status(icon: Texture2D, color: Color, kind: Kind, stacks: int, shows_stacks: bool) -> void:
	_is_overflow = false
	_glyph.visible = true
	_glyph.texture = icon
	_glyph.modulate = color.lightened(config.glyph_lighten)
	_background.color = color.darkened(config.background_darken)
	_set_border(config.buff_border_color if kind == Kind.BUFF else config.debuff_border_color)
	_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_stack_label.remove_theme_color_override(&"font_color")
	_stack_label.text = str(stacks) if shows_stacks else ""
	_apply_label_font()


func show_debuff(debuff: DebuffComponent.ActiveDebuff) -> void:
	show_status(debuff.data.icon, debuff.data.icon_color, debuff_kind(debuff.data), debuff.stacks, shows_debuff_stacks(debuff.data))
	update_debuff_time(debuff)


func show_buff(buff: BuffComponent.ActiveBuff) -> void:
	show_status(buff.data.icon, buff.data.icon_color, Kind.BUFF, buff.stacks, buff.data.max_stacks > 1)
	update_buff_time(buff)


## `ratio` is the time still left over the full duration, in [0, 1]: the clock
## covers it, so a fresh status starts covered and clears as the hands turn.
func set_remaining(ratio: float, has_clock: bool) -> void:
	_clock.visible = has_clock and not _is_overflow
	_clock.set_fraction(ratio if _clock.visible else 0.0)


func update_debuff_time(debuff: DebuffComponent.ActiveDebuff) -> void:
	set_remaining(DebuffComponent.get_remaining_ratio(debuff), not debuff.data.permanent)


func update_buff_time(buff: BuffComponent.ActiveBuff) -> void:
	if buff.data.is_permanent():
		set_remaining(0.0, false)
		return
	set_remaining(buff.time_left / buff.data.stack_duration, true)


## The "+" slot: more statuses than slots, without saying which.
func show_overflow() -> void:
	_is_overflow = true
	_glyph.visible = false
	_glyph.texture = null
	_clock.visible = false
	_clock.set_fraction(0.0)
	_background.color = config.overflow_background_color
	_set_border(config.overflow_border_color)
	_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stack_label.add_theme_color_override(&"font_color", config.overflow_text_color)
	_stack_label.text = config.overflow_text
	_apply_label_font()


func is_overflow() -> bool:
	return _is_overflow


func get_glyph_texture() -> Texture2D:
	return _glyph.texture


func get_glyph_color() -> Color:
	return _glyph.modulate


func get_background_color() -> Color:
	return _background.color


func get_border_color() -> Color:
	return _border_color


func get_border_width() -> float:
	return config.border_width(_side)


func get_stack_text() -> String:
	return _stack_label.text


func get_clock() -> CooldownClock:
	return _clock


## Clock fraction, or 0 while the clock is hidden (permanent statuses).
func get_clock_fraction() -> float:
	return _clock.get_fraction() if _clock.visible else 0.0


static func debuff_kind(data: DebuffData) -> Kind:
	return Kind.BUFF if data.is_beneficial else Kind.DEBUFF


static func shows_debuff_stacks(data: DebuffData) -> bool:
	return data.get_stack_cap() > 1


func _build() -> void:
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph = TextureRect.new()
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock = CooldownClock.create(config.clock, CooldownClock.Shape.SQUARE)
	_border = Control.new()
	_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border.draw.connect(_draw_border)
	_stack_label = Label.new()
	_stack_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	add_child(_glyph)
	add_child(_clock)
	add_child(_border)
	add_child(_stack_label)


func _set_border(color: Color) -> void:
	if color == _border_color:
		return
	_border_color = color
	_border.queue_redraw()


func _draw_border() -> void:
	var width: float = config.border_width(_side)
	var inset: float = width / 2.0
	var rect := Rect2(Vector2(inset, inset), _border.size - Vector2(width, width))
	_border.draw_rect(rect, _border_color, false, width)


func _apply_label_font() -> void:
	var ratio: float = config.overflow_font_ratio if _is_overflow else config.stack_font_ratio
	CooldownText.style_label(_stack_label, StatusIconConfig.font_size(_side, ratio), config.cooldown_text)
