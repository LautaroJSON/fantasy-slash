class_name EnemySpawnEntry
extends Resource
## One enemy type in the regular waves' mix (docs/specs/enemy-types.md).

@export var stats: EnemyStats
## Relative chance among the types allowed in a wave.
@export var weight: float
## First wave (1-based) in which this type can appear.
@export var first_wave: int
## Most enemies of this type in one wave (also the size of its pool).
@export var max_per_wave: int
