class_name AbilityComponent
extends Node
## One ability slot of the player (basic or ultimate). Holds the equipped
## ability, its own upgrades and effective stats, the cast and the cooldown.
## Player upgrades never change these stats; abilities only read the player's
## stats they scale with.

signal cast_started
signal cast_released
## Emitted when a charged ability starts charging (key pressed).
signal charge_started
## Emitted once per charge milestone: every ChargeFeedbackConfig.milestone_interval
## seconds of charge and when the charge is full. `index` starts at 1.
signal charge_milestone_reached(index: int, is_full: bool)
## Emitted once per enemy hit, with the damage actually applied to it.
signal enemy_hit(enemy: Enemy, applied: float, is_crit: bool)
## Emitted when the ability gains or spends an empowered cast (e.g. Tsubame Gaeshi).
signal empowered_changed(active: bool)

## Float tolerance when comparing charge times (the steps add up only
## approximately). Structural, not a design value.
const TIME_EPSILON: float = 0.0001

@export var slot: AbilityData.Slot
@export var body: CharacterBody3D
@export var visual: Node3D
@export var player_stats: StatsComponent
@export var registry: EnemyRegistry
@export var swing_player: AnimationPlayer
@export var tuning: PlayerTuning
## Lets abilities that move the player walk with the normal movement rules.
@export var movement: MovementComponent
## Lets abilities that hold the weapon return it to its rest pose.
@export var sword_swing: SwordSwing
## Lets abilities hold the weapon in its scabbard (e.g. Sheathe while charging).
@export var weapon_mount: WeaponMount
## Lets abilities change how much damage the player takes (e.g. while charging).
@export var health: HealthComponent
## Spacing of the charge milestones of charged abilities.
@export var charge_feedback: ChargeFeedbackConfig
## Lets abilities grant and read the player's buffs.
@export var buffs: BuffComponent
## Lets abilities act on the player's dash (e.g. reset its cooldown) or follow
## a dash that cut their cast short (e.g. the Spin's slash).
@export var dash: DashComponent

var _data: AbilityData = null
var _behavior: AbilityBehavior = null
var _upgrades: Array[AbilityUpgradeData] = []
## Level of each unique upgrade taken this run, by id.
var _unique_levels: Dictionary[StringName, int] = {}
var _cache: PackedFloat64Array = PackedFloat64Array()
var _cast_left: float = 0.0
var _cooldown_left: float = 0.0
var _cooldown_total: float = 0.0
var _charging: bool = false
var _charge_elapsed: float = 0.0
## Charge ratio frozen on the release, used by the cast that follows.
var _released_charge_ratio: float = 0.0
## Milestones already reached by the current charge.
var _milestones_reached: int = 0
var _full_charge_reached: bool = false


func _physics_process(delta: float) -> void:
	advance(delta)


## Instantiates the ability's behavior and resets the slot (no upgrades, ready).
func equip(data: AbilityData) -> void:
	cancel_charge()
	_remove_behavior()
	_data = data
	_upgrades.clear()
	_unique_levels.clear()
	_cast_left = 0.0
	_cooldown_left = 0.0
	_cooldown_total = 0.0
	_recalculate()
	_behavior = data.behavior.instantiate() as AbilityBehavior
	add_child(_behavior)


func is_equipped() -> bool:
	return _data != null


func get_data() -> AbilityData:
	return _data


func get_behavior() -> AbilityBehavior:
	return _behavior


func get_stat(stat: AbilityData.Stat) -> float:
	return _cache[stat]


func add_upgrade(upgrade: AbilityUpgradeData) -> void:
	_upgrades.append(upgrade)
	_recalculate()


func get_upgrades() -> Array[AbilityUpgradeData]:
	return _upgrades


## True when the card is one of the equipped ability's upgrades (stat or unique).
## Checks the card type first: has() on a typed array logs an error for other classes.
func owns_upgrade(card: UpgradeCard) -> bool:
	if _data == null:
		return false
	if card is AbilityUpgradeData:
		return _data.upgrades.has(card as AbilityUpgradeData)
	if card is AbilityUniqueUpgradeData:
		return _data.unique_upgrades.has(card as AbilityUniqueUpgradeData)
	return false


## Applies one of this ability's cards, stat or unique.
func apply_card(card: UpgradeCard) -> void:
	if card is AbilityUniqueUpgradeData:
		add_unique_upgrade(card as AbilityUniqueUpgradeData)
	else:
		add_upgrade(card as AbilityUpgradeData)


## Undoes one of this ability's cards: one stat upgrade or one unique level (sandbox).
func remove_card(card: UpgradeCard) -> void:
	var unique: AbilityUniqueUpgradeData = card as AbilityUniqueUpgradeData
	if unique != null:
		_unique_levels[unique.id] = maxi(get_unique_level(unique.id) - 1, 0)
		return
	var index: int = _upgrades.find(card as AbilityUpgradeData)
	if index >= 0:
		_upgrades.remove_at(index)
		_recalculate()


## Copies of a stat upgrade taken, or the level of a unique upgrade.
func count_card(card: UpgradeCard) -> int:
	var unique: AbilityUniqueUpgradeData = card as AbilityUniqueUpgradeData
	if unique != null:
		return get_unique_level(unique.id)
	return _upgrades.count(card as AbilityUpgradeData)


## Back to the ability's base state (sandbox reset).
func clear_upgrades() -> void:
	_upgrades.clear()
	_unique_levels.clear()
	if _data != null:
		_recalculate()


## Raises the unique upgrade one level, never past its max_level.
func add_unique_upgrade(upgrade: AbilityUniqueUpgradeData) -> void:
	_unique_levels[upgrade.id] = mini(get_unique_level(upgrade.id) + 1, upgrade.max_level)


## 0 when the unique upgrade has not been taken.
func get_unique_level(id: StringName) -> int:
	return _unique_levels.get(id, 0)


func has_unique(id: StringName) -> bool:
	return get_unique_level(id) > 0


## The equipped ability's unique upgrade with this id, or null.
func get_unique_upgrade(id: StringName) -> AbilityUniqueUpgradeData:
	if _data == null:
		return null
	for upgrade: AbilityUniqueUpgradeData in _data.unique_upgrades:
		if upgrade.id == id:
			return upgrade
	return null


## Value of the unique upgrade at its current level (0 when not taken).
func get_unique_value(id: StringName) -> float:
	var upgrade: AbilityUniqueUpgradeData = get_unique_upgrade(id)
	if upgrade == null:
		return 0.0
	return upgrade.get_value(get_unique_level(id))


func is_unique_maxed(upgrade: AbilityUniqueUpgradeData) -> bool:
	return get_unique_level(upgrade.id) >= upgrade.max_level


## Makes the ability ready at once (e.g. "Reset" after a kill).
func reset_cooldown() -> void:
	_cooldown_left = 0.0


## Takes `seconds` off the remaining cooldown, never below 0 (e.g. "Tornado").
## The surplus is lost; without a cooldown nothing changes.
func reduce_cooldown(seconds: float) -> void:
	_cooldown_left = maxf(_cooldown_left - seconds, 0.0)


## The cooldown starts on the key press; the hit lands when the cast ends.
## A charged ability starts charging instead (unless its behavior skips the
## charge, which casts at once with a full charge): its cast (and cooldown) starts on
## release_charge().
func try_cast() -> bool:
	if not can_cast():
		return false
	if _behavior.is_charged() and _behavior.skips_charge():
		_released_charge_ratio = 1.0
		_start_cast()
	elif _behavior.is_charged():
		_start_charge()
	else:
		_start_cast()
	return true


## True while the equipped ability holds an empowered cast.
func is_empowered() -> bool:
	return is_equipped() and _behavior.is_empowered()


## Called by behaviors when they gain or spend an empowered cast.
func notify_empowered(active: bool) -> void:
	empowered_changed.emit(active)


## True when try_cast() would start the ability now.
func can_cast() -> bool:
	return is_equipped() and not is_casting() and not is_charging() and _cooldown_left <= 0.0


## True while casting an ability whose cast a dash may cut short.
func dash_cancels_cast() -> bool:
	return is_casting() and _data.dash_cancels_cast


## Ends the running cast at once, without release(). The cooldown keeps running.
func cancel_cast() -> void:
	if not is_casting():
		return
	_cast_left = 0.0
	_behavior.cancel_cast(self)
	cast_released.emit()


## Like cancel_cast(), for a cast cut short by a dash that has just started;
## the behavior hears about the dash afterwards (e.g. the Spin's dash slash).
func cut_cast_by_dash() -> void:
	if not is_casting():
		return
	cancel_cast()
	_behavior.cast_cut_by_dash(self)


## True when the equipped ability may cut a running dash short to be cast.
func interrupts_dash() -> bool:
	return is_equipped() and _data.interrupts_dash


## Ends the charge and casts with the charge reached so far.
func release_charge() -> bool:
	if not is_charging():
		return false
	_released_charge_ratio = get_charge_ratio()
	_charging = false
	_start_cast()
	return true


## Tells the equipped ability that the player started a dash (and, while
## charging, that it happened during the charge).
func notify_dash() -> void:
	if not is_equipped():
		return
	_behavior.dash_started(self)
	if is_charging():
		_behavior.dash_during_charge(self)


## Adds `seconds` of charge at once (never past CHARGE_TIME), with the
## milestones it crosses.
func add_charge(seconds: float) -> void:
	if not is_charging():
		return
	_advance_charge(seconds)


## Drops the charge without casting (no cooldown).
func cancel_charge() -> void:
	if not is_charging():
		return
	_charging = false
	_behavior.cancel_charge(self)


func is_casting() -> bool:
	return _cast_left > 0.0


## True while the cooldown counts down (after a cast).
func is_on_cooldown() -> bool:
	return _cooldown_left > 0.0


func is_charging() -> bool:
	return _charging


## Humanoid clip the body plays while this ability charges or casts; &"" =
## the default (docs/specs/sheath-socket-hand-grip.md §2.7).
func get_body_clip() -> StringName:
	if _behavior == null or not (is_charging() or is_casting()):
		return &""
	return _behavior.get_body_clip(self)


## Charge reached, in [0, 1]: 1 once CHARGE_TIME has been held (0 when not charging).
func get_charge_ratio() -> float:
	if not is_charging():
		return 0.0
	if _full_charge_reached:
		return 1.0
	return minf(_charge_elapsed / get_stat(AbilityData.Stat.CHARGE_TIME), 1.0)


## Charge ratio at the last release (read by the cast that follows it).
func get_released_charge_ratio() -> float:
	return _released_charge_ratio


func get_cast_remaining() -> float:
	return _cast_left


## True while charging or casting an ability that moves the player (e.g. a sprint).
func controls_motion() -> bool:
	return (is_casting() or is_charging()) and _behavior.controls_motion()


## Moves the player for this physics step; only valid while controls_motion().
func move_body(delta: float, wish_direction: Vector3) -> void:
	_behavior.move_body(self, delta, wish_direction)


## Seconds until the ability is ready (0 when ready).
func get_cooldown_remaining() -> float:
	return _cooldown_left


## 0 when ready, 1 right after casting.
func get_cooldown_ratio() -> float:
	if _cooldown_total <= 0.0:
		return 0.0
	return _cooldown_left / _cooldown_total


func advance(delta: float) -> void:
	_advance_charge(delta)
	_advance_cast(delta)
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


## Called by behaviors for every enemy they damage.
func report_hit(enemy: Enemy, applied: float, is_crit: bool = false) -> void:
	enemy_hit.emit(enemy, applied, is_crit)


func _start_charge() -> void:
	_charging = true
	_charge_elapsed = 0.0
	_milestones_reached = 0
	_full_charge_reached = false
	_behavior.begin_charge(self)
	charge_started.emit()


func _start_cast() -> void:
	_cooldown_total = get_stat(AbilityData.Stat.COOLDOWN)
	_cooldown_left = _cooldown_total
	_cast_left = get_stat(AbilityData.Stat.CAST_DURATION)
	_behavior.begin(self)
	cast_started.emit()


## The charge keeps growing up to CHARGE_TIME and then holds there.
func _advance_charge(delta: float) -> void:
	if not is_charging():
		return
	_charge_elapsed = minf(_charge_elapsed + delta, get_stat(AbilityData.Stat.CHARGE_TIME))
	_behavior.charge(self, delta)
	_reach_milestones()


## One milestone per milestone_interval of charge; the one reaching CHARGE_TIME
## is the full-charge milestone and the last one of the charge.
func _reach_milestones() -> void:
	var charge_time: float = get_stat(AbilityData.Stat.CHARGE_TIME)
	while not _full_charge_reached:
		var index: int = _milestones_reached + 1
		var at: float = minf(index * charge_feedback.milestone_interval, charge_time)
		if _charge_elapsed < at - TIME_EPSILON:
			return
		_milestones_reached = index
		_full_charge_reached = at >= charge_time - TIME_EPSILON
		_behavior.charge_milestone(self, index, _full_charge_reached)
		charge_milestone_reached.emit(index, _full_charge_reached)


func _advance_cast(delta: float) -> void:
	if not is_casting():
		return
	_behavior.channel(self, minf(delta, _cast_left))
	_cast_left -= delta
	if _cast_left <= 0.0:
		_cast_left = 0.0
		_behavior.release(self)
		cast_released.emit()


func _recalculate() -> void:
	_cache.resize(AbilityData.Stat.size())
	for i: int in AbilityData.Stat.size():
		_cache[i] = _data.get_base(i as AbilityData.Stat)
	for upgrade: AbilityUpgradeData in _upgrades:
		_cache[upgrade.stat] += upgrade.amount
	_apply_limits()


func _apply_limits() -> void:
	var cooldown: int = AbilityData.Stat.COOLDOWN
	var cast: int = AbilityData.Stat.CAST_DURATION
	var tick: int = AbilityData.Stat.TICK_INTERVAL
	var charge: int = AbilityData.Stat.CHARGE_TIME
	_cache[cooldown] = maxf(_cache[cooldown], _data.min_cooldown)
	_cache[cast] = maxf(_cache[cast], _data.min_cast_duration)
	_cache[tick] = maxf(_cache[tick], _data.min_tick_interval)
	_cache[charge] = maxf(_cache[charge], _data.min_charge_time)


func _remove_behavior() -> void:
	if _behavior == null:
		return
	remove_child(_behavior)
	_behavior.queue_free()
	_behavior = null
