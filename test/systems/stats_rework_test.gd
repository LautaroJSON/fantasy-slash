extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const FIXED_STATS: Array[PlayerStats.Stat] = [
	PlayerStats.Stat.ATTACK_ARC, PlayerStats.Stat.DASH_DISTANCE, PlayerStats.Stat.DASH_COOLDOWN,
	PlayerStats.Stat.JUMP_VELOCITY, PlayerStats.Stat.DASH_DURATION,
]
const CRIT_ROLL: float = 0.0
const NO_CRIT_ROLL: float = 0.99
const EPSILON: float = 0.0001

var _registry: EnemyRegistry


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)


func after_test() -> void:
	Session.character_class = null


func _assert_starting_stats(stats: PlayerStats) -> void:
	assert_float(stats.crit_chance).is_equal_approx(0.05, EPSILON)
	assert_float(stats.crit_damage).is_equal_approx(1.0, EPSILON)
	assert_float(stats.lifesteal).is_equal_approx(0.0, EPSILON)
	assert_float(stats.dash_cooldown).is_equal_approx(1.5, EPSILON)
	assert_float(stats.dash_distance).is_equal_approx(3.0, EPSILON)


## Damage the warrior's basic attack deals to a fresh enemy with this roll.
func _hit_with_roll(roll: float) -> float:
	Session.character_class = WARRIOR
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.enemy_registry = _registry
	add_child(player)
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, -1.5), null)
	enemy.health.defense = 0.0
	var before: float = enemy.health.current_health
	ComboDriver.drive_by_hand(player)
	ComboDriver.use_unit_combo(player)
	assert_bool(ComboDriver.strike(player, roll)).is_true()
	var dealt: float = before - enemy.health.current_health
	enemy.deactivate()
	return dealt


func test_ac229_every_class_starts_with_the_new_base_stats() -> void:
	_assert_starting_stats(WARRIOR.base_stats)
	_assert_starting_stats(BERSERKER.base_stats)


func test_ac230_a_base_crit_deals_double_damage() -> void:
	var normal: float = _hit_with_roll(NO_CRIT_ROLL)
	var crit: float = _hit_with_roll(CRIT_ROLL)
	assert_float(normal).is_greater(0.0)
	assert_float(crit).is_equal_approx(normal * 2.0, EPSILON)


func test_ac232_the_catalog_has_ten_cards_and_no_fixed_stat() -> void:
	# 10 from stats-rework.md + "Acumulación de Aflicción" (affliction.md, AC859).
	assert_int(CATALOG.upgrades.size()).is_equal(11)
	for upgrade: UpgradeData in CATALOG.upgrades:
		assert_bool(FIXED_STATS.has(upgrade.stat)).override_failure_message(upgrade.title).is_false()
