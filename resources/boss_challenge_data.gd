class_name BossChallengeData
extends Resource
## One kind of boss challenge: which enemy type and how many of them.

## Shown in the HUD next to the wave number.
@export var title: String
@export var stats: EnemyStats
## Enemies spawned by the challenge (and pre-instantiated by its pool).
@export var count: int
