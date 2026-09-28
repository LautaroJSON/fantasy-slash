extends GdUnitTestSuite
## docs/specs/sheathe-upgrades-rework.md (AC1071–AC1088). The empowered-state
## cases of tsubame_gaeshi_test.gd (tap at full charge, glow, gold frame, spent
## on the cast) live here now, with Hosho as the trigger.

const TestWorld := preload("res://test/helpers/test_world.gd")
const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
const SLOT_CONFIG: AbilitySlotViewConfig = preload("res://data/ui/ability_slot_view_config.tres")
const HOSHO: AbilityUniqueUpgradeData = preload("res://data/abilities/sheathe/unique/hosho.tres")
const NUKI: AbilityUniqueUpgradeData = preload("res://data/abilities/sheathe/unique/nuki.tres")
const ZEN: AbilityUniqueUpgradeData = preload("res://data/abilities/sheathe/unique/zen.tres")
const COMPENSATION: BuffData = preload("res://data/buffs/compensation.tres")
const NETSUI: BuffData = preload("res://data/buffs/netsui.tres")
const TRIUMPH: BuffData = preload("res://data/buffs/triumph.tres")
const ATTACK_SPEED_CARD: UpgradeData = preload("res://data/upgrades/attack_speed.tres")
const SHEATHE_SCRIPT_PATH: String = "res://components/abilities/sheathe_ability.gd"
const STEP: float = 0.05
const TOLERANCE: float = 0.0001

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _changes: Array[bool] = []
var _applied: Array[float] = []


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
	_applied.clear()
	var stats: PlayerStats = SAMURAI.base_stats.duplicate() as PlayerStats
	stats.crit_chance = 0.0
	_player.stats.set_base_stats(stats)
	await get_tree().physics_frame


func after_test() -> void:
	Session.character_class = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_empowered_changed(active: bool) -> void:
	_changes.append(active)


func _on_enemy_hit(_enemy: Enemy, applied: float, _is_crit: bool) -> void:
	_applied.append(applied)


func _equip(cards: Array[AbilityUniqueUpgradeData]) -> void:
	_ability.set_physics_process(false)
	_player.buffs.set_physics_process(false)
	_ability.equip(SHEATHE)
	_ability.empowered_changed.connect(_on_empowered_changed)
	_ability.enemy_hit.connect(_on_enemy_hit)
	for card: AbilityUniqueUpgradeData in cards:
		_player.apply_upgrade(card)


func _behavior() -> SheatheAbility:
	return _ability.get_behavior() as SheatheAbility


## An idle enemy with no defense and plenty of health: applied damage = raw damage.
func _spawn_dummy(distance: float) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(_player.global_position + Vector3(0.0, 0.0, -distance), null)
	enemy.health.setup(100000.0, 0.0)
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


## One combo strike through the basic attack (emits AttackComponent.attacked).
func _combo_strike(enemies: Array[Enemy]) -> void:
	_player.attack.strike_enemies(enemies, 1.0, 1.0, 1.0)


func _strikes(count: int, enemy: Enemy) -> void:
	var targets: Array[Enemy] = [enemy]
	for i: int in count:
		_combo_strike(targets)


func _blade() -> MeshInstance3D:
	return _player.get_node("Visual/SwordPivot").get_child(0).get_node("Model") as MeshInstance3D


func _unique_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: AbilityUniqueUpgradeData in SHEATHE.unique_upgrades:
		ids.append(card.id)
	return ids


# --- Cleanup ---


func test_ac1071_only_hosho_nuki_and_zen_remain() -> void:
	assert_array(_unique_ids()).contains_exactly([&"hosho", &"nuki", &"zen"])
	for path: String in ["wind_step", "zanshin", "tsubame_gaeshi"]:
		assert_bool(ResourceLoader.exists("res://data/abilities/sheathe/unique/%s.tres" % path)).is_false()
	var source: String = FileAccess.get_file_as_string(SHEATHE_SCRIPT_PATH)
	for name: String in ["WIND_STEP", "ZANSHIN", "TSUBAME_GAESHI"]:
		assert_bool(source.contains(name)).is_false()


func test_ac1072_without_uniques_a_dash_adds_no_charge_and_a_full_slash_stores_nothing() -> void:
	_equip([])
	_spawn_dummy(1.0)
	assert_bool(_ability.try_cast()).is_true()
	_advance(1.0)
	var before: float = _ability.get_charge_ratio()
	_ability.notify_dash()
	assert_float(_ability.get_charge_ratio()).is_equal_approx(before, TOLERANCE)
	_advance(SHEATHE.charge_time)
	_ability.release_charge()
	_advance(SHEATHE.cast_duration + STEP)
	assert_bool(_ability.is_empowered()).is_false()
	assert_array(_changes).is_empty()


# --- Hosho ---


func test_ac1074_one_charge_per_combo_strike_that_hits() -> void:
	_equip([HOSHO])
	var a: Enemy = _spawn_dummy(1.0)
	var b: Enemy = _spawn_dummy(1.5)
	var c: Enemy = _spawn_dummy(2.0)
	_combo_strike([a] as Array[Enemy])
	assert_int(_behavior().get_compensation_charges()).is_equal(1)
	_combo_strike([a, b, c] as Array[Enemy])
	assert_int(_behavior().get_compensation_charges()).is_equal(2)
	_combo_strike([] as Array[Enemy])
	assert_int(_behavior().get_compensation_charges()).is_equal(2)


func test_ac1075_the_fifth_charge_resets_the_cooldown_and_empowers() -> void:
	_equip([HOSHO])
	var enemy: Enemy = _spawn_dummy(1.0)
	_charge_and_release(0.5)
	assert_bool(_ability.is_on_cooldown()).is_true()
	_strikes(4, enemy)
	assert_bool(_ability.is_empowered()).is_false()
	assert_bool(_ability.is_on_cooldown()).is_true()
	_strikes(1, enemy)
	assert_int(_behavior().get_compensation_charges()).is_equal(0)
	assert_bool(_ability.is_on_cooldown()).is_false()
	assert_bool(_ability.is_empowered()).is_true()
	assert_array(_changes).is_equal([true])
	assert_object(_blade().material_overlay).is_same(SHEATHE_CONFIG.empowered_flash_overlay)


func test_ac1076_no_charges_while_empowered() -> void:
	_equip([HOSHO])
	var enemy: Enemy = _spawn_dummy(1.0)
	_strikes(5, enemy)
	_strikes(3, enemy)
	assert_int(_behavior().get_compensation_charges()).is_equal(0)
	assert_int(_player.buffs.get_stacks(COMPENSATION.id)).is_equal(0)


func test_ac1077_the_empowered_sheathe_is_a_tap_at_full_charge_with_four_times_the_damage() -> void:
	_equip([HOSHO])
	var enemy: Enemy = _spawn_dummy(1.0)
	_full_slash()
	var manual: float = _applied[0]
	_ability.reset_cooldown()
	_strikes(5, enemy)
	var far: Enemy = _spawn_dummy(5.0)
	var far_before: float = far.health.current_health
	assert_bool(_ability.try_cast()).is_true()
	assert_bool(_ability.is_charging()).is_false()
	assert_bool(_ability.is_casting()).is_true()
	assert_float(_ability.get_released_charge_ratio()).is_equal(1.0)
	assert_float(far.health.current_health).is_less(far_before)
	assert_float(_applied[_applied.size() - 1]).is_equal_approx(manual * SHEATHE_CONFIG.hosho.damage_multiplier, 0.01)
	assert_float(SHEATHE_CONFIG.hosho.damage_multiplier).is_equal(4.0)


func test_ac1078_casting_it_spends_the_glow_and_the_charges_start_over() -> void:
	_equip([HOSHO])
	var enemy: Enemy = _spawn_dummy(1.0)
	_strikes(5, enemy)
	await get_tree().create_timer(SHEATHE_CONFIG.empowered_flash_duration + 0.1).timeout
	assert_object(_blade().material_overlay).is_same(SHEATHE_CONFIG.empowered_overlay)
	_ability.try_cast()
	_advance(SHEATHE.cast_duration + STEP)
	assert_bool(_ability.is_empowered()).is_false()
	assert_object(_blade().material_overlay).is_null()
	assert_array(_changes).is_equal([true, false])
	_strikes(1, enemy)
	assert_int(_behavior().get_compensation_charges()).is_equal(1)


func test_ac1079_without_hosho_combo_strikes_build_nothing() -> void:
	_equip([])
	var enemy: Enemy = _spawn_dummy(1.0)
	_strikes(6, enemy)
	assert_int(_behavior().get_compensation_charges()).is_equal(0)
	assert_int(_player.buffs.get_stacks(COMPENSATION.id)).is_equal(0)
	assert_bool(_ability.is_empowered()).is_false()


func test_ac1080_compensation_shows_the_charges_and_never_expires() -> void:
	_equip([HOSHO])
	var enemy: Enemy = _spawn_dummy(1.0)
	for i: int in 4:
		_strikes(1, enemy)
		assert_int(_player.buffs.get_stacks(COMPENSATION.id)).is_equal(i + 1)
	_player.buffs.advance(60.0)
	assert_int(_player.buffs.get_stacks(COMPENSATION.id)).is_equal(4)
	_strikes(1, enemy)
	assert_int(_player.buffs.get_stacks(COMPENSATION.id)).is_equal(0)


func test_ac1080_the_hud_frame_turns_gold_while_empowered() -> void:
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	await get_tree().process_frame
	(arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHEATHE)
	get_tree().paused = false
	var player: Player = arena.get_node("Player") as Player
	var slot: AbilitySlotView = arena.get_node("UI/Hud/AbilitySlots/BasicSlot") as AbilitySlotView
	var ability: AbilityComponent = player.basic_ability
	ability.set_physics_process(false)
	player.apply_upgrade(HOSHO)
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = arena.get_node("EnemyRegistry") as EnemyRegistry
	arena.add_child(enemy)
	enemy.activate(player.global_position + Vector3(0.0, 0.0, -1.0), null)
	enemy.health.setup(100000.0, 0.0)
	for i: int in 5:
		player.attack.strike_enemies([enemy] as Array[Enemy], 1.0, 1.0, 1.0)
	await get_tree().process_frame
	assert_bool(ability.is_empowered()).is_true()
	assert_bool(slot.is_showing_empowered()).is_true()
	assert_that(SLOT_CONFIG.empowered_frame_color).is_not_equal(SLOT_CONFIG.frame_color)
	ability.try_cast()
	await get_tree().process_frame
	assert_bool(slot.is_showing_empowered()).is_false()


# --- Zen and Netsui ---


func test_ac1081_a_full_manual_charge_grants_netsui_even_on_a_miss() -> void:
	_equip([ZEN])
	_full_slash()
	assert_int(_player.buffs.get_stacks(NETSUI.id)).is_equal(1)


func test_ac1081_a_charge_below_full_grants_nothing() -> void:
	_equip([ZEN])
	_charge_and_release(SHEATHE.charge_time * 0.99)
	assert_float(_ability.get_released_charge_ratio()).is_less(1.0)
	assert_int(_player.buffs.get_stacks(NETSUI.id)).is_equal(0)


func test_ac1082_the_empowered_sheathe_grants_netsui() -> void:
	_equip([HOSHO, ZEN])
	var enemy: Enemy = _spawn_dummy(1.0)
	_strikes(5, enemy)
	assert_int(_player.buffs.get_stacks(NETSUI.id)).is_equal(0)
	_ability.try_cast()
	assert_int(_player.buffs.get_stacks(NETSUI.id)).is_equal(1)


func test_ac1083_netsui_doubles_attack_speed_past_the_cards_for_three_seconds() -> void:
	_player.buffs.set_physics_process(false)
	for i: int in ATTACK_SPEED_CARD.max_stacks:
		_player.apply_upgrade(ATTACK_SPEED_CARD)
	var normal: float = _player.stats.get_stat(PlayerStats.Stat.ATTACK_SPEED)
	assert_float(normal).is_equal_approx(SAMURAI.base_stats.attack_speed + ATTACK_SPEED_CARD.amount * ATTACK_SPEED_CARD.max_stacks, TOLERANCE)
	_player.buffs.add_stack(NETSUI)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.ATTACK_SPEED)).is_equal_approx(normal * 2.0, TOLERANCE)
	_player.buffs.advance(NETSUI.stack_duration - 1.0 / 60.0)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.ATTACK_SPEED)).is_equal_approx(normal * 2.0, TOLERANCE)
	_player.buffs.advance(2.0 / 60.0)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.ATTACK_SPEED)).is_equal_approx(normal, TOLERANCE)


func test_ac1084_gaining_netsui_again_restarts_it_without_stacking() -> void:
	_player.buffs.set_physics_process(false)
	var normal: float = _player.stats.get_stat(PlayerStats.Stat.ATTACK_SPEED)
	_player.buffs.add_stack(NETSUI)
	_player.buffs.advance(2.0)
	_player.buffs.add_stack(NETSUI)
	assert_float(_player.buffs.get_time_left(NETSUI.id)).is_equal_approx(NETSUI.stack_duration, TOLERANCE)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.ATTACK_SPEED)).is_equal_approx(normal * 2.0, TOLERANCE)


func test_ac1085_netsui_doubles_the_combo_clip_speed() -> void:
	_player.buffs.set_physics_process(false)
	var normal: float = _player.attack.get_clip_speed()
	_player.buffs.add_stack(NETSUI)
	assert_float(_player.attack.get_clip_speed()).is_equal_approx(normal * 2.0, TOLERANCE)


func test_ac1086_without_zen_no_sheathe_grants_netsui() -> void:
	_equip([HOSHO])
	var enemy: Enemy = _spawn_dummy(1.0)
	_full_slash()
	_ability.reset_cooldown()
	_strikes(5, enemy)
	_ability.try_cast()
	assert_int(_player.buffs.get_stacks(NETSUI.id)).is_equal(0)


# --- Data and icons ---


func test_ac1087_attack_speed_is_the_last_modifier_and_buffs_can_be_removed_or_permanent() -> void:
	assert_int(BuffModifier.Stat.ATTACK_SPEED).is_equal(BuffModifier.Stat.size() - 1)
	assert_int(BuffModifier.Stat.DAMAGE).is_equal(3)
	var buffs: BuffComponent = _player.buffs
	buffs.set_physics_process(false)
	var emitted: Array[int] = [0]
	buffs.changed.connect(func() -> void: emitted[0] += 1)
	buffs.add_stack(COMPENSATION)
	buffs.add_stack(TRIUMPH)
	buffs.advance(TRIUMPH.stack_duration + 1.0)
	assert_int(buffs.get_stacks(TRIUMPH.id)).is_equal(0)
	assert_int(buffs.get_stacks(COMPENSATION.id)).is_equal(1)
	var before: int = emitted[0]
	buffs.remove(COMPENSATION.id)
	assert_int(buffs.get_stacks(COMPENSATION.id)).is_equal(0)
	assert_int(emitted[0]).is_equal(before + 1)
	buffs.remove(COMPENSATION.id)
	assert_int(emitted[0]).is_equal(before + 1)


func test_ac1088_compensation_and_netsui_have_their_icons() -> void:
	for buff: BuffData in [COMPENSATION, NETSUI]:
		assert_object(buff.icon).is_not_null()
		assert_that(buff.icon_color).is_not_equal(Color(0, 0, 0, 0))
	var source: String = FileAccess.get_file_as_string("res://assets/icons/status/SOURCE.md")
	for glyph: String in ["sword_array.svg", "lightning_frequency.svg"]:
		assert_bool(source.contains("`%s`" % glyph)).is_true()
	assert_str(COMPENSATION.icon.resource_path).is_equal("res://assets/icons/status/sword_array.svg")
	assert_str(NETSUI.icon.resource_path).is_equal("res://assets/icons/status/lightning_frequency.svg")
	assert_bool(COMPENSATION.is_permanent()).is_true()
	assert_bool(NETSUI.global).is_true()
	assert_int(NETSUI.max_stacks).is_equal(1)
	assert_float(NETSUI.stack_duration).is_equal(3.0)
	assert_str(ZEN.title).is_equal("Zen")
	assert_str(HOSHO.title).is_equal("Hosho")
	assert_str(NUKI.title).is_equal("Nuki")


func test_ac1088_the_cards_are_pooled_with_sheathe_and_leave_once_taken() -> void:
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	get_tree().paused = true
	await get_tree().process_frame
	(arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHEATHE)
	var wave_manager: WaveManager = arena.get_node("WaveManager") as WaveManager
	var player: Player = arena.get_node("Player") as Player
	for card: AbilityUniqueUpgradeData in [HOSHO, ZEN]:
		assert_bool(wave_manager.get_available_pool().has(card)).is_true()
		player.apply_upgrade(card)
		assert_bool(player.is_maxed(card)).is_true()
		assert_bool(wave_manager.get_available_pool().has(card)).is_false()
