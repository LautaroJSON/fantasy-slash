class_name GroupAIConfig
extends Resource
## Group behaviour of the regular enemies: attack tokens, the ring around the
## player, separation and the spawn-in (docs/specs/enemy-group-ai.md).

## Enemies allowed to attack at once without Rage.
@export var base_attackers: int
## Enemies allowed to attack at once up to early_attackers_max_level.
@export var early_attackers: int
## Last enemy level that uses early_attackers instead of base_attackers.
@export var early_attackers_max_level: int
## Fodder attackers at once, whatever the Rage (their own pool of tokens).
@export var fodder_max_attackers: int
## Rage levels per extra simultaneous attacker (docs/specs/enemy-pace.md).
@export var rage_levels_per_extra_attacker: int
## Most simultaneous attackers, whatever the Rage.
@export var max_attackers_cap: int
## Minimum seconds between two token grants.
@export var token_gap: float
## Seconds a token may be held without starting a windup before it is taken back.
@export var token_approach_timeout: float
## Seconds a token rests after an attack that started ends, before it can be
## granted again: at level 1 and at last_level (docs/specs/enemy-level-pace.md).
@export var rest_first_level: float
@export var rest_last_level: float
## Rest lost per Rage level.
@export var rest_per_rage: float
@export var min_rest: float
## Level at which rest_last_level applies (the enemies' level cap).
@export var last_level: int
## Melee enemies without a token wait this far beyond their attack_range, in meters.
@export var wait_margin: float
## Places around the player the melee enemies spread over.
@export var slot_count: int
## Seconds between two choices of place by the same enemy.
@export var slot_refresh_time: float
## Distance to its place at which a waiting enemy stops walking, in meters.
@export var arrive_tolerance: float
## Without a free place, an enemy waits this much farther out, in meters.
@export var overflow_step: float
## Walking enemies push away from others closer than this (× body_scale), in meters.
@export var separation_radius: float
## Strength of that push relative to the walking direction.
@export var separation_weight: float
## Seconds an enemy takes to come out of the floor.
@export var spawn_in_time: float
## Depth (× body_scale) the body rises from, in meters.
@export var spawn_depth: float
## Radius (× body_scale) of the hole shown while it rises, in meters.
@export var spawn_marker_radius: float
## Seconds the hole takes to reach its full size (it then stays until the body is out).
@export var spawn_marker_grow_time: float


## Pure: simultaneous attackers allowed to enemies of `level` at `rage_level`.
func max_attackers_for(level: int, rage_level: int) -> int:
	var base: int = early_attackers if level <= early_attackers_max_level else base_attackers
	var extra: int = floori(float(maxi(rage_level, 0)) / rage_levels_per_extra_attacker) if rage_levels_per_extra_attacker > 0 else 0
	return mini(base + extra, max_attackers_cap)


## Pure: flat unit direction of place `index` around the player.
func slot_direction(index: int) -> Vector3:
	var angle: float = TAU * float(index) / float(slot_count)
	return Vector3(sin(angle), 0.0, cos(angle))


## Pure: rest of a token given back by an enemy of `level` at `rage_level`.
func rest_for(level: int, rage_level: int) -> float:
	var progress: float = 1.0
	if last_level > 1:
		progress = clampf(float(level - 1) / float(last_level - 1), 0.0, 1.0)
	return maxf(min_rest, lerpf(rest_first_level, rest_last_level, progress) - rest_per_rage * float(maxi(rage_level, 0)))


## Pure: simultaneous attackers of a token `group` for enemies of `level` at `rage_level`.
func max_attackers_for_group(group: EnemyStats.AttackTokenGroup, level: int, rage_level: int) -> int:
	if group == EnemyStats.AttackTokenGroup.FODDER:
		return fodder_max_attackers
	return max_attackers_for(level, rage_level)
