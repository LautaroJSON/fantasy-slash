class_name BuffModifier
extends Resource
## One effect of a buff, scaled by its stack count. Which action uses it (e.g.
## only while an ability is cast) is decided by whoever grants the buff.

enum Stat {
	## Fraction added to movement speed.
	MOVE_SPEED,
	## Fraction added to an ability's speed (e.g. turns per second of the Spin).
	ABILITY_SPEED,
	## Crit chance added.
	CRIT_CHANCE,
	## Fraction added to the player's DAMAGE (global buffs only; docs/specs/warrior-abilities-rework.md).
	DAMAGE,
}

@export var stat: Stat
## Amount added per stack (0.05 = +5 % per stack).
@export var per_stack: float
