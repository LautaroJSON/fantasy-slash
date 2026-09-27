extends GdUnitTestSuite
## Which ability hits show the impact VFX (docs/specs/hit-impact-vfx.md, AC938):
## Sheathe and Spin (its dash slash too) do; an ability whose data does not ask
## for it and the Berserker's air slash do not.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const SWIFT_STRIKE: AbilityData = preload("res://data/abilities/swift_strike/swift_strike.tres")
const STEP: float = 0.05
const TOLERANCE: float = 0.0001

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _host: HitImpactVfxHost


func after_test() -> void:
	Session.character_class = null


func _make_player(character_class: CharacterClassData) -> void:
	Session.character_class = character_class
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_ability.set_physics_process(false)
	_host = _player.get_node("HitImpactVfx") as HitImpactVfxHost
	await get_tree().physics_frame


func _spawn_enemy(offset: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(_player.global_position + offset, null)
	enemy.set_physics_process(false)
	return enemy


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


func _ahead(distance: float) -> Vector3:
	var visual: Node3D = _player.get_node("Visual") as Node3D
	return -visual.global_basis.z * distance


func test_ac938_a_sheathe_release_shows_the_impact() -> void:
	await _make_player(SAMURAI)
	_ability.equip(SHEATHE)
	_spawn_enemy(_ahead(2.0))
	assert_bool(_ability.try_cast()).is_true()
	_advance(1.0)
	assert_bool(_ability.release_charge()).is_true()
	assert_int(_host.get_active_count()).is_equal(1)


func test_ac938_a_spin_turn_shows_the_impact() -> void:
	await _make_player(BERSERKER)
	_ability.equip(SPIN)
	_spawn_enemy(Vector3(2.0, 0.0, 0.0))
	assert_bool(_ability.try_cast()).is_true()
	_advance(0.9)
	assert_int(_host.get_active_count()).is_equal(0)
	_advance(0.2)
	assert_int(_host.get_active_count()).is_equal(1)


func test_ac938_the_spin_dash_slash_hit_shows_the_impact() -> void:
	await _make_player(BERSERKER)
	_ability.equip(SPIN)
	var enemy: Enemy = _spawn_enemy(Vector3(2.0, 0.0, 0.0))
	# The dash slash reports its hits through the same ability (spin_ability.gd).
	_ability.report_hit(enemy, 1.0, false)
	assert_int(_host.get_active_count()).is_equal(1)


func test_ac938_an_ability_without_the_flag_shows_nothing() -> void:
	await _make_player(SAMURAI)
	assert_bool(SWIFT_STRIKE.shows_hit_impact).is_false()
	_ability.equip(SWIFT_STRIKE)
	var enemy: Enemy = _spawn_enemy(_ahead(2.0))
	_ability.report_hit(enemy, 1.0, false)
	assert_int(_host.get_active_count()).is_equal(0)


func test_ac938_the_air_slash_shows_nothing() -> void:
	await _make_player(BERSERKER)
	var enemy: Enemy = _spawn_enemy(_ahead(2.0))
	_player.air_slash.enemy_hit.emit(enemy, 1.0, false)
	assert_int(_host.get_active_count()).is_equal(0)
