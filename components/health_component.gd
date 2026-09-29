class_name HealthComponent
extends Node
## Tracks hit points. Applies defense and invulnerability to incoming hits.

signal health_changed(current: float, maximum: float)
signal died
## Emitted by every hit that actually removes health, with the amount removed.
signal damaged(amount: float)
## A hit of an enemy reached the owner while invulnerable (docs/specs/perfect-dodge.md).
signal hit_evaded(raw: float, attacker: Enemy)

@export var rules: CombatRules
## Frontal block of the owner (docs/specs/warrior-abilities-rework.md); optional:
## only the player has one.
@export var guard: ShieldGuard

var max_health: float = 0.0
var defense: float = 0.0
var is_invulnerable: bool = false
## Fraction of every hit removed after defense (0 = none), e.g. while charging
## an ability. Set and cleared by whoever grants it.
var damage_reduction: float = 0.0
## Fraction of defense ignored (0 = none, 1 = all), e.g. from an armor debuff.
## Written by the owner's DebuffComponent.
var defense_reduction: float = 0.0
## Takes damage but never drops below rules.protected_min_health (sandbox).
var death_protected: bool = false
var current_health: float:
	get:
		return _current_health

var _current_health: float = 0.0
var _is_dead: bool = false


func setup(max_hp: float, new_defense: float) -> void:
	max_health = max_hp
	defense = new_defense
	defense_reduction = 0.0
	is_invulnerable = false
	_current_health = max_hp
	_is_dead = false
	_emit_health_changed()


## Returns the damage actually applied (0 when invulnerable or dead; no overkill).
## defense_reduction lowers defense; damage_reduction applies after defense.
func receive_hit(raw: float) -> float:
	if is_invulnerable or _is_dead:
		return 0.0
	var mitigated: float = DamageMath.mitigate(raw, get_effective_defense(), rules.min_damage_after_defense)
	return _apply_damage(mitigated * (1.0 - damage_reduction))


## A hit of an enemy on the owner (invulnerable owners emit hit_evaded): the guard, when raised and facing the
## attacker, absorbs its share first. A hit absorbed whole removes nothing
## and emits no `damaged` (no flicker, no hit clip). Returns the damage applied.
func receive_hit_from(raw: float, attacker: Enemy) -> float:
	if _is_dead:
		return 0.0
	if is_invulnerable:
		hit_evaded.emit(raw, attacker)
		return 0.0
	var left: float = raw if guard == null else guard.absorb(raw, attacker)
	if left <= 0.0:
		return 0.0
	return receive_hit(left)


## Damage that ignores defense (e.g. bleeding). Returns the damage applied.
func receive_true_damage(amount: float) -> float:
	if is_invulnerable or _is_dead or amount <= 0.0:
		return 0.0
	return _apply_damage(amount)


## Kills outright, ignoring defense (e.g. an execution). Returns the health removed.
func execute() -> float:
	if is_invulnerable or _is_dead:
		return 0.0
	return _apply_damage(_current_health)


## Defense after defense_reduction.
func get_effective_defense() -> float:
	return defense * (1.0 - defense_reduction)


## Fraction of health left, in [0, 1].
func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return _current_health / max_health


func _apply_damage(amount: float) -> float:
	var applied: float = minf(amount, _current_health - _health_floor())
	_current_health -= applied
	_emit_health_changed()
	if applied > 0.0:
		damaged.emit(applied)
	if _current_health <= 0.0:
		_die()
	return applied


func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	_current_health = minf(_current_health + amount, max_health)
	_emit_health_changed()


## Raising the maximum heals by the same amount; lowering it clamps current health.
func set_max_health(value: float) -> void:
	var gained: float = value - max_health
	max_health = value
	if gained > 0.0 and not _is_dead:
		_current_health += gained
	_current_health = minf(_current_health, max_health)
	_emit_health_changed()


func is_dead() -> bool:
	return _is_dead


func _die() -> void:
	_is_dead = true
	died.emit()


func _health_floor() -> float:
	if not death_protected:
		return 0.0
	return minf(rules.protected_min_health, _current_health)


func _emit_health_changed() -> void:
	health_changed.emit(_current_health, max_health)
