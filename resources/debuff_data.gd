class_name DebuffData
extends Resource
## A status effect of an entity: a debuff or a buff, kept in the same list
## (DebuffComponent). The strength (potency) comes from whoever applies it;
## this Resource only holds the shared definition.

## What the status does while active.
enum Effect {
	## Removes potency x max health every tick_interval, ignoring defense.
	DAMAGE_OVER_TIME,
	## Ignores potency x stacks of the entity's defense (fraction, capped at 1).
	ARMOR_REDUCTION,
	## Buff: the owner raises its own stats when it applies it (e.g. Rage);
	## the component only lists it.
	STAT_BOOST,
	## Only listed (icon, aura): the owner applies what it means (e.g. a boss shield).
	STATUS,
}

## Identity: applying a debuff with the same id refreshes the existing one.
@export var id: StringName
@export var effect: Effect
## Seconds the debuff lasts after being applied or refreshed.
@export var duration: float
## Seconds between damage ticks (DAMAGE_OVER_TIME only).
@export var tick_interval: float
## Highest stack count; each application adds one. 1 or less = no stacking.
@export var max_stacks: int
## Never expires with time; only clear() (the entity's reset) removes it.
## Its icon has no clock.
@export var permanent: bool
## Glyph of the status icon (white SVG in assets/icons/status/, tinted with icon_color).
@export var icon: Texture2D
## Color of the status: tints the icon's glyph and background.
@export var icon_color: Color
## Good for whoever carries it (e.g. Rage on an enemy): its icon gets the buff frame.
@export var is_beneficial: bool


## At least 1: debuffs that do not declare it never stack.
func get_stack_cap() -> int:
	return maxi(max_stacks, 1)
