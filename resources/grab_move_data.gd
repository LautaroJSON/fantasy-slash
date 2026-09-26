class_name GrabMoveData
extends BossMoveData
## The boss lunges with open hands; catching the target holds it (no actions)
## for hold_time and then slams it. `attack` gives the windup, the reach and
## arc of the catch and the damage.

@export var attack: EnemyAttackData
@export var lunge_speed: float
@export var lunge_distance: float
## The lunge stops this far from the target, in meters.
@export var stop_distance: float
@export var hold_time: float
## Multiplies the boss damage for the slam that ends a hold.
@export var slam_multiplier: float
## Recovery when the lunge catches nothing.
@export var miss_recovery_time: float
