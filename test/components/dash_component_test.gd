extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const COMBAT_RULES: CombatRules = preload("res://data/combat/combat_rules.tres")
const BERSERKER_STATS: PlayerStats = preload("res://data/classes/berserker/berserker_stats.tres")
const SAMURAI_STATS: PlayerStats = preload("res://data/classes/samurai/samurai_stats.tres")
const DISPLAY_TABLE: StatDisplayTable = preload("res://data/ui/stat_display_table.tres")
const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const BASE_DASH_SPEED: float = 15.0
const MAX_DASH_FRAMES: int = 120


## Dash wired to plain components, outside the tree: timers are driven by hand.
func _make_dash() -> DashComponent:
	var health: HealthComponent = auto_free(HealthComponent.new())
	health.rules = COMBAT_RULES
	health.setup(100.0, 0.0)
	var stats: StatsComponent = auto_free(StatsComponent.new())
	stats.base_stats = PLAYER_STATS
	stats.rules = COMBAT_RULES
	var dash: DashComponent = auto_free(DashComponent.new())
	dash.health = health
	dash.stats = stats
	return dash


func test_ac14_dash_grants_invulnerability() -> void:
	var dash: DashComponent = _make_dash()
	assert_bool(dash.try_dash(Vector3.FORWARD)).is_true()
	assert_bool(dash.health.is_invulnerable).is_true()
	assert_float(dash.health.receive_hit(50.0)).is_equal_approx(0.0, 0.0001)


func test_ac15_dash_is_rejected_during_cooldown() -> void:
	var dash: DashComponent = _make_dash()
	assert_bool(dash.try_dash(Vector3.FORWARD)).is_true()
	dash.advance_timers(PLAYER_STATS.dash_cooldown - 0.1)
	assert_bool(dash.try_dash(Vector3.FORWARD)).is_false()
	dash.advance_timers(0.15)
	assert_bool(dash.try_dash(Vector3.FORWARD)).is_true()


func test_ac15_dash_ready_is_emitted_when_cooldown_ends() -> void:
	var dash: DashComponent = _make_dash()
	var ready_count: Array[int] = [0]
	dash.dash_ready.connect(func() -> void: ready_count[0] += 1)
	dash.try_dash(Vector3.FORWARD)
	dash.advance_timers(1.0)
	assert_int(ready_count[0]).is_equal(0)
	dash.advance_timers(1.1)
	assert_int(ready_count[0]).is_equal(1)


func test_ac16_dash_covers_dash_distance() -> void:
	var floor_body: StaticBody3D = TestWorld.make_floor(60.0)
	auto_free(floor_body)
	add_child(floor_body)
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	add_child(player)
	for i: int in 20:
		await get_tree().physics_frame
	var start: Vector3 = player.global_position
	var dash: DashComponent = player.get_node("DashComponent") as DashComponent
	assert_bool(dash.try_dash(Vector3.FORWARD)).is_true()
	for i: int in 40:
		await get_tree().physics_frame
	var travelled: float = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	assert_float(travelled).is_equal_approx(PLAYER_STATS.dash_distance, 0.1)


func _spawn_player_on_floor() -> Player:
	var floor_body: StaticBody3D = TestWorld.make_floor(60.0)
	auto_free(floor_body)
	add_child(floor_body)
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	add_child(player)
	for i: int in 20:
		await get_tree().physics_frame
	return player


func _upgrade(player: Player, stat: PlayerStats.Stat, amount: float) -> void:
	var upgrade := UpgradeData.new()
	upgrade.stat = stat
	upgrade.amount = amount
	player.stats.add_upgrade(upgrade)


## Dashes forward and returns [seconds the dash lasted, horizontal distance].
## The duration has a tolerance of one physics frame.
func _measure_dash(player: Player) -> Array[float]:
	var start: Vector3 = player.global_position
	assert_bool(player.dash.try_dash(Vector3.FORWARD)).is_true()
	var frames: int = 0
	await get_tree().physics_frame
	while player.dash.is_dashing() and frames < MAX_DASH_FRAMES:
		await get_tree().physics_frame
		frames += 1
	var travelled: float = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	return [float(frames + 1) / Engine.physics_ticks_per_second, travelled]


func _assert_dash(measured: Array[float], expected_duration: float, expected_distance: float) -> void:
	var frame: float = 1.0 / Engine.physics_ticks_per_second
	assert_float(measured[0]).is_between(expected_duration - frame, expected_duration + frame)
	assert_float(measured[1]).is_equal_approx(expected_distance, 0.1)


func test_ac395_dash_speed_is_the_last_stat_and_every_class_has_one() -> void:
	# Adapted (sprint-stamina.md): the stamina stats come after it; DASH_SPEED keeps
	# its index as the last of the stats before them.
	assert_int(PlayerStats.Stat.DASH_SPEED).is_equal(PlayerStats.Stat.STAMINA_MAX - 1)
	for stats: PlayerStats in [PLAYER_STATS, BERSERKER_STATS, SAMURAI_STATS]:
		assert_float(stats.dash_speed).is_greater(0.0)
		assert_float(stats.get_base(PlayerStats.Stat.DASH_SPEED)).is_equal(stats.dash_speed)


func test_ac396_dash_speed_is_internal() -> void:
	assert_object(DISPLAY_TABLE.find(PlayerStats.Stat.DASH_SPEED)).is_null()
	for upgrade: UpgradeData in CATALOG.upgrades:
		assert_int(upgrade.stat).override_failure_message(upgrade.title).is_not_equal(PlayerStats.Stat.DASH_SPEED)


func test_ac397_dash_lasts_distance_over_speed() -> void:
	var player: Player = await _spawn_player_on_floor()
	var measured: Array[float] = await _measure_dash(player)
	_assert_dash(measured, PLAYER_STATS.dash_distance / PLAYER_STATS.dash_speed, PLAYER_STATS.dash_distance)


func test_ac398_faster_dash_covers_the_same_distance_in_half_the_time() -> void:
	var player: Player = await _spawn_player_on_floor()
	_upgrade(player, PlayerStats.Stat.DASH_SPEED, BASE_DASH_SPEED)
	var measured: Array[float] = await _measure_dash(player)
	_assert_dash(measured, PLAYER_STATS.dash_distance / (2.0 * BASE_DASH_SPEED), PLAYER_STATS.dash_distance)


func test_ac398_longer_dash_lasts_longer_at_the_same_speed() -> void:
	var player: Player = await _spawn_player_on_floor()
	var distance: float = 2.0 * PLAYER_STATS.dash_distance
	_upgrade(player, PlayerStats.Stat.DASH_DISTANCE, PLAYER_STATS.dash_distance)
	var measured: Array[float] = await _measure_dash(player)
	_assert_dash(measured, distance / PLAYER_STATS.dash_speed, distance)


func test_ac399_dash_duration_and_dash_tuning_are_gone() -> void:
	var tuning: PlayerTuning = load("res://data/player/player_tuning.tres")
	assert_bool("dash_duration" in tuning).is_false()
	var dash: DashComponent = auto_free(DashComponent.new())
	assert_bool("tuning" in dash).is_false()


## Dashes forward and returns the seconds the player stayed invulnerable. Also
## checks every frame that invulnerability matches is_dashing().
func _measure_invulnerability(player: Player) -> float:
	assert_bool(player.dash.try_dash(Vector3.FORWARD)).is_true()
	var frames: int = 0
	await get_tree().physics_frame
	while player.health.is_invulnerable and frames < MAX_DASH_FRAMES:
		assert_bool(player.dash.is_dashing()).is_true()
		await get_tree().physics_frame
		frames += 1
	assert_bool(player.dash.is_dashing()).is_false()
	return float(frames) / Engine.physics_ticks_per_second


func _assert_seconds(measured: float, expected: float) -> void:
	var frame: float = 1.0 / Engine.physics_ticks_per_second
	assert_float(measured).is_between(expected - frame, expected + frame)


func test_ac546_iframe_duration_is_no_longer_a_stat() -> void:
	assert_bool(PlayerStats.Stat.has("IFRAME_DURATION")).is_false()
	for stats: PlayerStats in [PLAYER_STATS, BERSERKER_STATS, SAMURAI_STATS]:
		assert_bool("iframe_duration" in stats).is_false()
	for upgrade: UpgradeData in CATALOG.upgrades:
		assert_int(upgrade.stat).override_failure_message(upgrade.title).is_less(PlayerStats.Stat.size())


func test_ac547_warrior_is_invulnerable_exactly_while_dashing() -> void:
	var player: Player = await _spawn_player_on_floor()
	var seconds: float = await _measure_invulnerability(player)
	_assert_seconds(seconds, PLAYER_STATS.dash_distance / PLAYER_STATS.dash_speed)
	assert_bool(player.health.is_invulnerable).is_false()


func test_ac547_samurai_is_invulnerable_exactly_while_dashing() -> void:
	var player: Player = await _spawn_player_on_floor()
	player.stats.set_base_stats(SAMURAI_STATS)
	var seconds: float = await _measure_invulnerability(player)
	_assert_seconds(seconds, SAMURAI_STATS.dash_distance / SAMURAI_STATS.dash_speed)


func test_ac549_invulnerability_follows_dash_upgrades() -> void:
	var player: Player = await _spawn_player_on_floor()
	_upgrade(player, PlayerStats.Stat.DASH_DISTANCE, PLAYER_STATS.dash_distance)
	var longer: float = await _measure_invulnerability(player)
	_assert_seconds(longer, 2.0 * PLAYER_STATS.dash_distance / PLAYER_STATS.dash_speed)
	player.dash.reset_cooldown()
	_upgrade(player, PlayerStats.Stat.DASH_SPEED, PLAYER_STATS.dash_speed)
	var faster: float = await _measure_invulnerability(player)
	_assert_seconds(faster, PLAYER_STATS.dash_distance / PLAYER_STATS.dash_speed)
