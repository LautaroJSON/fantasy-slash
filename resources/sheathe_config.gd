class_name SheatheConfig
extends Resource
## Feel of the Sheathe ability. Not upgradeable (its upgradeable stats live in
## AbilityData: damage and charge time).

## Share of the full damage, knockback and reach at zero charge (0.3 = 30 %).
## It grows linearly to 100 % at full charge.
@export var min_charge_factor: float
## Fraction of MOVE_SPEED the player keeps while charging.
@export var charge_move_speed_factor: float
## Fraction of the damage taken removed while charging (0.5 = half damage).
@export var charge_damage_reduction: float
## Initial speed of the push, in m/s, at full charge (scaled by the charge factor).
@export var knockback_speed: float
## Radius around the player of the wave that pushes (without damage) the
## enemies the slash missed, in meters.
@export var wave_radius: float
## Humanoid clip played while charging (docs/specs/sheath-socket-hand-grip.md §2.7);
## the katana waits in its sheath, held in the left hand.
@export var charge_body_clip: StringName
## Humanoid clip played during the release cast: draw, follow-through and
## chiburi, with the katana in the hand (docs/specs/sheathe-release-animation.md).
@export var release_body_clip: StringName
## Transparency of the area on the ground once fully charged (0 = opaque; at
## most 0.5 opacity, Principle II).
@export var full_charge_transparency: float

@export_group("Empowered (Tsubame Gaeshi)")
## Glow laid over the katana while an empowered Sheathe is stored.
@export var empowered_overlay: Material
## Brighter glow shown for empowered_flash_duration when it is gained.
@export var empowered_flash_overlay: Material
## Seconds the gain flash lasts before the steady glow.
@export var empowered_flash_duration: float


## Multiplier of damage, knockback and reach for a charge ratio in [0, 1].
func charge_factor(ratio: float) -> float:
	return lerpf(min_charge_factor, 1.0, clampf(ratio, 0.0, 1.0))
