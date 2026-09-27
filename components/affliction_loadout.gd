class_name AfflictionLoadout
extends Node
## Afflictions of the player's run (docs/specs/affliction.md): the violet cards
## taken, their levels and the Affliction each one fills. Every Affliction is
## one bar (slot) on every enemy, filled by the hits of its cards' sources:
## build-up = level value x source scale x (1 + AFFLICTION_BUILDUP) x
## (1 - enemy resistance). When a bar fills, applies the Affliction's status
## and/or area burst. Burst damage and status ticks are not hits: they never
## build up, heal or cause hit lag.

## A card was added, levelled up or removed.
signal changed
signal triggered(enemy: Enemy, type: AfflictionData)
## Damage of a burst on one enemy (damage numbers).
signal burst_hit(enemy: Enemy, applied: float)

@export var config: AfflictionConfig
@export var stats: StatsComponent
@export var attack: AttackComponent
@export var air_slash: AirSlashComponent
@export var basic_ability: AbilityComponent

## Set by the Player (same registry as its attacks).
var registry: EnemyRegistry = null

## Held cards, their level and the slot of their Affliction (parallel arrays).
var _cards: Array[AfflictionUpgradeData] = []
var _levels: PackedInt32Array = PackedInt32Array()
var _card_slots: PackedInt32Array = PackedInt32Array()
## Afflictions in the order they were first taken; the index is the enemy bar slot.
var _types: Array[AfflictionData] = []
## Enemies inside a burst, gathered before damaging them (a kill changes the registry).
var _burst_targets: Array[Enemy] = []


func _ready() -> void:
	attack.enemy_hit.connect(_on_combo_hit)
	air_slash.enemy_hit.connect(_on_air_slash_hit)
	basic_ability.enemy_hit.connect(_on_ability_hit)


## Pure: build-up of one hit.
static func buildup(base: float, source_scale: float, player_bonus: float, resistance: float) -> float:
	return base * source_scale * (1.0 + player_bonus) * (1.0 - resistance)


## A new card takes level 1 (and a slot for its Affliction if it is new); a held
## one levels up. Ignored at its cap.
func apply_card(card: AfflictionUpgradeData) -> void:
	if is_card_maxed(card):
		return
	var index: int = _cards.find(card)
	if index >= 0:
		_levels[index] += 1
	else:
		_add_card(card)
	changed.emit()


## Sandbox: one level down; at 0 the card goes, and its Affliction with it when
## no other card fills it.
func remove_card(card: AfflictionUpgradeData) -> void:
	var index: int = _cards.find(card)
	if index < 0:
		return
	_levels[index] -= 1
	if _levels[index] <= 0:
		_remove_card_at(index)
	changed.emit()


## Level of a card (0 = not taken).
func count_card(card: AfflictionUpgradeData) -> int:
	var index: int = _cards.find(card)
	return 0 if index < 0 else _levels[index]


## At its max level, or its Affliction is new and the run already holds max_types.
func is_card_maxed(card: AfflictionUpgradeData) -> bool:
	var level: int = count_card(card)
	if level >= card.max_level:
		return true
	return level == 0 and _slot_of(card.affliction) < 0 and _types.size() >= config.max_types


func get_type_count() -> int:
	return _types.size()


func get_type(slot: int) -> AfflictionData:
	return _types[slot]


func get_card_count() -> int:
	return _cards.size()


func get_card(index: int) -> AfflictionUpgradeData:
	return _cards[index]


func get_card_level(index: int) -> int:
	return _levels[index]


func clear() -> void:
	_cards.clear()
	_levels.clear()
	_card_slots.clear()
	_types.clear()
	changed.emit()


func _add_card(card: AfflictionUpgradeData) -> void:
	var slot: int = _slot_of(card.affliction)
	if slot < 0:
		_types.append(card.affliction)
		slot = _types.size() - 1
	_cards.append(card)
	_levels.append(1)
	_card_slots.append(slot)


func _remove_card_at(index: int) -> void:
	var slot: int = _card_slots[index]
	_cards.remove_at(index)
	_levels.remove_at(index)
	_card_slots.remove_at(index)
	if _card_slots.has(slot):
		return
	_types.remove_at(slot)
	for i: int in _card_slots.size():
		if _card_slots[i] > slot:
			_card_slots[i] -= 1


func _slot_of(type: AfflictionData) -> int:
	for slot: int in _types.size():
		if _types[slot].id == type.id:
			return slot
	return -1


func _on_combo_hit(enemy: Enemy, applied: float, _is_crit: bool) -> void:
	_build_up(enemy, applied, AfflictionUpgradeData.Source.BASIC_ATTACK, attack.combo.affliction_scale)


func _on_air_slash_hit(enemy: Enemy, applied: float, _is_crit: bool) -> void:
	_build_up(enemy, applied, AfflictionUpgradeData.Source.BASIC_ATTACK, air_slash.get_affliction_scale())


func _on_ability_hit(enemy: Enemy, applied: float, _is_crit: bool) -> void:
	var data: AbilityData = basic_ability.get_data()
	if data != null:
		_build_up(enemy, applied, AfflictionUpgradeData.Source.ABILITY, data.affliction_scale)


## Feeds every bar whose cards take hits from `source`; fills trigger their effect.
func _build_up(enemy: Enemy, applied: float, source: AfflictionUpgradeData.Source, source_scale: float) -> void:
	if applied <= 0.0 or _cards.is_empty() or enemy.health.is_dead():
		return
	var bonus: float = stats.get_stat(PlayerStats.Stat.AFFLICTION_BUILDUP)
	var resistance: float = enemy.afflictions.get_resistance()
	for i: int in _cards.size():
		var card: AfflictionUpgradeData = _cards[i]
		if card.source != source:
			continue
		var amount: float = buildup(card.get_value(_levels[i]), source_scale, bonus, resistance)
		if enemy.afflictions.add_buildup(_card_slots[i], amount):
			_trigger(enemy, _types[_card_slots[i]])


func _trigger(enemy: Enemy, type: AfflictionData) -> void:
	var potency: float = type.potency_for(stats.get_stat(PlayerStats.Stat.DAMAGE))
	if type.debuff != null:
		enemy.debuffs.apply(type.debuff, potency)
	if type.has_burst():
		_burst(enemy, type.burst_radius, potency)
	triggered.emit(enemy, type)


## Area damage around `center` (itself included), defense applies, no crit.
func _burst(center: Enemy, radius: float, damage: float) -> void:
	_burst_targets.clear()
	_burst_targets.append(center)
	if registry != null:
		_gather_burst_targets(center, radius)
	for enemy: Enemy in _burst_targets:
		var applied: float = enemy.health.receive_hit(damage)
		burst_hit.emit(enemy, applied)


func _gather_burst_targets(center: Enemy, radius: float) -> void:
	var origin := Vector2(center.global_position.x, center.global_position.z)
	for enemy: Enemy in registry.get_active():
		var point := Vector2(enemy.global_position.x, enemy.global_position.z)
		if enemy != center and origin.distance_to(point) <= radius + enemy.get_hit_padding():
			_burst_targets.append(enemy)
