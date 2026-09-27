class_name PlayerAnimationConfig
extends Resource
## How the player's state maps to the humanoid's clips, and how the class
## weapon returns to the hand. Control feel, not upgradeable.

## Horizontal speed, in m/s, above which the player runs instead of idling.
@export var run_speed_threshold: float
## Seconds the weapon takes to blend back into the hand after an ability.
@export var weapon_mount_blend: float
## Seconds the body takes to blend from a strike's last pose back into
## locomotion: a strike ends where the next one starts, not in the guard.
@export var attack_exit_blend: float
