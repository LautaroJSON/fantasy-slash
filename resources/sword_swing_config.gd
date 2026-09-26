class_name SwordSwingConfig
extends Resource
## Pose and timing of the basic attack's horizontal sword sweep.

## Height of the sweep pivot above the player's feet, in meters.
@export var pivot_height: float
## Distance from the body's centre to the hilt, so the blade clears the capsule.
@export var hilt_offset: float
## Pitch of the blade during the sweep, in radians (negative = slightly down).
@export var blade_tilt: float
## Seconds the blade takes to cross the arc at the class's base attack speed.
## Scaled by base / current ATTACK_SPEED, so faster attacks sweep faster.
@export var swing_duration: float
## Easing curve of the sweep (see ease(); below 1 = fast start, slow end).
@export var sweep_ease: float
## Seconds to blend back to the rest pose after the sweep, at base attack
## speed (scaled like swing_duration).
## Abilities that hand the weapon back (recover()) always use it unscaled.
@export var recover_duration: float
