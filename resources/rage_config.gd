class_name RageConfig
extends Resource
## Rage: the buff enemies get once the player has no upgrades left
## (docs/specs/enemy-rage.md). Each rage level grows some stats over the
## enemy's level-scaled values; rage never lowers a stat.

## Status listed in the enemy's DebuffComponent (icon and aura).
@export var status: DebuffData
## Growth per rage level, over the level-scaled value (caps apply to the result).
@export var growth: Array[EnemyStatGrowth]


## Pure: rewrites in `out` the stats listed in `growth` for `rage_level`.
## Level 0 or less leaves `out` untouched.
func write_raged(rage_level: int, out: EnemyStats) -> void:
	if rage_level <= 0:
		return
	for stat_growth: EnemyStatGrowth in growth:
		var base: float = out.get_stat(stat_growth.stat)
		out.set_stat(stat_growth.stat, maxf(base, stat_growth.scale(base, rage_level + 1)))
