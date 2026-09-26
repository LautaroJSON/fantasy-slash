extends GdUnitTestSuite
## Floor warnings of every enemy attack (docs/specs/enemy-ground-telegraph.md).
## The player stays invulnerable: only the warnings are checked here.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const GROUP_AI: GroupAIConfig = preload("res://data/enemies/group_ai_config.tres")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const SHIELDBEARER: EnemyStats = preload("res://data/enemies/shieldbearer_stats.tres")
const CHARGER: EnemyStats = preload("res://data/enemies/charger_stats.tres")
const LEAPER: EnemyStats = preload("res://data/enemies/leaper_stats.tres")
const HARASSER: EnemyStats = preload("res://data/enemies/harasser_stats.tres")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const TITAN: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const EPS := Vector3(0.05, 0.05, 0.05)

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
	_player.health.is_invulnerable = true


func _spawn(stats: EnemyStats, at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
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


## Physics frames until the warning flashes (−1 if it never does within `limit`).
func _frames_until_flash(telegraph: GroundTelegraph, limit: int) -> int:
	for i: int in limit:
		await get_tree().physics_frame
		if telegraph.is_flashing():
			return i
	return -1


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


func test_ac505_grunt_sector_fills_flashes_and_hides() -> void:
	var enemy: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -1.5))
	var punch: EnemyAttackData = GRUNT.attacks[0]
	var telegraph: GroundTelegraph = enemy.get_telegraph()
	await _physics_frames(5)
	assert_int(telegraph.get_shape()).is_equal(GroundTelegraph.Shape.SECTOR)
	assert_float(telegraph.get_size()).is_equal_approx(punch.hit_range, 0.001)
	assert_float(telegraph.get_arc()).is_equal_approx(punch.hit_arc_degrees, 0.001)
	assert_float(telegraph.get_fill_ratio()).is_between(0.05, 0.3)
	assert_vector(telegraph.get_direction()).is_equal_approx(enemy.get_facing(), EPS)
	var frames: int = await _frames_until_flash(telegraph, 60)
	assert_int(frames).is_between(20, 30)
	await _physics_frames(30)
	assert_bool(telegraph.is_showing()).is_false()


func test_ac506_a_cancelled_windup_clears_the_warning() -> void:
	var enemy: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(10)
	assert_bool(enemy.get_telegraph().is_showing()).is_true()
	enemy.apply_knockback(Vector3(0.0, 0.0, -1.0), 5.0)
	assert_bool(enemy.get_telegraph().is_showing()).is_false()


## boss-colmena (AC543): the Gemelos are gone; the Escudero remains.
func test_ac507_shieldbearer_shows_its_sector() -> void:
	var shield: Enemy = _spawn(SHIELDBEARER, Vector3(0.0, 0.0, 1.9))
	await _physics_frames(5)
	assert_int(shield.get_telegraph().get_shape()).is_equal(GroundTelegraph.Shape.SECTOR)
	assert_float(shield.get_telegraph().get_size()).is_equal_approx(SHIELDBEARER.attacks[0].hit_range, 0.001)


func test_ac508_charger_line_follows_then_flashes() -> void:
	var enemy: Enemy = _spawn(CHARGER, Vector3(0.0, 0.0, -5.0))
	var charge: ChargeAttackData = CHARGER.attacks[0] as ChargeAttackData
	var telegraph: GroundTelegraph = enemy.get_telegraph()
	await _physics_frames(5)
	assert_int(telegraph.get_shape()).is_equal(GroundTelegraph.Shape.LINE)
	assert_float(telegraph.get_size()).is_equal_approx(charge.charge_distance + charge.hit_range, 0.001)
	assert_float(telegraph.get_width()).is_equal_approx(2.0 * charge.hit_range, 0.001)
	_player.global_position = Vector3(3.0, 0.0, 0.0)
	await _physics_frames(15)
	assert_vector(telegraph.get_direction()).is_equal_approx(enemy.get_facing(), EPS)
	assert_int(await _frames_until_flash(telegraph, 60)).is_not_equal(-1)
	await _physics_frames(60)
	assert_bool(telegraph.is_showing()).is_false()


func test_ac509_leaper_circle_follows_then_locks_and_dusts() -> void:
	var enemy: Enemy = _spawn(LEAPER, Vector3(0.0, 0.0, -6.0))
	var telegraph: GroundTelegraph = enemy.get_telegraph()
	await _physics_frames(10)
	assert_int(telegraph.get_shape()).is_equal(GroundTelegraph.Shape.CIRCLE)
	assert_float(telegraph.get_size()).is_equal_approx(LEAPER.attacks[0].hit_range, 0.001)
	_player.global_position = Vector3(1.0, 0.0, 0.0)
	await _physics_frames(5)
	assert_float(telegraph.get_origin().x).is_equal_approx(1.0, 0.05)
	await _physics_frames(35)
	var locked: Vector3 = telegraph.get_origin()
	_player.global_position = Vector3(5.0, 0.0, 5.0)
	await _physics_frames(5)
	assert_vector(telegraph.get_origin()).is_equal_approx(locked, EPS)
	assert_int(await _frames_until_flash(telegraph, 90)).is_not_equal(-1)
	assert_bool(telegraph.get_dust().emitting).is_true()


func test_ac510_harasser_lunge_line() -> void:
	var enemy: Enemy = _spawn(HARASSER, Vector3(0.0, 0.0, 4.0))
	var telegraph: GroundTelegraph = enemy.get_telegraph()
	await _physics_frames(3)
	assert_int(telegraph.get_shape()).is_equal(GroundTelegraph.Shape.LINE)
	assert_float(telegraph.get_width()).is_equal_approx(HARASSER.attacks[0].hit_range, 0.001)
	assert_int(await _frames_until_flash(telegraph, 30)).is_not_equal(-1)


func test_ac511_verdugo_slash_grab_and_shockwave() -> void:
	var slash: Enemy = _spawn(_boss_with(VERDUGO, 0), Vector3(0.0, 0.0, -3.0))
	var telegraph: GroundTelegraph = slash.get_telegraph()
	await _physics_frames(5)
	var step: EnemyAttackData = ((VERDUGO.behavior_config as BossConfig).moves[0] as ComboMoveData).steps[0]
	assert_int(telegraph.get_shape()).is_equal(GroundTelegraph.Shape.SECTOR)
	assert_float(telegraph.get_size()).is_equal_approx(step.hit_range, 0.001)
	var flashes: int = 0
	var was_flashing: bool = false
	for i: int in 130:
		await get_tree().physics_frame
		if telegraph.is_flashing() and not was_flashing:
			flashes += 1
		was_flashing = telegraph.is_flashing()
	assert_int(flashes).is_equal(3)
	slash.deactivate()
	var grab: Enemy = _spawn(_boss_with(VERDUGO, 2), Vector3(0.0, 0.0, -3.5))
	await _physics_frames(5)
	assert_int(grab.get_telegraph().get_shape()).is_equal(GroundTelegraph.Shape.LINE)
	grab.deactivate()
	var wave: Enemy = _spawn(_boss_with(VERDUGO, 1), Vector3(0.0, 0.0, -6.0))
	await _physics_frames(5)
	assert_bool(wave.get_telegraph().is_showing()).is_false()


func test_ac512_titan_slam_circle_locks_and_sweep_sector() -> void:
	var slam: Enemy = _spawn(_boss_with(TITAN, 0), Vector3(0.0, 0.0, -6.0))
	var telegraph: GroundTelegraph = slam.get_telegraph()
	await _physics_frames(5)
	assert_int(telegraph.get_shape()).is_equal(GroundTelegraph.Shape.CIRCLE)
	assert_float(telegraph.get_size()).is_equal_approx(((TITAN.behavior_config as TitanConfig).moves[0] as HandSlamMoveData).impact_radius, 0.001)
	await _physics_frames(55)
	var locked: Vector3 = telegraph.get_origin()
	_player.global_position = Vector3(6.0, 0.0, 0.0)
	await _physics_frames(10)
	assert_vector(telegraph.get_origin()).is_equal_approx(locked, EPS)
	assert_int(await _frames_until_flash(telegraph, 60)).is_not_equal(-1)
	assert_bool(telegraph.get_dust().emitting).is_true()
	slam.deactivate()
	_player.global_position = Vector3.ZERO
	var sweep: Enemy = _spawn(_boss_with(TITAN, 1), Vector3(0.0, 0.0, -5.0))
	await _physics_frames(5)
	assert_int(sweep.get_telegraph().get_shape()).is_equal(GroundTelegraph.Shape.SECTOR)
	assert_float(sweep.get_telegraph().get_arc()).is_equal_approx(200.0, 0.001)


func test_ac513_activate_and_deactivate_clear_the_warning() -> void:
	var enemy: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -1.5))
	await _physics_frames(5)
	assert_bool(enemy.get_telegraph().is_showing()).is_true()
	enemy.deactivate()
	assert_bool(enemy.get_telegraph().is_showing()).is_false()
	enemy.activate(Vector3(0.0, 0.0, -12.0), _player)
	assert_bool(enemy.get_telegraph().is_showing()).is_false()


func test_ac514_no_warning_without_an_attack() -> void:
	var coordinator: AttackCoordinator = auto_free(AttackCoordinator.new())
	coordinator.config = GROUP_AI
	coordinator.registry = _registry
	coordinator.player = _player
	add_child(coordinator)
	# Both tokens held by target-less blockers.
	for i: int in 2:
		var blocker: Enemy = auto_free(ENEMY_SCENE.instantiate())
		blocker.registry = _registry
		blocker.coordinator = coordinator
		add_child(blocker)
		blocker.activate(Vector3(30.0 + 3.0 * i, 0.0, 30.0), null)
		coordinator.advance(GROUP_AI.token_gap)
		coordinator.request_token(blocker)
		blocker.begin_attack()
	var waiting: Enemy = auto_free(ENEMY_SCENE.instantiate())
	waiting.registry = _registry
	waiting.coordinator = coordinator
	add_child(waiting)
	waiting.activate(Vector3(0.0, 0.0, -1.5), _player)
	var rising: Enemy = _spawn(GRUNT, Vector3(2.0, 0.0, -1.5))
	rising.begin_spawn_in(GROUP_AI)
	for i: int in 40:
		await get_tree().physics_frame
		assert_bool(waiting.get_telegraph().is_showing()).is_false()
		assert_bool(rising.get_telegraph().is_showing()).is_false()
