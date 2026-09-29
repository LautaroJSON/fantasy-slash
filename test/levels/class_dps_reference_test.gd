extends GdUnitTestSuite
## Reference DPS of each class's continuous combo, and the Bruto's time to kill
## (docs/specs/early-power-curve.md §6.1, AC1136, AC1137).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
## A roll that never produces a critical hit: the crit is averaged instead.
const NO_CRIT_ROLL: float = 0.99
const FRAME: float = 1.0 / 60.0
const MEASURE_SECONDS: float = 10.0
## Measured DPS of the continuous combo at level 1, without cards or abilities.
const DPS_WARRIOR: float = 18.732
const DPS_BERSERKER: float = 13.44
const DPS_SAMURAI: float = 28.235
const DPS_REF: float = 20.1357
const DPS_TOLERANCE: float = 0.05
const KILL_TIME: float = 2.0
const KILL_TOLERANCE: float = 0.6

var _registry: EnemyRegistry
var _player: Player


func after_test() -> void:
	Session.character_class = null


func _spawn_player(character_class: CharacterClassData) -> void:
	Session.character_class = character_class
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	ComboDriver.drive_by_hand(_player)
	_player.attack.combo = _with_nearest_enemy_aim(_player.attack.combo)


func _with_nearest_enemy_aim(source: AttackComboConfig) -> AttackComboConfig:
	var combo: AttackComboConfig = source.duplicate(true) as AttackComboConfig
	combo.aim_mode = AttackComboConfig.AimMode.NEAREST_ENEMY
	return combo


func _spawn_target(health: float, stats: EnemyStats) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	enemy.stats = stats
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, -1.4), _player)
	enemy.health.setup(health, 0.0)
	return enemy


## Chains strikes as fast as the combo allows for `seconds` of clip time and
## returns the damage per second, the critical hit averaged.
func _measure_dps(character_class: CharacterClassData, seconds: float) -> float:
	_spawn_player(character_class)
	_spawn_target(1.0e9, GRUNT)
	var total: Array[float] = [0.0]
	_player.attack.attacked.connect(func(_h: int, damage: float, _c: bool) -> void: total[0] += damage)
	var anim: AnimationPlayer = ComboDriver.humanoid_of(_player).anim
	var hitstop: HitstopComponent = _player.get_node("Hitstop") as HitstopComponent
	var elapsed: float = 0.0
	while elapsed < seconds:
		_player.attack.try_attack_with_roll(NO_CRIT_ROLL)
		anim.advance(FRAME)
		_player.attack.advance(FRAME)
		hitstop.advance(FRAME)
		elapsed += FRAME
	var crit_factor: float = 1.0 + _player.stats.get_stat(PlayerStats.Stat.CRIT_CHANCE) * _player.stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE)
	return total[0] * crit_factor / seconds


## Seconds the continuous combo takes to kill a level 1 Bruto.
func _time_to_kill(character_class: CharacterClassData) -> float:
	_spawn_player(character_class)
	var grunt: Enemy = _spawn_target(GRUNT.max_health, GRUNT)
	grunt.health.setup(GRUNT.max_health, GRUNT.defense)
	var anim: AnimationPlayer = ComboDriver.humanoid_of(_player).anim
	var hitstop: HitstopComponent = _player.get_node("Hitstop") as HitstopComponent
	var elapsed: float = 0.0
	while not grunt.health.is_dead() and elapsed < 10.0:
		_player.attack.try_attack_with_roll(NO_CRIT_ROLL)
		anim.advance(FRAME)
		_player.attack.advance(FRAME)
		hitstop.advance(FRAME)
		elapsed += FRAME
	return elapsed



func test_ac1136_class_dps_matches_the_reference_table() -> void:
	for row: Array in [[WARRIOR, DPS_WARRIOR], [BERSERKER, DPS_BERSERKER], [SAMURAI, DPS_SAMURAI]]:
		var measured: float = _measure_dps(row[0], MEASURE_SECONDS)
		assert_float(measured).override_failure_message("%s dps" % row[0].resource_path).is_between(row[1] * (1.0 - DPS_TOLERANCE), row[1] * (1.0 + DPS_TOLERANCE))


## The reference DPS (the average of the classes) kills the Bruto in 2 s; each class takes 40 / its own DPS.
func test_ac1137_a_level_one_grunt_dies_in_about_two_seconds() -> void:
	assert_float(GRUNT.max_health / DPS_REF).is_equal_approx(KILL_TIME, 0.05)
	for row: Array in [[WARRIOR, DPS_WARRIOR], [BERSERKER, DPS_BERSERKER], [SAMURAI, DPS_SAMURAI]]:
		var seconds: float = _time_to_kill(row[0])
		assert_float(seconds).override_failure_message("%s kill time" % row[0].resource_path).is_between(GRUNT.max_health / row[1] - KILL_TOLERANCE, GRUNT.max_health / row[1] + KILL_TOLERANCE)
