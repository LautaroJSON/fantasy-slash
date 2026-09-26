class_name CardStyle
extends RefCounted
## Colored look for card buttons. Built once and shared by every card it styles.
## The focused card gets a frame on top of its background (gamepad navigation).

const STYLE_NORMAL: StringName = &"normal"
const STYLE_HOVER: StringName = &"hover"
const STYLE_PRESSED: StringName = &"pressed"
const STYLE_FOCUS: StringName = &"focus"
const FONT_COLORS: Array[StringName] = [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]

var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _focus: StyleBoxFlat
var _font_color: Color


func _init(background: Color, hover_background: Color, font_color: Color, config: UpgradePickerConfig) -> void:
	_normal = StyleBoxFlat.new()
	_normal.bg_color = background
	_hover = StyleBoxFlat.new()
	_hover.bg_color = hover_background
	_focus = StyleBoxFlat.new()
	_focus.draw_center = false
	_focus.border_color = config.focus_border_color
	_focus.set_border_width_all(config.focus_border_width)
	_font_color = font_color


func apply_to(button: Button) -> void:
	button.add_theme_stylebox_override(STYLE_NORMAL, _normal)
	button.add_theme_stylebox_override(STYLE_FOCUS, _focus)
	button.add_theme_stylebox_override(STYLE_HOVER, _hover)
	button.add_theme_stylebox_override(STYLE_PRESSED, _hover)
	for color_name: StringName in FONT_COLORS:
		button.add_theme_color_override(color_name, _font_color)
