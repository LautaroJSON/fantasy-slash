extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
const FEEDBACK: ChargeFeedbackConfig = preload("res://data/player/charge_feedback_config.tres")
const SLOT_CONFIG: AbilitySlotViewConfig = preload("res://data/ui/ability_slot_view_config.tres")
const TSUBAME_GAESHI: AbilityUniqueUpgradeData = preload("res://data/abilities/sheathe/unique/tsubame_gaeshi.tres")
const STEP: float = 0.05
const TOLERANCE: float = 0.0001

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _changes: Array[bool] = []


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
	_changes.clear()
	await get_tree().physics_frame


func after_test() -> void:
	Session.character_class = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_empowered_changed(active: bool) -> void:
	_changes.append(active)


func _equip(with_card: bool) -> void:
	_ability.set_physics_process(false)
	_ability.equip(SHEATHE)
	_ability.empowered_changed.connect(_on_empowered_changed)
	if with_card:
		_player.apply_upgrade(TSUBAME_GAESHI)


func _spawn_idle_enemy(distance: float) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(_player.global_position + Vector3(0.0, 0.0, -distance), null)
	return enemy


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


## Holds for `seconds`, releases (the hit lands at once) and lets the recovery end.
func _charge_and_release(seconds: float) -> void:
	assert_bool(_ability.try_cast()).is_true()
	_advance(seconds)
	_ability.release_charge()
	_advance(SHEATHE.cast_duration + STEP)


func _full_slash() -> void:
	_charge_and_release(SHEATHE.charge_time + STEP)


func _blade() -> MeshInstance3D:
	return _player.get_node("Visual/SwordPivot").get_child(0).get_node("Model") as MeshInstance3D


func test_ac387_the_tsubame_gaeshi_card_is_a_binary_sheathe_unique() -> void:
	assert_str(TSUBAME_GAESHI.id).is_equal("tsubame_gaeshi")
	assert_str(TSUBAME_GAESHI.title).is_equal("Tsubame Gaeshi")
	assert_int(TSUBAME_GAESHI.max_level).is_equal(1)
	assert_array(SHEATHE.unique_upgrades).contains([TSUBAME_GAESHI])


func test_ac388_a_full_manual_charge_that_connects_stores_an_empowered_sheathe() -> void:
	_equip(true)
	var enemy: Enemy = _spawn_idle_enemy(1.0)
	_full_slash()
	assert_float(enemy.health.current_health).is_less(40.0)
	assert_bool(_ability.is_empowered()).is_true()
	assert_array(_changes).is_equal([true])


func test_ac389_no_empowered_below_full_charge() -> void:
	_equip(true)
	_spawn_idle_enemy(1.0)
	_charge_and_release(2.0)
	assert_bool(_ability.is_empowered()).is_false()
	assert_array(_changes).is_empty()


func test_ac389_no_empowered_when_the_full_slash_hits_nobody() -> void:
	_equip(true)
	_full_slash()
	assert_bool(_ability.is_empowered()).is_false()


func test_ac389_no_empowered_without_the_card() -> void:
	_equip(false)
	_spawn_idle_enemy(1.0)
	_full_slash()
	assert_bool(_ability.is_empowered()).is_false()


func test_ac390_the_empowered_sheathe_is_a_tap_at_full_charge() -> void:
	_equip(true)
	_spawn_idle_enemy(1.0)
	_full_slash()
	_ability.reset_cooldown()
	var hits: Array[Enemy] = []
	_ability.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: hits.append(enemy))
	var far: Enemy = _spawn_idle_enemy(5.0)
	assert_bool(_ability.try_cast()).is_true()
	assert_bool(_ability.is_charging()).is_false()
	assert_bool(_ability.is_casting()).is_true()
	assert_float(_ability.get_released_charge_ratio()).is_equal(1.0)
	assert_bool(hits.has(far)).is_true()
	assert_bool(_ability.is_empowered()).is_false()
	assert_array(_changes).is_equal([true, false])


func test_ac391_the_empowered_sheathe_does_not_store_another() -> void:
	_equip(true)
	_spawn_idle_enemy(1.0)
	_full_slash()
	_ability.reset_cooldown()
	_ability.try_cast()
	_advance(SHEATHE.cast_duration + STEP)
	assert_bool(_ability.is_empowered()).is_false()
	assert_array(_changes).is_equal([true, false])


func test_ac392_the_katana_flashes_then_glows_and_the_camera_shakes() -> void:
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	_equip(true)
	_spawn_idle_enemy(1.0)
	assert_object(_blade().material_overlay).is_null()
	camera.stop_shake()
	_full_slash()
	assert_object(_blade().material_overlay).is_same(SHEATHE_CONFIG.empowered_flash_overlay)
	assert_float(camera.get_shake_strength()).is_greater_equal(FEEDBACK.empowered_shake)
	await get_tree().create_timer(SHEATHE_CONFIG.empowered_flash_duration + 0.1).timeout
	assert_object(_blade().material_overlay).is_same(SHEATHE_CONFIG.empowered_overlay)
	_ability.reset_cooldown()
	_ability.try_cast()
	assert_object(_blade().material_overlay).is_null()


func test_ac393_the_hud_frame_turns_gold_while_empowered() -> void:
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	await get_tree().process_frame
	(arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHEATHE)
	get_tree().paused = false
	var player: Player = arena.get_node("Player") as Player
	var slot: AbilitySlotView = arena.get_node("UI/Hud/AbilitySlots/BasicSlot") as AbilitySlotView
	var ability: AbilityComponent = player.basic_ability
	ability.set_physics_process(false)
	player.apply_upgrade(TSUBAME_GAESHI)
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = arena.get_node("EnemyRegistry") as EnemyRegistry
	arena.add_child(enemy)
	enemy.activate(player.global_position + Vector3(0.0, 0.0, -1.0), null)
	ability.try_cast()
	for i: int in 70:
		ability.advance(STEP)
	ability.release_charge()
	await get_tree().process_frame
	assert_bool(ability.is_empowered()).is_true()
	assert_bool(slot.is_showing_empowered()).is_true()
	assert_that(SLOT_CONFIG.empowered_frame_color).is_not_equal(SLOT_CONFIG.frame_color)
	# Adapted (sheathe-release-animation.md): wait out the whole release cast.
	for i: int in ceili(SHEATHE.cast_duration / STEP) + 1:
		ability.advance(STEP)
	ability.reset_cooldown()
	ability.try_cast()
	await get_tree().process_frame
	assert_bool(slot.is_showing_empowered()).is_false()


func test_ac394_the_card_is_pooled_with_sheathe_and_leaves_once_taken() -> void:
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	get_tree().paused = true
	await get_tree().process_frame
	(arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHEATHE)
	var wave_manager: WaveManager = arena.get_node("WaveManager") as WaveManager
	var player: Player = arena.get_node("Player") as Player
	assert_bool(wave_manager.get_available_pool().has(TSUBAME_GAESHI)).is_true()
	player.apply_upgrade(TSUBAME_GAESHI)
	assert_bool(player.is_maxed(TSUBAME_GAESHI)).is_true()
	assert_bool(wave_manager.get_available_pool().has(TSUBAME_GAESHI)).is_false()
