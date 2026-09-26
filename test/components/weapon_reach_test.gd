extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const NO_CRIT_ROLL: float = 0.99
const REACH_TOLERANCE: float = 0.05

var _registry: EnemyRegistry


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)


func after_test() -> void:
	Session.character_class = null


func _enemy_radius() -> float:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	var shape: CollisionShape3D = enemy.get_node("CollisionShape3D") as CollisionShape3D
	return (shape.shape as CapsuleShape3D).radius


## Horizontal reach of the blade tip during the sweep, from the player's centre.
func _tip_reach(character_class: CharacterClassData) -> float:
	var weapon: WeaponData = character_class.weapon
	var model: Node3D = auto_free(weapon.model.instantiate())
	var mesh_instance: MeshInstance3D = model.get_node("Model") as MeshInstance3D
	var bounds: AABB = mesh_instance.transform * mesh_instance.mesh.get_aabb()
	return weapon.swing.hilt_offset + absf(bounds.position.z) * cos(weapon.swing.blade_tilt)


func _assert_range_matches_blade(character_class: CharacterClassData) -> void:
	var expected: float = _tip_reach(character_class) + _enemy_radius()
	assert_float(character_class.base_stats.attack_range).is_equal_approx(expected, REACH_TOLERANCE)


func test_ac211_base_range_reaches_where_the_blade_tip_grazes_the_enemy() -> void:
	_assert_range_matches_blade(WARRIOR)
	_assert_range_matches_blade(BERSERKER)
	_assert_range_matches_blade(SAMURAI)


func test_ac212_the_warrior_hits_a_grunt_stopped_at_its_attack_range() -> void:
	Session.character_class = WARRIOR
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.enemy_registry = _registry
	add_child(player)
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, -GRUNT_STATS.attack_range), null)
	var health_before: float = enemy.health.current_health
	player.attack.advance_cooldown(10.0)
	assert_bool(player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_float(enemy.health.current_health).is_less(health_before)
