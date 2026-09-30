class_name StageObstacle
extends Marker3D
## A circle on the ground that walking enemies steer around and spawns avoid
## (docs/specs/stages.md §2.5). Placed inside a prop's adapter scene.

## Radius of the blocked circle, in metres.
@export var radius: float
