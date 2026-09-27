extends GdUnitTestSuite
## docs/specs/warrior-abilities-rework.md §4.5: the weapon trail only while the
## blade sweeps (AC840–AC842).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const PARRY_CONFIG: ParryConfig = preload("res://data/abilities/parry/parry_config.tres")
const RIPOSTE: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/riposte.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const FRAME: float = 1.0 / 60.0
const HIT: float = 20.0

var _registry: EnemyRegistry
var _player: Player
var _trail: WeaponTrail
var _slot: AbilityComponent


func before_test() -> void:
	Session.character_class = WARRIOR
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_trail = _player.get_node("WeaponTrail") as WeaponTrail
	_slot = _player.basic_ability
	_slot.set_physics_process(false)


func after_test() -> void:
	Session.character_class = null


func _step() -> void:
	_slot.advance(FRAME)
	_trail.advance(FRAME)


func test_ac840_the_charge_and_a_plain_parry_never_trail() -> void:
	_slot.equip(SHIELD_CHARGE)
	assert_bool(_slot.try_cast()).is_true()
	while _slot.is_casting():
		assert_bool(_trail.is_emitting()).is_false()
		_step()
	assert_bool(_trail.is_emitting()).is_false()


func test_ac840_a_parry_without_riposte_never_trails() -> void:
	_slot.equip(PARRY)
	assert_bool(_slot.try_cast()).is_true()
	while _slot.is_casting():
		assert_bool(_trail.is_emitting()).is_false()
		_step()


func test_ac841_the_riposte_trails_only_while_the_blade_sweeps() -> void:
	_slot.equip(PARRY)
	_player.apply_upgrade(RIPOSTE)
	var attacker: Enemy = auto_free(ENEMY_SCENE.instantiate())
	attacker.registry = _registry
	add_child(attacker)
	attacker.activate(Vector3(0.0, 0.0, -2.0), null)
	assert_bool(_slot.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	var elapsed: float = 0.0
	var emitted: int = 0
	while _slot.is_casting():
		_step()
		elapsed += FRAME
		if not _slot.is_casting():
			break
		var inside: bool = elapsed >= PARRY_CONFIG.riposte_trail_start and elapsed < PARRY_CONFIG.riposte_trail_end
		var near_edge: bool = absf(elapsed - PARRY_CONFIG.riposte_trail_start) < FRAME or absf(elapsed - PARRY_CONFIG.riposte_trail_end) < FRAME
		if not near_edge:
			assert_bool(_trail.is_emitting()).override_failure_message("%.3f s" % elapsed).is_equal(inside)
		if _trail.is_emitting():
			emitted += 1
	assert_int(emitted).is_greater(0)
	assert_bool(_trail.is_emitting()).is_false()


func test_ac842_the_spin_and_sheathe_still_trail_for_the_whole_cast() -> void:
	_slot.equip(SPIN)
	assert_bool(_slot.try_cast()).is_true()
	assert_bool(_trail.is_emitting()).is_true()
	var spin_behavior: AbilityBehavior = auto_free(SPIN.behavior.instantiate())
	assert_bool(spin_behavior.trails_while_casting(_slot)).is_true()
	var sheathe_behavior: AbilityBehavior = auto_free(SHEATHE.behavior.instantiate())
	assert_bool(sheathe_behavior.trails_while_casting(_slot)).is_true()
