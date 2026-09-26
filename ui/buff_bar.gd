class_name BuffBar
extends HBoxContainer
## Row of the player's active buffs in the HUD: one colored square per buff
## with a translucent clock and the seconds left of its current stack in the
## centre, and its stack count in the bottom-right corner. The slots are created once; colors and
## stacks are refreshed when the buff list changes, and the times every frame
## while a buff is active, written only when the shown step changes.

@export var config: BuffBarConfig

var _buffs: BuffComponent = null
var _icons: Array[ColorRect] = []
var _labels: Array[Label] = []
var _time_labels: Array[Label] = []
var _clocks: Array[CooldownClock] = []
## Step shown by each time label (-1 = rewrite on the next update).
var _shown_steps: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_create_icons()
	set_process(false)


func _process(_delta: float) -> void:
	update_times()


func setup(buffs: BuffComponent) -> void:
	_buffs = buffs
	_buffs.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var active: Array[BuffComponent.ActiveBuff] = _buffs.get_active()
	var shown: int = mini(active.size(), _icons.size())
	for i: int in _icons.size():
		_icons[i].visible = i < shown
		_shown_steps[i] = -1
		if i < shown:
			_show(i, active[i])
	set_process(shown > 0)
	update_times()


## Remaining seconds of each shown buff's current stack. Called by _process and by tests.
func update_times() -> void:
	var active: Array[BuffComponent.ActiveBuff] = _buffs.get_active()
	var shown: int = mini(active.size(), _icons.size())
	for i: int in shown:
		_clocks[i].set_fraction(active[i].time_left / active[i].data.stack_duration)
		var step: int = CooldownText.to_step(active[i].time_left, config.cooldown_text)
		if step != _shown_steps[i]:
			_shown_steps[i] = step
			_time_labels[i].text = CooldownText.text_for_step(step, config.cooldown_text)


func get_visible_icon_count() -> int:
	var count: int = 0
	for icon: ColorRect in _icons:
		if icon.visible:
			count += 1
	return count


func get_icon(index: int) -> ColorRect:
	return _icons[index]


func get_stack_text(index: int) -> String:
	return _labels[index].text


func get_time_text(index: int) -> String:
	return _time_labels[index].text


func get_clock(index: int) -> CooldownClock:
	return _clocks[index]


func _show(index: int, buff: BuffComponent.ActiveBuff) -> void:
	_icons[index].color = buff.data.icon_color
	_icons[index].tooltip_text = buff.data.title
	_labels[index].text = str(buff.stacks)


func _create_icons() -> void:
	add_theme_constant_override(&"separation", roundi(config.spacing))
	_shown_steps.resize(config.max_icons)
	for i: int in config.max_icons:
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(config.icon_size, config.icon_size)
		icon.visible = false
		var time_label: Label = _create_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, config.time_font_size)
		var stack_label: Label = _create_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, config.stack_font_size)
		var clock: CooldownClock = CooldownClock.create(config.clock, CooldownClock.Shape.SQUARE)
		icon.add_child(clock)
		icon.add_child(time_label)
		icon.add_child(stack_label)
		add_child(icon)
		_icons.append(icon)
		_clocks.append(clock)
		_time_labels.append(time_label)
		_labels.append(stack_label)


func _create_label(horizontal: HorizontalAlignment, vertical: VerticalAlignment, font_size: int) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = horizontal
	label.vertical_alignment = vertical
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CooldownText.style_label(label, font_size, config.cooldown_text)
	return label
