extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const ZANSHIN: AbilityUniqueUpgradeData = preload("res://data/abilities/sheathe/unique/zanshin.tres")
const WIND_STEP: AbilityUniqueUpgradeData = preload("res://data/abilities/sheathe/unique/wind_step.tres")
const ENEMY_HEALTH: float = 40.0
## Leaves a grunt one weak hit from death.
const WOUND: float = 35.0
const STEP: float = 0.05
const TOLERANCE: float = 0.0001

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _dash_ready_count: Array[int] = [0]


func before_test() -> void:
	Session.character_class = SAMURAI
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_ability.set_physics_process(false)
	_ability.equip(SHEATHE)
	_dash_ready_count[0] = 0
	_player.dash.dash_ready.connect(func() -> void: _dash_ready_count[0] += 1)
	await get_tree().physics_frame


func after_test() -> void:
	Session.character_class = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spawn_idle_enemy(distance: float, wound: float) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(_player.global_position + Vector3(0.0, 0.0, -distance), null)
	enemy.health.receive_true_damage(wound)
	return enemy


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


## A tap slash (30 % charge): enough to kill a wounded grunt, not a healthy one.
func _tap_slash() -> void:
	_ability.try_cast()
	_ability.release_charge()
	_advance(SHEATHE.cast_duration + STEP)


## Dashes so the dash is on cooldown (no physics frames run, so it stays there).
func _put_dash_on_cooldown() -> void:
	assert_bool(_player.dash.try_dash(Vector3.RIGHT)).is_true()
	assert_float(_player.dash.get_cooldown_ratio()).is_equal(1.0)


func test_ac305_the_zanshin_card_is_a_binary_sheathe_unique() -> void:
	assert_str(ZANSHIN.id).is_equal("zanshin")
	assert_str(ZANSHIN.title).is_equal("Zanshin")
	assert_int(ZANSHIN.max_level).is_equal(1)
	assert_array(SHEATHE.unique_upgrades).contains([WIND_STEP, ZANSHIN])


func test_ac306_a_killing_slash_makes_the_dash_ready_once() -> void:
	_player.apply_upgrade(ZANSHIN)
	var first: Enemy = _spawn_idle_enemy(1.0, WOUND)
	var second: Enemy = _spawn_idle_enemy(1.2, WOUND)
	_put_dash_on_cooldown()
	_tap_slash()
	assert_bool(first.health.is_dead()).is_true()
	assert_bool(second.health.is_dead()).is_true()
	assert_float(_player.dash.get_cooldown_ratio()).is_equal(0.0)
	assert_int(_dash_ready_count[0]).is_equal(1)


func test_ac307_a_slash_that_does_not_kill_keeps_the_dash_cooldown() -> void:
	_player.apply_upgrade(ZANSHIN)
	var enemy: Enemy = _spawn_idle_enemy(1.0, 0.0)
	_put_dash_on_cooldown()
	_tap_slash()
	assert_float(enemy.health.current_health).is_less(ENEMY_HEALTH)
	assert_bool(enemy.health.is_dead()).is_false()
	assert_float(_player.dash.get_cooldown_ratio()).is_equal(1.0)
	assert_int(_dash_ready_count[0]).is_equal(0)


func test_ac308_without_the_card_a_kill_keeps_the_dash_cooldown() -> void:
	var enemy: Enemy = _spawn_idle_enemy(1.0, WOUND)
	_put_dash_on_cooldown()
	_tap_slash()
	assert_bool(enemy.health.is_dead()).is_true()
	assert_float(_player.dash.get_cooldown_ratio()).is_equal(1.0)


func test_ac308_resetting_a_ready_dash_emits_nothing() -> void:
	_player.dash.reset_cooldown()
	assert_int(_dash_ready_count[0]).is_equal(0)


func test_ac309_the_card_is_pooled_with_sheathe_and_leaves_once_taken() -> void:
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	get_tree().paused = true
	await get_tree().process_frame
	(arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHEATHE)
	var wave_manager: WaveManager = arena.get_node("WaveManager") as WaveManager
	var player: Player = arena.get_node("Player") as Player
	assert_bool(wave_manager.get_available_pool().has(ZANSHIN)).is_true()
	player.apply_upgrade(ZANSHIN)
	assert_bool(player.is_maxed(ZANSHIN)).is_true()
	assert_bool(wave_manager.get_available_pool().has(ZANSHIN)).is_false()
