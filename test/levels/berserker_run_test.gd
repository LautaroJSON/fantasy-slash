extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const CLASS_CATALOG: ClassCatalog = preload("res://data/classes/class_catalog.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const KNIGHT_SWORD_MODEL: Mesh = preload("res://assets/models/weapons/knight_set/knight_sword.res")
const FALCHION_MODEL: Mesh = preload("res://assets/models/weapons/falchion/falchion.obj")
const STAT_FORMATS: AbilityStatFormats = preload("res://data/ui/ability_stat_formats.tres")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const NO_CRIT_ROLL: float = 0.99
const FRAME: float = 1.0 / 60.0
const POSE_TOLERANCE: Vector3 = Vector3(0.01, 0.01, 0.01)

var _registry: EnemyRegistry


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)


func after_test() -> void:
	Session.character_class = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spawn_player(character_class: CharacterClassData) -> Player:
	Session.character_class = character_class
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.enemy_registry = _registry
	add_child(player)
	return player


func _pivot(player: Player) -> Node3D:
	return player.get_node("Visual/SwordPivot") as Node3D


func _assert_weapon_uses_model(player: Player, model: Mesh) -> void:
	var mesh_instance: MeshInstance3D = _pivot(player).get_child(0).get_node("Model") as MeshInstance3D
	assert_object(mesh_instance).is_not_null()
	assert_object(mesh_instance.mesh).is_same(model)


func test_ac184_the_berserker_hits_harder_lives_longer_and_attacks_slower() -> void:
	assert_array(CLASS_CATALOG.classes).contains([WARRIOR, BERSERKER])
	var berserker: PlayerStats = BERSERKER.base_stats
	var warrior: PlayerStats = WARRIOR.base_stats
	assert_float(berserker.damage).is_greater(warrior.damage)
	assert_float(berserker.max_health).is_greater(warrior.max_health)
	assert_float(berserker.attack_speed).is_less(warrior.attack_speed)
	assert_array(BERSERKER.abilities.abilities).is_equal([SPIN])


func test_ac185_each_class_carries_its_own_single_weapon() -> void:
	var warrior: Player = _spawn_player(WARRIOR)
	assert_int(_pivot(warrior).get_child_count()).is_equal(1)
	assert_str(_pivot(warrior).get_child(0).name).is_equal("KnightSword")
	_assert_weapon_uses_model(warrior, KNIGHT_SWORD_MODEL)
	var berserker: Player = _spawn_player(BERSERKER)
	assert_int(_pivot(berserker).get_child_count()).is_equal(1)
	assert_str(_pivot(berserker).get_child(0).name).is_equal("Greatsword")
	_assert_weapon_uses_model(berserker, FALCHION_MODEL)


func test_ac186_the_weapon_starts_at_the_class_rest_pose() -> void:
	var berserker: Player = _spawn_player(BERSERKER)
	assert_vector(_pivot(berserker).position).is_equal_approx(BERSERKER.weapon.rest_position, POSE_TOLERANCE)
	assert_vector(_pivot(berserker).rotation).is_equal_approx(BERSERKER.weapon.rest_rotation, POSE_TOLERANCE)
	assert_vector(BERSERKER.weapon.rest_rotation).is_not_equal(WARRIOR.weapon.rest_rotation)
	var warrior: Player = _spawn_player(WARRIOR)
	assert_vector(_pivot(warrior).position).is_equal_approx(Vector3(0.45, 1.3, 0.0), POSE_TOLERANCE)
	assert_vector(_pivot(warrior).rotation).is_equal_approx(Vector3(0.9, 0.0, 0.0), POSE_TOLERANCE)


func test_ac187_slower_strikes() -> void:
	# Adapted (class-combat-identity.md): the basic attack is the berserker's own
	# combo; its first strike stays committed (no new tap) far longer than the
	# warrior's, until its cancel point.
	var player: Player = _spawn_player(BERSERKER)
	ComboDriver.drive_by_hand(player)
	var first: AttackComboStep = BERSERKER.combo.steps[0]
	assert_float(first.cancel_point).is_greater(WARRIOR.combo.steps[0].cancel_point * 2.0)
	assert_bool(player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()
	var committed: float = first.cancel_point - FRAME
	ComboDriver.humanoid_of(player).anim.advance(committed)
	player.attack.advance(committed)
	assert_bool(player.attack.is_attacking()).is_true()
	assert_bool(player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_false()
	ComboDriver.finish(player)
	assert_bool(player.attack.try_attack_with_roll(NO_CRIT_ROLL)).is_true()


func test_ac221_heavy_sweep_stats() -> void:
	var berserker: PlayerStats = BERSERKER.base_stats
	assert_float(berserker.attack_range).is_equal_approx(3.0, 0.0001)
	assert_float(berserker.attack_arc_degrees).is_equal_approx(150.0, 0.0001)
	assert_float(berserker.attack_speed).is_equal_approx(0.65, 0.0001)
	assert_float(berserker.damage).is_equal_approx(25.0, 0.0001)


func test_ac222_the_strike_covers_the_wider_arc() -> void:
	# Adapted (humanoid-player-model.md): the sweep is gone; the 150° arc is
	# checked on the strike's hitbox. The nearest enemy is straight ahead
	# (auto-aim) and the other one 70° to its side.
	var player: Player = _spawn_player(BERSERKER)
	ComboDriver.drive_by_hand(player)
	var ahead: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.2))
	var side_angle: float = deg_to_rad(70.0)
	var side: Enemy = _spawn_enemy(Vector3(sin(side_angle), 0.0, -cos(side_angle)) * 2.0)
	assert_bool(ComboDriver.strike(player, NO_CRIT_ROLL)).is_true()
	assert_float(ahead.health.current_health).is_less(ahead.health.max_health)
	assert_float(side.health.current_health).is_less(side.health.max_health)


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


func test_ac193_the_berserker_run_offers_only_spin_cards() -> void:
	Session.character_class = BERSERKER
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	await get_tree().process_frame
	var picker: AbilityPicker = arena.get_node("UI/AbilityPicker") as AbilityPicker
	assert_array(picker.get_offered()).is_equal([SPIN])
	picker.choose(SPIN)
	var pool: Array[UpgradeCard] = (arena.get_node("WaveManager") as WaveManager).get_card_pool()
	for upgrade: AbilityUpgradeData in SPIN.upgrades:
		assert_bool(pool.has(upgrade)).is_true()
	for upgrade: AbilityUpgradeData in SHIELD_CHARGE.upgrades + PARRY.upgrades:
		assert_bool(pool.has(upgrade)).is_false()


func test_ac193_the_turn_time_has_a_display_format() -> void:
	assert_str(STAT_FORMATS.format_value(AbilityData.Stat.TICK_INTERVAL, 0.7)).is_equal("0.70 s")
