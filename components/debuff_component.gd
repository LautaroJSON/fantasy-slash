class_name DebuffComponent
extends Node
## Active status effects of an entity (debuffs and buffs), kept as a list so several kinds
## can coexist. Re-applying a debuff with the same id refreshes it (full
## duration, stronger potency) and adds a stack up to DebuffData.max_stacks.
## DAMAGE_OVER_TIME: each tick removes potency x max health, ignoring defense.
## ARMOR_REDUCTION: the health ignores stacks x potency of its defense.
## STAT_BOOST: a buff whose stats the owner applies; only listed here.
## Permanent statuses never expire and do not keep the component processing.

## A tick removed health. `target` is the owner, for listeners of many entities.
signal ticked(target: Node3D, amount: float)
## A debuff was added, stacked, expired or cleared.
signal changed


class ActiveDebuff:
	var data: DebuffData
	## Fraction of max health removed per tick, or of defense ignored per stack.
	var potency: float
	var stacks: int
	var ticks_left: int
	var tick_left: float
	## Seconds left (ARMOR_REDUCTION; damage debuffs expire by ticks).
	var time_left: float


@export var health: HealthComponent
## Entity that owns the debuffs (reported in `ticked`).
@export var target: Node3D

var _active: Array[ActiveDebuff] = []


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	advance(delta)


func apply(data: DebuffData, potency: float) -> void:
	var existing: ActiveDebuff = _find(data.id)
	if existing != null:
		_refresh(existing, potency)
		changed.emit()
		return
	var debuff := ActiveDebuff.new()
	debuff.data = data
	debuff.potency = potency
	debuff.stacks = 1
	debuff.ticks_left = _tick_count(data)
	debuff.tick_left = data.tick_interval
	debuff.time_left = data.duration
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
		if expired:
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
	if debuff.data.duration <= 0.0:
		return 0.0
	return clampf(get_remaining(debuff) / debuff.data.duration, 0.0, 1.0)


## Fraction of defense ignored by the active ARMOR_REDUCTION debuffs, in [0, 1].
func get_defense_reduction() -> float:
	var total: float = 0.0
	for debuff: ActiveDebuff in _active:
		if debuff.data.effect == DebuffData.Effect.ARMOR_REDUCTION:
			total += debuff.potency * debuff.stacks
	return minf(total, 1.0)


func _refresh(debuff: ActiveDebuff, potency: float) -> void:
	debuff.stacks = mini(debuff.stacks + 1, debuff.data.get_stack_cap())
	debuff.ticks_left = _tick_count(debuff.data)
	debuff.time_left = debuff.data.duration
	debuff.potency = maxf(debuff.potency, potency)
	_write_defense_reduction()


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
	var amount: float = minf(debuff.potency * health.max_health, health.current_health)
	ticked.emit(target, amount)
	health.receive_true_damage(amount)


func _on_list_shrunk() -> void:
	if not _has_expiring():
		set_physics_process(false)
	_on_list_changed()


func _on_list_changed() -> void:
	_write_defense_reduction()
	changed.emit()


func _write_defense_reduction() -> void:
	health.defense_reduction = get_defense_reduction()


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
