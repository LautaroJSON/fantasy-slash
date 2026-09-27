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
## Color of the HUD icon: tints its glyph and background.
@export var icon_color: Color
## Glyph of the HUD icon (white SVG in assets/icons/status/).
@export var icon: Texture2D
## Effects of each stack.
@export var modifiers: Array[BuffModifier]
## Its MOVE_SPEED and DAMAGE modifiers apply to the player's stats at all
## times (StatsComponent). Otherwise only whoever grants it reads them.
@export var global: bool
## When stack_duration runs out every stack is lost at once, not one by one.
@export var expires_all_stacks: bool


## Pure: total of `stat` for `stacks` stacks (0 when the buff has no such modifier).
func get_modifier(stat: BuffModifier.Stat, stacks: int) -> float:
	var total: float = 0.0
	for modifier: BuffModifier in modifiers:
		if modifier.stat == stat:
			total += modifier.per_stack * stacks
	return total
