extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const NO_CRIT_ROLL: float = 0.99
const TIME_TOLERANCE: float = 0.0001
const STEP: float = 0.01

var _registry: EnemyRegistry


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)


func after_test() -> void:
	Session.character_class = null


func _spawn_player(character_class: CharacterClassData) -> Player:
	Session.character_class = character_class
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.enemy_registry = _registry
	add_child(player)
	return player


func _attack(player: Player) -> void:
	player.attack.advance_cooldown(100.0)
	assert_bool(player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()


func _add_attack_speed(player: Player, amount: float) -> void:
	var upgrade := UpgradeData.new()
	upgrade.stat = PlayerStats.Stat.ATTACK_SPEED
	upgrade.amount = amount
	player.stats.add_upgrade(upgrade)


func _assert_base_sweep(character_class: CharacterClassData) -> void:
	var player: Player = _spawn_player(character_class)
	var duration: float = character_class.weapon.swing.swing_duration
	_attack(player)
	assert_float(player.sword_swing.get_swing_duration()).is_equal_approx(duration, TIME_TOLERANCE)
	player.sword_swing.advance(duration - STEP)
	assert_bool(player.sword_swing.is_swinging()).is_true()
	player.sword_swing.advance(STEP * 2.0)
	assert_bool(player.sword_swing.is_swinging()).is_false()


func _assert_double_speed_halves_the_animation(character_class: CharacterClassData) -> void:
	var player: Player = _spawn_player(character_class)
	var swing: SwordSwingConfig = character_class.weapon.swing
	_add_attack_speed(player, character_class.base_stats.attack_speed)
	_attack(player)
	assert_float(player.sword_swing.get_swing_duration()).is_equal_approx(swing.swing_duration / 2.0, TIME_TOLERANCE)
	assert_float(player.sword_swing.get_recover_duration()).is_equal_approx(swing.recover_duration / 2.0, TIME_TOLERANCE)


func test_ac224_each_class_sweeps_at_its_own_base_duration() -> void:
	assert_float(WARRIOR.weapon.swing.swing_duration).is_equal_approx(0.25, TIME_TOLERANCE)
	assert_float(BERSERKER.weapon.swing.swing_duration).is_equal_approx(0.35, TIME_TOLERANCE)
	_assert_base_sweep(WARRIOR)
	_assert_base_sweep(BERSERKER)
	_assert_base_sweep(SAMURAI)


func test_ac225_double_attack_speed_halves_sweep_and_recovery() -> void:
	_assert_double_speed_halves_the_animation(WARRIOR)
	_assert_double_speed_halves_the_animation(BERSERKER)
	_assert_double_speed_halves_the_animation(SAMURAI)


func test_ac226_the_sweep_never_outlasts_the_attack_interval() -> void:
	var player: Player = _spawn_player(BERSERKER)
	_add_attack_speed(player, 10.0)
	_attack(player)
	var interval: float = 1.0 / player.stats.get_stat(PlayerStats.Stat.ATTACK_SPEED)
	assert_float(player.sword_swing.get_swing_duration()).is_less_equal(interval)


func test_ac227_auto_aim_keeps_facing_for_the_scaled_sweep() -> void:
	var player: Player = _spawn_player(BERSERKER)
	_add_attack_speed(player, BERSERKER.base_stats.attack_speed)
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(Vector3(1.5, 0.0, -1.5), null)
	_attack(player)
	var movement: MovementComponent = player.get_node("MovementComponent") as MovementComponent
	var sweep: float = player.sword_swing.get_swing_duration()
	assert_bool(movement.face_direction_locked).is_true()
	player.attack.advance_cooldown(sweep - STEP)
	assert_bool(movement.face_direction_locked).is_true()
	player.attack.advance_cooldown(STEP * 2.0)
	assert_bool(movement.face_direction_locked).is_false()
