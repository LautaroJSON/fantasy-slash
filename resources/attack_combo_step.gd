class_name AttackComboStep
extends Resource
## One strike of the basic attack combo (docs/specs/humanoid-player-model.md,
## bdo-combat-feel.md, class-combat-identity.md). Its times are the source of
## truth of the strike: the AttackComponent runs them from the clip position,
## and the clip's events (hit_on, hit_off, combo, end) sit at the same times
## (a test compares them).

## Humanoid clip played for this strike (e.g. &"attack_1").
@export var animation: StringName
## Clip seconds (at speed 1) at which the damage lands and the facing locks.
@export var hit_start: float
## Clip seconds (at speed 1) at which the active phase ends.
@export var hit_end: float
## Clip seconds (at speed 1) of the cancel point: the combo window opens and
## the strike stops committing the player.
@export var cancel_point: float
## Clip seconds (at speed 1) at which the strike ends (the clip length).
@export var end_time: float
## True: at its cancel point the next strike starts on its own, with no attack
## tap and no combo window in between (a double strike, docs/specs/
## class-combat-identity.md §3.3). The dash still cuts it.
@export var auto_chain: bool
## Multiplier of the outgoing damage of this strike.
@export var damage_multiplier: float
## Multiplier of the knockback speed applied to the enemies hit.
@export var knockback_multiplier: float
## Multiplier of the ATTACK_RANGE stat for this strike's hit sector.
@export var range_multiplier: float
## Multiplier of the ATTACK_ARC stat for this strike's hit sector.
@export var arc_multiplier: float
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


## Pure: seconds of anticipation, until the damage lands.
func startup() -> float:
	return hit_start


## Pure: seconds from the end of the active phase to the end of the strike.
func recovery() -> float:
	return end_time - hit_end
