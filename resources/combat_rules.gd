class_name CombatRules
extends Resource
## Global combat rules: floors and caps that protect design constraints.

## Minimum damage of any hit after defense is subtracted.
@export var min_damage_after_defense: float
## Upper bound of the effective crit chance.
@export var max_crit_chance: float
## Upper bound of the effective crit damage bonus (1.0 = +100 %).
@export var max_crit_damage: float
## Upper bound of the effective attack arc, in degrees.
@export var max_attack_arc_degrees: float
## The effective dash cooldown never drops below the dash duration
## (the longer of dash_duration and dash_invulnerability) + this gap,
## so invulnerability can never be chained.
@export var min_dash_cooldown_gap: float
## Health a death-protected entity (sandbox player) never drops below.
@export var protected_min_health: float
