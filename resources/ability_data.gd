class_name AbilityData
extends Resource
## Definition of one ability: base stats, behavior and its own upgrade cards.
## Read-only at runtime: upgrades are accumulated by AbilityComponent.

enum Slot {
	BASIC,
	ULTIMATE,
}

enum Stat {
	BASE_DAMAGE,
	ATTACK_SCALING,
	COOLDOWN,
	HIT_RANGE,
	HIT_WIDTH,
	CAST_DURATION,
	TICK_INTERVAL,
	CHARGE_TIME,
}

@export var title: String
@export_multiline var description: String
@export var slot: Slot
## Scene whose root extends AbilityBehavior.
@export var behavior: PackedScene
## Flat damage of each hit.
@export var base_damage: float
## Fraction of the player's DAMAGE added to each hit (0.05 = 5 %).
@export var attack_scaling: float
## Seconds between casts, counted from the key press (from the release for
## charged abilities).
@export var cooldown: float
## Length of the hitbox in front of the player, in meters.
@export var hit_range: float
## Width of the hitbox, in meters.
@export var hit_width: float
## Seconds the cast lasts; the hit lands when it ends.
@export var cast_duration: float
## Seconds between the repeated hits of a channelled ability (e.g. one spin
## turn). Unused (0) by single-hit abilities.
@export var tick_interval: float
## Upgrades never bring the tick interval below this.
@export var min_tick_interval: float
## Upgrades never bring the cooldown below this.
@export var min_cooldown: float
## Upgrades never bring the cast duration below this.
@export var min_cast_duration: float
## Seconds a charged ability (held down) takes to reach full charge. Unused (0)
## by abilities cast on the key press.
@export var charge_time: float
## Upgrades never bring the charge time below this.
@export var min_charge_time: float
## Pressing this ability's key mid-dash cuts the dash short and casts it at once
## (when it can be cast). The dash iframes and cooldown are kept.
@export var interrupts_dash: bool
## A dash may cut this ability's cast short (its recovery). Otherwise the dash
## waits for the cast to end.
@export var dash_cancels_cast: bool
## Upgrade cards of this ability, offered only while it is equipped.
@export var upgrades: Array[AbilityUpgradeData]
## Unique upgrades that change how this ability works; offered only while equipped.
@export var unique_upgrades: Array[AbilityUniqueUpgradeData]
## Scale of the Affliction build-up of each of its hits (docs/specs/affliction.md):
## lower for abilities that hit the same enemy many times.
@export var affliction_scale: float


func get_base(stat: Stat) -> float:
	match stat:
		Stat.BASE_DAMAGE:
			return base_damage
		Stat.ATTACK_SCALING:
			return attack_scaling
		Stat.COOLDOWN:
			return cooldown
		Stat.HIT_RANGE:
			return hit_range
		Stat.HIT_WIDTH:
			return hit_width
		Stat.CAST_DURATION:
			return cast_duration
		Stat.TICK_INTERVAL:
			return tick_interval
		Stat.CHARGE_TIME:
			return charge_time
	return 0.0
