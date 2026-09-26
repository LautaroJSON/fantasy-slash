class_name BuffComponent
extends Node
## Active stacking buffs of the player, kept as a list so several kinds can
## coexist. Adding a buff adds a stack (up to BuffData.max_stacks) and restarts
## its countdown; every time the countdown runs out one stack is lost and, if
## any remain, the countdown starts again.

## A buff was added, gained or lost a stack, expired or was cleared.
signal changed


class ActiveBuff:
	var data: BuffData
	var stacks: int
	## Seconds until the next stack is lost.
	var time_left: float


var _active: Array[ActiveBuff] = []


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	advance(delta)


func add_stack(data: BuffData) -> void:
	var buff: ActiveBuff = _find(data.id)
	if buff == null:
		buff = ActiveBuff.new()
		buff.data = data
		_active.append(buff)
		set_physics_process(true)
	buff.stacks = mini(buff.stacks + 1, data.max_stacks)
	buff.time_left = data.stack_duration
	changed.emit()


func clear() -> void:
	if _active.is_empty():
		return
	_active.clear()
	set_physics_process(false)
	changed.emit()


## Iterates backwards so expired buffs can be removed in place.
func advance(delta: float) -> void:
	var lost: bool = false
	for i: int in range(_active.size() - 1, -1, -1):
		var buff: ActiveBuff = _active[i]
		buff.time_left -= delta
		while buff.time_left <= 0.0 and buff.stacks > 0:
			buff.stacks -= 1
			buff.time_left += buff.data.stack_duration
			lost = true
		if buff.stacks <= 0:
			_active.remove_at(i)
	if not lost:
		return
	if _active.is_empty():
		set_physics_process(false)
	changed.emit()


## 0 when the buff is not active.
func get_stacks(id: StringName) -> int:
	var buff: ActiveBuff = _find(id)
	return 0 if buff == null else buff.stacks


## 0 when the buff is not active.
func get_time_left(id: StringName) -> float:
	var buff: ActiveBuff = _find(id)
	return 0.0 if buff == null else buff.time_left


## Total of `stat` for the buff's current stacks (0 when not active).
func get_modifier(id: StringName, stat: BuffModifier.Stat) -> float:
	var buff: ActiveBuff = _find(id)
	if buff == null:
		return 0.0
	return buff.data.get_modifier(stat, buff.stacks)


## Live list (no copy). Do not modify it.
func get_active() -> Array[ActiveBuff]:
	return _active


func _find(id: StringName) -> ActiveBuff:
	for buff: ActiveBuff in _active:
		if buff.data.id == id:
			return buff
	return null
