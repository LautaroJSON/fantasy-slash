class_name SwordSwingConfig
extends Resource
## Pose and timing of the weapon's horizontal sweep (the Spin's dash slash) and
## of the blend back to rest after an ability. The basic attack is the
## humanoid's combo (docs/specs/humanoid-player-model.md).

## Height of the sweep pivot above the player's feet, in meters.
@export var pivot_height: float
## Distance from the body's centre to the hilt, so the blade clears the body.
@export var hilt_offset: float
## Pitch of the blade during the sweep, in radians (negative = slightly down).
@export var blade_tilt: float
## Easing curve of the sweep (see ease(); below 1 = fast start, slow end).
@export var sweep_ease: float
## Seconds to blend back to the rest pose after a sweep (scaled by the sweep's
## time_scale). Abilities that hand the weapon back (recover()) use it unscaled.
@export var recover_duration: float
