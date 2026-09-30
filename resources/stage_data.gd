class_name StageData
extends Resource
## One stage of the run: its map, its enemies, its bosses and its exit
## (docs/specs/stages.md).

@export var id: StringName
## Shown on the stage banner.
@export var display_name: String
@export var subtitle: String
## Map scene; its root is a Stage.
@export var scene: PackedScene
## Regular waves before the boss wave (the boss is wave regular_waves + 1 of the stage).
@export var regular_waves: int
## Enemy types of the regular waves and their mix; entry 0 is the fallback
## when no other type qualifies (docs/specs/enemy-types.md).
@export var enemy_types: Array[EnemySpawnEntry]
## Challenges the boss wave is drawn from, at random.
@export var boss_challenges: Array[BossChallengeData]
## Exit portal opened after the boss (unused on the last stage).
@export var portal: PortalData
@export var layout: StageLayout


## Pure: whether `stage_wave` (1-based, within the stage) is the boss wave.
func is_boss_wave(stage_wave: int) -> bool:
	return regular_waves >= 0 and stage_wave == regular_waves + 1
