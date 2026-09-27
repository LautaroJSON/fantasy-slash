class_name SpinConfig
extends Resource
## Feel of the Spin ability. Not upgradeable (its upgradeable stats live in
## AbilityData: duration, turn time, damage and radius).

## Fraction of MOVE_SPEED the player keeps while spinning.
@export var move_speed_factor: float
## Initial speed of the push applied to enemies hit, in m/s (lighter than the
## basic attack's PlayerTuning.knockback_speed).
@export var knockback_speed: float
## Humanoid clip the body loops while spinning, with the weapon in its hands
## (docs/specs/spin-visual-rework.md §2.1).
@export var body_clip: StringName

@export_group("Impact")
## Seconds each enemy hit by a turn freezes and shakes (Enemy.apply_hitlag).
## The player never pauses during the turns (Principle VII, channelled abilities).
@export var turn_hitlag: float
## Camera shake of a turn that hits at least one enemy.
@export var turn_shake: float

@export_group("Dash slash")
## Damage of the slash of a dash that cuts the spin short, as a multiple of one
## spin hit (docs/specs/spin-dash-slash.md).
@export var dash_slash_damage_factor: float
## Width of the band along the dash path where enemies are slashed, in meters.
@export var dash_slash_width: float
## Initial speed of the sideways push applied to slashed enemies, in m/s.
@export var dash_slash_knockback_speed: float
## Humanoid clip that replaces the dash clip while the dash slashes, stretched
## to the dash like it (docs/specs/spin-visual-rework.md §2.3).
@export var dash_slash_body_clip: StringName
## Seconds each slashed enemy freezes and shakes; the player's clip also pauses
## this long once, on the first enemy slashed (the dash keeps moving).
@export var dash_slash_hitlag: float
## Camera shake of each enemy slashed.
@export var dash_slash_shake: float
