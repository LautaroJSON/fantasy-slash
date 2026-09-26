class_name EnemyPaceConfig
extends Resource
## Pace of the enemies of a run (docs/specs/enemy-pace.md,
## docs/specs/enemy-level-pace.md): the attack data describes the fastest
## pace; windups and the pause between attacks are stretched, less and less
## as the level rises (level 1 → last_level), and every Rage level brings
## them further back, never below min_scale.

## Windup multiplier at level 1 and at last_level (linear in between).
@export var windup_scale_first_level: float
@export var windup_scale_last_level: float
## attack_interval multiplier at level 1 and at last_level.
@export var interval_scale_first_level: float
@export var interval_scale_last_level: float
## Level at which the *_last_level values apply (the enemies' level cap).
@export var last_level: int
## Windup multiplier lost per Rage level.
@export var windup_scale_per_rage: float
## attack_interval multiplier lost per Rage level.
@export var interval_scale_per_rage: float
## Neither multiplier goes below this (1 = the pace of the attack data).
@export var min_scale: float


## Pure: windup multiplier at `level` and `rage_level`.
func windup_scale_for(level: int, rage_level: int) -> float:
	var by_level: float = lerpf(windup_scale_first_level, windup_scale_last_level, _progress(level))
	return maxf(min_scale, by_level - windup_scale_per_rage * float(maxi(rage_level, 0)))


## Pure: attack_interval multiplier at `level` and `rage_level`.
func interval_scale_for(level: int, rage_level: int) -> float:
	var by_level: float = lerpf(interval_scale_first_level, interval_scale_last_level, _progress(level))
	return maxf(min_scale, by_level - interval_scale_per_rage * float(maxi(rage_level, 0)))


## 0 at level 1, 1 at last_level.
func _progress(level: int) -> float:
	if last_level <= 1:
		return 1.0
	return clampf(float(level - 1) / float(last_level - 1), 0.0, 1.0)
