extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
## Violet cards, also in the pool (docs/specs/affliction.md).
const AFFLICTION_CATALOG: AfflictionCatalog = preload("res://data/afflictions/affliction_catalog.tres")

const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const PICKER_CONFIG: UpgradePickerConfig = preload("res://data/ui/upgrade_picker_config.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const LETHAL_HIT: float = 100000.0

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _ability_picker: AbilityPicker
var _picker: UpgradePicker
var _pause: PauseMenu
var _wave_manager: WaveManager


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_ability_picker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_pause = _arena.get_node("UI/PauseMenu") as PauseMenu
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	get_tree().paused = true
	await get_tree().process_frame


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		# boss-colmena: a shielded boss (the Colmena) must die too.
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


func _slot(slot_name: String) -> AbilitySlotView:
	return _arena.get_node("UI/Hud/AbilitySlots/" + slot_name) as AbilitySlotView


func test_ac53_run_starts_paused_with_the_ability_picker_open() -> void:
	assert_bool(_ability_picker.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(_registry.alive_count()).is_equal(0)
	assert_int(_ability_picker.get_offered().size()).is_equal(2)
	assert_bool(_ability_picker.get_offered().has(SHIELD_CHARGE)).is_true()
	assert_bool(_ability_picker.get_offered().has(PARRY)).is_true()
	assert_bool(_player.basic_ability.is_equipped()).is_false()


func test_ac53_choosing_the_shield_charge_equips_it_and_starts_wave_one() -> void:
	_ability_picker.choose(SHIELD_CHARGE)
	assert_bool(_ability_picker.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_object(_player.basic_ability.get_data()).is_same(SHIELD_CHARGE)
	assert_bool(_player.ultimate_ability.is_equipped()).is_false()
	assert_int(_run_state.wave).is_equal(1)
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)


func test_ac54_card_pool_holds_player_and_equipped_ability_upgrades() -> void:
	_ability_picker.choose(SHIELD_CHARGE)
	var pool: Array[UpgradeCard] = _wave_manager.get_card_pool()
	assert_int(pool.size()).is_equal(CATALOG.upgrades.size() + SHIELD_CHARGE.upgrades.size() + SHIELD_CHARGE.unique_upgrades.size() + AFFLICTION_CATALOG.cards.size())
	for upgrade: AbilityUpgradeData in SHIELD_CHARGE.upgrades:
		assert_bool(pool.has(upgrade)).is_true()


func test_ac80_choosing_the_parry_pools_only_its_upgrades() -> void:
	_ability_picker.choose(PARRY)
	assert_object(_player.basic_ability.get_data()).is_same(PARRY)
	var pool: Array[UpgradeCard] = _wave_manager.get_card_pool()
	assert_int(pool.size()).is_equal(CATALOG.upgrades.size() + PARRY.upgrades.size() + PARRY.unique_upgrades.size() + AFFLICTION_CATALOG.cards.size())
	for upgrade: AbilityUpgradeData in PARRY.upgrades:
		assert_bool(pool.has(upgrade)).is_true()
	for upgrade: AbilityUpgradeData in SHIELD_CHARGE.upgrades:
		assert_bool(pool.has(upgrade)).is_false()


func test_ac55_choosing_an_ability_card_upgrades_the_slot_only() -> void:
	_ability_picker.choose(SHIELD_CHARGE)
	_kill_all_active()
	assert_bool(_picker.is_open()).is_true()
	_picker.choose(SHIELD_CHARGE.upgrades[0])
	assert_float(_player.basic_ability.get_stat(AbilityData.Stat.BASE_DAMAGE)).is_equal_approx(SHIELD_CHARGE.base_damage + SHIELD_CHARGE.upgrades[0].amount, 0.0001)
	assert_int(_player.stats.get_upgrades().size()).is_equal(0)
	for i: int in PlayerStats.Stat.size():
		var stat: PlayerStats.Stat = i as PlayerStats.Stat
		assert_float(_player.stats.get_stat(stat)).is_equal_approx(PLAYER_STATS.get_base(stat), 0.0001)
	assert_int(_run_state.wave).is_equal(2)
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)


func test_ac56_ability_cards_are_light_blue() -> void:
	_ability_picker.choose(SHIELD_CHARGE)
	var offer: Array[UpgradeCard] = [SHIELD_CHARGE.upgrades[0], DAMAGE_UPGRADE]
	_picker.show_offer(offer, false)
	var buttons: Array[Button] = _picker.get_card_buttons()
	assert_int(buttons.size()).is_equal(2)
	var ability_style: StyleBoxFlat = buttons[0].get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_object(ability_style).is_not_null()
	assert_that(ability_style.bg_color).is_equal(PICKER_CONFIG.ability_card_color)
	assert_bool(buttons[1].has_theme_stylebox_override(&"normal")).is_false()


func test_ac57_hud_shows_the_basic_slot_and_a_bigger_locked_ultimate() -> void:
	var basic: AbilitySlotView = _slot("BasicSlot")
	var ultimate: AbilitySlotView = _slot("UltimateSlot")
	assert_bool(basic.is_locked()).is_true()
	assert_bool(ultimate.is_locked()).is_true()
	assert_float(ultimate.get_radius()).is_greater(basic.get_radius())
	_ability_picker.choose(SHIELD_CHARGE)
	await get_tree().process_frame
	assert_bool(basic.is_locked()).is_false()
	assert_float(basic.get_shown_ratio()).is_equal(0.0)
	assert_bool(ultimate.is_locked()).is_true()
	assert_float(ultimate.size.x).is_greater(basic.size.x)
	_player.basic_ability.try_cast()
	await get_tree().process_frame
	assert_float(basic.get_shown_ratio()).is_greater(0.0)


func test_ac59_pause_is_ignored_while_choosing_the_ability() -> void:
	_pause.toggle()
	assert_bool(_pause.is_open()).is_false()
	assert_bool(_ability_picker.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
