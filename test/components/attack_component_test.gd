extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
## A roll that never produces a critical hit (base crit chance is 0.15).
const NO_CRIT_ROLL: float = 0.99

var _registry: EnemyRegistry
var _player: Player
var _attack: AttackComponent


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_attack = _player.get_node("AttackComponent") as AttackComponent


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _upgrade(stat: PlayerStats.Stat, amount: float) -> void:
	var upgrade := UpgradeData.new()
	upgrade.stat = stat
	upgrade.amount = amount
	_player.stats.add_upgrade(upgrade)


func test_ac8_hit_deals_damage_and_heals_by_lifesteal() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_upgrade(PlayerStats.Stat.LIFESTEAL, 0.1)
	_player.health.receive_hit(20.0)
	var health_before: float = _player.health.current_health
	assert_bool(_attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_float(enemy.health.current_health).is_equal_approx(25.0, 0.0001)
	assert_float(_player.health.current_health).is_equal_approx(health_before + 1.5, 0.0001)


func test_ac8_second_attack_during_cooldown_is_rejected() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	assert_bool(_attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	assert_bool(_attack.try_attack_with_roll(NO_CRIT_ROLL)).is_false()


func test_ac8_attack_turns_the_player_towards_the_nearest_enemy() -> void:
	_spawn_enemy(Vector3(1.5, 0.0, 0.0))
	_attack.try_attack_with_roll(NO_CRIT_ROLL)
	var visual: Node3D = _player.get_node("Visual") as Node3D
	assert_float(visual.rotation.y).is_equal_approx(-PI / 2.0, 0.01)


func test_ac9_enemy_out_of_range_takes_no_damage() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -3.0))
	_attack.try_attack_with_roll(NO_CRIT_ROLL)
	assert_float(enemy.health.current_health).is_equal_approx(40.0, 0.0001)


func test_ac9_enemy_behind_the_target_is_outside_the_arc() -> void:
	var target: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.2))
	var behind: Enemy = _spawn_enemy(Vector3(0.0, 0.0, 1.5))
	_attack.try_attack_with_roll(NO_CRIT_ROLL)
	assert_float(target.health.current_health).is_equal_approx(25.0, 0.0001)
	assert_float(behind.health.current_health).is_equal_approx(40.0, 0.0001)


func test_ac9_range_upgrades_extend_the_hitbox() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -2.5))
	for i: int in 3:
		_upgrade(PlayerStats.Stat.ATTACK_RANGE, 0.3)
	_attack.try_attack_with_roll(NO_CRIT_ROLL)
	assert_float(enemy.health.current_health).is_equal_approx(25.0, 0.0001)


func test_ac10_enemy_dies_after_three_hits_and_leaves_the_registry() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var kills: Array[int] = [0]
	enemy.killed.connect(func(_e: Enemy) -> void: kills[0] += 1)
	for i: int in 3:
		assert_bool(_attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
		_attack.advance_cooldown(1.0)
	assert_bool(enemy.health.is_dead()).is_true()
	assert_int(kills[0]).is_equal(1)
	assert_bool(enemy.visible).is_false()
	assert_int(_registry.alive_count()).is_equal(0)
