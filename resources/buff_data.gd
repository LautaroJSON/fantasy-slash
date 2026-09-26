class_name BuffData
extends Resource
## A stacking, timed positive status effect of the player. Stacks are lost one
## at a time: every stack_duration without a new stack, one stack expires.

## Identity: adding a buff with the same id adds a stack to the existing one.
@export var id: StringName
## Name shown in the HUD.
@export var title: String
## Highest stack count.
@export var max_stacks: int
## Seconds until one stack is lost; adding a stack restarts the countdown.
@export var stack_duration: float
## Color of the HUD icon.
@export var icon_color: Color
## Effects of each stack.
@export var modifiers: Array[BuffModifier]


## Pure: total of `stat` for `stacks` stacks (0 when the buff has no such modifier).
func get_modifier(stat: BuffModifier.Stat, stacks: int) -> float:
	var total: float = 0.0
	for modifier: BuffModifier in modifiers:
		if modifier.stat == stat:
			total += modifier.per_stack * stacks
	return total
