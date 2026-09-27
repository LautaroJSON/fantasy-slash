class_name DashFovKickConfig
extends Resource
## Camera field of view kick when a dash starts (docs/specs/dash-feel.md, module F).

## Degrees added to the field of view at the start of the dash.
@export var fov_add: float
## Seconds the field of view takes to ease back to its base value.
@export var return_time: float
