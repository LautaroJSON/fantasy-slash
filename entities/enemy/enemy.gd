class_name Enemy
extends CharacterBody3D
## Enemy entity. Poolable: activate()/deactivate() replace instantiate()/queue_free().
## What it does each frame (chase, telegraphed attacks) is decided by its
## EnemyBehavior, instantiated from stats.behavior; while pushed it only slides
## and the behavior is paused (docs/specs/enemy-attack-telegraph.md).

signal killed(enemy: Enemy)
## A player hit landed (after health changed); the HUD boss bar shakes on it.
signal hit_notified(applied: float, is_crit: bool)
## A boss calls a batch of minions (docs/specs/boss-colmena.md); WaveManager spawns them.
signal summon_requested(enemy: Enemy, summon: SummonData)

@export var stats: EnemyStats
@export var target: Player
@export var registry: EnemyRegistry
## Attack tokens, places around the player and separation (docs/specs/enemy-group-ai.md).
## Without it the enemy attacks whenever it can, as in the unit tests.
@export var coordinator: AttackCoordinator
## Hand-placed enemies activate themselves on ready; pooled ones wait for activate().
@export var start_active: bool

## Level given by the wave on activation; hand-placed enemies are level 1.
var level: int = 1

## Own duplicate of `stats` (created once in _ready so the shared .tres is
## never mutated), rewritten with the level-scaled values on each activate().
var _scaled: EnemyStats
## Extra hit reach for bodies bigger than the base capsule, set once in _ready.
var _hit_padding: float = 0.0
## Collision radius of the target, added to the attack hitboxes (set on activate).
var _target_padding: float = 0.0
var _behavior: EnemyBehavior
var _knockback: Vector3 = Vector3.ZERO
## Gravity multiplier of the current jump (launch()); back to 1 on landing.
var _gravity_scale: float = 1.0
## Multiplies every windup (enemy-pace.md); 1 unless apply_pace() stretched it.
var _windup_scale: float = 1.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Spawn-in: seconds left and total (0 when not rising), with its depth and hole size.
var _spawn_left: float = 0.0
var _spawn_total: float = 0.0
var _spawn_depth: float = 0.0
var _spawn_marker_radius: float = 0.0
var _spawn_marker_grow: float = 0.0
## Rest heights of Body and Hands (set once by _apply_body_scale).
var _body_rest_y: float = 0.0
var _hands_rest_y: float = 0.0
## Rest X of Body and Hands, the axis the hit lag shakes (set once by _apply_body_scale).
var _body_rest_x: float = 0.0
var _hands_rest_x: float = 0.0
## Hit lag (docs/specs/bdo-combat-feel.md): seconds left frozen, and the shake.
var _hitlag_left: float = 0.0
## Seconds left of a world freeze (docs/specs/parry-riposte-rework.md §2.5).
var _time_freeze_left: float = 0.0
var _hitlag_shake: ShakeState = ShakeState.new()
var _hitlag_amplitude: float = 0.0
var _hitlag_frequency: float = 0.0
## Speed the behavior runs at this frame (SLOW statuses, docs/specs/affliction.md):
## its delta and the walking speed are scaled, gravity is not.
var _speed_scale: float = 1.0
## Time dilation (docs/specs/perfect-dodge.md): seconds left and the speed factor.
var _dilation_left: float = 0.0
var _dilation_scale: float = 1.0

@onready var health: HealthComponent = $HealthComponent
@onready var debuffs: DebuffComponent = $DebuffComponent
@onready var afflictions: AfflictionComponent = $AfflictionComponent
@onready var health_bar: EnemyHealthBar = $HealthBar
@onready var affliction_bars: AfflictionBarRow = $HealthBar/AfflictionBars
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _body: MeshInstance3D = $Body
@onready var _hands: EnemyHands = $Hands
@onready var _spawn_marker: MeshInstance3D = $SpawnMarker
@onready var _shockwaves: Array[MeshInstance3D] = [$Shockwave as MeshInstance3D, $Shockwave2 as MeshInstance3D, $Shockwave3 as MeshInstance3D]
@onready var _telegraph: GroundTelegraph = $GroundTelegraph


func _ready() -> void:
	_scaled = stats.duplicate() as EnemyStats
	if stats.hands_config != null:
		_hands.apply_config(stats.hands_config)
	_behavior = stats.behavior.instantiate() as EnemyBehavior
	_behavior.name = &"Behavior"
	add_child(_behavior)
	_behavior.setup(self)
	_telegraph.prepare_arcs(_behavior.get_telegraph_arcs())
	_apply_body_scale()
	health.died.connect(_on_died)
	if start_active:
		activate(global_position, target)
	else:
		deactivate()


func _physics_process(delta: float) -> void:
	_advance_time_dilation(delta)
	if _spawn_left > 0.0:
		_advance_spawn_in(delta)
		return
	if _advance_time_freeze(delta):
		return
	if _advance_hitlag(delta):
		return
	_update_behaviour(delta)


func activate(at: Vector3, new_target: Player, new_level: int = 1) -> void:
	global_position = at
	target = new_target
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_gravity_scale = 1.0
	_windup_scale = 1.0
	_speed_scale = 1.0
	_target_padding = _collision_radius(target)
	_behavior.reset()
	_hands.reset()
	_end_spawn_in()
	_end_hitlag()
	_time_freeze_left = 0.0
	_dilation_left = 0.0
	_telegraph.clear()
	for ring: MeshInstance3D in _shockwaves:
		ring.visible = false
	if coordinator != null:
		coordinator.forget(self)
	level = new_level
	stats.write_scaled(level, _scaled)
	health.setup(_scaled.max_health, _scaled.defense)
	debuffs.clear()
	afflictions.setup(_scaled)
	affliction_bars.bind(null if target == null else target.afflictions)
	health_bar.reset()
	health_bar.set_level(level)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_collision.set_deferred(&"disabled", false)
	if registry != null:
		registry.register(self)
	_behavior.state_restored()


## Pace of the run (docs/specs/enemy-pace.md, enemy-level-pace.md): stretches the
## windups and the pause between attacks for this enemy's level and
## `rage_level`. Call after activate() and enrage().
func apply_pace(config: EnemyPaceConfig, rage_level: int) -> void:
	_windup_scale = config.windup_scale_for(level, rage_level)
	_scaled.attack_interval *= config.interval_scale_for(level, rage_level)


func get_windup_scale() -> float:
	return _windup_scale


## `seconds` of a windup at the pace of this enemy.
func windup(seconds: float) -> float:
	return seconds * _windup_scale


## Rage (docs/specs/enemy-rage.md): grows the level-scaled stats, restarts
## the health at the new maximum and lists the buff. Call after activate().
func enrage(config: RageConfig, rage_level: int) -> void:
	if rage_level <= 0:
		return
	config.write_raged(rage_level, _scaled)
	health.setup(_scaled.max_health, _scaled.defense)
	debuffs.apply(config.status, rage_level)
	_behavior.state_restored()


func deactivate() -> void:
	_behavior.deactivated()
	_telegraph.clear()
	if coordinator != null:
		coordinator.forget(self)
	if registry != null:
		registry.unregister(self)
	debuffs.clear()
	afflictions.clear()
	_end_hitlag()
	_time_freeze_left = 0.0
	_dilation_left = 0.0
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_collision.set_deferred(&"disabled", true)


## Pushes the enemy horizontally; it decelerates with its knockback_friction.
func apply_knockback(direction: Vector3, speed: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.is_zero_approx() or _behavior.resists_knockback(flat.normalized()):
		return
	_knockback = flat.normalized() * speed
	_behavior.knocked_back()


func is_knocked_back() -> bool:
	return not _knockback.is_zero_approx()


## Stuns for `seconds` × stats.stun_duration_scale (docs/specs/warrior-abilities-rework.md):
## it stands still (a push it had keeps sliding it). An enemy that does not
## resist control also cancels the attack it was preparing; a boss's behavior
## only pauses. Ignored when dead, inactive, rising or immune (scale 0).
func stun(status: DebuffData, seconds: float) -> void:
	var scaled: float = seconds * stats.stun_duration_scale
	if scaled <= 0.0 or health.is_dead() or _spawn_left > 0.0 or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	debuffs.apply(status, 1.0, scaled)
	if not stats.resists_control:
		_behavior.stunned()


func is_stunned() -> bool:
	return debuffs.is_stunned()


## Speed of the current push (0 when not pushed); a pushed enemy that stops
## against a wall or another enemy is what the Shield Charge stuns.
func get_push_speed() -> float:
	return _knockback.length()


## Current push velocity (read-only; decays with knockback_friction).
func get_knockback_velocity() -> Vector3:
	return _knockback


## Stats in effect for the current level. Read-only for callers.
func get_scaled_stats() -> EnemyStats:
	return _scaled


func get_body_scale() -> float:
	return stats.body_scale


## Extra reach added to the player's hitboxes so a big body is hit where it
## is, not only at its centre: base capsule radius × (body_scale − 1).
func get_hit_padding() -> float:
	return _hit_padding


func get_behavior() -> EnemyBehavior:
	return _behavior


func get_hands() -> EnemyHands:
	return _hands


## Collision radius of the current target, added to attack hitboxes.
func get_target_padding() -> float:
	return _target_padding


## Flat direction the enemy faces (−Z of its basis).
func get_facing() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))


## Walks at move_speed along a flat, normalized `direction` and faces it.
func move_towards(direction: Vector3, delta: float) -> void:
	walk(direction, delta)
	face(direction)


## Walks at move_speed along `direction` without turning. With a coordinator
## the walk also pushes away from nearby enemies.
func walk(direction: Vector3, delta: float) -> void:
	var heading: Vector3 = direction
	if coordinator != null:
		heading = (direction + coordinator.separation_for(self)).limit_length(1.0)
	velocity.x = heading.x * _scaled.move_speed * _speed_scale
	velocity.z = heading.z * _scaled.move_speed * _speed_scale
	_apply_gravity(_unscaled(delta))
	move_and_slide()


## True when the enemy takes part in the attack turns (it has a coordinator
## and its type does not ignore them, as bosses do).
func uses_attack_tokens() -> bool:
	return coordinator != null and not stats.ignores_attack_tokens


## Whether an attack may start now: asks the coordinator for a token (and
## queues otherwise). Always true outside the attack turns.
func can_start_attack() -> bool:
	if not uses_attack_tokens():
		return true
	return coordinator.request_token(self)


## The windup started: the token is being used.
func begin_attack() -> void:
	if uses_attack_tokens():
		coordinator.mark_started(self)


## The attack ended or was cancelled: the token goes back.
func end_attack() -> void:
	if uses_attack_tokens():
		coordinator.release_token(self)


## Comes out of the floor over config.spawn_in_time: the behavior waits, the
## hole grows and Body and Hands rise from config.spawn_depth.
func begin_spawn_in(config: GroupAIConfig) -> void:
	_spawn_total = config.spawn_in_time
	_spawn_left = config.spawn_in_time
	_spawn_depth = config.spawn_depth * stats.body_scale
	_spawn_marker_radius = config.spawn_marker_radius * stats.body_scale
	_spawn_marker_grow = config.spawn_marker_grow_time
	if _spawn_total <= 0.0:
		_end_spawn_in()
		return
	_spawn_marker.visible = true
	_pose_spawn_in(0.0)


func is_spawning_in() -> bool:
	return _spawn_left > 0.0


func get_body() -> MeshInstance3D:
	return _body


## Floor rings of a boss slam (docs/specs/boss-verdugo.md), placed in world space.
func get_shockwave(index: int) -> MeshInstance3D:
	return _shockwaves[index]


## Warning of the attack being prepared, on the floor (enemy-ground-telegraph.md).
func get_telegraph() -> GroundTelegraph:
	return _telegraph


func get_shockwave_count() -> int:
	return _shockwaves.size()


func get_spawn_marker() -> MeshInstance3D:
	return _spawn_marker


## Height of the body's rest position (the spawn-in rises to it).
func get_body_rest_height() -> float:
	return _body_rest_y


func _advance_spawn_in(delta: float) -> void:
	stand_still(delta)
	_spawn_left = maxf(_spawn_left - delta, 0.0)
	if _spawn_left <= 0.0:
		_end_spawn_in()
	else:
		_pose_spawn_in(1.0 - _spawn_left / _spawn_total)


## `progress` 0 → 1: the body rises with an ease-out; the hole reaches its
## full size in spawn_marker_grow_time.
func _pose_spawn_in(progress: float) -> void:
	var rise: float = 1.0 - pow(1.0 - progress, 2.0)
	var offset: float = -_spawn_depth * (1.0 - rise)
	_body.position.y = _body_rest_y + offset
	_hands.position.y = _hands_rest_y + offset
	var elapsed: float = progress * _spawn_total
	var grown: float = clampf(elapsed / _spawn_marker_grow, 0.0, 1.0) if _spawn_marker_grow > 0.0 else 1.0
	var radius: float = maxf(_spawn_marker_radius * grown, 0.001)
	_spawn_marker.scale = Vector3(radius, 1.0, radius)


func _end_spawn_in() -> void:
	_spawn_left = 0.0
	_body.position.y = _body_rest_y
	_hands.position.y = _hands_rest_y
	_spawn_marker.visible = false


## Moves with a given flat velocity (charges, lunges, jumps), without facing it.
func move_with_velocity(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x * _speed_scale
	velocity.z = horizontal.z * _speed_scale
	_apply_gravity(_unscaled(delta))
	move_and_slide()


## Starts a jump: upward speed and a gravity multiplier kept until it lands.
func launch(vertical_speed: float, gravity_scale: float) -> void:
	velocity.y = vertical_speed
	_gravity_scale = gravity_scale


func is_airborne() -> bool:
	return not is_on_floor()


## True when the last move ran into a wall.
func hit_wall() -> bool:
	return is_on_wall()


func get_gravity_strength() -> float:
	return _gravity


func stand_still(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(_unscaled(delta))
	move_and_slide()


func face(direction: Vector3) -> void:
	if direction.is_zero_approx():
		return
	rotation.y = atan2(-direction.x, -direction.z)


## Turns towards `direction` by at most `max_angle` radians.
func turn_towards(direction: Vector3, max_angle: float) -> void:
	if direction.is_zero_approx():
		return
	rotation.y = rotate_toward(rotation.y, atan2(-direction.x, -direction.z), max_angle)


## Scales the body, its collision and the hands (never the CharacterBody3D
## itself) and lifts the health bar to match. Runs once per instance.
func _apply_body_scale() -> void:
	var body_scale: float = stats.body_scale
	_body.scale = Vector3.ONE * body_scale
	_body.position.y *= body_scale
	_hands.scale = Vector3.ONE * body_scale
	_body_rest_y = _body.position.y
	_hands_rest_y = _hands.position.y
	_body_rest_x = _body.position.x
	_hands_rest_x = _hands.position.x
	_collision.scale = Vector3.ONE * body_scale
	_collision.position.y *= body_scale
	var capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D
	_hit_padding = capsule.radius * (body_scale - 1.0)
	health_bar.apply_body(body_scale, stats.health_bar_scale)
	health_bar.set_suppressed(stats.hud_health_bar)


func _update_behaviour(delta: float) -> void:
	var dilation: float = get_time_dilation()
	if is_knocked_back():
		_slide_back(delta, dilation)
		return
	_speed_scale = debuffs.get_speed_scale() * dilation
	if _speed_scale <= 0.0:
		stand_still(delta)
		return
	_behavior.physics_update(delta * _speed_scale)


func get_speed_scale() -> float:
	return _speed_scale


## Real frame time from a behavior's (slowed) delta, so gravity never slows down.
func _unscaled(delta: float) -> float:
	return delta / _speed_scale if _speed_scale > 0.0 else delta


## While pushed the enemy only slides; its behavior (and its timers) is paused.
## The push slides at `dilation` of its speed (gravity keeps the real delta).
func _slide_back(delta: float, dilation: float = 1.0) -> void:
	velocity.x = _knockback.x * dilation
	velocity.z = _knockback.z * dilation
	_apply_gravity(delta)
	move_and_slide()
	_knockback = _knockback.move_toward(Vector3.ZERO, _scaled.knockback_friction * delta * dilation)


func _apply_gravity(delta: float) -> void:
	# A launch leaves the floor with an upward speed, so only a grounded body
	# that is not rising stops falling.
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
		_gravity_scale = 1.0
	else:
		velocity.y -= _gravity * _gravity_scale * delta


func _collision_radius(body: Node3D) -> float:
	if body == null:
		return 0.0
	var shape: CollisionShape3D = body.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape == null or not shape.shape is CapsuleShape3D:
		return 0.0
	return (shape.shape as CapsuleShape3D).radius


func _on_died() -> void:
	killed.emit(self)
	deactivate()


## Called for every player hit (EnemyHitFeedback): shakes the floating bar
## and lets the HUD boss bar react too.
func notify_hit(applied: float, is_crit: bool) -> void:
	health_bar.notify_hit(applied, is_crit)
	hit_notified.emit(applied, is_crit)


## Hit lag of a player strike (docs/specs/bdo-combat-feel.md): for `duration`
## seconds the body shakes sideways and, unless stats.resists_hitlag, the
## enemy freezes (behavior and push paused; a push already given starts after).
## Restarts, never adds up. Ignored while rising from the floor.
func apply_hitlag(duration: float, config: HitstopConfig) -> void:
	if duration <= 0.0 or _spawn_left > 0.0:
		return
	_hitlag_left = duration
	_hitlag_amplitude = config.enemy_shake_amplitude
	_hitlag_frequency = config.enemy_shake_frequency
	_hitlag_shake.start(duration)


func is_in_hitlag() -> bool:
	return _hitlag_left > 0.0


## Advances the hit lag; true when the enemy is frozen this frame.
func _advance_hitlag(delta: float) -> bool:
	if not is_in_hitlag():
		return false
	_hitlag_left -= delta
	_set_hitlag_offset(_hitlag_shake.advance(delta, _hitlag_frequency) * _hitlag_amplitude)
	if _hitlag_left <= 0.0:
		_end_hitlag()
	return not stats.resists_hitlag


## Freezes the enemy for `seconds` (behavior, push and attack timers paused),
## bosses too and without shaking: the world freeze of a finisher
## (docs/specs/parry-riposte-rework.md §2.5). Restarts, never adds up.
func freeze_time(seconds: float) -> void:
	if seconds <= 0.0 or _spawn_left > 0.0:
		return
	_time_freeze_left = seconds


func is_time_frozen() -> bool:
	return _time_freeze_left > 0.0


## Slows the enemy to `scale` of its speed for `seconds` of real time: its
## behavior, walking, push and attack timers (docs/specs/perfect-dodge.md).
## Multiplies with the slow of debuffs; a freeze, hit lag or spawn-in wins over
## it. Restarts, never adds up. Gravity is not scaled.
func dilate_time(scale: float, seconds: float) -> void:
	if seconds <= 0.0:
		return
	_dilation_scale = clampf(scale, 0.0, 1.0)
	_dilation_left = seconds


func is_time_dilated() -> bool:
	return _dilation_left > 0.0


## Speed factor of the time dilation; 1 when none runs.
func get_time_dilation() -> float:
	return _dilation_scale if _dilation_left > 0.0 else 1.0


func _advance_time_dilation(delta: float) -> void:
	if _dilation_left > 0.0:
		_dilation_left = maxf(_dilation_left - delta, 0.0)


## Counts down the world freeze; true while the enemy is frozen this frame.
func _advance_time_freeze(delta: float) -> bool:
	if not is_time_frozen():
		return false
	_time_freeze_left = maxf(_time_freeze_left - delta, 0.0)
	return true


func _end_hitlag() -> void:
	_hitlag_left = 0.0
	_hitlag_shake.stop()
	_set_hitlag_offset(0.0)


func _set_hitlag_offset(offset: float) -> void:
	_body.position.x = _body_rest_x + offset
	_hands.position.x = _hands_rest_x + offset
