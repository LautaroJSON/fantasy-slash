extends GdUnitTestSuite
## Stamina (docs/specs/sprint-stamina.md): AC699-AC702.

const SAMURAI_STATS: PlayerStats = preload("res://data/classes/samurai/samurai_stats.tres")
const RULES: CombatRules = preload("res://data/combat/combat_rules.tres")
const CONFIG: SprintConfig = preload("res://data/player/sprint_config.tres")

var _stats: StatsComponent
var _stamina: StaminaComponent
var _changes: Array[Vector2] = []
var _depleted_count: int = 0


func before_test() -> void:
	_changes.clear()
	_depleted_count = 0
	_stats = auto_free(StatsComponent.new())
	_stats.base_stats = SAMURAI_STATS
	_stats.rules = RULES
	add_child(_stats)
	_stamina = auto_free(StaminaComponent.new())
	_stamina.stats = _stats
	_stamina.config = CONFIG
	_stamina.set_physics_process(false)
	add_child(_stamina)
	_stamina.stamina_changed.connect(func(current: float, maximum: float) -> void: _changes.append(Vector2(current, maximum)))
	_stamina.depleted.connect(func() -> void: _depleted_count += 1)


func _stamina_upgrade(amount: float) -> UpgradeData:
	var upgrade := UpgradeData.new()
	upgrade.stat = PlayerStats.Stat.STAMINA_MAX
	upgrade.amount = amount
	return upgrade


func test_ac699_starts_full_and_refills() -> void:
	assert_float(_stamina.get_current()).is_equal(100.0)
	assert_float(_stamina.get_max()).is_equal(100.0)
	_stamina.spend(60.0)
	_stamina.refill()
	assert_float(_stamina.get_current()).is_equal(100.0)


func test_ac700_spend_clamps_at_zero_and_depletes_once() -> void:
	_stamina.spend(30.0)
	assert_float(_stamina.get_current()).is_equal(70.0)
	assert_vector(_changes[-1]).is_equal(Vector2(70.0, 100.0))
	_stamina.spend(90.0)
	assert_float(_stamina.get_current()).is_equal(0.0)
	_stamina.spend(10.0)
	assert_float(_stamina.get_current()).is_equal(0.0)
	assert_int(_depleted_count).is_equal(1)
	assert_bool(_stamina.has_at_least(CONFIG.stamina_to_start_sprint)).is_false()


func test_ac701_regenerates_after_the_delay_up_to_the_max() -> void:
	_stamina.spend(50.0)
	_stamina.advance(CONFIG.stamina_regen_delay - 0.1)
	assert_float(_stamina.get_current()).is_equal(50.0)
	_stamina.advance(0.2)  # past the delay: this step already regenerates
	assert_float(_stamina.get_current()).is_equal_approx(55.0, 0.01)
	_stamina.advance(1.0)
	assert_float(_stamina.get_current()).is_equal_approx(80.0, 0.01)
	_stamina.advance(5.0)
	assert_float(_stamina.get_current()).is_equal(100.0)


func test_ac702_a_lower_max_trims_the_current_stamina() -> void:
	var upgrade: UpgradeData = _stamina_upgrade(50.0)
	_stats.add_upgrade(upgrade)
	_stamina.refill()
	assert_float(_stamina.get_current()).is_equal(150.0)
	_stats.remove_upgrade(upgrade)
	assert_float(_stamina.get_current()).is_equal(100.0)
	assert_vector(_changes[-1]).is_equal(Vector2(100.0, 100.0))
