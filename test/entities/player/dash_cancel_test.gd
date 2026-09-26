extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const NUKI: AbilityUniqueUpgradeData = preload("res://data/abilities/sheathe/unique/nuki.tres")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const SWIFT_STRIKE: AbilityData = preload("res://data/abilities/swift_strike/swift_strike.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const DISTANCE_TOLERANCE: float = 0.15

var _registry: EnemyRegistry
var _player: Player


func before_test() -> void:
	# Another suite may leave these held: a held action never reads as just pressed.
	Input.action_release(&"dash")
	Input.action_release(&"ability_basic")
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)


func after_test() -> void:
	Session.character_class = null
	Input.action_release(&"dash")
	Input.action_release(&"ability_basic")
	Input.action_release(&"move_forward")


func _spawn(character_class: CharacterClassData, ability: AbilityData) -> AbilityComponent:
	Session.character_class = character_class
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	await _physics_frames(10)
	_player.basic_ability.equip(ability)
	return _player.basic_ability


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _flat_distance(from: Vector3) -> float:
	return Vector2(_player.global_position.x - from.x, _player.global_position.z - from.z).length()


## Starts a dash and waits until it is under way.
func _start_dash() -> void:
	Input.action_press(&"dash")
	await _physics_frames(2)
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()


func _wait_dash_end() -> void:
	while _player.dash.is_dashing():
		await get_tree().physics_frame


## Casts and releases a tap Envainar so it ends on cooldown.
func _slash(ability: AbilityComponent) -> void:
	assert_bool(ability.try_cast()).is_true()
	ability.release_charge()
	await _physics_frames(25)
	assert_bool(ability.is_casting()).is_false()
	assert_bool(ability.is_on_cooldown()).is_true()


func test_ac355_only_sheathe_interrupts_the_dash() -> void:
	assert_bool(SHEATHE.interrupts_dash).is_true()
	assert_bool(THRUST.interrupts_dash).is_false()
	assert_bool(SWIFT_STRIKE.interrupts_dash).is_false()
	assert_bool(SPIN.interrupts_dash).is_false()


func test_ac356_pressing_sheathe_mid_dash_cuts_it_and_starts_charging() -> void:
	var ability: AbilityComponent = await _spawn(SAMURAI, SHEATHE)
	var start: Vector3 = _player.global_position
	await _start_dash()
	Input.action_press(&"ability_basic")
	# The press is read on the next physics step after it.
	await _physics_frames(2)
	assert_bool(_player.dash.is_dashing()).is_false()
	assert_bool(ability.is_charging()).is_true()
	await _physics_frames(15)
	assert_float(_flat_distance(start)).is_less(SAMURAI.base_stats.dash_distance - DISTANCE_TOLERANCE)


## Replaces AC357 (docs/specs/dash-iframes.md): the invulnerability ends with the cut.
func test_ac548_the_cut_ends_the_invulnerability_and_the_cooldown_keeps_running() -> void:
	await _spawn(SAMURAI, SHEATHE)
	await _start_dash()
	assert_bool(_player.health.is_invulnerable).is_true()
	Input.action_press(&"ability_basic")
	# The press is read on the next physics step after it.
	await _physics_frames(2)
	assert_bool(_player.dash.is_dashing()).is_false()
	assert_bool(_player.health.is_invulnerable).is_false()
	assert_float(_player.dash.get_cooldown_ratio()).is_greater(0.0)


func test_ac358_sheathe_on_cooldown_does_not_cut_the_dash() -> void:
	var ability: AbilityComponent = await _spawn(SAMURAI, SHEATHE)
	await _slash(ability)
	var start: Vector3 = _player.global_position
	await _start_dash()
	Input.action_press(&"ability_basic")
	# The press is read on the next physics step after it.
	await _physics_frames(2)
	assert_bool(_player.dash.is_dashing()).is_true()
	await _wait_dash_end()
	assert_float(_flat_distance(start)).is_equal_approx(SAMURAI.base_stats.dash_distance, DISTANCE_TOLERANCE)
	assert_bool(ability.is_charging()).is_false()


func test_ac359_the_warrior_thrust_still_waits_for_the_dash() -> void:
	var ability: AbilityComponent = await _spawn(WARRIOR, THRUST)
	var start: Vector3 = _player.global_position
	await _start_dash()
	Input.action_press(&"ability_basic")
	# The press is read on the next physics step after it.
	await _physics_frames(2)
	assert_bool(_player.dash.is_dashing()).is_true()
	await _wait_dash_end()
	await _physics_frames(1)
	assert_float(_flat_distance(start)).is_equal_approx(WARRIOR.base_stats.dash_distance, DISTANCE_TOLERANCE)
	assert_bool(ability.is_casting()).is_false()
	assert_bool(ability.is_on_cooldown()).is_false()


func test_ac360_with_nuki_the_same_dash_recharges_and_is_cut_by_sheathe() -> void:
	var ability: AbilityComponent = await _spawn(SAMURAI, SHEATHE)
	_player.apply_upgrade(NUKI)
	await _slash(ability)
	await _start_dash()
	assert_bool(ability.is_on_cooldown()).is_false()
	Input.action_press(&"ability_basic")
	# The press is read on the next physics step after it.
	await _physics_frames(2)
	assert_bool(_player.dash.is_dashing()).is_false()
	assert_bool(ability.is_charging()).is_true()


## Holds E for a while and releases it: the slash lands and the recovery starts.
func _charge_and_release(ability: AbilityComponent) -> void:
	Input.action_press(&"ability_basic")
	await _physics_frames(10)
	assert_bool(ability.is_charging()).is_true()
	Input.action_release(&"ability_basic")
	await _physics_frames(2)
	assert_bool(ability.is_casting()).is_true()


func test_ac362_a_dash_cuts_the_sheathe_recovery() -> void:
	var ability: AbilityComponent = await _spawn(SAMURAI, SHEATHE)
	await _charge_and_release(ability)
	var start: Vector3 = _player.global_position
	await _start_dash()
	assert_bool(ability.is_casting()).is_false()
	await _wait_dash_end()
	assert_float(_flat_distance(start)).is_equal_approx(SAMURAI.base_stats.dash_distance, DISTANCE_TOLERANCE)
	assert_bool(ability.is_on_cooldown()).is_true()


func test_ac363_after_the_cut_the_katana_rests_and_the_trail_stops() -> void:
	var ability: AbilityComponent = await _spawn(SAMURAI, SHEATHE)
	await _charge_and_release(ability)
	await _start_dash()
	var trail: WeaponTrail = _player.get_node("WeaponTrail") as WeaponTrail
	assert_bool(trail.is_emitting()).is_false()
	await _physics_frames(ceili(SAMURAI.weapon.swing.recover_duration * Engine.physics_ticks_per_second) + 5)
	var pivot: Node3D = _player.get_node("Visual/SwordPivot") as Node3D
	assert_vector(pivot.position).is_equal_approx(SAMURAI.weapon.rest_position, Vector3.ONE * 0.01)
	assert_vector(pivot.rotation).is_equal_approx(SAMURAI.weapon.rest_rotation, Vector3.ONE * 0.01)


func test_ac364_without_a_dash_the_recovery_holds_the_player_still() -> void:
	var ability: AbilityComponent = await _spawn(SAMURAI, SHEATHE)
	await _charge_and_release(ability)
	var start: Vector3 = _player.global_position
	Input.action_press(&"move_forward")
	await _physics_frames(8)
	assert_bool(ability.is_casting()).is_true()
	assert_float(_flat_distance(start)).is_less(0.05)
	await _physics_frames(10)
	Input.action_release(&"move_forward")
	assert_bool(ability.is_casting()).is_false()


func test_ac365_with_nuki_the_dash_that_cuts_the_recovery_recharges_sheathe() -> void:
	var ability: AbilityComponent = await _spawn(SAMURAI, SHEATHE)
	_player.apply_upgrade(NUKI)
	await _charge_and_release(ability)
	assert_bool(ability.is_on_cooldown()).is_true()
	await _start_dash()
	assert_bool(ability.is_casting()).is_false()
	assert_bool(ability.is_on_cooldown()).is_false()


func test_ac366_the_thrust_still_blocks_the_dash_while_cast() -> void:
	var ability: AbilityComponent = await _spawn(WARRIOR, THRUST)
	assert_bool(THRUST.dash_cancels_cast).is_false()
	assert_bool(ability.try_cast()).is_true()
	Input.action_press(&"dash")
	await _physics_frames(2)
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_false()
	assert_bool(ability.is_casting()).is_true()
