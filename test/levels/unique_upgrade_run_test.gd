extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
## Adapted (parry-riposte-rework.md): Represalia, the only leveled unique of
## the Parry, is gone; the run equips the Shield Charge, whose Contundencia has
## levels and Impulso is binary.
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const RIPOSTE: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/riposte.tres")
const MOMENTUM: AbilityUniqueUpgradeData = preload("res://data/abilities/shield_charge/unique/momentum.tres")
const CONCUSSIVE: AbilityUniqueUpgradeData = preload("res://data/abilities/shield_charge/unique/concussive.tres")
const PICKER_CONFIG: UpgradePickerConfig = preload("res://data/ui/upgrade_picker_config.tres")
const LETHAL_HIT: float = 100000.0

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _picker: UpgradePicker
var _wave_manager: WaveManager


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	get_tree().paused = true
	await get_tree().process_frame
	var ability_picker: AbilityPicker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	ability_picker.choose(SHIELD_CHARGE)


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


func _show(cards: Array[UpgradeCard]) -> Array[Button]:
	_picker.show_offer(cards, false)
	return _picker.get_card_buttons()


func test_ac103_unique_cards_are_gold_and_show_their_level() -> void:
	var cards: Array[UpgradeCard] = [CONCUSSIVE]
	var button: Button = _show(cards)[0]
	var style: StyleBoxFlat = button.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_that(style.bg_color).is_equal(PICKER_CONFIG.unique_card_color)
	assert_str(button.text).contains("Contundencia (Nv 1)")
	_player.apply_upgrade(CONCUSSIVE)
	assert_str(_show(cards)[0].text).contains("Contundencia (Nv 2)")
	assert_str(_show(cards)[0].text).contains(CONCUSSIVE.level_descriptions[1])


func test_ac103_choosing_a_unique_card_upgrades_the_slot() -> void:
	_kill_all_active()
	_picker.choose(CONCUSSIVE)
	assert_int(_player.basic_ability.get_unique_level(&"concussive")).is_equal(1)
	assert_int(_player.stats.get_upgrades().size()).is_equal(0)


func test_ac103_maxed_unique_cards_leave_the_pool() -> void:
	assert_bool(_wave_manager.get_available_pool().has(MOMENTUM)).is_true()
	_player.apply_upgrade(MOMENTUM)
	assert_bool(_wave_manager.get_available_pool().has(MOMENTUM)).is_false()
	for i: int in CONCUSSIVE.max_level - 1:
		_player.apply_upgrade(CONCUSSIVE)
	assert_bool(_wave_manager.get_available_pool().has(CONCUSSIVE)).is_true()
	_player.apply_upgrade(CONCUSSIVE)
	assert_bool(_wave_manager.get_available_pool().has(CONCUSSIVE)).is_false()
	assert_int(_player.basic_ability.get_unique_level(&"concussive")).is_equal(CONCUSSIVE.max_level)


func test_ac123_binary_unique_rows_show_active_or_inactive() -> void:
	var pause: PauseMenu = _arena.get_node("UI/PauseMenu") as PauseMenu
	var panel: SandboxUpgradePanel = pause.get_sandbox_panel()
	panel.setup(_player, _wave_manager.get_card_pool())
	assert_str(panel.value_text(MOMENTUM)).is_equal("(inactivo)")
	_player.apply_upgrade(MOMENTUM)
	assert_str(panel.value_text(MOMENTUM)).is_equal("(activo)")
	_player.apply_upgrade(CONCUSSIVE)
	assert_str(panel.value_text(CONCUSSIVE)).is_equal("(1.5 s)")


func test_ac104_only_the_equipped_ability_unique_upgrades_are_pooled() -> void:
	var pool: Array[UpgradeCard] = _wave_manager.get_card_pool()
	assert_bool(pool.has(MOMENTUM)).is_true()
	assert_bool(pool.has(CONCUSSIVE)).is_true()
	assert_bool(pool.has(RIPOSTE)).is_false()
