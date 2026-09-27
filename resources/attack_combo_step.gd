class_name AttackComboStep
extends Resource
## One strike of the basic attack combo (docs/specs/humanoid-player-model.md,
## bdo-combat-feel.md).

## Humanoid clip played for this strike (e.g. &"attack_1").
@export var animation: StringName
## Multiplier of the outgoing damage of this strike.
@export var damage_multiplier: float
## Multiplier of the knockback speed applied to the enemies hit.
@export var knockback_multiplier: float
## Meters the strike carries the player forward, tied to the clip time.
@export var lunge_distance: float
## Clip seconds (at speed 1) at which the lunge starts.
@export var lunge_start: float
## Clip seconds (at speed 1) at which the lunge ends.
@export var lunge_end: float
## Seconds the player's clip pauses and the enemies hit freeze when it lands.
@export var hitlag: float
## Camera shake strength when it lands, in [0, 1].
@export var shake_strength: float


## Pure: meters of lunge covered at clip time `clip_time`.
func lunge_covered(clip_time: float) -> float:
	if lunge_end <= lunge_start:
		return lunge_distance if clip_time >= lunge_end else 0.0
	return lunge_distance * clampf((clip_time - lunge_start) / (lunge_end - lunge_start), 0.0, 1.0)
