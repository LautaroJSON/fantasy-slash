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
## Deeper charge poses (docs/specs/sheathe-visual-rework.md §2.4): one per
## milestone, the last one at full charge. Level 0 is charge_body_clip.
@export var charge_sink_clips: Array[StringName] = []
## Seconds the body blends into each deeper charge pose.
@export var charge_sink_blend: float
## Humanoid clip played during the release cast: draw, follow-through and
## chiburi, with the katana in the hand (docs/specs/sheathe-release-animation.md).
@export var release_body_clip: StringName
## Seconds the body blends from the (deeper) charge pose into the release clip.
@export var release_body_blend: float
## Transparency of the area on the ground once fully charged (0 = opaque; at
## most 0.5 opacity, Principle II).
@export var full_charge_transparency: float

@export_group("Release")
## Seconds after the release when the draw holds (at the top of the draw):
## the clip and the enemies hit pause for release_feel.hitlag.
@export var strike_pause_at: float
@export var release_feel: StrikeFeel
## Seconds after the release when the wind cut bursts out (after the pause):
## camera shake of burst_feel and the kick of the charge zoom.
@export var burst_at: float
@export var burst_feel: StrikeFeel

@export_group("Charge glow")
## Energy of the light at the mouth of the sheath on the first milestone.
@export var glow_energy_base: float
## Energy added by each following milestone.
@export var glow_energy_step: float
## Energy at full charge (also the cap).
@export var glow_energy_full: float
## Reach of the light, in meters.
@export var glow_range: float
## Radius the glow sphere grows to on a milestone, in meters.
@export var glow_radius: float
## Radius it grows to at full charge, in meters.
@export var glow_full_radius: float
## Transparency of the glow sphere when a pulse starts (it fades to 1).
@export var glow_start_transparency: float
## Seconds a milestone pulse lasts (light and sphere).
@export var glow_duration: float
## Seconds the full charge pulse lasts.
@export var glow_full_duration: float

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


## Light energy of the charge glow at milestone `index` (1-based).
func glow_energy_for(index: int, is_full: bool) -> float:
	if is_full:
		return glow_energy_full
	return minf(glow_energy_base + glow_energy_step * (index - 1), glow_energy_full)


## Body clip of the charge after milestone `index` (0 = none yet): the last
## sink clip is kept for the full charge.
func charge_clip_for(index: int, is_full: bool) -> StringName:
	if is_full and not charge_sink_clips.is_empty():
		return charge_sink_clips[-1]
	var level: int = mini(index, charge_sink_clips.size() - 1)
	return charge_sink_clips[level - 1] if level > 0 else charge_body_clip
