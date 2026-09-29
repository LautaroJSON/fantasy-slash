extends GdUnitTestSuite
## Pace of the enemies (docs/specs/enemy-pace.md, enemy-level-pace.md). At level 1
## without Rage every windup lasts ×2.2 and attack_interval ×3.0; the grunt punch:
## 0.5 s windup (0.9 s paced), 0.15 s active, 0.45 s recovery, 0.4 s interval (1.0 s paced).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const PACE: EnemyPaceConfig = preload("res://data/enemies/enemy_pace_config.tres")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const CHARGER: EnemyStats = preload("res://data/enemies/charger_stats.tres")
const LEAPER: EnemyStats = preload("res://data/enemies/leaper_stats.tres")
const HARASSER: EnemyStats = preload("res://data/enemies/harasser_stats.tres")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const TITAN: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const PHYSICS_FPS: float = 60.0

var _registry: EnemyRegistry
var _player: Player


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(80.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)


func _spawn(stats: EnemyStats, at: Vector3, rage_level: int = 0, level: int = 1) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player, level)
	enemy.apply_pace(PACE, rage_level)
	return enemy


## A boss keeping only move `index` of its BossConfig.
func _boss_with(stats: EnemyStats, index: int) -> EnemyStats:
	var copy: EnemyStats = stats.duplicate() as EnemyStats
	var config: BossConfig = stats.behavior_config.duplicate() as BossConfig
	config.moves = [(stats.behavior_config as BossConfig).moves[index]] as Array[BossMoveData]
	copy.behavior_config = config
	return copy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_ac518_ac558_paced_grunt_waits_the_longer_windup() -> void:
	_spawn(GRUNT, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(60)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)
	await _physics_frames(12)
	assert_float(_player.health.current_health).is_equal_approx(91.0, 0.0001)


func test_ac519_ac558_paced_attacks_are_further_apart() -> void:
	_spawn(GRUNT, Vector3(0.0, 0.0, -1.5))
	var punch: EnemyAttackData = GRUNT.attacks[0]
	var hits: Array[int] = []
	var last_health: float = _player.health.current_health
	for frame: int in 360:
		await get_tree().physics_frame
		if _player.health.current_health < last_health:
			hits.append(frame)
			last_health = _player.health.current_health
	assert_int(hits.size()).is_equal(2)
	var cycle: float = punch.windup_time * PACE.windup_scale_for(1, 0) + punch.active_time + punch.recovery_time + GRUNT.attack_interval * PACE.interval_scale_for(1, 0)
	assert_int(hits[1] - hits[0]).is_greater_equal(int(cycle * PHYSICS_FPS) - 1)


func test_ac520_the_floor_warning_lasts_the_paced_windup() -> void:
	var enemy: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(3)
	var telegraph: GroundTelegraph = enemy.get_telegraph()
	assert_float(telegraph.get_duration()).is_equal_approx(GRUNT.attacks[0].windup_time * PACE.windup_scale_for(1, 0), 0.0001)
	await _physics_frames(30)
	assert_float(telegraph.get_fill_ratio()).is_between(0.35, 0.6)


## enemy-level-pace (AC559): level 25 prepares ×1.2; with Rage 2 it is the data pace.
func test_ac521_ac559_high_level_and_rage_speed_up_the_pace() -> void:
	var late: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -1.5), 0, 25)
	assert_float(late.get_windup_scale()).is_equal_approx(1.2, 0.0001)
	await _physics_frames(3)
	assert_float(late.get_telegraph().get_duration()).is_equal_approx(0.6, 0.0001)
	late.deactivate()
	var raged: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -1.5), 2, 25)
	assert_float(raged.get_windup_scale()).is_equal_approx(1.0, 0.0001)
	await _physics_frames(35)
	assert_float(_player.health.current_health).is_less(100.0)


func test_ac522_every_type_stretches_its_windup() -> void:
	_player.health.is_invulnerable = true
	var cases: Array = [
		[CHARGER, Vector3(0.0, 0.0, -5.0), CHARGER.attacks[0].windup_time],
		[LEAPER, Vector3(0.0, 0.0, -6.0), LEAPER.attacks[0].windup_time],
		[HARASSER, Vector3(0.0, 0.0, 4.0), HARASSER.attacks[0].windup_time],
		[_boss_with(VERDUGO, 0), Vector3(0.0, 0.0, -3.0), ((VERDUGO.behavior_config as BossConfig).moves[0] as ComboMoveData).steps[0].windup_time],
		[_boss_with(TITAN, 1), Vector3(0.0, 0.0, -5.0), ((TITAN.behavior_config as BossConfig).moves[1] as SweepMoveData).attack.windup_time],
	]
	for case: Array in cases:
		var enemy: Enemy = _spawn(case[0], case[1])
		await _physics_frames(3)
		var expected: float = float(case[2]) * PACE.windup_scale_for(1, 0)
		if case[0] == LEAPER:
			expected += (LEAPER.attacks[0] as LeapAttackData).leap_time
		assert_float(enemy.get_telegraph().get_duration()).override_failure_message(str(case[1])).is_equal_approx(expected, 0.0001)
		enemy.deactivate()


func test_ac523_activate_restores_the_data_pace() -> void:
	var enemy: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -8.0))
	assert_float(enemy.get_scaled_stats().attack_interval).is_equal_approx(GRUNT.attack_interval * PACE.interval_scale_for(1, 0), 0.0001)
	enemy.activate(Vector3(0.0, 0.0, -8.0), _player)
	assert_float(enemy.get_windup_scale()).is_equal_approx(1.0, 0.0001)
	assert_float(enemy.get_scaled_stats().attack_interval).is_equal_approx(GRUNT.attack_interval, 0.0001)
