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
	## Moves and acts slower: potency x stacks is the fraction of speed lost
	## (docs/specs/affliction.md). Keep new effects after this one: .tres files
	## store the integer.
	SLOW,
}

## What re-applying does while the status is active.
enum StackMode {
	## Upgradable: one instance whose strength is potency x stacks; re-applying
	## adds a stack (up to the cap) and restarts the duration.
	INTENSITY,
	## Stackable: every stack is a full instance that waits for its turn; the
	## strength never grows. Re-applying queues a stack, or restarts the
	## running instance when the queue is full.
	QUEUE,
}

## What a DAMAGE_OVER_TIME tick removes.
enum DamageScaling {
	## potency x max health (e.g. bleeding).
	MAX_HEALTH,
	## potency health points, computed by whoever applies it (e.g. poison).
	FLAT,
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
@export var stack_mode: StackMode
@export var damage_scaling: DamageScaling
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


## Whether its strength grows with the stack count (upgradable statuses).
func stacks_intensity() -> bool:
	return stack_mode == StackMode.INTENSITY
