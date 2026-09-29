class_name HordeConfig
extends Resource
## Horde of fodder that comes on top of the regular mix of a normal wave, in
## tight groups and in batches (docs/specs/fodder-minion.md).

## The horde's enemy type; its max_per_wave is the size of its pool.
@export var entry: EnemySpawnEntry
## First wave (1-based) with a horde.
@export var first_wave: int
## Fodder of wave first_wave.
@export var base_total: int
## Extra fodder for every wave after first_wave.
@export var total_per_wave: int
## Most fodder in one wave.
@export var max_total: int
## Size of each group, drawn between the two.
@export var group_size_min: int
@export var group_size_max: int
## Groups that come out when the wave starts.
@export var initial_groups: int
## Most fodder alive at once (performance).
@export var max_alive: int
## With this many fodder alive or fewer, the next group is scheduled.
@export var refill_below: int
## Seconds between that moment and the group coming out.
@export var refill_delay: float
## Radius of the disc a group comes out in, in meters.
@export var group_radius: float
## Minimum distance between two members of a group, in meters.
@export var member_separation: float

## Golden angle, in radians (sunflower disc).
const GOLDEN_ANGLE: float = 2.399963229728653


## Pure: fodder of `wave` (1-based); none before first_wave or in a boss wave.
func total_for(wave: int, is_boss_wave: bool) -> int:
	if is_boss_wave or wave < first_wave:
		return 0
	return mini(base_total + total_per_wave * (wave - first_wave), max_total)


## Pure: size of a group for `roll` in [0, 1).
func group_size(roll: float) -> int:
	var span: int = group_size_max - group_size_min + 1
	return group_size_min + mini(floori(clampf(roll, 0.0, 0.999999) * float(span)), span - 1)


## Pure: flat offset of member `index` inside the group's disc (Vogel spiral,
## members at least member_separation apart while the disc has room for them).
func member_offset(index: int) -> Vector3:
	var radius: float = group_radius * sqrt((float(index) + 0.5) / float(maxi(group_size_max, 1)))
	var angle: float = float(index) * GOLDEN_ANGLE
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
