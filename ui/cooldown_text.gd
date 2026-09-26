class_name CooldownText
extends RefCounted
## Remaining seconds as text ("S.S" below the threshold, whole seconds above,
## always rounded up). Seconds become an integer step and each step's string
## comes from a table built once per config, so views that only write the text
## when the step changes never build strings per frame (Principle V).

static var _table: PackedStringArray = PackedStringArray()
static var _table_config: CooldownTextConfig = null


## 0 = nothing to show. Steps up to the decimal count are tenths; the ones
## after them are whole seconds, capped at max_seconds.
static func to_step(seconds: float, config: CooldownTextConfig) -> int:
	if seconds <= 0.0:
		return 0
	var decimal_count: int = config.get_decimal_step_count()
	var tenths: int = maxi(ceili(seconds / config.decimal_step - config.rounding_epsilon), 1)
	if tenths <= decimal_count:
		return tenths
	var first_whole: int = config.get_first_whole_second()
	var whole: int = clampi(ceili(seconds - config.rounding_epsilon), first_whole, config.max_seconds)
	return decimal_count + 1 + whole - first_whole


## "" for step 0.
static func text_for_step(step: int, config: CooldownTextConfig) -> String:
	if _table_config != config:
		_build_table(config)
	return _table[clampi(step, 0, _table.size() - 1)]


static func format(seconds: float, config: CooldownTextConfig) -> String:
	return text_for_step(to_step(seconds, config), config)


## Font size and outline of a 2D timer label.
static func style_label(label: Label, font_size: int, config: CooldownTextConfig) -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_constant_override(&"outline_size", config.outline_size)
	label.add_theme_color_override(&"font_outline_color", config.outline_color)


static func _build_table(config: CooldownTextConfig) -> void:
	_table_config = config
	_table = PackedStringArray([""])
	for i: int in range(1, config.get_decimal_step_count() + 1):
		_table.append("%.1f" % (i * config.decimal_step))
	for whole: int in range(config.get_first_whole_second(), config.max_seconds + 1):
		_table.append(str(whole))
