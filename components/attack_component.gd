class_name AttackComponent
extends Node
## Sword attack with auto-aim at the nearest living enemy. The hitbox is a
## logical circular sector (range + arc) checked by distance, not an Area3D.

signal attacked(hit_count: int, total_damage: float, was_crit: bool)
## Emitted once per enemy hit, with the damage actually applied to it.
signal enemy_hit(enemy: Enemy, applied: float, is_crit: bool)

@export var visual: Node3D
@export var stats: StatsComponent
@export var health: HealthComponent
@export var registry: EnemyRegistry
@export var sword_swing: SwordSwing
@export var movement: MovementComponent
@export var tuning: PlayerTuning

var _cooldown: float = 0.0
var _facing_lock: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Reused every attack: enemies may leave the registry while damage is applied.
var _hit_buffer: Array[Enemy] = []


func _physics_process(delta: float) -> void:
	advance_cooldown(delta)


func try_attack() -> bool:
	return try_attack_with_roll(_rng.randf())


## `crit_roll` in [0, 1) decides the critical hit; injected so tests are deterministic.
func try_attack_with_roll(crit_roll: float) -> bool:
	if _cooldown > 0.0:
		return false
	var attack_speed: float = stats.get_stat(PlayerStats.Stat.ATTACK_SPEED)
	var interval: float = 1.0 / attack_speed
	var time_scale: float = stats.base_stats.attack_speed / attack_speed
	var swing_time: float = _swing_time(interval, time_scale)
	_cooldown = interval
	_face_nearest_enemy(swing_time)
	_play_swing(swing_time, time_scale)
	_strike(crit_roll)
	return true


func advance_cooldown(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_advance_facing_lock(delta)


## Turns towards the nearest enemy and keeps facing it for `lock_time` (the sweep).
func _face_nearest_enemy(lock_time: float) -> void:
	var nearest: Enemy = registry.find_nearest(visual.global_position)
	if nearest == null:
		return
	var to_target: Vector3 = nearest.global_position - visual.global_position
	to_target.y = 0.0
	if to_target.is_zero_approx():
		return
	visual.rotation.y = atan2(-to_target.x, -to_target.z)
	movement.face_direction_locked = true
	_facing_lock = lock_time


## The blade sweeps horizontally across the same arc the hitbox covers.
func _play_swing(swing_time: float, time_scale: float) -> void:
	sword_swing.play(stats.get_stat(PlayerStats.Stat.ATTACK_ARC), swing_time, time_scale)


## The class weapon's sweep, sped up with the attack speed (time_scale =
## base / current ATTACK_SPEED), never longer than the attack interval.
func _swing_time(interval: float, time_scale: float) -> float:
	return minf(sword_swing.config.swing_duration * time_scale, interval)


func _strike(crit_roll: float) -> void:
	var is_crit: bool = DamageMath.roll_crit(stats.get_stat(PlayerStats.Stat.CRIT_CHANCE), crit_roll)
	var damage: float = DamageMath.outgoing(
		stats.get_stat(PlayerStats.Stat.DAMAGE),
		stats.get_stat(PlayerStats.Stat.DAMAGE_BONUS),
		is_crit,
		stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	_collect_hits()
	var total: float = 0.0
	for enemy: Enemy in _hit_buffer:
		total += _hit_enemy(enemy, damage, is_crit)
	health.heal(total * stats.get_stat(PlayerStats.Stat.LIFESTEAL))
	attacked.emit(_hit_buffer.size(), total, is_crit)


## Applies the hit and pushes the enemy away from the player. Returns the damage applied.
func _hit_enemy(enemy: Enemy, damage: float, is_crit: bool) -> float:
	var applied: float = enemy.health.receive_hit(damage)
	enemy_hit.emit(enemy, applied, is_crit)
	enemy.apply_knockback(enemy.global_position - visual.global_position, tuning.knockback_speed)
	return applied


func _collect_hits() -> void:
	_hit_buffer.clear()
	var origin: Vector3 = visual.global_position
	var forward: Vector3 = -visual.global_basis.z
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	var attack_range: float = stats.get_stat(PlayerStats.Stat.ATTACK_RANGE)
	var min_dot: float = cos(deg_to_rad(stats.get_stat(PlayerStats.Stat.ATTACK_ARC) / 2.0))
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


func _advance_facing_lock(delta: float) -> void:
	if _facing_lock <= 0.0:
		return
	_facing_lock -= delta
	if _facing_lock <= 0.0:
		movement.face_direction_locked = false
