class_name AttackCoordinator
extends Node
## Group behaviour of the regular enemies (docs/specs/enemy-group-ai.md):
## - Attack tokens: at most max_attackers_for(level, rage level) enemies may attack at once,
##   grants are token_gap apart and go first-come first-served. A request not
##   renewed for a couple of frames leaves the queue; a token not used to start
##   a windup within token_approach_timeout is taken back. A token given back
##   after an attack that started rests for rest_for(level, rage) before it can
##   be granted again (docs/specs/enemy-level-pace.md).
## - Places (slots) around the player for the melee enemies.
## - Separation push between walking enemies.

## Physics frames a request may go unrenewed before it leaves the queue.
const STALE_REQUEST_FRAMES: int = 2

@export var config: GroupAIConfig
@export var registry: EnemyRegistry
## Optional: its Rage level sets max_attackers; no Rage when empty.
@export var run_state: RunState
## Centre of the ring of places.
@export var player: Node3D

var _holders: Array[Enemy] = []
## Seconds each holder has held its token without starting a windup (−1 once started).
var _holder_idle: Array[float] = []
var _queue: Array[Enemy] = []
## Physics frame of each queued enemy's last request.
var _queue_frame: Array[int] = []
var _gap_left: float = 0.0
## Seconds left of each resting token (they count as taken).
var _resting: Array[float] = []
## Enemy holding each place, or null.
var _slot_owner: Array[Enemy] = []


func _ready() -> void:
	_slot_owner.resize(config.slot_count)
	_slot_owner.fill(null)


func _physics_process(delta: float) -> void:
	advance(delta)


## Simultaneous attackers allowed to enemies of `level` (they share the wave's level).
func get_max_attackers(level: int) -> int:
	return config.max_attackers_for(level, _rage_level())


func _rage_level() -> int:
	return run_state.get_rage_level() if run_state != null else 0


## True if `enemy` holds a token or gets one now; otherwise it is queued.
func request_token(enemy: Enemy) -> bool:
	if _holders.has(enemy):
		return true
	var frame: int = Engine.get_physics_frames()
	var index: int = _queue.find(enemy)
	if index < 0:
		_queue.append(enemy)
		_queue_frame.append(frame)
		index = _queue.size() - 1
	else:
		_queue_frame[index] = frame
	if index != 0 or _gap_left > 0.0 or _holders.size() + _resting.size() >= get_max_attackers(enemy.level):
		return false
	_queue.remove_at(0)
	_queue_frame.remove_at(0)
	_holders.append(enemy)
	_holder_idle.append(0.0)
	_gap_left = config.token_gap
	return true


func has_token(enemy: Enemy) -> bool:
	return _holders.has(enemy)


func get_holder_count() -> int:
	return _holders.size()


## Position of `enemy` in the queue (−1 when not queued).
func get_queue_index(enemy: Enemy) -> int:
	return _queue.find(enemy)


## The holder started its windup: the approach timeout no longer applies.
func mark_started(enemy: Enemy) -> void:
	var index: int = _holders.find(enemy)
	if index >= 0:
		_holder_idle[index] = -1.0


## Gives the token back. After an attack that started it rests first; a token
## never used (cancelled, lost, never started) is free at once.
func release_token(enemy: Enemy) -> void:
	var index: int = _holders.find(enemy)
	if index < 0:
		return
	if _holder_idle[index] < 0.0:
		_resting.append(config.rest_for(enemy.level, _rage_level()))
	_holders.remove_at(index)
	_holder_idle.remove_at(index)


func get_resting_count() -> int:
	return _resting.size()


func withdraw(enemy: Enemy) -> void:
	var index: int = _queue.find(enemy)
	if index >= 0:
		_queue.remove_at(index)
		_queue_frame.remove_at(index)


## Drops everything `enemy` holds (death, deactivation).
func forget(enemy: Enemy) -> void:
	release_token(enemy)
	withdraw(enemy)
	free_slot(enemy)


func advance(delta: float) -> void:
	_gap_left = maxf(_gap_left - delta, 0.0)
	for i: int in range(_resting.size() - 1, -1, -1):
		_resting[i] -= delta
		if _resting[i] <= 0.0:
			_resting.remove_at(i)
	for i: int in range(_holders.size() - 1, -1, -1):
		if _holder_idle[i] < 0.0:
			continue
		_holder_idle[i] += delta
		if _holder_idle[i] >= config.token_approach_timeout:
			_holders.remove_at(i)
			_holder_idle.remove_at(i)
	var frame: int = Engine.get_physics_frames()
	for i: int in range(_queue.size() - 1, -1, -1):
		if frame - _queue_frame[i] > STALE_REQUEST_FRAMES:
			_queue.remove_at(i)
			_queue_frame.remove_at(i)


## Frees the place of `enemy` and takes the free place nearest to its current
## bearing around the player. Returns its index, or −1 when all are taken.
func claim_slot(enemy: Enemy) -> int:
	free_slot(enemy)
	var offset: Vector3 = enemy.global_position - player.global_position
	var bearing: float = atan2(offset.x, offset.z)
	var best: int = -1
	var best_gap: float = INF
	for i: int in _slot_owner.size():
		if _slot_owner[i] != null:
			continue
		var gap: float = absf(angle_difference(bearing, TAU * float(i) / float(config.slot_count)))
		if gap < best_gap:
			best_gap = gap
			best = i
	if best >= 0:
		_slot_owner[best] = enemy
	return best


func free_slot(enemy: Enemy) -> void:
	var index: int = _slot_owner.find(enemy)
	if index >= 0:
		_slot_owner[index] = null


func get_slot(enemy: Enemy) -> int:
	return _slot_owner.find(enemy)


func slot_position(index: int, radius: float) -> Vector3:
	return player.global_position + config.slot_direction(index) * radius


## Distance at which a melee enemy without a token waits.
func get_wait_distance(attack_range: float) -> float:
	return attack_range + config.wait_margin


## Flat push away from the enemies closer than separation_radius (scaled by
## the bigger of the two bodies), weighted by separation_weight.
func separation_for(enemy: Enemy) -> Vector3:
	var push := Vector3.ZERO
	for other: Enemy in registry.get_active():
		if other == enemy:
			continue
		var radius: float = config.separation_radius * maxf(enemy.get_body_scale(), other.get_body_scale())
		var away := Vector3(enemy.global_position.x - other.global_position.x, 0.0, enemy.global_position.z - other.global_position.z)
		var distance: float = away.length()
		if distance >= radius:
			continue
		var direction: Vector3 = away / distance if distance > 0.001 else Vector3.ZERO
		if direction == Vector3.ZERO:
			# Same spot: push along an arbitrary but stable axis.
			direction = Vector3.RIGHT if enemy.get_instance_id() > other.get_instance_id() else Vector3.LEFT
		push += direction * (1.0 - distance / radius)
	return push * config.separation_weight
