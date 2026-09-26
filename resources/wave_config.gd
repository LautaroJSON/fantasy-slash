class_name WaveConfig
extends Resource
## Wave spawning configuration.

@export var enemies_per_wave: int
## Enemies pre-instantiated by a pool without a spawn entry (spawn entries size their own pools).
@export var pool_size: int
## Spawn positions are picked within ±this value on X and Z.
@export var spawn_half_extent: float
## Minimum distance between a spawn position and the player.
@export var min_spawn_distance: float
## Random positions tried per enemy before accepting the last one.
@export var spawn_attempts: int
## Upgrade cards offered after each wave.
@export var cards_per_offer: int
## Waves needed for enemies to gain one level.
@export var waves_per_enemy_level: int
## Highest level an enemy can reach.
@export var max_enemy_level: int
## Every this many waves the wave is a boss challenge (4 → waves 4, 8, 12…).
@export var boss_wave_interval: int
## Challenges a boss wave is drawn from, at random.
@export var boss_challenges: Array[BossChallengeData]
## Minimum distance between enemies spawned in the same wave.
@export var min_spawn_separation: float
## Enemy types of the regular waves and their mix; entry 0 (the Bruto) is the
## fallback when no other type qualifies (docs/specs/enemy-types.md).
@export var enemy_types: Array[EnemySpawnEntry]


## Pure: whether `wave` (1-based) is a boss challenge.
func is_boss_wave(wave: int) -> bool:
	return boss_wave_interval > 0 and wave % boss_wave_interval == 0


## Pure: level of the enemies spawned in `wave` (1-based).
func enemy_level_for(wave: int) -> int:
	var gained: int = floori(float(maxi(wave - 1, 0)) / waves_per_enemy_level)
	return mini(1 + gained, max_enemy_level)
