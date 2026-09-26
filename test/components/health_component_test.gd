extends GdUnitTestSuite

const COMBAT_RULES: CombatRules = preload("res://data/combat/combat_rules.tres")


func _make_health(max_hp: float, defense: float) -> HealthComponent:
	var health: HealthComponent = auto_free(HealthComponent.new())
	health.rules = COMBAT_RULES
	health.setup(max_hp, defense)
	return health


func test_ac4_hit_applies_defense() -> void:
	var health: HealthComponent = _make_health(100.0, 3.0)
	var applied: float = health.receive_hit(8.0)
	assert_float(applied).is_equal_approx(5.0, 0.0001)
	assert_float(health.current_health).is_equal_approx(95.0, 0.0001)


func test_ac4_overkill_returns_only_remaining_health() -> void:
	var health: HealthComponent = _make_health(10.0, 0.0)
	var applied: float = health.receive_hit(25.0)
	assert_float(applied).is_equal_approx(10.0, 0.0001)
	assert_float(health.current_health).is_equal_approx(0.0, 0.0001)
	assert_bool(health.is_dead()).is_true()


func test_ac4_died_is_emitted_once() -> void:
	var health: HealthComponent = _make_health(10.0, 0.0)
	var deaths: Array[int] = [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	health.receive_hit(25.0)
	health.receive_hit(25.0)
	assert_int(deaths[0]).is_equal(1)


func test_ac4_dead_takes_no_damage() -> void:
	var health: HealthComponent = _make_health(10.0, 0.0)
	health.receive_hit(25.0)
	assert_float(health.receive_hit(5.0)).is_equal_approx(0.0, 0.0001)


func test_ac4_heal_is_capped_at_max() -> void:
	var health: HealthComponent = _make_health(100.0, 0.0)
	health.receive_hit(10.0)
	health.heal(50.0)
	assert_float(health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac4_invulnerable_takes_no_damage() -> void:
	var health: HealthComponent = _make_health(100.0, 0.0)
	health.is_invulnerable = true
	assert_float(health.receive_hit(30.0)).is_equal_approx(0.0, 0.0001)
	assert_float(health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac4_raising_max_health_heals_the_difference() -> void:
	var health: HealthComponent = _make_health(100.0, 0.0)
	health.receive_hit(30.0)
	health.set_max_health(120.0)
	assert_float(health.max_health).is_equal_approx(120.0, 0.0001)
	assert_float(health.current_health).is_equal_approx(90.0, 0.0001)
