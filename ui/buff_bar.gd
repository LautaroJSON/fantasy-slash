class_name BuffBar
extends HBoxContainer
## Row of the player's active buffs in the HUD, with the shared status icon
## (docs/specs/status-icons.md): glyph, frame, translucent clock covering the
## time left of the current stack and the stack count in the corner. With more
## buffs than slots, the last slot is the "+". The slots are created once; the
## icons are refreshed when the buff list changes, and the clocks every frame
## while a buff is active.

@export var config: BuffBarConfig

var _buffs: BuffComponent = null
var _row: StatusIconRow


func _ready() -> void:
	_create_row()
	set_process(false)


func _process(_delta: float) -> void:
	update_times()


func setup(buffs: BuffComponent) -> void:
	_buffs = buffs
	_buffs.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var active: Array[BuffComponent.ActiveBuff] = _buffs.get_active()
	var shown: int = _row.set_shown(active.size())
	for i: int in shown:
		_row.icon(i).show_buff(active[i])
	set_process(not active.is_empty())


## Clock of each shown buff's current stack. Called by _process and by tests.
func update_times() -> void:
	var active: Array[BuffComponent.ActiveBuff] = _buffs.get_active()
	for i: int in mini(active.size(), _row.get_visible_icon_count()):
		_row.icon(i).update_buff_time(active[i])


func get_visible_icon_count() -> int:
	return _row.get_visible_icon_count()


func get_icon(index: int) -> StatusIconView:
	return _row.icon(index)


func get_row() -> StatusIconRow:
	return _row


func get_stack_text(index: int) -> String:
	return _row.icon(index).get_stack_text()


func get_clock(index: int) -> CooldownClock:
	return _row.icon(index).get_clock()


func _create_row() -> void:
	_row = StatusIconRow.create(config.status_icon, config.max_icons, config.icon_size, roundi(config.spacing))
	add_child(_row)
