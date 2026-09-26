class_name EnemyRegistry
extends Node
## Keeps the list of active enemies so nobody has to search the scene tree per frame.

signal enemy_killed(enemy: Enemy)
signal all_dead
## A debuff tick (e.g. bleeding) removed health from a registered enemy.
signal enemy_debuff_ticked(enemy: Enemy, amount: float)

var _active: Array[Enemy] = []


func register(enemy: Enemy) -> void:
	if _active.has(enemy):
		return
	_active.append(enemy)
	enemy.killed.connect(_on_enemy_killed)
	enemy.debuffs.ticked.connect(_on_debuff_ticked)


func unregister(enemy: Enemy) -> void:
	if not _active.has(enemy):
		return
	_active.erase(enemy)
	enemy.killed.disconnect(_on_enemy_killed)
	enemy.debuffs.ticked.disconnect(_on_debuff_ticked)


## Nearest living enemy on the XZ plane, or null when there is none.
func find_nearest(from: Vector3) -> Enemy:
	var nearest: Enemy = null
	var best_distance_sq: float = INF
	for enemy: Enemy in _active:
		if enemy.health.is_dead():
			continue
		var distance_sq: float = _flat_distance_sq(from, enemy.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = enemy
	return nearest


## Returns the live internal list (no copy). Do not modify it while iterating.
func get_active() -> Array[Enemy]:
	return _active


func alive_count() -> int:
	return _active.size()


func _on_enemy_killed(enemy: Enemy) -> void:
	unregister(enemy)
	enemy_killed.emit(enemy)
	if _active.is_empty():
		all_dead.emit()


func _on_debuff_ticked(target: Node3D, amount: float) -> void:
	enemy_debuff_ticked.emit(target as Enemy, amount)


func _flat_distance_sq(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length_squared()
