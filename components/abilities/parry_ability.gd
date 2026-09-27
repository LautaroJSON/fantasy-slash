class_name ParryAbility
extends AbilityBehavior
## The Warrior's Parry (docs/specs/warrior-abilities-rework.md §3.2, §5.2): a tap
## raises the shield for CAST_DURATION (the window). Every frontal hit in the
## window is cancelled. The first one leaves success_cooldown of cooldown and a
## short shield push (success_recovery); a window that blocked nothing leaves
## the player exposed for whiff_recovery with the full cooldown.
## Golden upgrades: "Represalia" returns the cancelled damage to the attacker,
## "Contragolpe" renews the cooldown and answers the first block with an
## automatic thrust (invulnerable), and "Duelo" marks the attacker: its death
## grants a stack of Triumph.

enum State {
	IDLE,
	WINDOW,
	SUCCESS,
	WHIFF,
	RIPOSTE,
}

const RETRIBUTION: StringName = &"retribution"
const RIPOSTE: StringName = &"riposte"
const DUEL: StringName = &"duel"

@export var config: ParryConfig

var _state: State = State.IDLE
var _ability: AbilityComponent = null
## Seconds into the current state (the window or the riposte).
var _elapsed: float = 0.0
var _window: float = 0.0
var _blocked_any: bool = false
## The riposte made the player invulnerable (so only it clears the flag).
var _invulnerable: bool = false
## Reused buffers (Principle V).
var _hit_buffer: Array[Enemy] = []
var _no_enemies: Array[Enemy] = []

@onready var _indicator: AbilityRectIndicator = $Indicator
@onready var _block_vfx: BlockSparkVfx = $BlockVfx


func begin(ability: AbilityComponent) -> void:
	_ability = ability
	_state = State.WINDOW
	_elapsed = 0.0
	_window = ability.get_stat(AbilityData.Stat.CAST_DURATION)
	_blocked_any = false
	face_nearest_enemy(ability)
	ability.guard.raise(config.block_reduction, config.guard_arc_degrees)
	if not ability.guard.blocked.is_connected(_on_blocked):
		ability.guard.blocked.connect(_on_blocked)


## The window plus the recovery of a parry that blocks nothing; a block
## shortens it (success) or turns it into the riposte.
func cast_duration(ability: AbilityComponent) -> float:
	return ability.get_stat(AbilityData.Stat.CAST_DURATION) + config.whiff_recovery


func channel(ability: AbilityComponent, step: float) -> void:
	var before: float = _elapsed
	_elapsed += step
	if _state == State.WINDOW and _elapsed >= _window - AbilityComponent.TIME_EPSILON:
		_end_window(ability)
	elif _state == State.RIPOSTE:
		if _crossed(before, config.riposte_hit_time):
			_riposte_hit(ability)
		if _crossed(before, config.riposte_trail_start) or _crossed(before, config.riposte_trail_end):
			ability.notify_trail_changed()


func release(ability: AbilityComponent) -> void:
	_finish(ability)


func cancel_cast(ability: AbilityComponent) -> void:
	_finish(ability)


func get_body_clip(_ability: AbilityComponent) -> StringName:
	match _state:
		State.SUCCESS:
			return config.success_body_clip
		State.WHIFF:
			return config.whiff_body_clip
		State.RIPOSTE:
			return config.riposte_body_clip
	return config.parry_body_clip


func holds_weapon_in_hand(_ability: AbilityComponent) -> bool:
	return true


## Only the riposte's thrust sweeps the blade.
func trails_while_casting(_ability: AbilityComponent) -> bool:
	return _state == State.RIPOSTE and _elapsed >= config.riposte_trail_start and _elapsed < config.riposte_trail_end


func get_state() -> State:
	return _state


func get_indicator() -> AbilityRectIndicator:
	return _indicator


func get_block_vfx() -> BlockSparkVfx:
	return _block_vfx


func _end_window(ability: AbilityComponent) -> void:
	ability.guard.lower()
	if _blocked_any:
		_state = State.SUCCESS
		ability.set_cast_remaining(config.success_recovery)
	else:
		_state = State.WHIFF


func _on_blocked(amount: float, attacker: Enemy) -> void:
	if _state != State.WINDOW or _ability == null:
		return
	var ability: AbilityComponent = _ability
	_block_vfx.play(ability.visual, attacker.global_position, config.block_spark_scale)
	ability.report_strike(config.block_feel, _no_enemies)
	_retaliate(ability, amount, attacker)
	_challenge(ability, attacker)
	if _blocked_any:
		return
	_blocked_any = true
	if ability.has_unique(RIPOSTE):
		ability.reset_cooldown()
		_begin_riposte(ability, attacker)
	else:
		ability.reduce_cooldown(maxf(ability.get_cooldown_remaining() - config.success_cooldown, 0.0))


## "Represalia": the attacker takes the cancelled damage × the level's value.
func _retaliate(ability: AbilityComponent, amount: float, attacker: Enemy) -> void:
	if not ability.has_unique(RETRIBUTION) or not _is_alive(attacker):
		return
	var applied: float = attacker.health.receive_hit(amount * ability.get_unique_value(RETRIBUTION))
	ability.report_hit(attacker, applied)


## "Duelo": marks the attacker; its death while marked grants Triumph.
func _challenge(ability: AbilityComponent, attacker: Enemy) -> void:
	if not ability.has_unique(DUEL) or not _is_alive(attacker):
		return
	attacker.debuffs.apply(config.challenged, 1.0)
	if not attacker.killed.is_connected(_on_challenged_killed):
		attacker.killed.connect(_on_challenged_killed, CONNECT_ONE_SHOT)


func _on_challenged_killed(enemy: Enemy) -> void:
	if _ability == null or not enemy.debuffs.has_debuff(config.challenged.id):
		return
	_ability.buffs.add_stack(config.triumph)


## "Contragolpe": the rest of the window becomes an invulnerable thrust at the attacker.
func _begin_riposte(ability: AbilityComponent, attacker: Enemy) -> void:
	ability.guard.lower()
	_state = State.RIPOSTE
	_elapsed = 0.0
	var to_attacker: Vector3 = attacker.global_position - ability.visual.global_position
	to_attacker.y = 0.0
	if not to_attacker.is_zero_approx():
		ability.visual.rotation.y = atan2(-to_attacker.x, -to_attacker.z)
	ability.health.is_invulnerable = true
	_invulnerable = true
	ability.set_cast_remaining(config.riposte_duration)
	show_indicator(ability, _indicator)
	ability.notify_trail_changed()


func _riposte_hit(ability: AbilityComponent) -> void:
	_collect_hits(ability)
	var is_crit: bool = DamageMath.roll_crit(ability.player_stats.get_stat(PlayerStats.Stat.CRIT_CHANCE), randf())
	var damage: float = DamageMath.apply_crit(hit_damage(ability), is_crit, ability.player_stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	for enemy: Enemy in _hit_buffer:
		var applied: float = enemy.health.receive_hit(damage)
		ability.report_hit(enemy, applied, is_crit)
		enemy.apply_knockback(enemy.global_position - ability.visual.global_position, config.riposte_knockback_speed)
	if not _hit_buffer.is_empty():
		ability.report_strike(config.riposte_feel, _hit_buffer)
	_indicator.start_fade()


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


func _finish(ability: AbilityComponent) -> void:
	ability.guard.lower()
	if ability.guard.blocked.is_connected(_on_blocked):
		ability.guard.blocked.disconnect(_on_blocked)
	if _invulnerable:
		ability.health.is_invulnerable = false
		_invulnerable = false
	var was_riposte: bool = _state == State.RIPOSTE
	_state = State.IDLE
	if was_riposte:
		ability.notify_trail_changed()


func _crossed(before: float, at: float) -> bool:
	return before < at and _elapsed >= at


func _is_alive(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.health.is_dead() and enemy.process_mode != Node.PROCESS_MODE_DISABLED
