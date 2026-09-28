class_name SheatheVortexConfig
extends Resource
## Look of the Sheathe's cut vortex (docs/specs/sheathe-vortex-vfx.md): the
## riposte's vortex language (CircleSlashVfxConfig) along a straight cut.
## Every "_by_level" array is indexed by the vortex level (index 0 = level 1).

## Seconds the head takes from the player's feet to the cut's tip.
@export var sweep_duration: float
## Seconds everything fades after the head arrives.
@export var fade_duration: float
## Ribbon quads per meter of cut.
@export var segments_per_meter: int
## Height of the cut's axis over the floor, in meters.
@export var axis_height: float

@export_group("Band")
## Turns the band winds around the axis from the feet to the tip.
@export var turns: float
## Outer radius of the band at its head, in meters.
@export var band_radius: float
## Outer radius at the tail relative to the head (the band funnels in).
@export var band_tail_ratio: float
## Radial width of the band at its head, in meters.
@export var band_width_by_level: Array[float]
## Width at the tail relative to the head.
@export var band_tail_width_ratio: float
## Length of the band behind its head, as a fraction of the cut.
@export var band_tail_length: float
## Alpha of the band's head (the tail fades to 0).
@export var head_alpha: float

@export_group("Streaks")
## Thin light streaks that race along the cut, winding around its axis.
@export var streak_count_by_level: Array[int]
## Distance of each streak from the axis, in meters.
@export var streak_radius_min: float
@export var streak_radius_max: float
## Radial width of each streak, in meters.
@export var streak_width_min: float
@export var streak_width_max: float
## Length of each streak's tail, as a fraction of the cut.
@export var streak_tail_min: float
@export var streak_tail_max: float
## Speed of each streak relative to the band's head.
@export var streak_speed_min: float
@export var streak_speed_max: float
## Turns each streak winds around the axis over the whole cut.
@export var streak_turns_min: float
@export var streak_turns_max: float
## Streaks converge toward the axis at their tail by this ratio.
@export var streak_spiral_ratio: float
@export var streak_alpha: float

@export_group("Floor")
## Flat stripe under the cut that grows with the head.
@export var floor_width: float
@export var floor_height: float
@export var floor_alpha: float

@export_group("Light")
## Brief light that rides the band's head.
@export var light_energy_by_level: Array[float]
@export var light_range: float
## Multiplier of the wind cut's sparks and flash light at each level.
@export var burst_scale_by_level: Array[float]

## White, unshaded, additive, vertex-colored (shared with the riposte's vortex).
@export var material: StandardMaterial3D


func get_band_width(level: int) -> float:
	return band_width_by_level[_index(band_width_by_level.size(), level)]


func get_streak_count(level: int) -> int:
	return streak_count_by_level[_index(streak_count_by_level.size(), level)]


func get_max_streak_count() -> int:
	var most: int = 0
	for count: int in streak_count_by_level:
		most = maxi(most, count)
	return most


func get_light_energy(level: int) -> float:
	return light_energy_by_level[_index(light_energy_by_level.size(), level)]


func get_burst_scale(level: int) -> float:
	return burst_scale_by_level[_index(burst_scale_by_level.size(), level)]


static func _index(size: int, level: int) -> int:
	return clampi(level - 1, 0, size - 1)
