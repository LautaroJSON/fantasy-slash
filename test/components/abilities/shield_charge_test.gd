extends GdUnitTestSuite
## docs/specs/warrior-abilities-rework.md §3.1 and §5.1: the Shield Charge
## (AC816–AC828, AC846 and AC849 in part).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const CONFIG: ShieldChargeConfig = preload("res://data/abilities/shield_charge/shield_charge_config.tres")
const COOLDOWN_CARD: AbilityUpgradeData = preload("res://data/abilities/shield_charge/upgrades/cooldown.tres")
const HAMMER_ANVIL: AbilityUniqueUpgradeData = preload("res://data/abilities/shield_charge/unique/hammer_anvil.tres")
const MOMENTUM: AbilityUniqueUpgradeData = preload("res://data/abilities/shield_charge/unique/momentum.tres")
const CONCUSSIVE: AbilityUniqueUpgradeData = preload("res://data/abilities/shield_charge/unique/concussive.tres")
const POISON_ABILITY: AfflictionUpgradeData = preload("res://data/afflictions/cards/poison_ability.tres")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const STUN_ID: StringName = &"stun"
const TOLERANCE: float = 0.001
const HIT: float = 20.0
## Physics frames of the travel (0.4 s at 60 Hz).
const TRAVEL_FRAMES: int = 24

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent


func before_test() -> void:
	Session.character_class = WARRIOR
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(80.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_player.health.setup(1000.0, 0.0)
	_ability = _player.basic_ability
	_ability.equip(SHIELD_CHARGE)
	await _frames(10)


func after_test() -> void:
	Session.character_class = null


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## An idle enemy (no target) with no defense, so the applied damage is the raw one.
func _spawn(at: Vector3, stats: EnemyStats = GRUNT) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	enemy.health.setup(1000.0, 0.0)
	return enemy


func _behavior() -> ShieldChargeAbility:
	return _ability.get_behavior() as ShieldChargeAbility


func _guard() -> ShieldGuard:
	return _player.get_node("ShieldGuard") as ShieldGuard


func _bash_damage() -> float:
	return SHIELD_CHARGE.base_damage + SHIELD_CHARGE.attack_scaling * _player.stats.get_stat(PlayerStats.Stat.DAMAGE)


## Bash from where the player stands, without the travel (no physics step between).
func _bash_in_place() -> void:
	assert_bool(_ability.try_cast()).is_true()
	_ability.advance(CONFIG.travel_time)


func test_ac816_the_charge_covers_its_range_in_its_travel_time() -> void:
	var start: Vector3 = _player.global_position
	assert_bool(_ability.try_cast()).is_true()
	await _frames(TRAVEL_FRAMES - 1)
	assert_int(_behavior().get_phase()).is_equal(ShieldChargeAbility.Phase.TRAVEL)
	await _frames(1)
	assert_int(_behavior().get_phase()).is_equal(ShieldChargeAbility.Phase.RECOVERY)
	var covered: float = Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()
	assert_float(covered).is_equal_approx(SHIELD_CHARGE.hit_range, 0.1)
	assert_float(_player.global_position.z).is_less(start.z)


func test_ac817_the_shield_halves_frontal_hits_while_charging() -> void:
	var front: Enemy = _spawn(Vector3(4.0, 0.0, -4.0))
	var back: Enemy = _spawn(Vector3(0.0, 0.0, 6.0))
	assert_bool(_ability.try_cast()).is_true()
	await _frames(4)
	assert_bool(_guard().is_raised()).is_true()
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal_approx(HIT * 0.5, TOLERANCE)
	assert_float(_player.health.receive_hit_from(HIT, back)).is_equal_approx(HIT, TOLERANCE)
	await _frames(TRAVEL_FRAMES)
	assert_bool(_guard().is_raised()).is_false()


func test_ac818_the_enemies_in_front_are_dragged_without_damage() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -1.6))
	assert_bool(_ability.try_cast()).is_true()
	await _frames(18)
	var ahead: float = _player.global_position.z - enemy.global_position.z
	assert_float(ahead).is_greater(0.0)
	assert_float(ahead).is_less_equal(CONFIG.capture_depth + enemy.get_hit_padding() + 0.3)
	assert_float(enemy.global_position.z).is_less(-3.0)
	assert_float(enemy.health.current_health).is_equal(enemy.health.max_health)


func test_ac819_the_bash_hits_the_rectangle_in_front() -> void:
	var inside: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	var beside: Enemy = _spawn(Vector3(1.4, 0.0, -1.0))
	var far: Enemy = _spawn(Vector3(0.0, 0.0, -3.0))
	var hits: Array[float] = []
	_ability.enemy_hit.connect(func(_e: Enemy, applied: float, _c: bool) -> void: hits.append(applied))
	_bash_in_place()
	assert_int(hits.size()).is_equal(1)
	assert_float(hits[0]).is_equal_approx(_bash_damage(), TOLERANCE)
	assert_float(inside.health.current_health).is_equal_approx(1000.0 - _bash_damage(), TOLERANCE)
	assert_bool(inside.is_knocked_back()).is_true()
	assert_float(inside.get_push_speed()).is_equal_approx(CONFIG.bash_knockback_speed, TOLERANCE)
	assert_bool(inside.is_stunned()).is_false()
	assert_float(beside.health.current_health).is_equal(1000.0)
	assert_float(far.health.current_health).is_equal(1000.0)


func test_ac820_an_absorbed_frontal_hit_empowers_the_bash() -> void:
	var attacker: Enemy = _spawn(Vector3(3.0, 0.0, -3.0))
	var target: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	assert_bool(_behavior().is_absorbed()).is_true()
	_ability.advance(CONFIG.travel_time)
	assert_float(target.health.current_health).is_equal_approx(1000.0 - _bash_damage() * CONFIG.absorb_damage_multiplier, TOLERANCE)
	assert_bool(target.is_stunned()).is_true()
	assert_float(target.debuffs.get_remaining_seconds(STUN_ID)).is_equal_approx(CONFIG.stun_duration, TOLERANCE)
	assert_float(_behavior().get_bash_vfx().get_ring_radius()).is_equal_approx(_behavior().get_bash_vfx().config.ring_radius * CONFIG.empowered_ring_scale, TOLERANCE)


func test_ac820_a_hit_from_behind_does_not_empower_it() -> void:
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, 4.0))
	var target: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	assert_bool(_behavior().is_absorbed()).is_false()
	_ability.advance(CONFIG.travel_time)
	assert_float(target.health.current_health).is_equal_approx(1000.0 - _bash_damage(), TOLERANCE)
	assert_bool(target.is_stunned()).is_false()


func test_ac821_a_wall_ends_the_travel_at_once() -> void:
	var wall: StaticBody3D = auto_free(TestWorld.make_box(Vector3(6.0, 3.0, 1.0), Vector3(0.0, 1.5, -2.5)))
	add_child(wall)
	await _frames(2)
	assert_bool(_ability.try_cast()).is_true()
	await _frames(14)
	assert_int(_behavior().get_phase()).is_equal(ShieldChargeAbility.Phase.RECOVERY)
	assert_float(_player.global_position.z).is_greater(-2.5)


func test_ac821_a_boss_ends_the_travel_when_reached() -> void:
	var boss: Enemy = _spawn(Vector3(0.0, 0.0, -3.0), VERDUGO)
	assert_bool(_ability.try_cast()).is_true()
	await _frames(14)
	assert_int(_behavior().get_phase()).is_equal(ShieldChargeAbility.Phase.RECOVERY)
	assert_float(_player.global_position.z).is_greater(boss.global_position.z)
	assert_float(boss.health.current_health).is_less(1000.0)


func test_ac822_a_pushed_enemy_hitting_a_wall_is_stunned() -> void:
	var wall: StaticBody3D = auto_free(TestWorld.make_box(Vector3(6.0, 3.0, 1.0), Vector3(0.0, 1.5, -3.5)))
	add_child(wall)
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -1.2))
	await _frames(2)
	_bash_in_place()
	assert_bool(enemy.is_stunned()).is_false()
	await _frames(20)
	assert_bool(enemy.is_stunned()).is_true()


func test_ac822_a_pushed_enemy_that_hits_nothing_is_not_stunned() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -1.2))
	_bash_in_place()
	await _frames(40)
	assert_bool(enemy.is_stunned()).is_false()


func test_ac822_two_enemies_colliding_are_both_stunned() -> void:
	var pushed: Enemy = _spawn(Vector3(0.0, 0.0, -1.2))
	var standing: Enemy = _spawn(Vector3(0.0, 0.0, -3.4))
	await _frames(2)
	_bash_in_place()
	await _frames(20)
	assert_bool(pushed.is_stunned()).is_true()
	assert_bool(standing.is_stunned()).is_true()
	assert_float(standing.health.current_health).is_equal(1000.0)


func test_ac822_find_contact_tells_a_wall_from_an_enemy() -> void:
	var a: Enemy = _spawn(Vector3(10.0, 0.0, 0.0))
	var b: Enemy = _spawn(Vector3(10.0, 0.0, -0.9))
	var c: Enemy = _spawn(Vector3(10.0, 0.0, -6.0))
	var others: Array[Enemy] = [a, b, c]
	assert_int(ShieldChargeAbility.find_contact(a.global_position, Vector3.FORWARD, others, 0, CONFIG.contact_distance)).is_equal(1)
	assert_int(ShieldChargeAbility.find_contact(a.global_position, Vector3.BACK, others, 0, CONFIG.contact_distance)).is_equal(-1)
	assert_int(ShieldChargeAbility.find_contact(c.global_position, Vector3.FORWARD, others, 2, CONFIG.contact_distance)).is_equal(-1)


func test_ac823_the_watch_list_empties_after_the_window() -> void:
	_spawn(Vector3(0.0, 0.0, -1.2))
	_bash_in_place()
	assert_int(_behavior().get_watched().size()).is_equal(1)
	await _frames(ceili(CONFIG.impact_window * 60.0) + 3)
	assert_int(_behavior().get_watched().size()).is_equal(0)


func test_ac824_hammer_and_anvil_hurts_both_enemies() -> void:
	_player.apply_upgrade(HAMMER_ANVIL)
	var pushed: Enemy = _spawn(Vector3(0.0, 0.0, -1.2))
	var standing: Enemy = _spawn(Vector3(0.0, 0.0, -3.4))
	await _frames(2)
	var hits: Array[Enemy] = []
	_ability.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: hits.append(enemy))
	_bash_in_place()
	await _frames(20)
	var share: float = _bash_damage() * HAMMER_ANVIL.level_values[0]
	assert_float(standing.health.current_health).is_equal_approx(1000.0 - share, TOLERANCE)
	assert_float(pushed.health.current_health).is_equal_approx(1000.0 - _bash_damage() - share, TOLERANCE)
	assert_int(hits.count(standing)).is_equal(1)


func test_ac825_momentum_halves_the_cooldown_on_three_hits() -> void:
	_player.apply_upgrade(MOMENTUM)
	for x: float in [-0.6, 0.0, 0.6]:
		_spawn(Vector3(x, 0.0, -1.0))
	_bash_in_place()
	# The bash halves what was left when it lands (the full 7 s: this step is
	# counted after it), then the travel step runs out.
	assert_float(_ability.get_cooldown_remaining()).is_equal_approx(SHIELD_CHARGE.cooldown * MOMENTUM.level_values[0] - CONFIG.travel_time, TOLERANCE)


func test_ac825_two_hits_keep_the_cooldown() -> void:
	_player.apply_upgrade(MOMENTUM)
	for x: float in [-0.5, 0.5]:
		_spawn(Vector3(x, 0.0, -1.0))
	_bash_in_place()
	assert_float(_ability.get_cooldown_remaining()).is_equal_approx(SHIELD_CHARGE.cooldown - CONFIG.travel_time, TOLERANCE)


func test_ac826_concussive_lengthens_every_stun() -> void:
	assert_int(CONCUSSIVE.max_level).is_equal(2)
	assert_float(_behavior().stun_seconds(_ability)).is_equal_approx(CONFIG.stun_duration, TOLERANCE)
	_player.apply_upgrade(CONCUSSIVE)
	assert_float(_behavior().stun_seconds(_ability)).is_equal_approx(1.5, TOLERANCE)
	_player.apply_upgrade(CONCUSSIVE)
	assert_float(_behavior().stun_seconds(_ability)).is_equal_approx(2.0, TOLERANCE)
	var attacker: Enemy = _spawn(Vector3(3.0, 0.0, -3.0))
	var target: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	_ability.advance(CONFIG.travel_time)
	assert_float(target.debuffs.get_remaining_seconds(STUN_ID)).is_equal_approx(2.0, TOLERANCE)


func test_ac827_a_dash_cuts_the_charge() -> void:
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -1.6))
	assert_bool(_ability.try_cast()).is_true()
	await _frames(8)
	_ability.cut_cast_by_dash()
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_guard().is_raised()).is_false()
	assert_int(_behavior().get_dragged().size()).is_equal(0)
	assert_bool(_behavior().get_bash_vfx().is_dust_emitting()).is_false()
	await _frames(30)
	assert_float(enemy.health.current_health).is_equal(1000.0)
	assert_bool(_ability.is_on_cooldown()).is_true()


func test_ac828_cooldown_and_card_caps() -> void:
	assert_bool(_ability.try_cast()).is_true()
	assert_float(_ability.get_cooldown_remaining()).is_equal_approx(7.0, TOLERANCE)
	for upgrade: AbilityUpgradeData in SHIELD_CHARGE.upgrades:
		assert_int(upgrade.max_stacks).override_failure_message(upgrade.title).is_greater(0)
	for i: int in COOLDOWN_CARD.max_stacks:
		_ability.add_upgrade(COOLDOWN_CARD)
	assert_float(_ability.get_stat(AbilityData.Stat.COOLDOWN)).is_equal_approx(SHIELD_CHARGE.min_cooldown, TOLERANCE)


func test_ac846_dust_ring_and_sparks_use_nodes_made_on_load() -> void:
	var children: int = _count_nodes(_behavior())
	var attacker: Enemy = _spawn(Vector3(3.0, 0.0, -3.0))
	assert_int(_behavior().get_block_vfx().get_pool_size()).is_equal(_behavior().get_block_vfx().config.pool_size)
	assert_bool(_ability.try_cast()).is_true()
	await _frames(3)
	assert_bool(_behavior().get_bash_vfx().is_dust_emitting()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	assert_int(_behavior().get_block_vfx().count_emitting()).is_greater_equal(1)
	await _frames(TRAVEL_FRAMES)
	assert_bool(_behavior().get_bash_vfx().is_ring_visible()).is_true()
	assert_bool(_behavior().get_bash_vfx().is_dust_emitting()).is_false()
	assert_int(_count_nodes(_behavior())).is_equal(children)


func test_ac849_the_bash_loads_ability_afflictions_at_one_and_a_half() -> void:
	assert_float(SHIELD_CHARGE.affliction_scale).is_equal_approx(1.5, TOLERANCE)
	_player.apply_upgrade(POISON_ABILITY)
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	_bash_in_place()
	var expected: float = POISON_ABILITY.get_value(1) * 1.5 * (1.0 + _player.stats.get_stat(PlayerStats.Stat.AFFLICTION_BUILDUP))
	assert_float(enemy.afflictions.get_buildup(0)).is_equal_approx(expected, TOLERANCE)


func _count_nodes(root: Node) -> int:
	var total: int = 1
	for child: Node in root.get_children():
		total += _count_nodes(child)
	return total
