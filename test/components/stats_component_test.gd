extends GdUnitTestSuite

const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const COMBAT_RULES: CombatRules = preload("res://data/combat/combat_rules.tres")


func _make_stats() -> StatsComponent:
	var stats: StatsComponent = auto_free(StatsComponent.new())
	stats.base_stats = PLAYER_STATS
	stats.rules = COMBAT_RULES
	return stats


func _make_upgrade(stat: PlayerStats.Stat, amount: float) -> UpgradeData:
	var upgrade := UpgradeData.new()
	upgrade.stat = stat
	upgrade.amount = amount
	return upgrade


func _add_many(stats: StatsComponent, stat: PlayerStats.Stat, amount: float, count: int) -> void:
	for i: int in count:
		stats.add_upgrade(_make_upgrade(stat, amount))


func test_ac5_without_upgrades_every_stat_equals_its_base() -> void:
	var stats: StatsComponent = _make_stats()
	for i: int in PlayerStats.Stat.size():
		var stat: PlayerStats.Stat = i as PlayerStats.Stat
		assert_float(stats.get_stat(stat)).is_equal_approx(PLAYER_STATS.get_base(stat), 0.0001)


func test_ac5_upgrades_accumulate_on_a_single_stat() -> void:
	var stats: StatsComponent = _make_stats()
	_add_many(stats, PlayerStats.Stat.DAMAGE, 4.0, 2)
	assert_float(stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(23.0, 0.0001)
	assert_float(stats.get_stat(PlayerStats.Stat.DEFENSE)).is_equal_approx(PLAYER_STATS.defense, 0.0001)
	assert_int(stats.get_upgrades().size()).is_equal(2)


func test_ac5_upgrades_do_not_mutate_the_base_resource() -> void:
	var stats: StatsComponent = _make_stats()
	_add_many(stats, PlayerStats.Stat.DAMAGE, 4.0, 2)
	assert_float(PLAYER_STATS.damage).is_equal_approx(15.0, 0.0001)


func test_ac5_add_upgrade_emits_stats_changed() -> void:
	var stats: StatsComponent = _make_stats()
	var emissions: Array[int] = [0]
	stats.stats_changed.connect(func() -> void: emissions[0] += 1)
	stats.add_upgrade(_make_upgrade(PlayerStats.Stat.DAMAGE, 4.0))
	assert_int(emissions[0]).is_equal(1)


func test_ac6_crit_chance_is_capped() -> void:
	var stats: StatsComponent = _make_stats()
	_add_many(stats, PlayerStats.Stat.CRIT_CHANCE, 0.05, 20)
	assert_float(stats.get_stat(PlayerStats.Stat.CRIT_CHANCE)).is_equal_approx(COMBAT_RULES.max_crit_chance, 0.0001)


func test_ac6_attack_arc_is_capped() -> void:
	var stats: StatsComponent = _make_stats()
	_add_many(stats, PlayerStats.Stat.ATTACK_ARC, 15.0, 30)
	assert_float(stats.get_stat(PlayerStats.Stat.ATTACK_ARC)).is_equal_approx(COMBAT_RULES.max_attack_arc_degrees, 0.0001)


## The floor is the dash duration + gap since docs/specs/dash-iframes.md (AC550).
func test_ac6_ac550_dash_cooldown_never_drops_below_dash_duration_plus_gap() -> void:
	var stats: StatsComponent = _make_stats()
	_add_many(stats, PlayerStats.Stat.DASH_COOLDOWN, -0.15, 20)
	var floor_value: float = PLAYER_STATS.dash_duration + COMBAT_RULES.min_dash_cooldown_gap
	assert_float(stats.get_stat(PlayerStats.Stat.DASH_COOLDOWN)).is_equal_approx(floor_value, 0.0001)


## Replaces "the floor follows iframe upgrades" (docs/specs/dash-iframes.md).
func test_ac550_dash_cooldown_floor_follows_dash_duration_upgrades() -> void:
	var stats: StatsComponent = _make_stats()
	_add_many(stats, PlayerStats.Stat.DASH_COOLDOWN, -0.15, 20)
	stats.add_upgrade(_make_upgrade(PlayerStats.Stat.DASH_DURATION, PLAYER_STATS.dash_duration))
	var floor_value: float = 2.0 * PLAYER_STATS.dash_duration + COMBAT_RULES.min_dash_cooldown_gap
	assert_float(stats.get_stat(PlayerStats.Stat.DASH_COOLDOWN)).is_equal_approx(floor_value, 0.0001)


## The floor is the longer of the dash movement and its invulnerability plus the gap
## (docs/specs/dash-invulnerability-parameter.md).
func test_ac550_dash_cooldown_floor_follows_dash_invulnerability_upgrades() -> void:
	var stats: StatsComponent = _make_stats()
	_add_many(stats, PlayerStats.Stat.DASH_COOLDOWN, -0.15, 20)
	stats.add_upgrade(_make_upgrade(PlayerStats.Stat.DASH_INVULNERABILITY, 1.0))
	var floor_value: float = PLAYER_STATS.dash_invulnerability + 1.0 + COMBAT_RULES.min_dash_cooldown_gap
	assert_float(stats.get_stat(PlayerStats.Stat.DASH_COOLDOWN)).is_equal_approx(floor_value, 0.0001)
