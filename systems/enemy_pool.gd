class_name EnemyPool
extends Node
## Pre-instantiates enemies when the level loads. Enemies are reused through
## activate()/deactivate(); nothing is instantiated or freed during combat.
## With a boss challenge assigned, it holds exactly that challenge's enemies;
## with a spawn entry, max_per_wave enemies of that type.

@export var enemy_scene: PackedScene
@export var config: WaveConfig
@export var registry: EnemyRegistry
## Handed to every enemy of the pool (docs/specs/enemy-group-ai.md); may be empty.
@export var coordinator: AttackCoordinator
## Optional: when set, the pool holds challenge.count enemies with challenge.stats.
@export var challenge: BossChallengeData
## Optional: when set, the pool holds spawn_entry.max_per_wave enemies with spawn_entry.stats.
@export var spawn_entry: EnemySpawnEntry

var _available: Array[Enemy] = []
var _created: int = 0


func _ready() -> void:
	for i: int in _pool_size():
		_create_enemy()


## Returns an inactive enemy (still to be activated), or null if the pool is exhausted.
func acquire() -> Enemy:
	if _available.is_empty():
		push_error("EnemyPool exhausted: raise its size (WaveConfig.pool_size, BossChallengeData.count or EnemySpawnEntry.max_per_wave).")
		return null
	return _available.pop_back()


func available_count() -> int:
	return _available.size()


## Creates the enemies missing to reach `count` (sandbox caps). Only called
## while the level loads, never in combat (Principle V).
func grow_to(count: int) -> void:
	for i: int in count - get_size():
		_create_enemy()


## Enemies the pool owns, active or not.
func get_size() -> int:
	return _created


func _pool_size() -> int:
	if challenge != null:
		return challenge.count
	if spawn_entry != null:
		return spawn_entry.max_per_wave
	return config.pool_size


func _create_enemy() -> void:
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	if challenge != null:
		enemy.stats = challenge.stats
	elif spawn_entry != null:
		enemy.stats = spawn_entry.stats
	enemy.registry = registry
	enemy.coordinator = coordinator
	enemy.start_active = false
	enemy.killed.connect(_reclaim)
	enemy.returned.connect(_reclaim)
	add_child(enemy)
	_created += 1
	_available.append(enemy)


func _reclaim(enemy: Enemy) -> void:
	_available.append(enemy)
