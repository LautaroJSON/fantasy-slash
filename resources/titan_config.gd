class_name TitanConfig
extends BossConfig
## Armour and breakable hands of the Titán (docs/specs/boss-titan.md).

## Fraction of each hit the body shrugs off, except near a resting hand or while stunned.
@export var body_armor: float
## Health of each hand as a fraction of the Titán's (level-scaled) maximum health.
@export var hand_health_fraction: float
## Hits count on a resting hand when the target is within the hand's radius plus this, in meters.
@export var weak_point_margin: float
## Seconds stunned after a hand breaks.
@export var break_stun_time: float
## Meters (× body_scale) the body sinks while stunned.
@export var stun_body_drop: float
## Size of a hand about to break (it shrinks from 1 as it loses health).
@export var damaged_hand_min_scale: float
@export var hit_shake_time: float
## Shake of a hit hand, in local units.
@export var hit_shake_amount: float


## Pure: size of a hand with `ratio` of its health left.
func hand_size_for(ratio: float) -> float:
	return lerpf(damaged_hand_min_scale, 1.0, clampf(ratio, 0.0, 1.0))
