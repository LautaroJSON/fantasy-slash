class_name PlayerStats
extends Resource
## Initial values of every upgradeable player stat. Read-only at runtime:
## upgrades are accumulated by StatsComponent, never written here.

enum Stat {
	DAMAGE,
	DEFENSE,
	MAX_HEALTH,
	CRIT_CHANCE,
	CRIT_DAMAGE,
	ATTACK_SPEED,
	ATTACK_RANGE,
	LIFESTEAL,
	DAMAGE_BONUS,
	MOVE_SPEED,
	JUMP_VELOCITY,
	DASH_DISTANCE,
	DASH_COOLDOWN,
	ATTACK_ARC,
	DASH_DURATION,
	STAMINA_MAX,
	STAMINA_REGEN,
	SPRINT_STAMINA_COST,
	SPRINT_SPEED_FACTOR,
	AFFLICTION_BUILDUP,
	DASH_INVULNERABILITY,
}

@export var damage: float
@export var defense: float
@export var max_health: float
## Probability in [0, 1].
@export var crit_chance: float
## Extra damage of a critical hit, as a fraction (1.0 = +100 %, i.e. x2).
## A crit deals damage x (1 + crit_damage).
@export var crit_damage: float
## Attacks per second.
@export var attack_speed: float
## Attack hitbox radius in meters.
@export var attack_range: float
## Fraction of dealt damage returned as healing.
@export var lifesteal: float
## Extra damage fraction (0.1 = +10 %).
@export var damage_bonus: float
## Meters per second.
@export var move_speed: float
## Initial upward velocity of a jump, in m/s.
@export var jump_velocity: float
## Meters covered by one dash.
@export var dash_distance: float
## Seconds between dashes.
@export var dash_cooldown: float
## Width of the attack hitbox, in degrees.
@export var attack_arc_degrees: float
## Seconds the dash movement lasts. Its speed is dash_distance / dash_duration.
## The invulnerability has its own parameter, dash_invulnerability.
@export var dash_duration: float
## Stamina of a full bar (docs/specs/sprint-stamina.md).
@export var stamina_max: float
## Stamina regained per second once the regen delay has passed.
@export var stamina_regen: float
## Stamina spent per second of sprinting.
@export var sprint_stamina_cost: float
## Sprint top speed as a multiple of move_speed.
@export var sprint_speed_factor: float
## Extra Affliction build-up per hit, as a fraction (0.1 = +10 %; docs/specs/affliction.md).
@export var affliction_buildup: float
## Seconds the player is invulnerable from the start of a dash; it may outlast
## the dash movement (dash_duration). The dash cooldown never drops below it.
@export var dash_invulnerability: float


func get_base(stat: Stat) -> float:
	match stat:
		Stat.DAMAGE:
			return damage
		Stat.DEFENSE:
			return defense
		Stat.MAX_HEALTH:
			return max_health
		Stat.CRIT_CHANCE:
			return crit_chance
		Stat.CRIT_DAMAGE:
			return crit_damage
		Stat.ATTACK_SPEED:
			return attack_speed
		Stat.ATTACK_RANGE:
			return attack_range
		Stat.LIFESTEAL:
			return lifesteal
		Stat.DAMAGE_BONUS:
			return damage_bonus
		Stat.MOVE_SPEED:
			return move_speed
		Stat.JUMP_VELOCITY:
			return jump_velocity
		Stat.DASH_DISTANCE:
			return dash_distance
		Stat.DASH_COOLDOWN:
			return dash_cooldown
		Stat.ATTACK_ARC:
			return attack_arc_degrees
		Stat.DASH_DURATION:
			return dash_duration
		Stat.STAMINA_MAX:
			return stamina_max
		Stat.STAMINA_REGEN:
			return stamina_regen
		Stat.SPRINT_STAMINA_COST:
			return sprint_stamina_cost
		Stat.SPRINT_SPEED_FACTOR:
			return sprint_speed_factor
		Stat.AFFLICTION_BUILDUP:
			return affliction_buildup
		Stat.DASH_INVULNERABILITY:
			return dash_invulnerability
	return 0.0
