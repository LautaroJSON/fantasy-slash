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
## Uniform size of the hands (1 = the mesh as the model or enemy.tscn makes it).
@export var hand_scale: float
## Shake cycles per second when a hand is hit (bosses; 0 = no shake).
@export var shake_frequency: float
## Radius of one hand in meters at hand_scale 1 (the mesh the model gives it);
## the Titan's weak point is measured with it.
@export var hand_radius: float
## Rotation of the right hand's mesh in degrees (fists, claws, blades); the left
## hand mirrors Y and Z.
@export var hand_rotation: Vector3
## Rotation of the hands at rest, in degrees, on top of hand_rotation (see EnemyHands).
@export var rest_rotation: Vector3
## The left hand holds on to the right one (a two-handed weapon): it takes its
## rotation and sits at off_hand_grip from it, in the right hand's own frame.
@export var off_hand_follows: bool
@export var off_hand_grip: Vector3
