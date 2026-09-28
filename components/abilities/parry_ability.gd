class_name ParryAbility
extends AbilityBehavior
## The Warrior's Parry (docs/specs/warrior-abilities-rework.md §3.2, §5.2, and
## docs/specs/parry-riposte-rework.md): a tap snaps the shield in front, bigger,
## for CAST_DURATION (the window). Every frontal hit in the window is cancelled.
## The first one is answered with an invulnerable thrust at the attacker and
## leaves success_cooldown of cooldown; a window that blocked nothing leaves
## the player exposed for whiff_recovery with the full cooldown.
## Golden upgrades: "Contragolpe" renews the cooldown and turns the thrust into
## the empowered riposte (every enemy freezes, then a 360° strike that counts
## as a basic attack), and "Duelo" marks the attacker and the enemies the
## empowered riposte hits: a marked enemy's death grants a stack of Triumph.

enum State {
	IDLE,
	WINDOW,
	WHIFF,
	RIPOSTE,
	EMPOWERED,
}

const RIPOSTE: StringName = &"riposte"
const DUEL: StringName = &"duel"

@export var config: ParryConfig

var _state: State = State.IDLE
var _ability: AbilityComponent = null
## Seconds into the current state (the window, the thrust or the empowered riposte).
var _elapsed: float = 0.0
var _window: float = 0.0
var _blocked_any: bool = false
## The thrust or the empowered riposte made the player invulnerable (so only it clears the flag).
var _invulnerable: bool = false
## Reused buffers (Principle V).
var _hit_buffer: Array[Enemy] = []
var _no_enemies: Array[Enemy] = []

@onready var _indicator: AbilityRectIndicator = $Indicator
@onready var _block_vfx: BlockSparkVfx = $BlockVfx
@onready var _slash_vfx: CircleSlashVfx = $SlashVfx


func begin(ability: AbilityComponent) -> void:
	_ability = ability
	_state = State.WINDOW
	_elapsed = 0.0
	_window = ability.get_stat(AbilityData.Stat.CAST_DURATION)
	_blocked_any = false
	face_nearest_enemy(ability)
	ability.guard.raise(config.block_reduction, config.guard_arc_degrees)
	ability.guard.pop_shield(config.shield_pop_scale, config.shield_hold_scale, config.shield_pop_time, config.shield_settle_time)
	if not ability.guard.blocked.is_connected(_on_blocked):
		ability.guard.blocked.connect(_on_blocked)


## The window plus the recovery of a parry that blocks nothing; a block turns
## it into the thrust or the empowered riposte.
func cast_duration(ability: AbilityComponent) -> float:
	return ability.get_stat(AbilityData.Stat.CAST_DURATION) + config.whiff_recovery


func channel(ability: AbilityComponent, step: float) -> void:
	var before: float = _elapsed
	_elapsed += step
	match _state:
		State.WINDOW:
			_advance_window(ability)
		State.RIPOSTE:
			_advance_riposte(ability, before)
		State.EMPOWERED:
			_advance_empowered(ability, before)


func release(ability: AbilityComponent) -> void:
	_finish(ability)


func cancel_cast(ability: AbilityComponent) -> void:
	_finish(ability)


func get_body_clip(_ability: AbilityComponent) -> StringName:
	match _state:
		State.WHIFF:
			return config.whiff_body_clip
		State.RIPOSTE:
			return config.riposte_body_clip
		State.EMPOWERED:
			return config.empowered_body_clip
	return config.parry_body_clip


## The shield snaps in front, and the empowered riposte snaps into its
## wind-up: their clips start without blending.
func get_body_clip_blend(_ability: AbilityComponent) -> float:
	return config.parry_enter_blend if _state == State.WINDOW or _state == State.EMPOWERED else DEFAULT_BLEND


## The empowered riposte cannot be cut by a dash until its strike is over.
func locks_dash(_ability: AbilityComponent) -> bool:
	return _state == State.EMPOWERED and _elapsed < config.empowered_dash_lock


func holds_weapon_in_hand(_ability: AbilityComponent) -> bool:
	return true


## Only the thrust and the 360° strike sweep the blade.
func trails_while_casting(_ability: AbilityComponent) -> bool:
	if _state == State.RIPOSTE:
		return _elapsed >= config.riposte_trail_start and _elapsed < config.riposte_trail_end
	if _state == State.EMPOWERED:
		return _elapsed >= config.empowered_trail_start and _elapsed < config.empowered_trail_end
	return false


func get_state() -> State:
	return _state


func get_indicator() -> AbilityRectIndicator:
	return _indicator


func get_block_vfx() -> BlockSparkVfx:
	return _block_vfx


func get_slash_vfx() -> CircleSlashVfx:
	return _slash_vfx


## Radius of the empowered riposte's 360° strike at the current "Contragolpe" level.
func get_empowered_radius(ability: AbilityComponent) -> float:
	return ability.player_stats.get_stat(PlayerStats.Stat.ATTACK_RANGE) * config.get_empowered_range_scale(ability.get_unique_level(RIPOSTE))


func _advance_window(ability: AbilityComponent) -> void:
	if _elapsed >= _window - AbilityComponent.TIME_EPSILON:
		_lower_shield(ability)
		_state = State.WHIFF


func _advance_riposte(ability: AbilityComponent, before: float) -> void:
	if _crossed(before, config.riposte_hit_time):
		_riposte_hit(ability)
	if _crossed(before, config.riposte_trail_start) or _crossed(before, config.riposte_trail_end):
		ability.notify_trail_changed()


func _advance_empowered(ability: AbilityComponent, before: float) -> void:
	if _crossed(before, config.empowered_trail_start):
		_slash_vfx.play(ability.visual, get_empowered_radius(ability), ability.get_unique_level(RIPOSTE))
	if _crossed(before, config.empowered_hit_time):
		_empowered_hit(ability)
	if _crossed(before, config.empowered_trail_start) or _crossed(before, config.empowered_trail_end):
		ability.notify_trail_changed()


func _lower_shield(ability: AbilityComponent) -> void:
	ability.guard.lower()
	ability.guard.shrink_shield(config.shield_shrink_time)


func _on_blocked(_amount: float, attacker: Enemy) -> void:
	if _state != State.WINDOW or _ability == null:
		return
	var ability: AbilityComponent = _ability
	_block_vfx.play(ability.visual, attacker.global_position, config.block_spark_scale)
	ability.report_strike(config.block_feel, _no_enemies)
	_challenge(ability, attacker)
	if _blocked_any:
		return
	_blocked_any = true
	if ability.has_unique(RIPOSTE):
		ability.reset_cooldown()
		_begin_empowered(ability, attacker)
	else:
		ability.reduce_cooldown(maxf(ability.get_cooldown_remaining() - config.success_cooldown, 0.0))
		_begin_riposte(ability, attacker)


## "Duelo": marks an enemy; its death while marked grants Triumph.
func _challenge(ability: AbilityComponent, enemy: Enemy) -> void:
	if not ability.has_unique(DUEL) or not _is_alive(enemy):
		return
	enemy.debuffs.apply(config.challenged, 1.0)
	if not enemy.killed.is_connected(_on_challenged_killed):
		enemy.killed.connect(_on_challenged_killed, CONNECT_ONE_SHOT)


func _on_challenged_killed(enemy: Enemy) -> void:
	if _ability == null or not enemy.debuffs.has_debuff(config.challenged.id):
		return
	_ability.buffs.add_stack(config.triumph)


## Every parry that blocks: the rest of the window becomes an invulnerable thrust at the attacker.
func _begin_riposte(ability: AbilityComponent, attacker: Enemy) -> void:
	_start_counter(ability, attacker)
	_state = State.RIPOSTE
	ability.set_cast_remaining(config.riposte_duration)
	show_indicator(ability, _indicator)
	ability.notify_trail_changed()


## "Contragolpe": every enemy freezes, the camera zooms in, and after the
## freeze the player strikes all around.
func _begin_empowered(ability: AbilityComponent, attacker: Enemy) -> void:
	_start_counter(ability, attacker)
	_state = State.EMPOWERED
	ability.set_cast_remaining(config.empowered_duration)
	for enemy: Enemy in ability.registry.get_active():
		enemy.freeze_time(config.empowered_freeze)
	ability.camera.kick_fov(-config.empowered_zoom_deg, config.empowered_zoom_return)
	ability.camera.shake(config.empowered_shake)


## Lowers the shield, turns to the attacker and makes the player invulnerable.
func _start_counter(ability: AbilityComponent, attacker: Enemy) -> void:
	_lower_shield(ability)
	_elapsed = 0.0
	var to_attacker: Vector3 = attacker.global_position - ability.visual.global_position
	to_attacker.y = 0.0
	if not to_attacker.is_zero_approx():
		ability.visual.rotation.y = atan2(-to_attacker.x, -to_attacker.z)
	ability.health.is_invulnerable = true
	_invulnerable = true


func _riposte_hit(ability: AbilityComponent) -> void:
	_collect_thrust_hits(ability)
	var is_crit: bool = DamageMath.roll_crit(ability.player_stats.get_stat(PlayerStats.Stat.CRIT_CHANCE), randf())
	var damage: float = DamageMath.apply_crit(hit_damage(ability), is_crit, ability.player_stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	for enemy: Enemy in _hit_buffer:
		var applied: float = enemy.health.receive_hit(damage)
		ability.report_hit(enemy, applied, is_crit)
		enemy.apply_knockback(enemy.global_position - ability.visual.global_position, config.riposte_knockback_speed)
	if not _hit_buffer.is_empty():
		ability.report_strike(config.riposte_feel, _hit_buffer)
	_indicator.start_fade()


## The 360° strike: a basic attack on every enemy around. "Duelo" marks them
## first, so one the strike kills dies marked and grants Triumph.
func _empowered_hit(ability: AbilityComponent) -> void:
	_slash_vfx.burst()
	_collect_empowered_hits(ability)
	if _hit_buffer.is_empty():
		return
	for enemy: Enemy in _hit_buffer:
		_challenge(ability, enemy)
	ability.attack.strike_enemies(_hit_buffer, config.get_empowered_damage_multiplier(ability.get_unique_level(RIPOSTE)), config.empowered_knockback_multiplier, randf())
	ability.report_strike(config.empowered_feel, _hit_buffer)


func _collect_thrust_hits(ability: AbilityComponent) -> void:
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


func _collect_empowered_hits(ability: AbilityComponent) -> void:
	_hit_buffer.clear()
	var origin: Vector3 = ability.visual.global_position
	var radius: float = get_empowered_radius(ability)
	for enemy: Enemy in ability.registry.get_active():
		var offset := Vector2(enemy.global_position.x - origin.x, enemy.global_position.z - origin.z)
		var reach: float = radius + enemy.get_hit_padding()
		if offset.length_squared() <= reach * reach and _is_alive(enemy):
			_hit_buffer.append(enemy)


func _finish(ability: AbilityComponent) -> void:
	_lower_shield(ability)
	if ability.guard.blocked.is_connected(_on_blocked):
		ability.guard.blocked.disconnect(_on_blocked)
	if _invulnerable:
		ability.health.is_invulnerable = false
		_invulnerable = false
	var was_striking: bool = _state == State.RIPOSTE or _state == State.EMPOWERED
	_state = State.IDLE
	if was_striking:
		ability.notify_trail_changed()


func _crossed(before: float, at: float) -> bool:
	return before < at and _elapsed >= at


func _is_alive(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.health.is_dead() and enemy.process_mode != Node.PROCESS_MODE_DISABLED
