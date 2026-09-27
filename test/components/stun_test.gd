extends GdUnitTestSuite
## docs/specs/warrior-abilities-rework.md §3.3 and §4.2: the stun (AC804–AC811).

const TestWorld := preload("res://test/helpers/test_world.gd")
const StatusOverlayProbe := preload("res://test/helpers/status_overlay_probe.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const BOSS_BAR_SCENE: PackedScene = preload("res://ui/boss_health_bar.tscn")
const BOSS_BAR_CONFIG: BossBarConfig = preload("res://data/ui/boss_bar_config.tres")
const GROUP_AI: GroupAIConfig = preload("res://data/enemies/group_ai_config.tres")
const STUN: DebuffData = preload("res://data/debuffs/stun.tres")
const WEAKEN: DebuffData = preload("res://data/debuffs/weaken.tres")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const CHARGER: EnemyStats = preload("res://data/enemies/charger_stats.tres")
const LEAPER: EnemyStats = preload("res://data/enemies/leaper_stats.tres")
const HARASSER: EnemyStats = preload("res://data/enemies/harasser_stats.tres")
const SHIELDBEARER: EnemyStats = preload("res://data/enemies/shieldbearer_stats.tres")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const TITAN: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const COLMENA: EnemyStats = preload("res://data/enemies/colmena_stats.tres")
const TOLERANCE: float = 0.001
const FRAME: float = 1.0 / 60.0

var _registry: EnemyRegistry
var _player: Player
var _coordinator: AttackCoordinator


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_coordinator = auto_free(AttackCoordinator.new())
	_coordinator.config = GROUP_AI
	_coordinator.registry = _registry
	_coordinator.player = _player
	add_child(_coordinator)


func _spawn(stats: EnemyStats, at: Vector3, with_target: bool = true, with_coordinator: bool = false) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	if with_coordinator:
		enemy.coordinator = _coordinator
	add_child(enemy)
	enemy.activate(at, _player if with_target else null)
	return enemy


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Where each type starts an attack at once (the player faces −Z, so +Z is behind).
func _attack_spot(stats: EnemyStats) -> Vector3:
	match stats:
		CHARGER:
			return Vector3(0.0, 0.0, -5.0)
		LEAPER:
			return Vector3(0.0, 0.0, -6.0)
		HARASSER:
			return Vector3(0.0, 0.0, 4.0)
	return Vector3(0.0, 0.0, 1.9)


func test_ac804_stun_data() -> void:
	assert_int(DebuffData.Effect.SLOW).is_equal(4)
	assert_int(DebuffData.Effect.STUN).is_equal(5)
	assert_int(STUN.effect).is_equal(5)
	assert_str(STUN.icon.resource_path).is_equal("res://assets/icons/status/knocked_out_stars.svg")
	assert_that(STUN.icon_color).is_equal(Color(1.0, 0.95, 0.55))
	assert_bool(STUN.is_beneficial).is_false()
	var source: String = FileAccess.get_file_as_string("res://assets/icons/status/SOURCE.md")
	assert_str(source).contains("`knocked_out_stars.svg`")
	assert_str(source).contains("delapouite/knocked-out-stars")


func test_ac805_apply_takes_its_own_duration() -> void:
	var enemy: Enemy = _spawn(GRUNT, Vector3(20.0, 0.0, 20.0), false)
	enemy.debuffs.apply(STUN, 1.0, 2.5)
	assert_float(enemy.debuffs.get_remaining_seconds(STUN.id)).is_equal_approx(2.5, TOLERANCE)
	enemy.debuffs.advance(0.5)
	enemy.debuffs.apply(STUN, 1.0, 1.0)
	assert_float(enemy.debuffs.get_remaining_seconds(STUN.id)).is_equal_approx(2.0, TOLERANCE)
	enemy.debuffs.apply(STUN, 1.0, 3.0)
	assert_float(enemy.debuffs.get_remaining_seconds(STUN.id)).is_equal_approx(3.0, TOLERANCE)
	var active: DebuffComponent.ActiveDebuff = enemy.debuffs.get_active()[0]
	enemy.debuffs.advance(1.5)
	assert_float(DebuffComponent.get_remaining_ratio(active)).is_equal_approx(0.5, TOLERANCE)
	# Without the third parameter nothing changes: the data's duration.
	enemy.debuffs.apply(WEAKEN, 0.1)
	assert_float(enemy.debuffs.get_remaining_seconds(WEAKEN.id)).is_equal_approx(WEAKEN.duration, TOLERANCE)


func test_ac806_a_stunned_common_enemy_stands_still_and_acts_again_after() -> void:
	var enemy: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -8.0))
	await _frames(5)
	enemy.stun(STUN, 0.5)
	assert_bool(enemy.is_stunned()).is_true()
	await _frames(1)
	assert_float(enemy.get_speed_scale()).is_equal(0.0)
	var position: Vector3 = enemy.global_position
	var heading: float = enemy.rotation.y
	await _frames(15)
	assert_float(Vector2(enemy.global_position.x - position.x, enemy.global_position.z - position.z).length()).is_less(TOLERANCE)
	assert_float(enemy.rotation.y).is_equal_approx(heading, TOLERANCE)
	await _frames(30)
	assert_bool(enemy.is_stunned()).is_false()
	var moved_from: Vector3 = enemy.global_position
	await _frames(10)
	assert_float(enemy.global_position.distance_to(moved_from)).is_greater(0.05)


func test_ac807_a_stunned_grunt_gives_its_attack_turn_back() -> void:
	var enemy: Enemy = _spawn(GRUNT, _attack_spot(GRUNT), true, true)
	for i: int in 5:
		await get_tree().physics_frame
	assert_bool(enemy.get_behavior().is_attacking()).is_true()
	assert_bool(_coordinator.has_token(enemy)).is_true()
	enemy.stun(STUN, 1.0)
	assert_bool(enemy.get_behavior().is_attacking()).is_false()
	assert_bool(_coordinator.has_token(enemy)).is_false()


func test_ac807_a_stun_cancels_the_windup_of_every_common_type() -> void:
	for stats: EnemyStats in [GRUNT, CHARGER, LEAPER, HARASSER, SHIELDBEARER] as Array[EnemyStats]:
		var enemy: Enemy = _spawn(stats, _attack_spot(stats))
		for i: int in 5:
			await get_tree().physics_frame
		var label: String = stats.resource_path
		assert_bool(enemy.get_behavior().is_attacking()).override_failure_message(label).is_true()
		enemy.stun(STUN, 1.0)
		assert_bool(enemy.get_behavior().is_attacking()).override_failure_message(label).is_false()
		assert_bool(enemy.get_telegraph().is_showing()).override_failure_message(label).is_false()
		enemy.deactivate()


func test_ac808_a_pushed_enemy_keeps_sliding_while_stunned() -> void:
	var enemy: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -8.0), false)
	await _frames(3)
	enemy.apply_knockback(Vector3.FORWARD, 8.0)
	enemy.stun(STUN, 1.0)
	var start: Vector3 = enemy.global_position
	await _frames(10)
	assert_float(enemy.global_position.distance_to(start)).is_greater(0.3)
	assert_bool(enemy.is_stunned()).is_true()


func test_ac809_bosses_are_stunned_less_and_resume_their_attack() -> void:
	for stats: EnemyStats in [VERDUGO, TITAN, COLMENA] as Array[EnemyStats]:
		assert_float(stats.stun_duration_scale).override_failure_message(stats.resource_path).is_equal_approx(0.3, TOLERANCE)
		assert_bool(stats.resists_control).is_true()
	var boss: Enemy = _spawn(VERDUGO, Vector3(0.0, 0.0, -2.5))
	var behavior: BossBehavior = boss.get_behavior() as BossBehavior
	for i: int in 120:
		await get_tree().physics_frame
		if behavior.is_attacking():
			break
	assert_bool(behavior.is_attacking()).is_true()
	boss.stun(STUN, 1.0)
	assert_float(boss.debuffs.get_remaining_seconds(STUN.id)).is_equal_approx(0.3, TOLERANCE)
	assert_bool(behavior.is_attacking()).is_true()
	var phase: BossBehavior.Phase = behavior.get_phase()
	var time: float = behavior._time
	await _frames(10)
	assert_bool(boss.is_stunned()).is_true()
	assert_int(behavior.get_phase()).is_equal(phase)
	assert_float(behavior._time).is_equal_approx(time, TOLERANCE)
	await _frames(15)
	assert_bool(boss.is_stunned()).is_false()


func test_ac810_immune_dead_or_rising_enemies_are_not_stunned() -> void:
	var immune_stats: EnemyStats = GRUNT.duplicate() as EnemyStats
	immune_stats.stun_duration_scale = 0.0
	var immune: Enemy = _spawn(immune_stats, Vector3(20.0, 0.0, 20.0), false)
	immune.stun(STUN, 1.0)
	assert_bool(immune.is_stunned()).is_false()
	var dead: Enemy = _spawn(GRUNT, Vector3(-20.0, 0.0, 20.0), false)
	dead.health.receive_hit(100000.0)
	dead.stun(STUN, 1.0)
	assert_bool(dead.is_stunned()).is_false()
	var inactive: Enemy = _spawn(GRUNT, Vector3(20.0, 0.0, -20.0), false)
	inactive.deactivate()
	inactive.stun(STUN, 1.0)
	assert_bool(inactive.is_stunned()).is_false()
	var rising: Enemy = _spawn(GRUNT, Vector3(-20.0, 0.0, -20.0), false)
	rising.begin_spawn_in(GROUP_AI)
	rising.stun(STUN, 1.0)
	assert_bool(rising.is_stunned()).is_false()


func test_ac811_the_stun_icon_shows_on_commons_and_bosses() -> void:
	var enemy: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -6.0), false)
	var probe: StatusOverlayProbe = auto_free(StatusOverlayProbe.new())
	add_child(probe)
	probe.watch(enemy)
	enemy.stun(STUN, 1.0)
	assert_object(probe.row().icon(0).get_glyph_texture()).is_same(STUN.icon)
	enemy.debuffs.advance(1.1)
	assert_int(probe.visible_icon_count()).is_equal(0)
	var boss: Enemy = _spawn(VERDUGO, Vector3(10.0, 0.0, -10.0), false)
	var bar: BossHealthBar = auto_free(BOSS_BAR_SCENE.instantiate())
	add_child(bar)
	bar.setup(BOSS_BAR_CONFIG)
	bar.track(boss)
	boss.stun(STUN, 1.0)
	assert_int(bar.get_visible_debuff_count()).is_equal(1)
	assert_object(bar.get_debuff_icon(0).get_glyph_texture()).is_same(STUN.icon)
