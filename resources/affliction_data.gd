class_name AfflictionData
extends Resource
## One kind of Affliction (docs/specs/affliction.md): what fills its bar is the
## player's cards; this Resource says what happens when the bar fills.

## How effect_value becomes the strength of the effect.
enum EffectScaling {
	## effect_value as is (e.g. a fraction of speed or defense).
	FIXED,
	## effect_value x the player's DAMAGE when it triggers (e.g. poison ticks, burst).
	PLAYER_DAMAGE,
}

## Structural identity; cards of the same id fill the same bar.
@export var id: StringName
## Name on the cards and in the pause menu.
@export var title: String
## Fill of its bar under the enemy health bar; the boss HUD uses its albedo_color,
## which is also the icon_color of its status.
@export var bar_material: StandardMaterial3D
## Status applied when the bar fills (null for a pure burst).
@export var debuff: DebuffData
## Potency of the status, or damage multiplier of the burst.
@export var effect_value: float
@export var effect_scaling: EffectScaling
## Radius of the area damage around the enemy, in meters (0 = no burst).
@export var burst_radius: float
## Material of the burst damage numbers: the color of its bar
## (docs/specs/affliction-damage-colors.md).
@export var damage_number_material: StandardMaterial3D


func has_burst() -> bool:
	return burst_radius > 0.0


## Strength of the effect for a player with `player_damage` DAMAGE.
func potency_for(player_damage: float) -> float:
	if effect_scaling == EffectScaling.PLAYER_DAMAGE:
		return effect_value * player_damage
	return effect_value
