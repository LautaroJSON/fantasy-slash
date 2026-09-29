extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
## Offsets that make the test class clearly different from the warrior.
const TEST_DAMAGE_OFFSET: float = 7.0
const TEST_HEALTH_OFFSET: float = 50.0

var _arena: Node3D


func after_test() -> void:
	Session.character_class = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _load_arena() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	preload("res://test/helpers/test_world.gd").without_horde(_arena)
	await get_tree().process_frame


func _player() -> Player:
	return _arena.get_node("Player") as Player


func _ability_picker() -> AbilityPicker:
	return _arena.get_node("UI/AbilityPicker") as AbilityPicker


## A second class built in memory: other base stats and a one-ability pool.
func _make_test_class() -> CharacterClassData:
	var stats: PlayerStats = PLAYER_STATS.duplicate() as PlayerStats
	stats.damage = PLAYER_STATS.damage + TEST_DAMAGE_OFFSET
	stats.max_health = PLAYER_STATS.max_health + TEST_HEALTH_OFFSET
	var pool := AbilityCatalog.new()
	pool.abilities = [SHIELD_CHARGE] as Array[AbilityData]
	var test_class := CharacterClassData.new()
	test_class.base_stats = stats
	test_class.abilities = pool
	test_class.weapon = WARRIOR.weapon
	return test_class


func test_ac180_without_a_chosen_class_the_player_is_a_warrior() -> void:
	await _load_arena()
	var player: Player = _player()
	assert_object(player.get_character_class()).is_same(WARRIOR)
	assert_object(player.stats.base_stats).is_same(PLAYER_STATS)
	assert_float(player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal(PLAYER_STATS.damage)
	assert_array(_ability_picker().get_offered()).contains_exactly_in_any_order([SHIELD_CHARGE, PARRY])


func test_ac181_the_chosen_class_sets_the_stats_and_the_ability_pool() -> void:
	var test_class: CharacterClassData = _make_test_class()
	Session.character_class = test_class
	await _load_arena()
	var player: Player = _player()
	assert_object(player.get_character_class()).is_same(test_class)
	assert_float(player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal(test_class.base_stats.damage)
	assert_float(player.stats.get_stat(PlayerStats.Stat.MAX_HEALTH)).is_equal(test_class.base_stats.max_health)
	assert_float(player.health.max_health).is_equal(test_class.base_stats.max_health)
	assert_float(player.health.current_health).is_equal(test_class.base_stats.max_health)
	assert_array(_ability_picker().get_offered()).is_equal([SHIELD_CHARGE])


func test_ac182_player_upgrades_add_on_top_of_the_class_stats() -> void:
	var test_class: CharacterClassData = _make_test_class()
	Session.character_class = test_class
	await _load_arena()
	_ability_picker().choose(SHIELD_CHARGE)
	var player: Player = _player()
	player.apply_upgrade(DAMAGE_UPGRADE)
	var expected: float = test_class.base_stats.damage + DAMAGE_UPGRADE.amount
	assert_float(player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal(expected)
