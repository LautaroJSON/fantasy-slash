class_name SpinConfig
extends Resource
## Feel of the Spin ability. Not upgradeable (its upgradeable stats live in
## AbilityData: duration, turn time, damage and radius).

## Fraction of MOVE_SPEED the player keeps while spinning.
@export var move_speed_factor: float
## Initial speed of the push applied to enemies hit, in m/s (lighter than the
## basic attack's PlayerTuning.knockback_speed).
@export var knockback_speed: float
## Weapon pivot position while spinning (blade held out), relative to Visual.
@export var blade_position: Vector3
## Weapon pivot rotation while spinning, in radians.
@export var blade_rotation: Vector3

@export_group("Dash slash")
## Damage of the slash of a dash that cuts the spin short, as a multiple of one
## spin hit (docs/specs/spin-dash-slash.md).
@export var dash_slash_damage_factor: float
## Width of the band along the dash path where enemies are slashed, in meters.
@export var dash_slash_width: float
## Initial speed of the sideways push applied to slashed enemies, in m/s.
@export var dash_slash_knockback_speed: float
## Arc crossed by the weapon's horizontal sweep, in degrees.
@export var dash_slash_arc_degrees: float
## Seconds the sweep takes to cross the arc.
@export var dash_slash_sweep_duration: float
