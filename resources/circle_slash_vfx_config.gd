class_name CircleSlashVfxConfig
extends Resource
## Circular slash of the Parry's empowered riposte: a white vortex around the
## player (docs/specs/riposte-levels.md §2.2). A wide band spirals in towards
## its tail, thin streaks whirl with it at several radii and heights, a flat
## spiral marks the floor, and sparks, dust and a flash burst out on the hit.
## Every "_by_level" array is indexed by the "Contragolpe" level (index 0 = level 1).

@export_group("Band")
## Segments of the whole circle (each ribbon uses the ones its arc covers).
@export var segments: int
## Height of the band over the player's feet, in meters (the blade's height).
@export var height: float
## The band rises this much towards its tail, in meters.
@export var tail_rise: float
## Width of the band at its head, inward from the hit radius, per level.
@export var band_width_by_level: Array[float]
## The outer edge of the band is this much higher than the inner one, in meters:
## a funnel that the low third-person camera sees from above, not edge-on.
@export var band_lift: float
## Inner edge of the band at the tail, over the hit radius (the vortex closes in).
@export var inner_radius_ratio: float
## Outer edge of the band at the tail, over the hit radius.
@export var outer_radius_ratio: float
## Alpha at the head of the band (Principle II: ≤ 0.5); the tail is 0.
@export var head_alpha: float
## Degrees of arc behind the head that still show (the fading tail).
@export var tail_degrees: float
## Seconds the head takes to go around once.
@export var sweep_duration: float
## Seconds the whole vortex takes to fade out once the head has gone around.
@export var fade_duration: float
## Shared unshaded, additive, vertex-colored material of every ribbon.
@export var material: StandardMaterial3D

@export_group("Streaks")
## Thin ribbons whirling with the band, per level.
@export var streak_count_by_level: Array[int]
## Each streak's radius at its head, over the hit radius (fixed table, no randomness).
@export var streak_radius_min: float
@export var streak_radius_max: float
## Each streak's height over the feet, in meters.
@export var streak_height_min: float
@export var streak_height_max: float
## Each streak's width, in meters.
@export var streak_width_min: float
@export var streak_width_max: float
## Degrees of each streak's fading tail.
@export var streak_tail_min: float
@export var streak_tail_max: float
## Each streak's turning speed over the band's.
@export var streak_speed_min: float
@export var streak_speed_max: float
## A streak's tail sits at this share of its head radius (the spiral).
@export var streak_spiral_ratio: float
## The outer edge of each streak is this much higher, in meters (see band_lift).
@export var streak_lift: float
## Alpha at the head of the streaks (≤ 0.5).
@export var streak_alpha: float

@export_group("Floor")
## Flat spiral on the floor behind the head, in degrees.
@export var floor_turns_degrees: float
## Its tail radius over the hit radius (it closes in towards the center).
@export var floor_inner_ratio: float
@export var floor_width: float
@export var floor_height: float
## Alpha at the head of the floor spiral (≤ 0.3).
@export var floor_alpha: float

@export_group("Burst")
## Sparks, dust and flash energy on the hit, per level.
@export var spark_amount_by_level: Array[int]
@export var dust_amount_by_level: Array[int]
@export var flash_energy_by_level: Array[float]
## Seconds the flash takes to go out.
@export var flash_duration: float


func get_band_width(level: int) -> float:
	return band_width_by_level[_index(band_width_by_level.size(), level)]


func get_streak_count(level: int) -> int:
	return streak_count_by_level[_index(streak_count_by_level.size(), level)]


func get_max_streak_count() -> int:
	var most: int = 0
	for count: int in streak_count_by_level:
		most = maxi(most, count)
	return most


func get_spark_amount(level: int) -> int:
	return spark_amount_by_level[_index(spark_amount_by_level.size(), level)]


func get_dust_amount(level: int) -> int:
	return dust_amount_by_level[_index(dust_amount_by_level.size(), level)]


func get_flash_energy(level: int) -> float:
	return flash_energy_by_level[_index(flash_energy_by_level.size(), level)]


## Array index of `level` (1-based), clamped to the array.
static func _index(size: int, level: int) -> int:
	return clampi(level, 1, size) - 1
