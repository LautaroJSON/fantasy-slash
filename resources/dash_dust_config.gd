class_name DashDustConfig
extends Resource
## Dust bursts at the feet when a dash takes off and when it ends, only on the
## floor (docs/specs/dash-feel.md, module D).

@export var amount: int
## Seconds each dust puff lives.
@export var lifetime: float
## Speed range of the puffs, in m/s.
@export var speed_min: float
@export var speed_max: float
## Cone of the puffs around straight up, in degrees (90 = flat along the floor).
@export var spread_degrees: float
## Diameter of each puff, in meters.
@export var size: float
## Also burst when the dash ends.
@export var burst_on_end: bool
