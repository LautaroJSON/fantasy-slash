class_name AfflictionComponent
extends Node
## Build-up of every Affliction bar of an enemy (docs/specs/affliction.md).
## Slot i is the player's i-th Affliction (AfflictionLoadout). The player never
## sees the points, only the bars (AfflictionBarRow, BossHealthBar) that read
## get_ratio(). A bar that gets no build-up for decay_delay seconds drains at
## decay_per_second until it is empty or fed again. Processes only while some
## bar has points or is flashing.

## Some bar gained, lost or reset points, or stopped flashing.
signal changed

@export var config: AfflictionConfig

var _buildup: PackedFloat32Array = PackedFloat32Array()
## Seconds since each bar last got build-up.
var _idle: PackedFloat32Array = PackedFloat32Array()
## Seconds each bar still shows full after triggering.
var _flash: PackedFloat32Array = PackedFloat32Array()
var _resistance: float = 0.0


func _ready() -> void:
	_buildup.resize(config.max_types)
	_idle.resize(config.max_types)
	_flash.resize(config.max_types)
	clear()


func _physics_process(delta: float) -> void:
	advance(delta)


## Called when the enemy activates: empty bars and the resistance of its type.
func setup(stats: EnemyStats) -> void:
	_resistance = config.clamp_resistance(stats.affliction_resistance)
	clear()


## Adds `amount` points to bar `slot`. Returns true when the bar filled: it goes
## back to 0 (the rest is dropped) and flashes for flash_duration.
func add_buildup(slot: int, amount: float) -> bool:
	if amount <= 0.0:
		return false
	_idle[slot] = 0.0
	_buildup[slot] += amount
	var filled: bool = _buildup[slot] >= config.threshold
	if filled:
		_buildup[slot] = 0.0
		_flash[slot] = config.flash_duration
	set_physics_process(true)
	changed.emit()
	return filled


## Points over the threshold, in [0, 1].
func get_ratio(slot: int) -> float:
	return clampf(_buildup[slot] / config.threshold, 0.0, 1.0)


func get_buildup(slot: int) -> float:
	return _buildup[slot]


## Fraction of every build-up this enemy resists.
func get_resistance() -> float:
	return _resistance


func is_flashing(slot: int) -> bool:
	return _flash[slot] > 0.0


## Flashes and draining; called by _physics_process and by tests.
func advance(delta: float) -> void:
	var moved: bool = false
	var active: bool = false
	for slot: int in _buildup.size():
		if _advance_flash(slot, delta):
			moved = true
		if _advance_decay(slot, delta):
			moved = true
		active = active or _flash[slot] > 0.0 or _buildup[slot] > 0.0
	set_physics_process(active)
	if moved:
		changed.emit()


func clear() -> void:
	_buildup.fill(0.0)
	_idle.fill(0.0)
	_flash.fill(0.0)
	set_physics_process(false)
	changed.emit()


## Returns true when the flash just ended.
func _advance_flash(slot: int, delta: float) -> bool:
	if _flash[slot] <= 0.0:
		return false
	_flash[slot] = maxf(_flash[slot] - delta, 0.0)
	return _flash[slot] <= 0.0


## Returns true when the bar lost points.
func _advance_decay(slot: int, delta: float) -> bool:
	if _buildup[slot] <= 0.0:
		return false
	_idle[slot] += delta
	var draining: float = minf(delta, _idle[slot] - config.decay_delay)
	if draining <= 0.0:
		return false
	_buildup[slot] = maxf(_buildup[slot] - config.decay_per_second * draining, 0.0)
	return true
