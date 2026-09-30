class_name BossPhaseData
extends Resource
## Phase 2 of a boss (docs/specs/boss-verdugo.md).

## Fraction of the maximum health at or below which phase 2 starts.
@export var health_threshold: float
## Seconds of the (invulnerable, idle) change of phase.
@export var transition_time: float
## Multiplies windups and recoveries in phase 2.
@export var time_scale: float
## Multiplies the hands' size in phase 2.
@export var phase_two_hand_scale: float
## Hand offset (relative to rest) during the change of phase.
@export var transition_hand_offset: Vector3
## Rotation of the hands' meshes during the change of phase, in degrees (see EnemyHands.play_pose).
@export var transition_hand_rotation: Vector3
## Seconds the hands and the model take to reach the pose of the change of phase
## (0 = the hands' return_time).
@export var transition_pose_time: float
