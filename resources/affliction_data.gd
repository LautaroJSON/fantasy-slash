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
## Status and potency applied instead of debuff and effect_value to enemies
## that resist control (EnemyStats.resists_control, the bosses). Null = the
## same status for every enemy (docs/specs/frost-freeze.md).
@export var resisted_debuff: DebuffData
@export var resisted_effect_value: float
## Material of the burst damage numbers: the color of its bar
## (docs/specs/affliction-damage-colors.md).
@export var damage_number_material: StandardMaterial3D


func has_burst() -> bool:
	return burst_radius > 0.0


## Status for an enemy: the resisted one for bosses (resists_control) when set.
func debuff_for(resists_control: bool) -> DebuffData:
	if resists_control and resisted_debuff != null:
		return resisted_debuff
	return debuff


## Strength of the effect for a player with `player_damage` DAMAGE, on an
## enemy that resists control or not.
func potency_for(player_damage: float, resists_control: bool = false) -> float:
	var value: float = effect_value
	if resists_control and resisted_debuff != null:
		value = resisted_effect_value
	if effect_scaling == EffectScaling.PLAYER_DAMAGE:
		return value * player_damage
	return value
