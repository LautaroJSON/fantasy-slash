class_name AirSlashComponent
extends Node
## The Berserker's air slash (docs/specs/berserker-air-slash.md). In the air,
## once per jump: HOVER (suspended, very slow, weapon raised, charging, with the
## hit band outlined on the ground) until the attack is released or
## hover_duration passes; DIVE (falls fast while the blade slashes down); on
## landing every enemy in a band in front takes the basic attack damage x the
## charge factor, then LANDING (the player stays still for landing_lock).
## Disabled (no config) for classes without an air slash.

signal struck(hit_count: int, total_damage: float, was_crit: bool)
## Emitted once per enemy hit, with the damage actually applied to it.
signal enemy_hit(enemy: Enemy, applied: float, is_crit: bool)

enum Phase {
	IDLE,
	HOVER,
	DIVE,
	LANDING,
}

@export var body: CharacterBody3D
@export var visual: Node3D
@export var stats: StatsComponent
@export var health: HealthComponent
@export var movement: MovementComponent
@export var sword_swing: SwordSwing
@export var camera: ThirdPersonCamera
## Assigned by Player.
var registry: EnemyRegistry = null

var _config: AirSlashConfig = null
var _phase: Phase = Phase.IDLE
var _elapsed: float = 0.0
var _charge_ratio: float = 0.0
var _used_this_jump: bool = false
## Height of the floor the player last stood on (the band is drawn there).
var _ground_y: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Reused every slash: enemies may leave the registry while damage is applied.
var _hit_buffer: Array[Enemy] = []

@onready var _indicator: AbilityRectIndicator = $Indicator
@onready var _wind_cut: WindCutVfx = $WindCut


## Tracks the floor while idle (the jump starts from it).
func _physics_process(_delta: float) -> void:
	track_floor()


## null disables the air slash (classes without one).
func setup(config: AirSlashConfig) -> void:
	_config = config
	cancel()


func is_enabled() -> bool:
	return _config != null


## On the floor and idle: remembers the floor height and allows a new slash.
func track_floor() -> void:
	if _phase != Phase.IDLE or not body.is_on_floor():
		return
	_ground_y = body.global_position.y
	_used_this_jump = false


## Starts the suspension: only in the air, idle, once per jump.
func try_start() -> bool:
	if not is_enabled() or _phase != Phase.IDLE or _used_this_jump or body.is_on_floor():
		return false
	_used_this_jump = true
	_elapsed = 0.0
	_charge_ratio = 0.0
	body.velocity = Vector3(body.velocity.x, 0.0, body.velocity.z)
	sword_swing.hold_pose(_config.raise_position, _config.raise_rotation)
	_indicator.show_rect(_feet_on_ground(), visual.global_rotation.y, _config.hit_length, _config.hit_width)
	_phase = Phase.HOVER
	return true


## Ends the suspension: the charge freezes and the dive starts.
func release() -> void:
	if _phase != Phase.HOVER:
		return
	_charge_ratio = minf(_elapsed / _config.hover_duration, 1.0)
	_elapsed = 0.0
	sword_swing.swing_to(_config.slam_position, _config.slam_rotation, _config.slam_duration)
	_phase = Phase.DIVE


## Drops the slash without a hit (e.g. a boss grab); the player falls normally.
func cancel() -> void:
	if _phase == Phase.IDLE:
		return
	if _phase == Phase.HOVER:
		sword_swing.recover()
	_indicator.start_fade()
	_phase = Phase.IDLE


func is_active() -> bool:
	return _phase != Phase.IDLE


func controls_motion() -> bool:
	return is_active()


## Moves the player for this physics step according to the phase.
func move_body(delta: float, wish_direction: Vector3) -> void:
	match _phase:
		Phase.HOVER:
			_hover(delta, wish_direction)
		Phase.DIVE:
			_dive(delta)
		Phase.LANDING:
			_land(delta)


func get_phase() -> Phase:
	return _phase


## Charge in [0, 1]: live while hovering, frozen from the release.
func get_charge_ratio() -> float:
	if _phase == Phase.HOVER:
		return minf(_elapsed / _config.hover_duration, 1.0)
	return _charge_ratio


## Multiple of the basic attack damage at the current charge.
func get_damage_factor() -> float:
	return lerpf(_config.min_damage_factor, _config.max_damage_factor, get_charge_ratio())


func is_used_this_jump() -> bool:
	return _used_this_jump


func get_indicator() -> AbilityRectIndicator:
	return _indicator


func get_wind_cut() -> WindCutVfx:
	return _wind_cut


## The hit of the slash; `crit_roll` in [0, 1) is injected so tests are deterministic.
func strike_with_roll(crit_roll: float) -> void:
	var is_crit: bool = DamageMath.roll_crit(stats.get_stat(PlayerStats.Stat.CRIT_CHANCE), crit_roll)
	var damage: float = DamageMath.outgoing(
		stats.get_stat(PlayerStats.Stat.DAMAGE),
		stats.get_stat(PlayerStats.Stat.DAMAGE_BONUS),
		is_crit,
		stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE)) * get_damage_factor()
	_collect_hits()
	var total: float = 0.0
	for enemy: Enemy in _hit_buffer:
		total += _hit_enemy(enemy, damage, is_crit)
	health.heal(total * stats.get_stat(PlayerStats.Stat.LIFESTEAL))
	struck.emit(_hit_buffer.size(), total, is_crit)


## Suspended: slow, no gravity; the band follows the player. Releases itself
## after hover_duration.
func _hover(delta: float, wish_direction: Vector3) -> void:
	movement.hover_move(wish_direction, delta, _config.hover_move_speed_factor)
	_elapsed += delta
	_indicator.resize(_feet_on_ground(), visual.global_rotation.y, _config.hit_length, _config.hit_width)
	if _elapsed >= _config.hover_duration:
		release()


## Falls straight down; the slash lands on the floor (or after max_dive_duration).
func _dive(delta: float) -> void:
	body.velocity = Vector3(0.0, -_config.dive_speed, 0.0)
	body.move_and_slide()
	_elapsed += delta
	if body.is_on_floor() or _elapsed >= _config.max_dive_duration:
		_impact()


func _impact() -> void:
	body.velocity = Vector3.ZERO
	strike_with_roll(_rng.randf())
	_wind_cut.play(body.global_position, visual.global_rotation.y, _config.hit_length, _charge_ratio)
	camera.shake(_config.impact_shake)
	_indicator.start_fade()
	_elapsed = 0.0
	_phase = Phase.LANDING


func _land(delta: float) -> void:
	movement.hold(delta)
	_elapsed += delta
	if _elapsed >= _config.landing_lock:
		_phase = Phase.IDLE


func _collect_hits() -> void:
	_hit_buffer.clear()
	var origin: Vector3 = body.global_position
	var forward: Vector3 = -visual.global_basis.z
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	var half_width: float = _config.hit_width / 2.0
	for enemy: Enemy in registry.get_active():
		var padding: float = enemy.get_hit_padding()
		if HitboxMath.in_rectangle(origin, flat_forward, enemy.global_position, _config.hit_length + padding, half_width + padding):
			_hit_buffer.append(enemy)


## Applies the hit and pushes the enemy away from the player. Returns the damage applied.
func _hit_enemy(enemy: Enemy, damage: float, is_crit: bool) -> float:
	var applied: float = enemy.health.receive_hit(damage)
	enemy_hit.emit(enemy, applied, is_crit)
	enemy.apply_knockback(enemy.global_position - body.global_position, _config.knockback_speed)
	return applied


func _feet_on_ground() -> Vector3:
	var position: Vector3 = body.global_position
	return Vector3(position.x, _ground_y, position.z)
