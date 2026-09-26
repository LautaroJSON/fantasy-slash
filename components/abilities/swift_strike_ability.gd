class_name SwiftStrikeAbility
extends AbilityBehavior
## Sprint towards the nearest enemy (or where the player faces), slicing every
## enemy crossed on the way once: BASE_DAMAGE + ATTACK_SCALING x player DAMAGE,
## no crit, bonus or lifesteal, no invulnerability. HIT_RANGE is the sprint
## distance, HIT_WIDTH the slice width and CAST_DURATION the sprint time.
## Walls cut the sprint short. Sliced enemies are pushed sideways.
## Unique upgrades: "Asesinato" executes enemies left at or below a health
## fraction; "Reset" makes the ability ready again if the sprint killed.

const STRIKE_ANIMATION: StringName = &"swift_strike"
const RECOVER_ANIMATION: StringName = &"swift_strike_recover"
const EXECUTE: StringName = &"execute"
const RESET_ON_KILL: StringName = &"reset_on_kill"

var _direction: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _killed_this_cast: bool = false
## Enemies already sliced this cast; cleared on every cast.
var _already_hit: Array[Enemy] = []
## Reused every step: enemies may leave the registry while damage is applied.
var _hit_buffer: Array[Enemy] = []

@onready var _indicator: AbilityRectIndicator = $Indicator


func begin(ability: AbilityComponent) -> void:
	face_nearest_enemy(ability)
	var forward: Vector3 = -ability.visual.global_basis.z
	_direction = Vector3(forward.x, 0.0, forward.z).normalized()
	_speed = ability.get_stat(AbilityData.Stat.HIT_RANGE) / ability.get_stat(AbilityData.Stat.CAST_DURATION)
	_already_hit.clear()
	_killed_this_cast = false
	play_cast_animation(ability, STRIKE_ANIMATION)
	show_indicator(ability, _indicator)


func controls_motion() -> bool:
	return true


## The last step is shortened so the sprint covers exactly HIT_RANGE.
func move_body(ability: AbilityComponent, delta: float, _wish_direction: Vector3) -> void:
	var body: CharacterBody3D = ability.body
	var step: float = minf(delta, ability.get_cast_remaining())
	var from: Vector3 = body.global_position
	body.velocity = _direction * _speed * (step / delta)
	body.move_and_slide()
	_slice_along(ability, from, body.global_position)


func release(ability: AbilityComponent) -> void:
	ability.body.velocity = Vector3(0.0, ability.body.velocity.y, 0.0)
	play_animation(ability, RECOVER_ANIMATION)
	_indicator.start_fade()
	if _killed_this_cast and ability.has_unique(RESET_ON_KILL):
		ability.reset_cooldown()


func get_indicator() -> AbilityRectIndicator:
	return _indicator


## Hits every new enemy inside the band swept this step.
func _slice_along(ability: AbilityComponent, from: Vector3, to: Vector3) -> void:
	var flat_direction := Vector2(_direction.x, _direction.z)
	var travelled: float = maxf(Vector2(to.x - from.x, to.z - from.z).dot(flat_direction), 0.0)
	var half_width: float = ability.get_stat(AbilityData.Stat.HIT_WIDTH) / 2.0
	_hit_buffer.clear()
	for enemy: Enemy in ability.registry.get_active():
		if _already_hit.has(enemy):
			continue
		var padding: float = enemy.get_hit_padding()
		if HitboxMath.in_rectangle(from, flat_direction, enemy.global_position, travelled + padding, half_width + padding):
			_hit_buffer.append(enemy)
	if _hit_buffer.is_empty():
		return
	var damage: float = hit_damage(ability)
	for enemy: Enemy in _hit_buffer:
		_slice(ability, enemy, damage, from)


func _slice(ability: AbilityComponent, enemy: Enemy, damage: float, path_point: Vector3) -> void:
	_already_hit.append(enemy)
	var applied: float = enemy.health.receive_hit(damage)
	applied += _try_execute(ability, enemy)
	ability.report_hit(enemy, applied)
	_killed_this_cast = _killed_this_cast or enemy.health.is_dead()
	enemy.apply_knockback(_sideways_from_path(enemy.global_position - path_point), ability.tuning.knockback_speed)


## "Asesinato": kills a survivor left at or below the threshold. Returns the
## extra health removed.
func _try_execute(ability: AbilityComponent, enemy: Enemy) -> float:
	if not ability.has_unique(EXECUTE) or enemy.health.is_dead():
		return 0.0
	if enemy.health.get_health_ratio() > ability.get_unique_value(EXECUTE):
		return 0.0
	return enemy.health.execute()


## Perpendicular to the sprint, towards the side the enemy is on.
func _sideways_from_path(offset: Vector3) -> Vector3:
	var side := Vector3(-_direction.z, 0.0, _direction.x)
	if offset.dot(side) < 0.0:
		return -side
	return side
