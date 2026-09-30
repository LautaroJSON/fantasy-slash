class_name PortalData
extends Resource
## A stage's exit portal (docs/specs/stages.md §4). Another style is another scene.

## Scene whose root extends PortalStyle: what the portal looks like.
@export var style_scene: PackedScene
## Seconds between the last card of the boss and the portal starting to open.
@export var open_delay: float
## Seconds the opening animation lasts; the portal can be entered once it ends.
@export var open_duration: float
## The player inside this radius (metres) enters the portal.
@export var enter_radius: float
