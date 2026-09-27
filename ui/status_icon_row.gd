class_name StatusIconRow
extends HBoxContainer
## Row of status icons with a fixed number of slots. With more statuses than
## slots, the last slot becomes the "+" overflow icon, so the row never grows
## past its slots. Every slot is created once (docs/specs/status-icons.md).

var _icons: Array[StatusIconView] = []
var _overflow: StatusIconView
var _max_icons: int = 0
var _spacing: int = 0


static func create(icon_config: StatusIconConfig, max_icons: int, side: float, spacing: int) -> StatusIconRow:
	var row := StatusIconRow.new()
	row._max_icons = max_icons
	row._spacing = spacing
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", spacing)
	for i: int in max_icons:
		var icon: StatusIconView = StatusIconView.create(icon_config, side)
		icon.visible = false
		row.add_child(icon)
		row._icons.append(icon)
	row._overflow = StatusIconView.create(icon_config, side)
	row._overflow.show_overflow()
	row._overflow.visible = false
	row.add_child(row._overflow)
	return row


## Shows the slots for `total` statuses and returns how many icons the caller
## fills (icon(0) .. icon(returned - 1)): all of them when they fit, otherwise
## one slot less and the "+" in the last slot.
func set_shown(total: int) -> int:
	var overflows: bool = total > _max_icons
	var shown: int = _max_icons - 1 if overflows else total
	for i: int in _icons.size():
		_icons[i].visible = i < shown
	_overflow.visible = overflows
	return shown


func icon(index: int) -> StatusIconView:
	return _icons[index]


func get_overflow() -> StatusIconView:
	return _overflow


func get_max_icons() -> int:
	return _max_icons


func set_side(side: float) -> void:
	for view: StatusIconView in _icons:
		view.set_side(side)
	_overflow.set_side(side)
	reset_size()


func get_side() -> float:
	return _overflow.get_side()


## Icons showing a status (the "+" not counted).
func get_visible_icon_count() -> int:
	var count: int = 0
	for view: StatusIconView in _icons:
		if view.visible:
			count += 1
	return count


func is_overflow_visible() -> bool:
	return _overflow.visible


## Width of the visible slots and their gaps, in pixels (without waiting for
## the container to lay them out).
func get_shown_width() -> float:
	var slots: int = get_visible_icon_count() + (1 if _overflow.visible else 0)
	if slots == 0:
		return 0.0
	return slots * get_side() + (slots - 1) * _spacing
