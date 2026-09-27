class_name ShieldChargeAbility
extends AbilityBehavior
## The Warrior's Shield Charge (docs/specs/warrior-abilities-rework.md §3.1, §5.1).
## TRAVEL: the player turns to the nearest enemy and covers HIT_RANGE in
## travel_time with the shield raised (guard_reduction of the frontal damage),
## dragging the enemies the front of the shield touches. A frontal hit absorbed
## while charging empowers the bash. BASH (at the end of the travel, or on a
## wall, or on an enemy that cannot be dragged): every enemy in bash_range ×
## HIT_WIDTH takes hit_damage() (× absorb_damage_multiplier and stunned when
## empowered) and is pushed. For impact_window seconds after the bash, a pushed
## enemy that hits a wall is stunned, and one that hits another enemy stuns
## both. RECOVERY: the player stands still until the cast ends.

enum Phase {
	IDLE,
	TRAVEL,
	RECOVERY,
}

const HAMMER_ANVIL: StringName = &"hammer_anvil"
const MOMENTUM: StringName = &"momentum"
const CONCUSSIVE: StringName = &"concussive"

@export var config: ShieldChargeConfig

var _phase: Phase = Phase.IDLE
var _ability: AbilityComponent = null
var _elapsed: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _absorbed: bool = false
## A travel step ran into a wall or an enemy that cannot be dragged.
var _stalled: bool = false
## Reused buffers (Principle V).
var _dragged: Array[Enemy] = []
var _hit_buffer: Array[Enemy] = []
var _watched: Array[Enemy] = []
var _pair: Array[Enemy] = []
var _watch_left: float = 0.0

@onready var _indicator: AbilityRectIndicator = $Indicator
@onready var _bash_vfx: ShieldBashVfx = $BashVfx
@onready var _block_vfx: BlockSparkVfx = $BlockVfx


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_watch_collisions(delta)


func begin(ability: AbilityComponent) -> void:
	_ability = ability
	_phase = Phase.TRAVEL
	_elapsed = 0.0
	_absorbed = false
	_stalled = false
	_dragged.clear()
	face_nearest_enemy(ability)
	var forward: Vector3 = -ability.visual.global_basis.z
	_direction = Vector3(forward.x, 0.0, forward.z).normalized()
	show_indicator(ability, _indicator)
	ability.guard.raise(config.guard_reduction, config.guard_arc_degrees)
	_connect_guard(ability)
	_bash_vfx.begin_dust(ability.visual)


func channel(ability: AbilityComponent, step: float) -> void:
	_elapsed += step
	if _phase == Phase.TRAVEL and (_stalled or _elapsed >= config.travel_time - AbilityComponent.TIME_EPSILON):
		_bash(ability)


func release(ability: AbilityComponent) -> void:
	if _phase == Phase.TRAVEL:
		_bash(ability)
	_phase = Phase.IDLE


## A dash (or a hold) cuts the charge: the shield lowers and the dragged enemies
## are let go. Enemies already pushed by the bash are still watched.
func cancel_cast(ability: AbilityComponent) -> void:
	if _phase == Phase.TRAVEL:
		_end_travel(ability)
		_indicator.start_fade()
	_phase = Phase.IDLE


func controls_motion() -> bool:
	return _phase == Phase.TRAVEL


## Charges straight ahead at HIT_RANGE / travel_time, dragging what the shield touches.
func move_body(ability: AbilityComponent, delta: float, _wish_direction: Vector3) -> void:
	var speed: float = ability.get_stat(AbilityData.Stat.HIT_RANGE) / config.travel_time
	var before: Vector3 = ability.body.global_position
	ability.movement.drive(_direction * speed, delta)
	var moved: Vector3 = ability.body.global_position - before
	if Vector2(moved.x, moved.z).length() < speed * delta * config.stall_ratio:
		_stalled = true
	_drag(ability, speed)


func get_body_clip(_ability: AbilityComponent) -> StringName:
	return config.charge_body_clip if _phase == Phase.TRAVEL else config.bash_body_clip


## The shield strikes, the sword stays in the right hand.
func holds_weapon_in_hand(_ability: AbilityComponent) -> bool:
	return true


## It strikes with the shield: no weapon trail.
func trails_while_casting(_ability: AbilityComponent) -> bool:
	return false


func get_phase() -> Phase:
	return _phase


func is_absorbed() -> bool:
	return _absorbed


func get_dragged() -> Array[Enemy]:
	return _dragged


func get_watched() -> Array[Enemy]:
	return _watched


func get_indicator() -> AbilityRectIndicator:
	return _indicator


func get_bash_vfx() -> ShieldBashVfx:
	return _bash_vfx


func get_block_vfx() -> BlockSparkVfx:
	return _block_vfx


## Seconds of every stun of the charge: "Contundencia" or stun_duration.
func stun_seconds(ability: AbilityComponent) -> float:
	if ability.has_unique(CONCUSSIVE):
		return ability.get_unique_value(CONCUSSIVE)
	return config.stun_duration


## Index in `others` of the nearest enemy (other than `self_index`) right
## ahead of `position` along `push_direction`, within contact_distance plus
## both hit paddings; −1 when there is none (the push hit a wall).
static func find_contact(position: Vector3, push_direction: Vector3, others: Array[Enemy], self_index: int, contact_distance: float) -> int:
	var flat := Vector3(push_direction.x, 0.0, push_direction.z)
	if flat.is_zero_approx():
		return -1
	flat = flat.normalized()
	var own_padding: float = others[self_index].get_hit_padding() if self_index >= 0 and self_index < others.size() else 0.0
	var best: int = -1
	var best_distance: float = INF
	for i: int in others.size():
		if i == self_index:
			continue
		var offset: Vector3 = others[i].global_position - position
		offset.y = 0.0
		if offset.dot(flat) <= 0.0:
			continue
		var distance: float = offset.length()
		if distance <= contact_distance + own_padding + others[i].get_hit_padding() and distance < best_distance:
			best = i
			best_distance = distance
	return best


## The dragged enemies are those in the strip this step: one that drifts ahead
## of it slows down with its friction until the shield catches it again.
func _drag(ability: AbilityComponent, speed: float) -> void:
	var origin: Vector3 = ability.visual.global_position
	var flat_forward := Vector2(_direction.x, _direction.z)
	var half_width: float = ability.get_stat(AbilityData.Stat.HIT_WIDTH) / 2.0
	_dragged.clear()
	for enemy: Enemy in ability.registry.get_active():
		if not is_instance_valid(enemy) or enemy.is_stunned():
			continue
		var padding: float = enemy.get_hit_padding()
		if not HitboxMath.in_rectangle(origin, flat_forward, enemy.global_position, config.capture_depth + padding, half_width + padding):
			continue
		if _resists_drag(enemy):
			_stalled = true
			continue
		_dragged.append(enemy)
		if not _watched.has(enemy):
			_watched.append(enemy)
	for enemy: Enemy in _dragged:
		enemy.apply_knockback(_direction, speed * config.drag_speed_factor)
	if not _dragged.is_empty():
		_watch_left = maxf(_watch_left, config.impact_window)
		set_physics_process(true)


func _resists_drag(enemy: Enemy) -> bool:
	return enemy.stats.resists_control or enemy.get_behavior().resists_knockback(_direction)


func _bash(ability: AbilityComponent) -> void:
	_end_travel(ability)
	_phase = Phase.RECOVERY
	ability.set_cast_remaining(ability.get_stat(AbilityData.Stat.CAST_DURATION) - maxf(_elapsed, config.travel_time))
	_collect_bash(ability)
	var damage: float = hit_damage(ability)
	if _absorbed:
		damage *= config.absorb_damage_multiplier
	var stun_time: float = stun_seconds(ability)
	for enemy: Enemy in _hit_buffer:
		var applied: float = enemy.health.receive_hit(damage)
		ability.report_hit(enemy, applied)
		if enemy.health.is_dead():
			continue
		enemy.apply_knockback(enemy.global_position - ability.visual.global_position, config.bash_knockback_speed)
		if _absorbed:
			enemy.stun(config.stun, stun_time)
		if not _watched.has(enemy):
			_watched.append(enemy)
	if not _hit_buffer.is_empty():
		ability.report_strike(config.empowered_feel if _absorbed else config.bash_feel, _hit_buffer)
	_bash_vfx.play_ring(ability.visual, config.empowered_ring_scale if _absorbed else 1.0)
	_indicator.start_fade()
	if ability.has_unique(MOMENTUM) and _hit_buffer.size() >= config.momentum_min_hits:
		ability.reduce_cooldown(ability.get_cooldown_remaining() * (1.0 - ability.get_unique_value(MOMENTUM)))
	_watch_left = config.impact_window
	set_physics_process(not _watched.is_empty())


func _collect_bash(ability: AbilityComponent) -> void:
	_hit_buffer.clear()
	var origin: Vector3 = ability.visual.global_position
	var flat_forward := Vector2(_direction.x, _direction.z)
	var half_width: float = ability.get_stat(AbilityData.Stat.HIT_WIDTH) / 2.0
	for enemy: Enemy in ability.registry.get_active():
		var padding: float = enemy.get_hit_padding()
		if HitboxMath.in_rectangle(origin, flat_forward, enemy.global_position, config.bash_range + padding, half_width + padding):
			_hit_buffer.append(enemy)


func _end_travel(ability: AbilityComponent) -> void:
	ability.guard.lower()
	_disconnect_guard(ability)
	_dragged.clear()
	_bash_vfx.finish_dust()


## Pushed enemies stopping against a wall or another enemy are stunned once.
func _watch_collisions(delta: float) -> void:
	if _ability == null or _watched.is_empty():
		set_physics_process(false)
		return
	var active: Array[Enemy] = _ability.registry.get_active()
	for i: int in range(_watched.size() - 1, -1, -1):
		if i >= _watched.size():
			continue
		var enemy: Enemy = _watched[i]
		if not is_instance_valid(enemy):
			_watched.remove_at(i)
			continue
		var index: int = active.find(enemy)
		if index < 0:
			_watched.remove_at(i)
			continue
		if not enemy.hit_wall() or enemy.get_push_speed() <= config.impact_min_speed:
			continue
		_collide(enemy, active, index)
	if _phase != Phase.TRAVEL:
		_watch_left -= delta
		if _watch_left <= 0.0:
			_watched.clear()
	if _watched.is_empty():
		set_physics_process(false)


func _collide(enemy: Enemy, active: Array[Enemy], index: int) -> void:
	var stun_time: float = stun_seconds(_ability)
	var contact: int = find_contact(enemy.global_position, enemy.get_knockback_velocity(), active, index, config.contact_distance)
	_watched.erase(enemy)
	_dragged.erase(enemy)
	enemy.stun(config.stun, stun_time)
	if contact < 0:
		return
	var other: Enemy = active[contact]
	_watched.erase(other)
	_dragged.erase(other)
	other.stun(config.stun, stun_time)
	if not _ability.has_unique(HAMMER_ANVIL):
		return
	var damage: float = hit_damage(_ability) * _ability.get_unique_value(HAMMER_ANVIL)
	_pair.clear()
	_pair.append(enemy)
	_pair.append(other)
	for hit: Enemy in _pair:
		_ability.report_hit(hit, hit.health.receive_hit(damage))
	_ability.report_strike(config.impact_feel, _pair)


func _connect_guard(ability: AbilityComponent) -> void:
	if not ability.guard.blocked.is_connected(_on_blocked):
		ability.guard.blocked.connect(_on_blocked)


func _disconnect_guard(ability: AbilityComponent) -> void:
	if ability.guard.blocked.is_connected(_on_blocked):
		ability.guard.blocked.disconnect(_on_blocked)


func _on_blocked(_amount: float, attacker: Enemy) -> void:
	if _phase != Phase.TRAVEL or _ability == null:
		return
	_absorbed = true
	_block_vfx.play(_ability.visual, attacker.global_position, 1.0)
	_ability.report_strike(config.absorb_feel, _no_enemies())


## An empty strike (only the camera shakes): the absorb hits nobody.
func _no_enemies() -> Array[Enemy]:
	_pair.clear()
	return _pair
