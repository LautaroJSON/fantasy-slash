class_name SummonData
extends Resource
## A batch of minions a boss calls (docs/specs/boss-colmena.md): one entry per
## minion, placed around the boss away from the player.

@export var stats: Array[EnemyStats]
## Minions appear this far from the boss, in meters.
@export var min_radius: float
@export var max_radius: float
## …and at least this far from the player, in meters.
@export var min_player_distance: float
