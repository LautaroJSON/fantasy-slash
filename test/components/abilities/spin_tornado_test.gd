extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const INVIGORATING: AbilityUniqueUpgradeData = preload("res://data/abilities/spin/unique/invigorating.tres")
const TORNADO: AbilityUniqueUpgradeData = preload("res://data/abilities/spin/unique/tornado.tres")
const CONCUSSION: BuffData = preload("res://data/buffs/concussion.tres")
const ENEMY_HEALTH: float = 40.0
const STEP: float = 0.05
const TOLERANCE: float = 0.0001
## Cooldown checks allow one cast step of drift.
const COOLDOWN_TOLERANCE: float = 0.05

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent


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
	await _physics_frames(20)


func after_test() -> void:
	Session.character_class = null


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


func _cast_by_hand() -> void:
	_ability.set_physics_process(false)
	_player.buffs.set_physics_process(false)
	assert_bool(_ability.try_cast()).is_true()


func _cooldown_left() -> float:
	return _ability.get_cooldown_ratio() * _ability.get_stat(AbilityData.Stat.COOLDOWN)


## Casts, spins until just before the 2nd turn (7 s of cooldown left when it
## lands), puts `victims` 1 HP enemies in range and lets the 2nd turn hit.
func _kill_on_second_turn(victims: int) -> void:
	_cast_by_hand()
	_advance(1.9)
	for i: int in victims:
		_spawn_idle_enemy(Vector3(2.0 if i == 0 else -2.0, 0.0, 0.0), 1.0)
	_advance(0.1)


func test_ac297_maelstrom_is_now_invigorating() -> void:
	assert_that(INVIGORATING.id).is_equal(&"invigorating")
	assert_str(INVIGORATING.title).is_equal("Vigorizante")
	assert_int(INVIGORATING.max_level).is_equal(1)
	assert_object(INVIGORATING.buff).is_same(CONCUSSION)
	assert_bool(ResourceLoader.exists("res://data/abilities/spin/unique/maelstrom.tres")).is_false()
	assert_int(SPIN.unique_upgrades.size()).is_equal(3)
	assert_that(SPIN.unique_upgrades[0].id).is_equal(&"armor_break")
	assert_that(SPIN.unique_upgrades[1].id).is_equal(&"invigorating")
	assert_that(SPIN.unique_upgrades[2].id).is_equal(&"tornado")


func test_ac298_concussion_move_speed_is_seven_percent() -> void:
	assert_float(CONCUSSION.get_modifier(BuffModifier.Stat.MOVE_SPEED, 4)).is_equal_approx(0.28, TOLERANCE)
	assert_float(CONCUSSION.get_modifier(BuffModifier.Stat.ABILITY_SPEED, 4)).is_equal_approx(0.2, TOLERANCE)
	assert_float(CONCUSSION.get_modifier(BuffModifier.Stat.CRIT_CHANCE, 4)).is_equal_approx(0.2, TOLERANCE)


func test_ac299_tornado_data() -> void:
	assert_that(TORNADO.id).is_equal(&"tornado")
	assert_str(TORNADO.title).is_equal("Tornado")
	assert_int(TORNADO.max_level).is_equal(1)
	assert_float(TORNADO.get_value(1)).is_equal_approx(1.0, TOLERANCE)
	assert_bool(SPIN.unique_upgrades.has(TORNADO)).is_true()
	assert_bool(_ability.owns_upgrade(TORNADO)).is_true()


func test_ac300_a_kill_takes_one_second_off() -> void:
	_player.apply_upgrade(TORNADO)
	_kill_on_second_turn(1)
	assert_float(_cooldown_left()).is_equal_approx(6.0, COOLDOWN_TOLERANCE)


func test_ac300_two_kills_in_one_turn_take_two_seconds() -> void:
	_player.apply_upgrade(TORNADO)
	_kill_on_second_turn(2)
	assert_float(_cooldown_left()).is_equal_approx(5.0, COOLDOWN_TOLERANCE)


func test_ac301_never_below_zero() -> void:
	_player.apply_upgrade(TORNADO)
	_cast_by_hand()
	_ability.reduce_cooldown(7.5)
	_advance(0.95)
	assert_float(_cooldown_left()).is_equal_approx(0.55, COOLDOWN_TOLERANCE)
	_spawn_idle_enemy(Vector3(2.0, 0.0, 0.0), 1.0)
	_advance(0.05)
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)


func test_ac301_without_a_cooldown_nothing_changes() -> void:
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	_ability.reduce_cooldown(1.0)
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	assert_bool(_ability.try_cast()).is_true()


func test_ac302_without_tornado_kills_do_not_shorten_it() -> void:
	_kill_on_second_turn(1)
	assert_float(_cooldown_left()).is_equal_approx(7.0, COOLDOWN_TOLERANCE)


func test_ac302_hits_that_do_not_kill_do_not_shorten_it() -> void:
	_player.apply_upgrade(TORNADO)
	_cast_by_hand()
	_advance(1.9)
	_spawn_idle_enemy(Vector3(2.0, 0.0, 0.0))
	_advance(0.1)
	assert_float(_cooldown_left()).is_equal_approx(7.0, COOLDOWN_TOLERANCE)


func test_ac303_cannot_recast_while_spinning() -> void:
	_player.apply_upgrade(TORNADO)
	_cast_by_hand()
	_advance(1.0)
	_ability.reduce_cooldown(SPIN.cooldown)
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	assert_bool(_ability.is_casting()).is_true()
	assert_bool(_ability.try_cast()).is_false()
	_advance(SPIN.cast_duration)
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_ability.try_cast()).is_true()
