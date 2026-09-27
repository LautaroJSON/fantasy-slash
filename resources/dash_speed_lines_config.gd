class_name DashSpeedLinesConfig
extends Resource
## Speed lines of the dash: thin additive streaks behind the body, along the
## dash (docs/specs/dash-feel.md, module C).

@export var count: int
## Length of each streak, in meters.
@export var length: float
## Side of the streak's cross section, in meters.
@export var thickness: float
## Largest sideways offset of a streak from the body's axis, in meters.
@export var spread: float
## Height range of the streaks above the feet, in meters.
@export var height_min: float
@export var height_max: float
## Seconds the streaks take to fade out once the dash ends.
@export var fade: float
## Transparency of the streaks while dashing.
@export var alpha: float
