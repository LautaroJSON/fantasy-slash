extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SPIN_SCENE: PackedScene = preload("res://components/abilities/spin_ability.tscn")
const CONFIG: WeaponTrailConfig = preload("res://data/player/weapon_trail_config.tres")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const SWIFT_STRIKE: AbilityData = preload("res://data/abilities/swift_strike/swift_strike.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const NO_CRIT_ROLL: float = 0.99
const FRAME: float = 1.0 / 60.0
const POSITION_TOLERANCE: Vector3 = Vector3(0.001, 0.001, 0.001)

var _registry: EnemyRegistry
var _player: Player
var _trail: WeaponTrail


func before_test() -> void:
	Session.character_class = WARRIOR
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_trail = _player.get_node("WeaponTrail") as WeaponTrail


func after_test() -> void:
	Session.character_class = null


func _start_basic_attack() -> void:
	_player.attack.advance_cooldown(10.0)
	assert_bool(_player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()


func _blade_tip() -> Node3D:
	return _player.get_node("Visual/SwordPivot/Sword/TrailTip") as Node3D


func _assert_emits_during_cast(ability: AbilityData) -> void:
	var slot: AbilityComponent = _player.basic_ability
	slot.equip(ability)
	assert_bool(_trail.is_emitting()).is_false()
	assert_bool(slot.try_cast()).is_true()
	assert_bool(_trail.is_emitting()).is_true()
	while slot.is_casting():
		slot.advance(FRAME)
		_trail.advance(FRAME)
		if slot.is_casting():
			assert_bool(_trail.is_emitting()).is_true()
	assert_bool(_trail.is_emitting()).is_false()


func test_ac215_basic_attack_lights_the_trail_until_the_sweep_ends() -> void:
	assert_bool(_trail.is_emitting()).is_false()
	_start_basic_attack()
	assert_bool(_trail.is_emitting()).is_true()
	_trail.advance(FRAME)
	_trail.advance(FRAME)
	assert_int(_trail.get_sample_count()).is_equal(2)
	_player.sword_swing.advance(10.0)
	assert_bool(_trail.is_emitting()).is_false()
	_trail.advance(CONFIG.lifetime)
	assert_int(_trail.get_sample_count()).is_equal(0)
	assert_bool(_trail.visible).is_false()


func test_ac216_trail_emits_for_the_whole_thrust() -> void:
	_assert_emits_during_cast(THRUST)


func test_ac216_trail_emits_for_the_whole_swift_strike() -> void:
	_assert_emits_during_cast(SWIFT_STRIKE)


func test_ac216_trail_emits_for_the_whole_spin() -> void:
	_assert_emits_during_cast(SPIN)


func test_ac217_the_newest_sample_is_at_the_blade_tip() -> void:
	_start_basic_attack()
	for i: int in 5:
		_player.sword_swing.advance(FRAME)
		_trail.advance(FRAME)
		assert_vector(_trail.get_sample_tip(0)).is_equal_approx(_blade_tip().global_position, POSITION_TOLERANCE)
	assert_vector(_trail.get_sample_tip(0)).is_not_equal(_trail.get_sample_tip(4))


func test_ac218_samples_fade_with_age_and_never_exceed_the_buffer() -> void:
	_start_basic_attack()
	for i: int in CONFIG.max_samples * 2:
		_trail.advance(0.001)
	assert_int(_trail.get_sample_count()).is_equal(CONFIG.max_samples)
	assert_float(_trail.get_sample_alpha(0)).is_equal_approx(CONFIG.head_alpha, 0.0001)
	for i: int in CONFIG.max_samples - 1:
		assert_float(_trail.get_sample_alpha(i + 1)).is_less(_trail.get_sample_alpha(i))


func test_ac219_ground_arc_and_spin_wind_trail_are_gone() -> void:
	assert_bool(_player.has_node("AttackIndicator")).is_false()
	var spin: Node = auto_free(SPIN_SCENE.instantiate())
	assert_bool(spin.has_node("WindTrail")).is_false()
