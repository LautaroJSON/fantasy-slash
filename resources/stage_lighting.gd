class_name StageLighting
extends Resource
## Light of one stage (docs/specs/stage-lighting-sky.md §3.1): sky, ambient,
## tonemap, adjustments, glow and fog in the Environment, plus the sun and the
## slow turn of the sky. The StageMap applies it to its WorldEnvironment and sun.

## Sky, ambient, tonemap, adjustments, glow and fog. The StageMap works on a copy.
@export var environment: Environment

@export_group("Sun")
@export var sun_color: Color = Color.WHITE
@export var sun_energy: float = 1.0
## Degrees; negative looks down.
@export var sun_pitch_deg: float = -45.0
@export var sun_yaw_deg: float = 0.0
@export var sun_shadows: bool = true
@export var sun_shadow_blur: float = 1.0
@export var sun_shadow_max_distance: float = 100.0

@export_group("Sky")
## Degrees per minute around the vertical axis; 0 = still.
@export var sky_rotation_speed_deg: float = 0.0
## Starting turn of the sky, to line its bright side up with the sun.
@export var sky_yaw_offset_deg: float = 0.0
