class_name ThrustAbility
extends AbilityBehavior
## Forward sword thrust. The player stands still (enforced by Player while the
## slot is casting), turns to the nearest enemy, and when the cast ends every
## enemy inside a logical rectangle in front takes BASE_DAMAGE + ATTACK_SCALING
## x player DAMAGE. No crit, damage bonus or lifesteal. The rectangle is
## outlined on the ground from the key press and fades out after the hit.
## Unique upgrade "Lacerante" makes every hit apply bleeding.

const THRUST_ANIMATION: StringName = &"thrust"
const RECOVER_ANIMATION: StringName = &"thrust_recover"
const BLEED: StringName = &"bleed"

## Reused every cast: enemies may leave the registry while damage is applied.
var _hit_buffer: Array[Enemy] = []

@onready var _indicator: AbilityRectIndicator = $Indicator


func begin(ability: AbilityComponent) -> void:
	face_nearest_enemy(ability)
	play_cast_animation(ability, THRUST_ANIMATION)
	show_indicator(ability, _indicator)


func release(ability: AbilityComponent) -> void:
	_collect_hits(ability)
	var damage: float = hit_damage(ability)
	for enemy: Enemy in _hit_buffer:
		_hit_enemy(ability, enemy, damage)
	play_animation(ability, RECOVER_ANIMATION)
	_indicator.start_fade()


func get_indicator() -> AbilityRectIndicator:
	return _indicator


func _collect_hits(ability: AbilityComponent) -> void:
	_hit_buffer.clear()
	var origin: Vector3 = ability.visual.global_position
	var forward: Vector3 = -ability.visual.global_basis.z
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	var length: float = ability.get_stat(AbilityData.Stat.HIT_RANGE)
	var half_width: float = ability.get_stat(AbilityData.Stat.HIT_WIDTH) / 2.0
	for enemy: Enemy in ability.registry.get_active():
		var padding: float = enemy.get_hit_padding()
		if HitboxMath.in_rectangle(origin, flat_forward, enemy.global_position, length + padding, half_width + padding):
			_hit_buffer.append(enemy)


func _hit_enemy(ability: AbilityComponent, enemy: Enemy, damage: float) -> void:
	var applied: float = enemy.health.receive_hit(damage)
	ability.report_hit(enemy, applied)
	enemy.apply_knockback(enemy.global_position - ability.visual.global_position, ability.tuning.knockback_speed)
	_apply_bleed(ability, enemy)


## "Lacerante": the hit leaves the enemy bleeding.
func _apply_bleed(ability: AbilityComponent, enemy: Enemy) -> void:
	if not ability.has_unique(BLEED) or enemy.health.is_dead():
		return
	enemy.debuffs.apply(ability.get_unique_upgrade(BLEED).debuff, ability.get_unique_value(BLEED))
