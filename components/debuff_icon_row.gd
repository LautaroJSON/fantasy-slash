class_name DebuffIconRow
extends Node3D
## Row of small square icons above an enemy's health bar, one per active
## debuff, colored by DebuffData.icon_material, with the debuff's remaining
## seconds written above each icon and, for stacking debuffs, the stack count
## in its bottom-right corner. Built from BoxMesh and TextMesh slots
## created once (Principles II and V); child of the bar so it faces the camera.
## Only processes while the enemy has debuffs, and rewrites a TextMesh only
## when its shown step changes (docs/specs/cooldown-timers.md).

@export var debuffs: DebuffComponent
@export var config: DebuffIconConfig

var _icons: Array[MeshInstance3D] = []
var _time_texts: Array[TextMesh] = []
var _stack_texts: Array[TextMesh] = []
var _stack_labels: Array[MeshInstance3D] = []
## Step shown by each time text (-1 = rewrite on the next update).
var _shown_steps: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_create_icons()
	debuffs.changed.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	update_times()


func refresh() -> void:
	var active: Array[DebuffComponent.ActiveDebuff] = debuffs.get_active()
	var shown: int = mini(active.size(), _icons.size())
	_layout(shown)
	for i: int in _icons.size():
		var icon: MeshInstance3D = _icons[i]
		icon.visible = i < shown
		_shown_steps[i] = -1
		if icon.visible:
			icon.material_override = active[i].data.icon_material
			_show_stacks(i, active[i])
	set_process(shown > 0)
	update_times()


## Remaining seconds of each shown debuff. Called by _process and by tests.
func update_times() -> void:
	var active: Array[DebuffComponent.ActiveDebuff] = debuffs.get_active()
	var shown: int = mini(active.size(), _icons.size())
	for i: int in shown:
		var step: int = CooldownText.to_step(DebuffComponent.get_remaining(active[i]), config.cooldown_text)
		if step != _shown_steps[i]:
			_shown_steps[i] = step
			_time_texts[i].text = CooldownText.text_for_step(step, config.cooldown_text)


func get_visible_icon_count() -> int:
	var count: int = 0
	for icon: MeshInstance3D in _icons:
		if icon.visible:
			count += 1
	return count


func get_icon(index: int) -> MeshInstance3D:
	return _icons[index]


func get_time_text(index: int) -> String:
	return _time_texts[index].text


func get_stack_text(index: int) -> String:
	return _stack_texts[index].text


func is_stack_visible(index: int) -> bool:
	return _stack_labels[index].visible


func get_time_mesh(index: int) -> TextMesh:
	return _time_texts[index]


func _create_icons() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(config.icon_size, config.icon_size, config.icon_size / 4.0)
	_shown_steps.resize(config.max_icons)
	for i: int in config.max_icons:
		var icon := MeshInstance3D.new()
		icon.mesh = box
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		icon.visible = false
		icon.add_child(_create_time_label())
		icon.add_child(_create_stack_label())
		add_child(icon)
		_icons.append(icon)


## Child of its icon, so it hides and moves with it. Each slot owns its TextMesh.
func _create_time_label() -> MeshInstance3D:
	var text := TextMesh.new()
	text.depth = 0.0
	text.font_size = config.time_font_size
	text.pixel_size = config.time_pixel_size
	var label := MeshInstance3D.new()
	label.mesh = text
	label.material_override = config.time_material
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = Vector3(0.0, config.time_height_above_icon, 0.0)
	_time_texts.append(text)
	return label


## Bottom-right stack count, only for debuffs that stack. Written on list
## changes only (a string per change, never per frame).
func _show_stacks(index: int, debuff: DebuffComponent.ActiveDebuff) -> void:
	var stacks_shown: bool = debuff.data.get_stack_cap() > 1
	_stack_labels[index].visible = stacks_shown
	if stacks_shown:
		_stack_texts[index].text = str(debuff.stacks)


## Second child of its icon, anchored at its bottom-right corner.
func _create_stack_label() -> MeshInstance3D:
	var text := TextMesh.new()
	text.depth = 0.0
	text.font_size = config.stack_font_size
	text.pixel_size = config.stack_pixel_size
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var label := MeshInstance3D.new()
	label.mesh = text
	label.material_override = config.time_material
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = Vector3(config.stack_offset.x, config.stack_offset.y, 0.0)
	label.visible = false
	_stack_texts.append(text)
	_stack_labels.append(label)
	return label


## Centres the visible icons on the bar.
func _layout(shown: int) -> void:
	var step: float = config.icon_size + config.spacing
	var start: float = -step * (shown - 1) / 2.0
	for i: int in _icons.size():
		_icons[i].position = Vector3(start + step * i, config.height_above_bar, 0.0)
