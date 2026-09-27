class_name DebuffComponent
extends Node
## Active status effects of an entity (debuffs and buffs), kept as a list so several kinds
## can coexist. Re-applying a debuff with the same id keeps the stronger
## potency and follows its StackMode (docs/specs/affliction.md):
## INTENSITY adds a stack up to DebuffData.max_stacks and restarts the duration;
## QUEUE queues a stack (each one a full instance that starts when the previous
## one ends) or, with the queue full, restarts the running instance.
## Strength = potency x stacks for INTENSITY, potency for QUEUE.
## DAMAGE_OVER_TIME: each tick removes strength x max health (or strength with
## DamageScaling.FLAT), ignoring defense.
## ARMOR_REDUCTION: the health ignores strength of its defense.
## SLOW: the owner acts at get_speed_scale() (1 - the strongest slow).
## STUN: get_speed_scale() is 0 while it lasts (the owner stands still).
## STAT_BOOST: a buff whose stats the owner applies; only listed here.
## Permanent statuses never expire and do not keep the component processing.

## A tick removed health. `target` is the owner, for listeners of many entities;
## `data` is the status that ticked (e.g. its damage number color).
signal ticked(target: Node3D, amount: float, data: DebuffData)
## A debuff was added, stacked, expired or cleared.
signal changed


class ActiveDebuff:
	var data: DebuffData
	## Fraction of max health (or health points, FLAT) removed per tick,
	## fraction of defense ignored or of speed lost, per stack.
	var potency: float
	var stacks: int
	var ticks_left: int
	var tick_left: float
	## Seconds left (ARMOR_REDUCTION; damage debuffs expire by ticks).
	var time_left: float
	## Seconds it was applied with: DebuffData.duration, or the one passed to
	## apply() (e.g. a stun); the clock of its icon is relative to it.
	var duration: float


@export var health: HealthComponent
## Entity that owns the debuffs (reported in `ticked`).
@export var target: Node3D

var _active: Array[ActiveDebuff] = []
## Bumped every time `changed` is emitted, so per-frame readers (the enemy
## status overlay) can tell the list changed without connecting to the signal.
var revision: int = 0
## Cached 1 - strongest SLOW, rewritten whenever the list or a strength changes.
var _speed_scale: float = 1.0


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	advance(delta)


## `duration` > 0 replaces DebuffData.duration for a timed status (e.g. a stun
## whose length comes from whoever applies it); re-applying one keeps the
## longer of what was left and the new duration.
func apply(data: DebuffData, potency: float, duration: float = 0.0) -> void:
	var existing: ActiveDebuff = _find(data.id)
	if existing != null:
		var left: float = existing.time_left
		if duration > 0.0:
			existing.duration = duration
		_refresh(existing, potency)
		if duration > 0.0 and _is_timed(existing):
			existing.time_left = maxf(left, duration)
			existing.duration = maxf(existing.duration, existing.time_left)
		_emit_changed()
		return
	var debuff := ActiveDebuff.new()
	debuff.data = data
	debuff.potency = potency
	debuff.stacks = 1
	debuff.duration = duration if duration > 0.0 else data.duration
	debuff.ticks_left = _tick_count(data)
	debuff.tick_left = data.tick_interval
	debuff.time_left = debuff.duration
	_active.append(debuff)
	set_physics_process(_has_expiring())
	_on_list_changed()


## Removes one status (e.g. a boss shield dropping); nothing if it is not active.
func remove(id: StringName) -> void:
	var debuff: ActiveDebuff = _find(id)
	if debuff == null:
		return
	_active.erase(debuff)
	_on_list_shrunk()


func clear() -> void:
	if _active.is_empty():
		return
	_active.clear()
	set_physics_process(false)
	_on_list_changed()


## Iterates backwards so expired debuffs can be removed in place.
func advance(delta: float) -> void:
	var removed: bool = false
	for i: int in range(_active.size() - 1, -1, -1):
		var debuff: ActiveDebuff = _active[i]
		if debuff.data.permanent:
			continue
		var expired: bool = _advance_timed(debuff, delta) if _is_timed(debuff) else _advance_ticks(debuff, delta)
		if _active.is_empty():
			return
		if expired and _start_queued_instance(debuff):
			_emit_changed()
		elif expired:
			_active.remove_at(i)
			removed = true
	if removed:
		_on_list_shrunk()


func has_debuff(id: StringName) -> bool:
	return _find(id) != null


## Live list (no copy). Do not modify it.
func get_active() -> Array[ActiveDebuff]:
	return _active


func get_ticks_left(id: StringName) -> int:
	var debuff: ActiveDebuff = _find(id)
	return 0 if debuff == null else debuff.ticks_left


## 0 when the debuff is not active.
func get_stacks(id: StringName) -> int:
	var debuff: ActiveDebuff = _find(id)
	return 0 if debuff == null else debuff.stacks


## 0 when the debuff is not active or expires by ticks.
func get_time_left(id: StringName) -> float:
	var debuff: ActiveDebuff = _find(id)
	return 0.0 if debuff == null else debuff.time_left


## Seconds until the debuff ends, for both kinds (0 when not active).
func get_remaining_seconds(id: StringName) -> float:
	var debuff: ActiveDebuff = _find(id)
	return 0.0 if debuff == null else get_remaining(debuff)


## Timed debuffs: time_left. Tick debuffs: time until their last tick.
## Permanent statuses: 0 (nothing to show).
static func get_remaining(debuff: ActiveDebuff) -> float:
	if debuff.data.permanent:
		return 0.0
	if _is_timed(debuff):
		return maxf(debuff.time_left, 0.0)
	return maxf((debuff.ticks_left - 1) * debuff.data.tick_interval + debuff.tick_left, 0.0)


## Remaining time over the full duration, in [0, 1] (the HUD cooldown clock).
static func get_remaining_ratio(debuff: ActiveDebuff) -> float:
	if debuff.duration <= 0.0:
		return 0.0
	return clampf(get_remaining(debuff) / debuff.duration, 0.0, 1.0)


## Fraction of defense ignored by the active ARMOR_REDUCTION debuffs, in [0, 1].
func get_defense_reduction() -> float:
	var total: float = 0.0
	for debuff: ActiveDebuff in _active:
		if debuff.data.effect == DebuffData.Effect.ARMOR_REDUCTION:
			total += get_strength(debuff)
	return minf(total, 1.0)


## Fraction of its normal speed the owner moves and acts at: 1 - the strongest
## active SLOW, in [0, 1].
func get_speed_scale() -> float:
	return _speed_scale


## Whether a STUN is active (the owner stands still: get_speed_scale() is 0).
func is_stunned() -> bool:
	for debuff: ActiveDebuff in _active:
		if debuff.data.effect == DebuffData.Effect.STUN:
			return true
	return false


## potency x stack multiplier (the stack count, or DebuffData.stack_multipliers)
## for upgradable (INTENSITY) statuses; potency for stackable (QUEUE) ones,
## whose stacks only lengthen the effect.
static func get_strength(debuff: ActiveDebuff) -> float:
	if debuff.data.stacks_intensity():
		return debuff.potency * debuff.data.stack_multiplier(debuff.stacks)
	return debuff.potency


func _refresh(debuff: ActiveDebuff, potency: float) -> void:
	debuff.potency = maxf(debuff.potency, potency)
	var cap: int = debuff.data.get_stack_cap()
	if debuff.data.stacks_intensity():
		debuff.stacks = mini(debuff.stacks + 1, cap)
		_restart_instance(debuff)
	elif debuff.stacks < cap:
		debuff.stacks += 1
	else:
		_restart_instance(debuff)
	_write_derived()


## Full duration again for the running instance (the tick phase is kept).
func _restart_instance(debuff: ActiveDebuff) -> void:
	debuff.ticks_left = _tick_count(debuff.data)
	debuff.time_left = debuff.duration


## A stackable status that ran out starts its next queued instance. Returns
## false when nothing was queued (the status ends).
func _start_queued_instance(debuff: ActiveDebuff) -> bool:
	if debuff.data.stacks_intensity() or debuff.stacks <= 1:
		return false
	debuff.stacks -= 1
	debuff.tick_left = debuff.data.tick_interval
	_restart_instance(debuff)
	return true


## Returns true when the debuff ran out.
func _advance_ticks(debuff: ActiveDebuff, delta: float) -> bool:
	debuff.tick_left -= delta
	if debuff.tick_left > 0.0:
		return false
	debuff.tick_left += debuff.data.tick_interval
	debuff.ticks_left -= 1
	_tick(debuff)
	return debuff.ticks_left <= 0


## Returns true when the debuff ran out.
func _advance_timed(debuff: ActiveDebuff, delta: float) -> bool:
	debuff.time_left -= delta
	return debuff.time_left <= 0.0


## Reported before applying, so a killing tick is still reported (the death
## unregisters the owner and clears this list through the pool reset).
func _tick(debuff: ActiveDebuff) -> void:
	if health.is_dead() or health.is_invulnerable:
		return
	var amount: float = minf(_tick_damage(debuff), health.current_health)
	ticked.emit(target, amount, debuff.data)
	health.receive_true_damage(amount)


func _tick_damage(debuff: ActiveDebuff) -> float:
	var strength: float = get_strength(debuff)
	if debuff.data.damage_scaling == DebuffData.DamageScaling.FLAT:
		return strength
	return strength * health.max_health


func _on_list_shrunk() -> void:
	if not _has_expiring():
		set_physics_process(false)
	_on_list_changed()


func _on_list_changed() -> void:
	_write_derived()
	_emit_changed()


func _emit_changed() -> void:
	revision += 1
	changed.emit()


## Values other nodes read every frame: the health's defense reduction and the speed scale.
func _write_derived() -> void:
	health.defense_reduction = get_defense_reduction()
	var slow: float = 0.0
	for debuff: ActiveDebuff in _active:
		if debuff.data.effect == DebuffData.Effect.SLOW:
			slow = maxf(slow, get_strength(debuff))
		elif debuff.data.effect == DebuffData.Effect.STUN:
			slow = 1.0
	_speed_scale = clampf(1.0 - slow, 0.0, 1.0)


func _find(id: StringName) -> ActiveDebuff:
	for debuff: ActiveDebuff in _active:
		if debuff.data.id == id:
			return debuff
	return null


static func _is_timed(debuff: ActiveDebuff) -> bool:
	return debuff.data.effect != DebuffData.Effect.DAMAGE_OVER_TIME


static func _tick_count(data: DebuffData) -> int:
	if data.tick_interval <= 0.0:
		return 0
	return roundi(data.duration / data.tick_interval)


## Whether any active status can run out (permanent ones never do).
func _has_expiring() -> bool:
	for debuff: ActiveDebuff in _active:
		if not debuff.data.permanent:
			return true
	return false
