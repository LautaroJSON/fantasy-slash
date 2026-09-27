class_name AbilityBehavior
extends Node
## Base of the logic of one ability. Instantiated once by AbilityComponent.equip()
## and driven by it: begin() on the key press, channel() every cast step,
## release() when the cast ends.
## Charged abilities (is_charged() true) first charge while the key is held:
## begin_charge() on the press, charge() every step, and begin() when the key is
## released; cancel_charge() when the charge is dropped without a cast.
## Behaviors that move the player while charging or casting return true from
## controls_motion() and implement move_body(); the others keep the player still.


func begin(_ability: AbilityComponent) -> void:
	pass


func release(_ability: AbilityComponent) -> void:
	pass


## True for abilities that are held down to charge and cast on the release.
func is_charged() -> bool:
	return false


func begin_charge(_ability: AbilityComponent) -> void:
	pass


## Called by AbilityComponent every step while the key is held.
func charge(_ability: AbilityComponent, _step: float) -> void:
	pass


## Called once per charge milestone (every ChargeFeedbackConfig.milestone_interval
## seconds of charge, and at full charge). `index` starts at 1.
func charge_milestone(_ability: AbilityComponent, _index: int, _is_full: bool) -> void:
	pass


## The player started a dash (charging or not).
func dash_started(_ability: AbilityComponent) -> void:
	pass


## The player started a dash while this ability was charging.
func dash_during_charge(_ability: AbilityComponent) -> void:
	pass


## The cast is cut short before it ends (e.g. a dash during the recovery):
## release() is not called.
func cancel_cast(_ability: AbilityComponent) -> void:
	pass


## The cast was cut short by a dash that has just started (after cancel_cast()).
## E.g. the Spin turns the dash into a slash.
func cast_cut_by_dash(_ability: AbilityComponent) -> void:
	pass


## A charged ability may be cast without charging (e.g. an empowered cast):
## try_cast() then casts at once with a full charge.
func skips_charge() -> bool:
	return false


## True while the ability holds an empowered cast (HUD feedback).
func is_empowered() -> bool:
	return false


## The charge ends without a cast (e.g. another ability is equipped).
func cancel_charge(_ability: AbilityComponent) -> void:
	pass


## Called by AbilityComponent every step of the cast with the cast time that
## elapsed (the last step is shortened so the steps add up to CAST_DURATION).
## Channelled abilities (e.g. a spin) act here.
func channel(_ability: AbilityComponent, _step: float) -> void:
	pass


func controls_motion() -> bool:
	return false


## Called by Player every physics step of the cast when controls_motion() is
## true. `wish_direction` is the player's movement input in world space.
func move_body(_ability: AbilityComponent, _delta: float, _wish_direction: Vector3) -> void:
	pass


## Turns the visual towards the nearest living enemy, if any.
func face_nearest_enemy(ability: AbilityComponent) -> void:
	var nearest: Enemy = ability.registry.find_nearest(ability.visual.global_position)
	if nearest == null:
		return
	var to_target: Vector3 = nearest.global_position - ability.visual.global_position
	to_target.y = 0.0
	if to_target.is_zero_approx():
		return
	ability.visual.rotation.y = atan2(-to_target.x, -to_target.z)


## Plays `animation` stretched to last exactly the cast, whatever its upgrades.
func play_cast_animation(ability: AbilityComponent, animation: StringName) -> void:
	var animator: AnimationPlayer = ability.swing_player
	var animation_length: float = animator.get_animation(animation).length
	animator.speed_scale = animation_length / ability.get_stat(AbilityData.Stat.CAST_DURATION)
	animator.stop()
	animator.play(animation)


## Plays `animation` at its own speed (e.g. the recovery after the cast).
func play_animation(ability: AbilityComponent, animation: StringName) -> void:
	var animator: AnimationPlayer = ability.swing_player
	animator.speed_scale = 1.0
	animator.stop()
	animator.play(animation)


## Outlines a rectangle from the player's feet towards where the visual faces.
func show_indicator(ability: AbilityComponent, indicator: AbilityRectIndicator) -> void:
	indicator.show_rect(
		ability.visual.global_position,
		ability.visual.global_rotation.y,
		ability.get_stat(AbilityData.Stat.HIT_RANGE),
		ability.get_stat(AbilityData.Stat.HIT_WIDTH))


## Flat damage plus the scaled player DAMAGE; no crit, bonus or lifesteal.
func hit_damage(ability: AbilityComponent) -> float:
	return DamageMath.ability_damage(
		ability.get_stat(AbilityData.Stat.BASE_DAMAGE),
		ability.get_stat(AbilityData.Stat.ATTACK_SCALING),
		ability.player_stats.get_stat(PlayerStats.Stat.DAMAGE))


## Humanoid clip the body plays while this ability charges or casts; &"" = the
## default (idle). E.g. Sheathe crouches while charging
## (docs/specs/sheath-socket-hand-grip.md §2.7).
func get_body_clip(_ability: AbilityComponent) -> StringName:
	return &""


## True while this ability's cast leaves the weapon in the humanoid's hand
## (WeaponMount keeps following the hand), so the body clip draws the cut.
## E.g. Sheathe's release (docs/specs/sheathe-release-animation.md).
func holds_weapon_in_hand(_ability: AbilityComponent) -> bool:
	return false
