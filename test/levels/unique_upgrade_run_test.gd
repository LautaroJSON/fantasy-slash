extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const SWIFT_STRIKE: AbilityData = preload("res://data/abilities/swift_strike/swift_strike.tres")
const RESET: AbilityUniqueUpgradeData = preload("res://data/abilities/swift_strike/unique/reset.tres")
const EXECUTE: AbilityUniqueUpgradeData = preload("res://data/abilities/swift_strike/unique/execute.tres")
const LACERATING: AbilityUniqueUpgradeData = preload("res://data/abilities/thrust/unique/lacerating.tres")
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
	ability_picker.choose(SWIFT_STRIKE)


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
	var cards: Array[UpgradeCard] = [EXECUTE]
	var button: Button = _show(cards)[0]
	var style: StyleBoxFlat = button.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_that(style.bg_color).is_equal(PICKER_CONFIG.unique_card_color)
	assert_str(button.text).contains("Asesinato (Nv 1)")
	_player.apply_upgrade(EXECUTE)
	assert_str(_show(cards)[0].text).contains("Asesinato (Nv 2)")
	assert_str(_show(cards)[0].text).contains(EXECUTE.level_descriptions[1])


func test_ac103_choosing_a_unique_card_upgrades_the_slot() -> void:
	_kill_all_active()
	_picker.choose(EXECUTE)
	assert_int(_player.basic_ability.get_unique_level(&"execute")).is_equal(1)
	assert_int(_player.stats.get_upgrades().size()).is_equal(0)


func test_ac103_maxed_unique_cards_leave_the_pool() -> void:
	assert_bool(_wave_manager.get_available_pool().has(RESET)).is_true()
	_player.apply_upgrade(RESET)
	assert_bool(_wave_manager.get_available_pool().has(RESET)).is_false()
	for i: int in 2:
		_player.apply_upgrade(EXECUTE)
	assert_bool(_wave_manager.get_available_pool().has(EXECUTE)).is_true()
	_player.apply_upgrade(EXECUTE)
	assert_bool(_wave_manager.get_available_pool().has(EXECUTE)).is_false()
	assert_int(_player.basic_ability.get_unique_level(&"execute")).is_equal(3)


func test_ac123_binary_unique_rows_show_active_or_inactive() -> void:
	var pause: PauseMenu = _arena.get_node("UI/PauseMenu") as PauseMenu
	var panel: SandboxUpgradePanel = pause.get_sandbox_panel()
	panel.setup(_player, _wave_manager.get_card_pool())
	assert_str(panel.value_text(RESET)).is_equal("(inactivo)")
	_player.apply_upgrade(RESET)
	assert_str(panel.value_text(RESET)).is_equal("(activo)")
	_player.apply_upgrade(EXECUTE)
	_player.apply_upgrade(EXECUTE)
	assert_str(panel.value_text(EXECUTE)).is_equal("(20 %)")


func test_ac104_only_the_equipped_ability_unique_upgrades_are_pooled() -> void:
	var pool: Array[UpgradeCard] = _wave_manager.get_card_pool()
	assert_bool(pool.has(RESET)).is_true()
	assert_bool(pool.has(EXECUTE)).is_true()
	assert_bool(pool.has(LACERATING)).is_false()
