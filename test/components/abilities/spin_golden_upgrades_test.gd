extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const SPIN_CONFIG: SpinConfig = preload("res://data/abilities/spin/spin_config.tres")
const ARMOR_BREAK: AbilityUniqueUpgradeData = preload("res://data/abilities/spin/unique/armor_break.tres")
const INVIGORATING: AbilityUniqueUpgradeData = preload("res://data/abilities/spin/unique/invigorating.tres")
const WEAKEN: DebuffData = preload("res://data/debuffs/weaken.tres")
const CONCUSSION: BuffData = preload("res://data/buffs/concussion.tres")
const ENEMY_HEALTH: float = 40.0
const STEP: float = 0.05
const TOLERANCE: float = 0.0001

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _spin: SpinAbility
var _crits: Array[bool] = []


func before_test() -> void:
	Session.character_class = BERSERKER
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_ability.equip(SPIN)
	_spin = _ability.get_behavior() as SpinAbility
	_crits.clear()
	_ability.enemy_hit.connect(func(_e: Enemy, _a: float, is_crit: bool) -> void: _crits.append(is_crit))
	await _physics_frames(20)


func after_test() -> void:
	Session.character_class = null
	Input.action_release(&"move_forward")


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Idle enemy (no target) whose health is lowered to `health_left` first.
func _spawn_idle_enemy(offset: Vector3, health_left: float = ENEMY_HEALTH) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(_player.global_position + offset, null)
	if health_left < ENEMY_HEALTH:
		enemy.health.receive_true_damage(ENEMY_HEALTH - health_left)
	return enemy


## Drives the cast by hand (the slot's own physics step is off) for determinism.
func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


## Buffs are frozen too, so stacks only change when the test says so.
func _cast_by_hand() -> void:
	_ability.set_physics_process(false)
	_player.buffs.set_physics_process(false)
	assert_bool(_ability.try_cast()).is_true()


func _hit_damage() -> float:
	return _ability.get_stat(AbilityData.Stat.BASE_DAMAGE) \
		+ _ability.get_stat(AbilityData.Stat.ATTACK_SCALING) * _player.stats.get_stat(PlayerStats.Stat.DAMAGE)


func _add_concussion(stacks: int) -> void:
	for i: int in stacks:
		_player.buffs.add_stack(CONCUSSION)


func test_ac284_unique_cards_of_the_spin() -> void:
	assert_that(ARMOR_BREAK.id).is_equal(&"armor_break")
	assert_str(ARMOR_BREAK.title).is_equal("Rompecorazas")
	assert_int(ARMOR_BREAK.max_level).is_equal(3)
	assert_float(ARMOR_BREAK.get_value(1)).is_equal_approx(0.05, TOLERANCE)
	assert_float(ARMOR_BREAK.get_value(2)).is_equal_approx(0.07, TOLERANCE)
	assert_float(ARMOR_BREAK.get_value(3)).is_equal_approx(0.1, TOLERANCE)
	assert_object(ARMOR_BREAK.debuff).is_same(WEAKEN)
	assert_that(INVIGORATING.id).is_equal(&"invigorating")
	assert_str(INVIGORATING.title).is_equal("Vigorizante")
	assert_int(INVIGORATING.max_level).is_equal(1)
	assert_object(INVIGORATING.buff).is_same(CONCUSSION)
	assert_bool(SPIN.unique_upgrades.has(ARMOR_BREAK)).is_true()
	assert_bool(SPIN.unique_upgrades.has(INVIGORATING)).is_true()
	assert_bool(_ability.owns_upgrade(ARMOR_BREAK)).is_true()
	assert_bool(_ability.owns_upgrade(INVIGORATING)).is_true()
	# One equip per test (a second one frees the first behavior late: orphan).
	assert_bool(_player.ultimate_ability.owns_upgrade(ARMOR_BREAK)).is_false()
	assert_bool(_player.ultimate_ability.owns_upgrade(INVIGORATING)).is_false()


func test_ac285_weaken_data() -> void:
	assert_that(WEAKEN.id).is_equal(&"weaken")
	assert_int(WEAKEN.effect).is_equal(DebuffData.Effect.ARMOR_REDUCTION)
	assert_float(WEAKEN.duration).is_equal_approx(4.0, TOLERANCE)
	assert_int(WEAKEN.max_stacks).is_equal(3)
	assert_that(WEAKEN.icon_material.albedo_color).is_equal(Color(0.55, 0.35, 0.8))


func test_ac286_weaken_stacks_to_three_and_expires_whole() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, 20.0))
	var icons: DebuffIconRow = enemy.get_node("HealthBar/DebuffIcons") as DebuffIconRow
	for i: int in 4:
		enemy.debuffs.apply(WEAKEN, 0.05)
		enemy.debuffs.advance(1.0)
	assert_int(enemy.debuffs.get_stacks(WEAKEN.id)).is_equal(3)
	enemy.debuffs.apply(WEAKEN, 0.05)
	assert_float(enemy.debuffs.get_time_left(WEAKEN.id)).is_equal_approx(4.0, TOLERANCE)
	assert_int(icons.get_visible_icon_count()).is_equal(1)
	enemy.debuffs.advance(3.9)
	assert_int(enemy.debuffs.get_stacks(WEAKEN.id)).is_equal(3)
	enemy.debuffs.advance(0.2)
	assert_int(enemy.debuffs.get_stacks(WEAKEN.id)).is_equal(0)
	assert_int(icons.get_visible_icon_count()).is_equal(0)


func test_ac287_three_stacks_lower_defense_per_level() -> void:
	var expected: Array[float] = [20.0 - 8.5, 20.0 - 7.9, 20.0 - 7.0]
	for level: int in 3:
		var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, 20.0 + level * 3.0))
		enemy.health.defense = 10.0
		for i: int in 3:
			enemy.debuffs.apply(WEAKEN, ARMOR_BREAK.get_value(level + 1))
		assert_float(enemy.health.receive_hit(20.0)).is_equal_approx(expected[level], TOLERANCE)


func test_ac287_reduction_ends_with_the_debuff_and_on_recycle() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, 20.0))
	enemy.health.defense = 10.0
	assert_float(enemy.health.receive_hit(20.0)).is_equal_approx(10.0, TOLERANCE)
	enemy.debuffs.apply(WEAKEN, 0.1)
	assert_float(enemy.health.defense_reduction).is_equal_approx(0.1, TOLERANCE)
	enemy.debuffs.advance(WEAKEN.duration + 0.1)
	assert_float(enemy.health.defense_reduction).is_equal(0.0)
	enemy.debuffs.apply(WEAKEN, 0.1)
	enemy.deactivate()
	enemy.activate(_player.global_position + Vector3(0.0, 0.0, 20.0), null)
	assert_float(enemy.health.defense_reduction).is_equal(0.0)


func test_ac288_every_spin_hit_adds_a_weaken_stack() -> void:
	_player.apply_upgrade(ARMOR_BREAK)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(2.0, 0.0, 0.0))
	_cast_by_hand()
	_advance(1.0)
	assert_int(enemy.debuffs.get_stacks(WEAKEN.id)).is_equal(1)
	_advance(1.0)
	assert_int(enemy.debuffs.get_stacks(WEAKEN.id)).is_equal(2)
	assert_float(enemy.health.defense_reduction).is_equal_approx(0.1, TOLERANCE)


func test_ac288_without_the_card_no_debuffs() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(2.0, 0.0, 0.0))
	_cast_by_hand()
	_advance(2.0)
	assert_bool(enemy.debuffs.get_active().is_empty()).is_true()


func test_ac291_a_kill_by_the_spin_grants_concussion() -> void:
	_player.apply_upgrade(INVIGORATING)
	_spawn_idle_enemy(Vector3(2.0, 0.0, 0.0), 1.0)
	_spawn_idle_enemy(Vector3(-2.0, 0.0, 0.0))
	_cast_by_hand()
	_advance(1.0)
	assert_int(_player.buffs.get_stacks(CONCUSSION.id)).is_equal(1)


func test_ac291_without_the_card_kills_grant_nothing() -> void:
	_spawn_idle_enemy(Vector3(2.0, 0.0, 0.0), 1.0)
	_cast_by_hand()
	_advance(1.0)
	assert_int(_player.buffs.get_stacks(CONCUSSION.id)).is_equal(0)


func test_ac292_stacks_speed_up_the_spin() -> void:
	_player.apply_upgrade(INVIGORATING)
	_add_concussion(4)
	assert_float(_spin.get_turn_time(_ability)).is_equal_approx(SPIN.tick_interval / 1.2, TOLERANCE)
	assert_float(_spin.get_move_speed_factor(_ability)).is_equal_approx(SPIN_CONFIG.move_speed_factor * 1.28, TOLERANCE)
	assert_float(_spin.get_crit_chance(_ability)).is_equal_approx(0.2, TOLERANCE)


func test_ac292_stacks_do_nothing_without_the_card() -> void:
	_add_concussion(4)
	assert_float(_spin.get_turn_time(_ability)).is_equal_approx(SPIN.tick_interval, TOLERANCE)
	assert_float(_spin.get_crit_chance(_ability)).is_equal(0.0)


func test_ac292_walking_outside_the_spin_is_unchanged() -> void:
	_player.apply_upgrade(INVIGORATING)
	_add_concussion(10)
	Input.action_press(&"move_forward")
	await _physics_frames(30)
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var expected: float = BERSERKER.base_stats.move_speed
	assert_float(speed).is_equal_approx(expected, expected * 0.05)


func test_ac292_walking_while_spinning_is_faster() -> void:
	_player.apply_upgrade(INVIGORATING)
	_add_concussion(4)
	_player.buffs.set_physics_process(false)
	assert_bool(_ability.try_cast()).is_true()
	Input.action_press(&"move_forward")
	await _physics_frames(30)
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var expected: float = BERSERKER.base_stats.move_speed * SPIN_CONFIG.move_speed_factor * 1.28
	assert_float(speed).is_equal_approx(expected, expected * 0.05)


func test_ac293_a_speed_change_mid_spin_does_not_jump() -> void:
	_player.apply_upgrade(INVIGORATING)
	var visual: Node3D = _player.get_node("Visual") as Node3D
	_cast_by_hand()
	_advance(0.5)
	var before: float = visual.rotation.y
	_add_concussion(4)
	_advance(STEP)
	var turned: float = angle_difference(before, visual.rotation.y)
	assert_float(turned).is_equal_approx(TAU * STEP * 1.2, 0.001)
	_advance(SPIN.cast_duration)
	# 0.5 turn, then 2.5 s at 1.2 turns/s = 3.5 turns: 3 completed.
	assert_int(_spin.get_turns_done()).is_equal(3)


func test_ac294_no_stacks_never_crit() -> void:
	_player.apply_upgrade(INVIGORATING)
	for i: int in 4:
		_spawn_idle_enemy(Vector3(cos(i * PI / 2.0) * 2.0, 0.0, sin(i * PI / 2.0) * 2.0))
	_cast_by_hand()
	_advance(SPIN.cast_duration)
	assert_bool(_crits.is_empty()).is_false()
	assert_bool(_crits.has(true)).is_false()


func test_ac294_a_crit_uses_the_player_crit_damage() -> void:
	var sure_crit := BuffData.new()
	sure_crit.id = CONCUSSION.id
	sure_crit.max_stacks = 1
	sure_crit.stack_duration = 10.0
	var modifier := BuffModifier.new()
	modifier.stat = BuffModifier.Stat.CRIT_CHANCE
	modifier.per_stack = 1.0
	sure_crit.modifiers.append(modifier)
	_player.apply_upgrade(INVIGORATING)
	_player.buffs.add_stack(sure_crit)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(2.0, 0.0, 0.0))
	_cast_by_hand()
	_advance(1.0)
	assert_int(_crits.size()).is_equal(1)
	assert_bool(_crits[0]).is_true()
	var crit_bonus: float = _player.stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE)
	var expected: float = minf(_hit_damage() * (1.0 + crit_bonus), ENEMY_HEALTH)
	assert_float(enemy.health.current_health).is_equal_approx(ENEMY_HEALTH - expected, 0.01)


func test_ac385_three_spin_turns_show_three_weaken_stacks() -> void:
	_player.apply_upgrade(ARMOR_BREAK)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(2.0, 0.0, 0.0))
	# Survives three hits whatever the spin damage is tuned to.
	enemy.health.set_max_health(_hit_damage() * 10.0)
	var icons: DebuffIconRow = enemy.get_node("HealthBar/DebuffIcons") as DebuffIconRow
	_cast_by_hand()
	for turn: int in 3:
		_advance(1.0)
		assert_int(enemy.debuffs.get_stacks(WEAKEN.id)).is_equal(turn + 1)
		assert_str(icons.get_stack_text(0)).is_equal(str(turn + 1))
	assert_bool(icons.is_stack_visible(0)).is_true()
