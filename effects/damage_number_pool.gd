class_name DamageNumberPool
extends Node3D
## Pre-instantiated damage numbers (Principle V). Listens to the player's hits
## (basic attack and abilities) and to debuff ticks on enemies (e.g. bleeding).
## When every number is busy, the oldest one is recycled so no hit goes without feedback.

@export var player: Player
## Optional: source of debuff tick numbers.
@export var registry: EnemyRegistry
@export var config: DamageNumberConfig
@export var material: StandardMaterial3D
## Material of critical-hit numbers (amber, Principle II).
@export var crit_material: StandardMaterial3D

var _free: Array[DamageNumber] = []
## Oldest first.
var _active: Array[DamageNumber] = []
var _last_spawned: DamageNumber = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i: int in config.pool_size:
		_create_number()
	player.attack.enemy_hit.connect(_on_enemy_hit)
	player.basic_ability.enemy_hit.connect(_on_enemy_hit)
	player.ultimate_ability.enemy_hit.connect(_on_enemy_hit)
	player.air_slash.enemy_hit.connect(_on_enemy_hit)
	player.afflictions.burst_hit.connect(_on_affliction_burst_hit)
	if registry != null:
		registry.enemy_debuff_ticked.connect(_on_enemy_debuff_ticked)


func spawn(amount: float, is_crit: bool, at: Vector3) -> void:
	var number: DamageNumber = _take_number()
	number.show_damage(amount, is_crit, at)
	_active.append(number)
	_last_spawned = number


func active_count() -> int:
	return _active.size()


func get_last_spawned() -> DamageNumber:
	return _last_spawned


func _take_number() -> DamageNumber:
	if not _free.is_empty():
		return _free.pop_back()
	return _active.pop_front()


func _create_number() -> void:
	var number := DamageNumber.new()
	add_child(number)
	number.setup(config, material, crit_material)
	number.finished.connect(_on_number_finished)
	_free.append(number)


func _on_number_finished(number: DamageNumber) -> void:
	_active.erase(number)
	_free.append(number)


func _on_enemy_hit(enemy: Enemy, applied: float, is_crit: bool) -> void:
	spawn(applied, is_crit, enemy.global_position + _spawn_offset(enemy))


## Area damage of an Affliction burst (docs/specs/affliction.md): never critical.
func _on_affliction_burst_hit(enemy: Enemy, applied: float) -> void:
	_on_enemy_hit(enemy, applied, false)


func _on_enemy_debuff_ticked(enemy: Enemy, amount: float) -> void:
	spawn(amount, false, enemy.global_position + _spawn_offset(enemy))


## Above the enemy's head: spawn_height grows with bigger bodies (bosses).
func _spawn_offset(enemy: Enemy) -> Vector3:
	return Vector3(
		_rng.randf_range(-config.spread, config.spread),
		config.spawn_height * enemy.get_body_scale(),
		_rng.randf_range(-config.spread, config.spread))
