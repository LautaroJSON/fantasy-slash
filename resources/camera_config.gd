class_name CameraConfig
extends Resource
## Configuration of the third-person orbit camera.

## Pivot point relative to the followed target.
@export var follow_offset: Vector3
## Maximum camera-to-pivot distance, in meters.
@export var spring_length: float
## Radians of rotation per pixel of mouse motion.
@export var mouse_sensitivity: float
## Radians of rotation per base pixel of touch drag (right half of the screen).
@export var touch_look_sensitivity: float
## Yaw speed with the right stick fully tilted, in radians per second.
@export var stick_yaw_speed: float
## Pitch speed with the right stick fully tilted, in radians per second.
@export var stick_pitch_speed: float
## Lowest pitch (looking down), in degrees.
@export var min_pitch_deg: float
## Highest pitch (looking up), in degrees.
@export var max_pitch_deg: float
@export var invert_y: bool
## Seconds a full shake lasts while decaying to zero.
@export var shake_duration: float
## Largest shake offset of the view, in meters, at strength 1.
@export var shake_max_offset: float
