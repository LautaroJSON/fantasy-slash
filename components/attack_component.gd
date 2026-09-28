class_name AttackComponent
extends Node
## Basic attack combo with auto-aim at the nearest living enemy
## (docs/specs/humanoid-player-model.md). Each tap, remembered for
## combo.input_buffer seconds, starts the next strike when it can: from rest,
## or inside the current strike's combo window. Each strike's times live in its
## AttackComboStep (docs/specs/class-combat-identity.md) and run against the
## position of its clip: damage lands once at hit_start, the combo window opens
## at cancel_point and the strike ends at end_time. The hitbox is a logical
## circular sector (range + arc, scaled per strike) checked by distance, not
## an Area3D.
## Without a humanoid (unit tests), a strike lands and ends at once.

signal attacked(hit_count: int, total_damage: float, was_crit: bool)
## Emitted once per enemy hit, with the damage actually applied to it.
signal enemy_hit(enemy: Enemy, applied: float, is_crit: bool)
## A strike of the combo started; `step_index` indexes combo.steps.
signal step_started(step_index: int)
## The strike in course ended or was cancelled (not emitted when chaining).
signal step_ended

enum ComboState {
	READY,
	STRIKING,
	CHAIN_OPEN,
}

@export var visual: Node3D
@export var stats: StatsComponent
@export var health: HealthComponent
@export var registry: EnemyRegistry
@export var movement: MovementComponent
@export var tuning: PlayerTuning
@export var combo: AttackComboConfig
## Plays the strike clips, whose position times each strike. Optional.
@export var humanoid: LowPolyHumanoid
## Plays the strike clips on the humanoid. Required with a humanoid.
@export var animator: PlayerAnimator
## Aim source of AimMode.CAMERA (docs/specs/bdo-combat-feel.md). Optional:
## without it the strikes aim at the nearest enemy.
@export var camera: ThirdPersonCamera

var _state: ComboState = ComboState.READY
## Strike in course (or last one); -1 after the combo resets.
var _step_index: int = -1
var _buffer_left: float = 0.0
## True once the current strike applied its damage (one hit per strike).
var _struck: bool = false
var _crit_roll: float = 0.0
var _facing_locked: bool = false
## Enemy the strike aimed at when it started (NEAREST_ENEMY); may be null.
var _aim_target: Enemy = null
## True from the hit window of the strike on: the facing no longer turns.
var _facing_fixed: bool = false
## Meters of lunge the current strike already covered.
var _lunge_covered: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Reused every strike: enemies may leave the registry while damage is applied.
var _hit_buffer: Array[Enemy] = []


func _ready() -> void:
	_connect_humanoid()


func _physics_process(delta: float) -> void:
	advance(delta)


## An attack tap: remembered for combo.input_buffer seconds.
func request_attack() -> void:
	_buffer_left = combo.input_buffer
	_try_start_buffered()


## Starts the next strike now if one can start. Returns true when it started.
func try_attack() -> bool:
	return try_attack_with_roll(_rng.randf())


## `crit_roll` in [0, 1) decides the critical hit; injected so tests are deterministic.
func try_attack_with_roll(crit_roll: float) -> bool:
	if not can_start_strike():
		return false
	_start_strike(crit_roll)
	return true


func advance(delta: float) -> void:
	_buffer_left = maxf(_buffer_left - delta, 0.0)
	_end_if_clip_lost()
	_advance_strike_moments()
	_try_start_buffered()


## True from the start of a strike until it ends, combo window included: the
## strike clip owns the humanoid meanwhile.
func is_attacking() -> bool:
	return _state != ComboState.READY


## True from the start of a strike until its combo window opens (the cancel
## point): the player cannot move; only the dash or the jump cut it
## (docs/specs/bdo-combat-feel.md, docs/specs/jump-cancels-strike.md).
func is_committed() -> bool:
	return _state == ComboState.STRIKING


## True while an attack tap is remembered and waiting to start a strike.
func has_buffered_attack() -> bool:
	return _buffer_left > 0.0


## Strike in course, or null when none runs.
func get_current_step() -> AttackComboStep:
	if _state == ComboState.READY or _step_index < 0:
		return null
	return _current_step()


## Moves the body during a committed strike: the windup steers the facing
## towards the aim and the strike's lunge carries the player forward.
func move_body(delta: float, wish_direction: Vector3) -> void:
	_steer_facing(delta, wish_direction)
	movement.drive(_lunge_velocity(delta), delta)


## A strike can start from rest or inside the combo window.
func can_start_strike() -> bool:
	return _state != ComboState.STRIKING


func get_state() -> ComboState:
	return _state


## Index of the strike in course (or last one); -1 when the combo is reset.
func get_step_index() -> int:
	return _step_index


## Clip speed of the strikes: faster with more ATTACK_SPEED.
func get_clip_speed() -> float:
	return stats.get_stat(PlayerStats.Stat.ATTACK_SPEED) / combo.reference_attack_speed


## Cuts the strike in course (dash, cast, hold): no damage if its hit window
## has not opened yet, and the next tap starts the combo over.
func cancel() -> void:
	_buffer_left = 0.0
	if _state == ComboState.READY:
		_step_index = -1
		return
	_end_strike()


func _connect_humanoid() -> void:
	if humanoid == null:
		return
	humanoid.anim.animation_finished.connect(_on_clip_finished)


func _try_start_buffered() -> void:
	if _buffer_left > 0.0 and can_start_strike():
		_buffer_left = 0.0
		_start_strike(_rng.randf())


func _start_strike(crit_roll: float) -> void:
	_step_index = (_step_index + 1) % combo.steps.size() if _state == ComboState.CHAIN_OPEN else 0
	_state = ComboState.STRIKING
	_struck = false
	_crit_roll = crit_roll
	_facing_fixed = false
	_lunge_covered = 0.0
	_aim_strike()
	step_started.emit(_step_index)
	if humanoid == null:
		_strike()
		_end_strike()
		return
	animator.play_attack(_current_step().animation, get_clip_speed())


func _current_step() -> AttackComboStep:
	return combo.steps[_step_index]


func _is_current_clip_playing() -> bool:
	return humanoid.anim.current_animation == _current_step().animation


## Safety net: if the strike clip stopped without its end event, the strike ends.
func _end_if_clip_lost() -> void:
	if humanoid == null or _state == ComboState.READY:
		return
	if not _is_current_clip_playing():
		_end_strike()


func _end_strike() -> void:
	_state = ComboState.READY
	_step_index = -1
	_aim_target = null
	_unlock_facing()
	step_ended.emit()


## Seconds of the current strike clip (at speed 1: the clip keeps its own time).
func _clip_time() -> float:
	return humanoid.anim.current_animation_position


## Runs the moments of the strike in course that its clip already reached:
## the hit at hit_start, the cancel point (or, with auto_chain, the next
## strike), and the end at end_time.
func _advance_strike_moments() -> void:
	if humanoid == null or _state == ComboState.READY or not _is_current_clip_playing():
		return
	var step: AttackComboStep = _current_step()
	var time: float = _clip_time()
	if not _struck and time >= step.hit_start:
		_facing_fixed = true
		_strike()
	if _state == ComboState.STRIKING and time >= step.cancel_point:
		_state = ComboState.CHAIN_OPEN
		if step.auto_chain:
			_start_strike(_rng.randf())
			return
	if time >= step.end_time:
		_end_strike()


## The strike clip reached its end: the strike ends in the same frame, before
## the animator picks the next clip.
func _on_clip_finished(clip: StringName) -> void:
	if _state != ComboState.READY and clip == _current_step().animation:
		_end_strike()


## Turns towards the start aim (AimMode) and locks the facing until the strike
## ends, even with nothing to aim at; only the windup may steer it
## (_steer_facing).
func _aim_strike() -> void:
	_aim_target = null
	movement.face_direction_locked = true
	_facing_locked = true
	var direction: Vector3 = _start_aim_direction()
	if direction.is_zero_approx():
		return
	visual.rotation.y = atan2(-direction.x, -direction.z)


func _start_aim_direction() -> Vector3:
	if camera == null or combo.aim_mode == AttackComboConfig.AimMode.NEAREST_ENEMY:
		return _nearest_enemy_direction()
	if combo.aim_mode == AttackComboConfig.AimMode.CAMERA_ASSIST:
		_aim_target = _find_assist_target(_camera_forward())
		if _aim_target != null:
			return _direction_to_target()
	return _camera_forward()


## The living enemy inside the assist cone (combo.assist_half_angle around
## `forward`, up to combo.assist_range) closest in angle; null without one.
func _find_assist_target(forward: Vector3) -> Enemy:
	var origin: Vector3 = visual.global_position
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	var min_dot: float = cos(deg_to_rad(combo.assist_half_angle))
	var best: Enemy = null
	var best_dot: float = -INF
	for enemy: Enemy in registry.get_active():
		if enemy.health.is_dead():
			continue
		var offset := Vector2(enemy.global_position.x - origin.x, enemy.global_position.z - origin.z)
		if offset.is_zero_approx() or offset.length() > combo.assist_range:
			continue
		var dot: float = flat_forward.dot(offset.normalized())
		if dot >= min_dot and dot > best_dot:
			best_dot = dot
			best = enemy
	return best


## Flat direction to the nearest enemy, which becomes the aim target; zero without one.
func _nearest_enemy_direction() -> Vector3:
	_aim_target = registry.find_nearest(visual.global_position)
	return _direction_to_target()


func _direction_to_target() -> Vector3:
	if not is_instance_valid(_aim_target) or not _aim_target.visible:
		return Vector3.ZERO
	var to_target: Vector3 = _aim_target.global_position - visual.global_position
	return Vector3(to_target.x, 0.0, to_target.z)


func _camera_forward() -> Vector3:
	var forward: Vector3 = camera.to_world_direction(Vector2(0.0, -1.0))
	return Vector3(forward.x, 0.0, forward.z)


## Where the windup steers. NEAREST_ENEMY: the movement input (only with
## windup_input_steering) and, without input, the aim target. CAMERA: the
## camera. CAMERA_ASSIST: the pulled enemy, or the camera without one. The
## camera modes ignore the movement input.
func _windup_aim_direction(wish_direction: Vector3) -> Vector3:
	if camera == null or combo.aim_mode == AttackComboConfig.AimMode.NEAREST_ENEMY:
		var wish := Vector3(wish_direction.x, 0.0, wish_direction.z) if combo.windup_input_steering else Vector3.ZERO
		return wish if not wish.is_zero_approx() else _direction_to_target()
	if combo.aim_mode == AttackComboConfig.AimMode.CAMERA_ASSIST and _aim_target != null:
		var to_target: Vector3 = _direction_to_target()
		if not to_target.is_zero_approx():
			return to_target
	return _camera_forward()


## Until the hit window opens, turns the facing towards the aim at most
## combo.windup_turn_speed degrees per second.
func _steer_facing(delta: float, wish_direction: Vector3) -> void:
	if _facing_fixed or _state != ComboState.STRIKING or _reached_hit_start():
		return
	var direction: Vector3 = _windup_aim_direction(wish_direction)
	if direction.is_zero_approx():
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	var difference: float = angle_difference(visual.rotation.y, target_yaw)
	var max_step: float = deg_to_rad(combo.windup_turn_speed) * delta
	visual.rotation.y += clampf(difference, -max_step, max_step)


## True once the clip of the strike in course reached its hit_start, even if
## advance() has not run yet this frame.
func _reached_hit_start() -> bool:
	return humanoid != null and _is_current_clip_playing() and _clip_time() >= _current_step().hit_start


## Horizontal velocity of the lunge this frame: the meters the clip advanced
## along the lunge since last frame, forward; zero with an enemy right ahead.
func _lunge_velocity(delta: float) -> Vector3:
	if humanoid == null or _state == ComboState.READY or delta <= 0.0 or not _is_current_clip_playing():
		return Vector3.ZERO
	var covered: float = _current_step().lunge_covered(_clip_time())
	var advanced: float = covered - _lunge_covered
	_lunge_covered = covered
	if advanced <= 0.0 or _is_lunge_blocked():
		return Vector3.ZERO
	var forward: Vector3 = -visual.global_basis.z
	return Vector3(forward.x, 0.0, forward.z).normalized() * (advanced / delta)


## True with an enemy ahead (inside the stop cone) closer than lunge_stop_distance.
func _is_lunge_blocked() -> bool:
	var origin: Vector3 = visual.global_position
	var forward: Vector3 = -visual.global_basis.z
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	var min_dot: float = cos(deg_to_rad(combo.lunge_stop_half_arc))
	for enemy: Enemy in registry.get_active():
		var offset := Vector2(enemy.global_position.x - origin.x, enemy.global_position.z - origin.z)
		if offset.length() - enemy.get_hit_padding() > combo.lunge_stop_distance:
			continue
		if offset.is_zero_approx() or flat_forward.dot(offset.normalized()) >= min_dot:
			return true
	return false


func _unlock_facing() -> void:
	if not _facing_locked:
		return
	_facing_locked = false
	movement.face_direction_locked = false


func _strike() -> void:
	_struck = true
	var step: AttackComboStep = _current_step()
	var is_crit: bool = DamageMath.roll_crit(stats.get_stat(PlayerStats.Stat.CRIT_CHANCE), _crit_roll)
	var damage: float = step.damage_multiplier * DamageMath.outgoing(
		stats.get_stat(PlayerStats.Stat.DAMAGE),
		stats.get_stat(PlayerStats.Stat.DAMAGE_BONUS),
		is_crit,
		stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	_collect_hits(step)
	var total: float = 0.0
	for enemy: Enemy in _hit_buffer:
		total += _hit_enemy(enemy, damage, is_crit, step.knockback_multiplier)
	health.heal(total * stats.get_stat(PlayerStats.Stat.LIFESTEAL))
	attacked.emit(_hit_buffer.size(), total, is_crit)


## Hits `enemies` as a basic-attack strike from outside the combo (e.g. the
## Parry's empowered riposte, docs/specs/parry-riposte-rework.md §2.4):
## damage_multiplier × the combo damage (bonus and crit), knockback and
## lifesteal; emits enemy_hit and attacked. `crit_roll` in [0, 1) decides the
## critical hit. Returns the total damage applied.
func strike_enemies(enemies: Array[Enemy], damage_multiplier: float, knockback_multiplier: float, crit_roll: float) -> float:
	var is_crit: bool = DamageMath.roll_crit(stats.get_stat(PlayerStats.Stat.CRIT_CHANCE), crit_roll)
	var damage: float = damage_multiplier * DamageMath.outgoing(
		stats.get_stat(PlayerStats.Stat.DAMAGE),
		stats.get_stat(PlayerStats.Stat.DAMAGE_BONUS),
		is_crit,
		stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	var total: float = 0.0
	for enemy: Enemy in enemies:
		total += _hit_enemy(enemy, damage, is_crit, knockback_multiplier)
	health.heal(total * stats.get_stat(PlayerStats.Stat.LIFESTEAL))
	attacked.emit(enemies.size(), total, is_crit)
	return total


## Applies the hit and pushes the enemy away from the player. Returns the damage applied.
func _hit_enemy(enemy: Enemy, damage: float, is_crit: bool, knockback_multiplier: float) -> float:
	var applied: float = enemy.health.receive_hit(damage)
	enemy_hit.emit(enemy, applied, is_crit)
	enemy.apply_knockback(enemy.global_position - visual.global_position, tuning.knockback_speed * knockback_multiplier)
	return applied


## Enemies inside the strike's sector: ATTACK_RANGE and ATTACK_ARC scaled by
## the step's multipliers, so the upgrades widen every strike.
func _collect_hits(step: AttackComboStep) -> void:
	_hit_buffer.clear()
	var origin: Vector3 = visual.global_position
	var forward: Vector3 = -visual.global_basis.z
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	var attack_range: float = stats.get_stat(PlayerStats.Stat.ATTACK_RANGE) * step.range_multiplier
	var min_dot: float = cos(deg_to_rad(stats.get_stat(PlayerStats.Stat.ATTACK_ARC) * step.arc_multiplier / 2.0))
	for enemy: Enemy in registry.get_active():
		if _is_in_hitbox(origin, flat_forward, enemy.global_position, attack_range + enemy.get_hit_padding(), min_dot):
			_hit_buffer.append(enemy)


func _is_in_hitbox(origin: Vector3, flat_forward: Vector2, point: Vector3, attack_range: float, min_dot: float) -> bool:
	var offset := Vector2(point.x - origin.x, point.z - origin.z)
	if offset.length_squared() > attack_range * attack_range:
		return false
	if offset.is_zero_approx():
		return true
	return flat_forward.dot(offset.normalized()) >= min_dot
