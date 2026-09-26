class_name EnemyHandsConfig
extends Resource
## Rest pose and idle motion of the two floating enemy hands. Offsets are in
## the enemy's local space at body_scale 1 (the Hands node scales with the body).

## Right hand at rest: x to the side, y height, z forward (−Z is the front).
## The left hand mirrors x.
@export var rest_offset: Vector3
## Vertical bob while idle, in meters.
@export var bob_amplitude: float
## Bob cycles per second.
@export var bob_frequency: float
## Seconds the hands take to go back to rest after a strike or a cancel.
@export var return_time: float
## Uniform size of the hand spheres (1 = the SphereMesh in enemy.tscn).
@export var hand_scale: float
## Shake cycles per second when a hand is hit (bosses; 0 = no shake).
@export var shake_frequency: float
