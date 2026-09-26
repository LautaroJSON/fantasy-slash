extends GdUnitTestSuite
## docs/specs/cooldown-timers.md: text format, ability slot timer and pulse,
## remaining seconds of debuffs and the 3D timers above enemy debuff icons.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SWIFT_STRIKE: AbilityData = preload("res://data/abilities/swift_strike/swift_strike.tres")
const TEXT_CONFIG: CooldownTextConfig = preload("res://data/ui/cooldown_text_config.tres")
const SLOT_CONFIG: AbilitySlotViewConfig = preload("res://data/ui/ability_slot_view_config.tres")
const ICON_CONFIG: DebuffIconConfig = preload("res://data/ui/debuff_icon_config.tres")
const LEVEL_MATERIAL: StandardMaterial3D = preload("res://materials/enemy_level_material.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const WEAKEN: DebuffData = preload("res://data/debuffs/weaken.tres")
const TOLERANCE: float = 0.0001

var _registry: EnemyRegistry
var _player: Player


func before_test() -> void:
	Session.character_class = SAMURAI
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	await get_tree().physics_frame


func after_test() -> void:
	Session.character_class = null


## Slot view outside the HUD, bound to the basic ability.
func _make_slot() -> AbilitySlotView:
	var slot: AbilitySlotView = auto_free(AbilitySlotView.new())
	slot.config = SLOT_CONFIG
	var key := Label.new()
	key.text = "E"
	slot.add_child(key)
	slot.key_label = key
	add_child(slot)
	slot.setup(_player.basic_ability)
	return slot


func _spawn_idle_enemy() -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(_player.global_position + Vector3(0.0, 0.0, 20.0), null)
	return enemy


func test_ac317_format_rounds_up_with_tenths_below_ten_seconds() -> void:
	var cases: Dictionary[float, String] = {
		0.0: "", -1.0: "", 0.03: "0.1", 2.5: "2.5", 2.5000001: "2.5", 2.51: "2.6",
		9.9: "9.9", 9.95: "10", 10.0: "10", 10.2: "11", 45.0: "45", 5000.0: "999",
	}
	for seconds: float in cases:
		assert_str(CooldownText.format(seconds, TEXT_CONFIG)).override_failure_message(
			"%s s" % seconds).is_equal(cases[seconds])
	var step: int = CooldownText.to_step(2.5, TEXT_CONFIG)
	assert_str(CooldownText.text_for_step(step, TEXT_CONFIG)).is_equal(CooldownText.text_for_step(step, TEXT_CONFIG))
	assert_int(CooldownText.to_step(2.46, TEXT_CONFIG)).is_equal(step)


func test_ac318_slot_shows_remaining_seconds_instead_of_the_key() -> void:
	_player.basic_ability.equip(SWIFT_STRIKE)
	var slot: AbilitySlotView = _make_slot()
	slot.advance(0.0)
	assert_str(slot.get_time_text()).is_equal("")
	assert_bool(slot.is_key_visible()).is_true()
	assert_bool(_player.basic_ability.try_cast()).is_true()
	assert_float(_player.basic_ability.get_cooldown_remaining()).is_equal_approx(6.0, TOLERANCE)
	slot.advance(0.0)
	assert_str(slot.get_time_text()).is_equal("6.0")
	assert_bool(slot.is_key_visible()).is_false()
	_player.basic_ability.reduce_cooldown(3.45)
	slot.advance(0.0)
	assert_str(slot.get_time_text()).is_equal("2.6")
	_player.basic_ability.reduce_cooldown(10.0)
	slot.advance(0.0)
	assert_str(slot.get_time_text()).is_equal("")
	assert_bool(slot.is_key_visible()).is_true()


func test_ac319_slot_pulses_when_the_cooldown_ends() -> void:
	_player.basic_ability.equip(SWIFT_STRIKE)
	var slot: AbilitySlotView = _make_slot()
	slot.advance(0.0)
	assert_bool(slot.is_pulsing()).is_false()
	assert_float(slot.scale.x).is_equal_approx(1.0, TOLERANCE)
	_player.basic_ability.try_cast()
	slot.advance(0.0)
	assert_bool(slot.is_pulsing()).is_false()
	_player.basic_ability.reduce_cooldown(10.0)
	slot.advance(0.0)
	assert_bool(slot.is_pulsing()).is_true()
	assert_float(slot.scale.x).is_equal_approx(SLOT_CONFIG.ready_pulse_scale, TOLERANCE)
	assert_vector(slot.pivot_offset).is_equal(Vector2.ONE * slot.get_radius())
	slot.advance(SLOT_CONFIG.ready_pulse_duration / 2.0)
	assert_float(slot.scale.x).is_equal_approx(lerpf(1.0, SLOT_CONFIG.ready_pulse_scale, 0.5), TOLERANCE)
	slot.advance(SLOT_CONFIG.ready_pulse_duration)
	assert_bool(slot.is_pulsing()).is_false()
	assert_float(slot.scale.x).is_equal_approx(1.0, TOLERANCE)


func test_ac320_no_time_while_charging_then_cooldown_after_release() -> void:
	_player.basic_ability.equip(SHEATHE)
	var slot: AbilitySlotView = _make_slot()
	assert_bool(_player.basic_ability.try_cast()).is_true()
	assert_bool(_player.basic_ability.is_charging()).is_true()
	slot.advance(0.0)
	assert_str(slot.get_time_text()).is_equal("")
	assert_bool(slot.is_showing_charge()).is_true()
	assert_bool(_player.basic_ability.release_charge()).is_true()
	slot.advance(0.0)
	assert_str(slot.get_time_text()).is_equal("8.0")
	assert_bool(slot.is_key_visible()).is_false()


func test_ac323_remaining_seconds_of_timed_and_tick_debuffs() -> void:
	var enemy: Enemy = _spawn_idle_enemy()
	enemy.debuffs.apply(WEAKEN, 0.05)
	enemy.debuffs.apply(BLEED, 0.01)
	assert_float(enemy.debuffs.get_remaining_seconds(WEAKEN.id)).is_equal_approx(4.0, TOLERANCE)
	assert_float(enemy.debuffs.get_remaining_seconds(BLEED.id)).is_equal_approx(5.0, TOLERANCE)
	enemy.debuffs.advance(1.5)
	assert_float(enemy.debuffs.get_remaining_seconds(WEAKEN.id)).is_equal_approx(2.5, TOLERANCE)
	enemy.debuffs.advance(0.8)
	assert_float(enemy.debuffs.get_remaining_seconds(BLEED.id)).is_equal_approx(2.7, TOLERANCE)
	enemy.debuffs.apply(WEAKEN, 0.05)
	enemy.debuffs.apply(BLEED, 0.01)
	assert_float(enemy.debuffs.get_remaining_seconds(WEAKEN.id)).is_equal_approx(4.0, TOLERANCE)
	assert_float(enemy.debuffs.get_remaining_seconds(BLEED.id)).is_equal_approx(4.0 + enemy.debuffs.get_active()[1].tick_left, TOLERANCE)
	assert_float(enemy.debuffs.get_remaining_seconds(&"missing")).is_equal(0.0)


func test_ac324_enemy_debuff_icons_show_their_remaining_seconds() -> void:
	var enemy: Enemy = _spawn_idle_enemy()
	var icons: DebuffIconRow = enemy.get_node("HealthBar/DebuffIcons") as DebuffIconRow
	assert_bool(icons.is_processing()).is_false()
	enemy.debuffs.apply(BLEED, 0.01)
	enemy.debuffs.apply(WEAKEN, 0.05)
	assert_bool(icons.is_processing()).is_true()
	assert_str(icons.get_time_text(0)).is_equal("5.0")
	assert_str(icons.get_time_text(1)).is_equal("4.0")
	assert_object(icons.get_time_mesh(0)).is_not_same(icons.get_time_mesh(1))
	var label: MeshInstance3D = icons.get_icon(0).get_child(0) as MeshInstance3D
	assert_object(label.mesh).is_same(icons.get_time_mesh(0))
	assert_object(label.material_override).is_same(LEVEL_MATERIAL)
	assert_object(ICON_CONFIG.time_material).is_same(LEVEL_MATERIAL)
	enemy.debuffs.advance(1.5)
	icons.update_times()
	assert_str(icons.get_time_text(0)).is_equal("3.5")
	assert_str(icons.get_time_text(1)).is_equal("2.5")
	enemy.debuffs.advance(2.6)
	assert_int(icons.get_visible_icon_count()).is_equal(1)
	assert_str(icons.get_time_text(0)).is_equal("0.9")
	enemy.debuffs.clear()
	assert_int(icons.get_visible_icon_count()).is_equal(0)
	assert_bool(icons.is_processing()).is_false()


func test_ac382_enemy_icon_shows_weaken_stacks() -> void:
	var enemy: Enemy = _spawn_idle_enemy()
	var icons: DebuffIconRow = enemy.get_node("HealthBar/DebuffIcons") as DebuffIconRow
	for stacks: int in [1, 2, 3, 3]:
		enemy.debuffs.apply(WEAKEN, 0.05)
		assert_str(icons.get_stack_text(0)).is_equal(str(stacks))
	assert_bool(icons.is_stack_visible(0)).is_true()
	var label: MeshInstance3D = icons.get_icon(0).get_child(1) as MeshInstance3D
	assert_object(label.material_override).is_same(LEVEL_MATERIAL)
	assert_str((label.mesh as TextMesh).text).is_equal("3")
	assert_object(label.mesh).is_not_same(icons.get_time_mesh(0))
	assert_float(ICON_CONFIG.icon_size).is_equal(0.2)


func test_ac383_bleed_shows_no_stack_count() -> void:
	var enemy: Enemy = _spawn_idle_enemy()
	var icons: DebuffIconRow = enemy.get_node("HealthBar/DebuffIcons") as DebuffIconRow
	enemy.debuffs.apply(BLEED, 0.001)
	enemy.debuffs.apply(WEAKEN, 0.05)
	assert_bool(icons.is_stack_visible(0)).is_false()
	assert_bool(icons.is_stack_visible(1)).is_true()
	assert_str(icons.get_stack_text(1)).is_equal("1")
