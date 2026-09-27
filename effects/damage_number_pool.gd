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
## Material of critical-hit numbers (white, Principle II v4.18.0).
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
	player.afflictions.triggered.connect(_on_affliction_triggered)
	if registry != null:
		registry.enemy_debuff_ticked.connect(_on_enemy_debuff_ticked)


## `tint` colors a normal number (null = white); `over_time` makes it italic.
func spawn(amount: float, is_crit: bool, at: Vector3, tint: StandardMaterial3D = null, over_time: bool = false) -> void:
	var number: DamageNumber = _take_number()
	number.show_damage(amount, is_crit, at, tint, over_time)
	_active.append(number)
	_last_spawned = number


## A word with the look of a normal number (e.g. an Affliction name).
func spawn_text(text: String, at: Vector3, tint: StandardMaterial3D = null) -> void:
	var number: DamageNumber = _take_number()
	number.show_text(text, at, tint)
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


## Area damage of an Affliction burst (docs/specs/affliction.md): never critical,
## in the color of its bar.
func _on_affliction_burst_hit(enemy: Enemy, applied: float, type: AfflictionData) -> void:
	spawn(applied, false, enemy.global_position + _spawn_offset(enemy), type.damage_number_material)


## Every Affliction says its name in its color each time its bar fills
## (docs/specs/affliction-name-popup.md §7).
func _on_affliction_triggered(enemy: Enemy, type: AfflictionData) -> void:
	spawn_text(type.title, enemy.global_position + _spawn_offset(enemy), type.text_material())


## Italic, and in the status color when it has one (e.g. poison).
func _on_enemy_debuff_ticked(enemy: Enemy, amount: float, data: DebuffData) -> void:
	spawn(amount, false, enemy.global_position + _spawn_offset(enemy), data.damage_number_material, true)


## Above the enemy's head: spawn_height grows with bigger bodies (bosses).
func _spawn_offset(enemy: Enemy) -> Vector3:
	return Vector3(
		_rng.randf_range(-config.spread, config.spread),
		config.spawn_height * enemy.get_body_scale(),
		_rng.randf_range(-config.spread, config.spread))
