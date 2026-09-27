class_name ParryConfig
extends Resource
## Tuning of the Warrior's Parry (docs/specs/warrior-abilities-rework.md §3.2
## and §5.2). The window is CAST_DURATION; damage, range and width of the
## riposte ("Contragolpe") and the cooldown are AbilityData stats.

@export_group("Block")
## Share of a frontal hit the shield cancels during the window (1 = all).
@export var block_reduction: float
## Arc in front of the player the shield covers, in degrees.
@export var guard_arc_degrees: float
## Seconds from the start of the parry clip until the shield is up (the clip's event).
@export var raise_time: float
## Cooldown left after the first block of a cast, in seconds.
@export var success_cooldown: float
## Seconds after the window of a successful parry (the shield push).
@export var success_recovery: float
## Seconds after the window of a parry that blocked nothing (exposed).
@export var whiff_recovery: float

@export_group("Riposte")
## Seconds the riposte ("Contragolpe") lasts from the block.
@export var riposte_duration: float
## Seconds into the riposte when the thrust hits (the clip's event).
@export var riposte_hit_time: float
## The blade sweeps (weapon trail) between these seconds of the riposte.
@export var riposte_trail_start: float
@export var riposte_trail_end: float
## Push speed of the riposte, in m/s.
@export var riposte_knockback_speed: float

@export_group("Duel")
## Mark left on the attacker whose hit was cancelled ("Duelo").
@export var challenged: DebuffData
## Buff gained when a marked enemy dies ("Duelo").
@export var triumph: BuffData

@export_group("Feel")
## A hit cancelled by the shield (only the camera shakes).
@export var block_feel: StrikeFeel
@export var riposte_feel: StrikeFeel
## Speed of the sparks of a block over the configured one.
@export var block_spark_scale: float

@export_group("Body")
## Humanoid clip of the window.
@export var parry_body_clip: StringName
## Humanoid clip after a successful window.
@export var success_body_clip: StringName
## Humanoid clip after a window that blocked nothing.
@export var whiff_body_clip: StringName
## Humanoid clip of the riposte.
@export var riposte_body_clip: StringName
