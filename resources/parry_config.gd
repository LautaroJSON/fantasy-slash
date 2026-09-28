class_name ParryConfig
extends Resource
## Tuning of the Warrior's Parry (docs/specs/warrior-abilities-rework.md §3.2,
## §5.2, and docs/specs/parry-riposte-rework.md). The window is CAST_DURATION;
## damage, range and width of the thrust and the cooldown are AbilityData stats.

@export_group("Block")
## Share of a frontal hit the shield cancels during the window (1 = all).
@export var block_reduction: float
## Arc in front of the player the shield covers, in degrees.
@export var guard_arc_degrees: float
## Seconds from the start of the parry clip until the shield is up (the clip's event).
@export var raise_time: float
## Cooldown left after the first block of a cast, in seconds.
@export var success_cooldown: float
## Seconds after the window of a parry that blocked nothing (exposed).
@export var whiff_recovery: float

@export_group("Riposte")
## Seconds the thrust that answers a block lasts from the block.
@export var riposte_duration: float
## Seconds into the riposte when the thrust hits (the clip's event).
@export var riposte_hit_time: float
## The blade sweeps (weapon trail) between these seconds of the riposte.
@export var riposte_trail_start: float
@export var riposte_trail_end: float
## Push speed of the riposte, in m/s.
@export var riposte_knockback_speed: float

@export_group("Shield")
## Blend into the parry clip, in seconds (0: the shield snaps in front).
@export var parry_enter_blend: float
## Shield size: it pops to shield_pop_scale in shield_pop_time, settles on
## shield_hold_scale by shield_settle_time, and shrinks back in
## shield_shrink_time once lowered. Purely visual.
@export var shield_pop_scale: float
@export var shield_hold_scale: float
@export var shield_pop_time: float
@export var shield_settle_time: float
@export var shield_shrink_time: float

@export_group("Empowered riposte")
## "Contragolpe": seconds every active enemy stays frozen from the block.
@export var empowered_freeze: float
## Seconds from the block when the 360° strike hits (after the freeze).
@export var empowered_hit_time: float
## Seconds the whole empowered riposte lasts from the block (the player is
## invulnerable all along).
@export var empowered_duration: float
## Seconds from the block during which a dash cannot cut it.
@export var empowered_dash_lock: float
## "Contragolpe" levels: the radius of the strike over the player's ATTACK_RANGE
## is the product of the first `level` steps (docs/specs/riposte-levels.md).
@export var empowered_range_steps: Array[float]
## Damage of the strike over one combo strike (it counts as a basic attack):
## the product of the first `level` steps.
@export var empowered_damage_steps: Array[float]
@export var empowered_knockback_multiplier: float
## Camera zoom (FOV degrees taken off) and its return, and the shake, at the block.
@export var empowered_zoom_deg: float
@export var empowered_zoom_return: float
@export var empowered_shake: float
## The blade sweeps (weapon trail) between these seconds from the block.
@export var empowered_trail_start: float
@export var empowered_trail_end: float
## Hit lag of the strike (it has no combo step to take it from).
@export var empowered_feel: StrikeFeel

@export_group("Duel")
## Mark left on the attacker whose hit was cancelled ("Duelo").
@export var challenged: DebuffData
## Buff gained when a marked enemy dies ("Duelo").
@export var triumph: BuffData

@export_group("Feel")
## A hit cancelled by the shield (only the camera shakes).
@export var block_feel: StrikeFeel
@export var riposte_feel: StrikeFeel
## Speed of the sparks of a block over the configured one.
@export var block_spark_scale: float

@export_group("Body")
## Humanoid clip of the window.
@export var parry_body_clip: StringName
## Humanoid clip after a window that blocked nothing.
@export var whiff_body_clip: StringName
## Humanoid clip of the riposte.
@export var riposte_body_clip: StringName
## Humanoid clip of the empowered riposte (freeze, 360° strike, recovery).
@export var empowered_body_clip: StringName


## Radius of the 360° strike over ATTACK_RANGE at "Contragolpe" `level`
## (clamped to 1..the number of steps).
func get_empowered_range_scale(level: int) -> float:
	return _product(empowered_range_steps, level)


## Damage of the 360° strike over one combo strike at "Contragolpe" `level`.
func get_empowered_damage_multiplier(level: int) -> float:
	return _product(empowered_damage_steps, level)


static func _product(steps: Array[float], level: int) -> float:
	var total: float = 1.0
	for i: int in clampi(level, 1, steps.size()):
		total *= steps[i]
	return total
