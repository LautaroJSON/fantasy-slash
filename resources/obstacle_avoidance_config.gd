class_name ObstacleAvoidanceConfig
extends Resource
## How walking enemies steer around a stage's obstacles (docs/specs/stages.md §2.5).

## Obstacles farther ahead than this (metres) are ignored.
@export var lookahead: float
## Clearance added to each obstacle's radius.
@export var margin: float
## Weight of the sideways push at the obstacle's edge.
@export var strength: float
