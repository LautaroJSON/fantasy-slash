extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const CLASS_CATALOG: ClassCatalog = preload("res://data/classes/class_catalog.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const KATANA_SHEATH_SCENE: PackedScene = preload("res://entities/player/weapons/katana_sheath.tscn")
const STAT_FORMATS: AbilityStatFormats = preload("res://data/ui/ability_stat_formats.tres")
const TOLERANCE: float = 0.0001
const POSE_TOLERANCE: Vector3 = Vector3(0.001, 0.001, 0.001)

var _registry: EnemyRegistry


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)


func after_test() -> void:
	Session.character_class = null
	get_tree().paused = false
	Input.action_release(&"ability_basic")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spawn_player(character_class: CharacterClassData) -> Player:
	Session.character_class = character_class
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	player.enemy_registry = _registry
	add_child(player)
	return player


func test_ac236_the_samurai_is_agile_critical_and_carries_only_sheathe() -> void:
	assert_array(CLASS_CATALOG.classes).is_equal([WARRIOR, BERSERKER, SAMURAI])
	var stats: PlayerStats = SAMURAI.base_stats
	assert_float(stats.damage).is_equal(14.0)
	assert_float(stats.defense).is_equal(1.0)
	assert_float(stats.max_health).is_equal(90.0)
	assert_float(stats.crit_chance).is_equal_approx(0.15, TOLERANCE)
	assert_float(stats.crit_damage).is_equal(1.0)
	assert_float(stats.attack_speed).is_equal_approx(1.4, TOLERANCE)
	assert_float(stats.attack_arc_degrees).is_equal(100.0)
	assert_float(stats.move_speed).is_equal(6.5)
	assert_float(stats.jump_velocity).is_equal(WARRIOR.base_stats.jump_velocity)
	assert_float(stats.dash_distance).is_equal(WARRIOR.base_stats.dash_distance)
	assert_float(stats.dash_cooldown).is_equal(WARRIOR.base_stats.dash_cooldown)
	assert_array(SAMURAI.abilities.abilities).is_equal([SHEATHE])


func test_ac238_only_the_samurai_wears_a_sheath_at_the_hip() -> void:
	var samurai: Player = _spawn_player(SAMURAI)
	var sheath: Node3D = samurai.get_sheath()
	assert_object(sheath).is_not_null()
	assert_str(sheath.scene_file_path).is_equal(KATANA_SHEATH_SCENE.resource_path)
	assert_object(sheath.get_parent()).is_same(samurai.get_node("Visual"))
	assert_vector(sheath.position).is_equal_approx(SAMURAI.weapon.sheath_position, POSE_TOLERANCE)
	assert_vector(sheath.rotation).is_equal_approx(SAMURAI.weapon.sheath_rotation, POSE_TOLERANCE)
	assert_object(_spawn_player(WARRIOR).get_sheath()).is_null()
	assert_object(_spawn_player(BERSERKER).get_sheath()).is_null()
	assert_object(WARRIOR.weapon.sheath).is_null()
	assert_object(BERSERKER.weapon.sheath).is_null()


func test_ac251_the_hud_slot_shows_the_charge_while_held() -> void:
	Session.character_class = SAMURAI
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	await get_tree().process_frame
	(arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHEATHE)
	get_tree().paused = false
	var player: Player = arena.get_node("Player") as Player
	var slot: AbilitySlotView = arena.get_node("UI/Hud/AbilitySlots/BasicSlot") as AbilitySlotView
	var ability: AbilityComponent = player.basic_ability
	ability.set_physics_process(false)
	ability.try_cast()
	ability.advance(1.5)
	await get_tree().process_frame
	assert_bool(slot.is_showing_charge()).is_true()
	assert_float(slot.get_shown_charge()).is_equal_approx(0.5, TOLERANCE)
	ability.release_charge()
	await get_tree().process_frame
	assert_bool(slot.is_showing_charge()).is_false()
	assert_float(slot.get_shown_ratio()).is_equal(1.0)


func test_ac255_a_samurai_run_picks_sheathe_and_slashes_with_the_ability_key() -> void:
	Session.character_class = SAMURAI
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	await get_tree().process_frame
	var picker: AbilityPicker = arena.get_node("UI/AbilityPicker") as AbilityPicker
	assert_array(picker.get_offered()).is_equal([SHEATHE])
	picker.choose(SHEATHE)
	var player: Player = arena.get_node("Player") as Player
	assert_object(player.basic_ability.get_data()).is_same(SHEATHE)
	var pool: Array[UpgradeCard] = (arena.get_node("WaveManager") as WaveManager).get_card_pool()
	for upgrade: AbilityUpgradeData in SHEATHE.upgrades:
		assert_bool(pool.has(upgrade)).is_true()
	get_tree().paused = false
	var registry: EnemyRegistry = arena.get_node("EnemyRegistry") as EnemyRegistry
	var hits: Array[Enemy] = []
	player.basic_ability.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: hits.append(enemy))
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = registry
	arena.add_child(enemy)
	enemy.activate(player.global_position + Vector3(0.0, 0.0, -1.0), null)
	Input.action_press(&"ability_basic")
	await _physics_frames(10)
	assert_bool(player.basic_ability.is_charging()).is_true()
	Input.action_release(&"ability_basic")
	await _physics_frames(30)
	assert_bool(hits.has(enemy)).is_true()


func test_ac252_the_charge_time_has_a_display_format() -> void:
	assert_str(STAT_FORMATS.format_value(AbilityData.Stat.CHARGE_TIME, 2.7)).is_equal("2.7 s")


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
