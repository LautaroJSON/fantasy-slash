class_name DamageMath
extends RefCounted
## Pure combat formulas. No state, no side effects.


## Damage leaving the attacker, before the target's defense.
## A crit adds `crit_bonus` as a fraction (1.0 = +100 %, x2).
static func outgoing(damage: float, bonus: float, is_crit: bool, crit_bonus: float) -> float:
	return apply_crit(damage * (1.0 + bonus), is_crit, crit_bonus)


## `damage` multiplied by (1 + crit_bonus) on a crit, unchanged otherwise.
static func apply_crit(damage: float, is_crit: bool, crit_bonus: float) -> float:
	var multiplier: float = 1.0 + crit_bonus if is_crit else 1.0
	return damage * multiplier


## Damage of an ability hit, before the target's defense: flat base plus a
## fraction of the attacker's damage.
static func ability_damage(base: float, scaling: float, attack: float) -> float:
	return base + scaling * attack


## Damage after the target's defense, never below `min_damage`.
static func mitigate(raw: float, defense: float, min_damage: float) -> float:
	return maxf(raw - defense, min_damage)


## `roll` is a value in [0, 1) injected by the caller so the result is testable.
static func roll_crit(chance: float, roll: float) -> bool:
	return roll < chance
