class_name EnemyStatGrowth
extends Resource
## How one enemy stat grows per level above 1. Growth is linear over the base
## value (not compounded), optionally limited by a cap.

enum Mode { PERCENT, FLAT }

@export var stat: EnemyStats.Stat
@export var mode: Mode
## PERCENT: fraction of the base per level (0.2 = +20 %). FLAT: units per level.
@export var amount: float
## Upper limit of the scaled value; ignored when has_cap is false.
@export var has_cap: bool
@export var cap: float


## Pure: `base` scaled to `level`. Level 1 always returns the base.
func scale(base: float, level: int) -> float:
	var steps: int = maxi(level - 1, 0)
	var value: float = base
	match mode:
		Mode.PERCENT:
			value = base * (1.0 + amount * steps)
		Mode.FLAT:
			value = base + amount * steps
	if has_cap:
		value = minf(value, cap)
	return value
