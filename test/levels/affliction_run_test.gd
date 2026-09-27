extends GdUnitTestSuite
## docs/specs/affliction.md: the Affliction mechanic inside a real run (arena):
## offers, cap, Rage, boss HUD rows, status icon, pause and violet cards.

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const TITAN: BossChallengeData = preload("res://data/enemies/boss_challenges/titan.tres")
const AFFLICTION_CATALOG: AfflictionCatalog = preload("res://data/afflictions/affliction_catalog.tres")
const BUILDUP_CARD: UpgradeData = preload("res://data/upgrades/affliction_buildup.tres")
const PICKER_CONFIG: UpgradePickerConfig = preload("res://data/ui/upgrade_picker_config.tres")
const POISON_BASIC: AfflictionUpgradeData = preload("res://data/afflictions/cards/poison_basic_attack.tres")
const POISON_ABILITY: AfflictionUpgradeData = preload("res://data/afflictions/cards/poison_ability.tres")
const BURST_BASIC: AfflictionUpgradeData = preload("res://data/afflictions/cards/burst_basic_attack.tres")
const FROST_ABILITY: AfflictionUpgradeData = preload("res://data/afflictions/cards/frost_ability.tres")
const CORROSION_BASIC: AfflictionUpgradeData = preload("res://data/afflictions/cards/corrosion_basic_attack.tres")
const CORROSION_ABILITY: AfflictionUpgradeData = preload("res://data/afflictions/cards/corrosion_ability.tres")
const POISON_STATUS: DebuffData = preload("res://data/debuffs/poison.tres")
const LETHAL_HIT: float = 100000.0

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _picker: UpgradePicker
var _wave_manager: WaveManager


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	get_tree().paused = true
	await get_tree().process_frame
	var ability_picker: AbilityPicker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	ability_picker.choose(THRUST)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


func _first_enemy() -> Enemy:
	return _registry.get_active()[0]


func test_ac878_the_pool_drops_a_fourth_affliction() -> void:
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(BURST_BASIC)
	_player.apply_upgrade(FROST_ABILITY)
	var available: Array[UpgradeCard] = _wave_manager.get_available_pool()
	assert_bool(available.has(CORROSION_BASIC)).is_false()
	assert_bool(available.has(CORROSION_ABILITY)).is_false()
	assert_bool(available.has(POISON_ABILITY)).is_true()
	assert_bool(available.has(POISON_BASIC)).is_true()


func test_ac880_violet_cards_are_normal_offers_and_can_be_banned() -> void:
	var normal: Array[UpgradeCard] = UpgradeOffer.without_unique(_wave_manager.get_available_pool())
	for card: AfflictionUpgradeData in AFFLICTION_CATALOG.cards:
		assert_bool(normal.has(card)).is_true()
	assert_bool(normal.has(BUILDUP_CARD)).is_true()
	assert_int(_player.afflictions.get_type_count()).is_equal(0)
	_run_state.ban(POISON_BASIC)
	assert_bool(_wave_manager.get_available_pool().has(POISON_BASIC)).is_false()


func test_ac881_without_cards_left_rage_starts_as_before() -> void:
	for card: UpgradeCard in _wave_manager.get_card_pool():
		_run_state.ban(card)
	_kill_all_active()
	await get_tree().process_frame
	assert_int(_run_state.get_rage_level()).is_greater(0)


func test_ac888_boss_hud_rows_follow_the_buildup() -> void:
	_kill_all_active()
	_picker.choose(POISON_BASIC)
	_kill_all_active()
	_wave_manager.start_boss_wave(TITAN)
	await get_tree().process_frame
	var bar: BossHealthBar = (_arena.get_node("UI/Hud").get_node("%BossBars") as BossBarStack).get_bar(0)
	var boss: Enemy = bar.get_tracked()
	var rows: AfflictionHudRows = bar.get_affliction_rows()
	assert_int(rows.get_visible_row_count()).is_equal(1)
	_player.attack.enemy_hit.emit(boss, 5.0, false)
	var expected: float = 20.0 * (1.0 - boss.stats.affliction_resistance) / 100.0
	assert_float(rows.get_fill_width(0)).is_equal_approx(520.0 * expected, 0.01)
	assert_object(rows.get_fill_color(0)).is_equal(POISON_BASIC.affliction.bar_material.albedo_color)
	assert_bool(boss.affliction_bars.is_visible_in_tree()).is_false()


func test_ac890_the_pause_lists_the_afflictions() -> void:
	var pause: PauseMenu = _arena.get_node("UI/PauseMenu") as PauseMenu
	_player.apply_upgrade(BUILDUP_CARD)
	_player.apply_upgrade(BUILDUP_CARD)
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(FROST_ABILITY)
	get_tree().paused = false
	pause.toggle()
	assert_str(pause.get_value_text(PlayerStats.Stat.AFFLICTION_BUILDUP)).is_equal("+20 %")
	assert_str(pause.get_afflictions_text()).is_equal("Aflicciones 2/3\nVeneno (básicos) nv. 2\nEscarcha (habilidad) nv. 1")
	pause.toggle()


func test_ac891_violet_cards_show_the_next_level() -> void:
	_player.apply_upgrade(POISON_BASIC)
	var cards: Array[UpgradeCard] = [POISON_BASIC]
	_picker.show_offer(cards, false)
	var button: Button = _picker.get_card_buttons()[0]
	var style: StyleBoxFlat = button.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_that(style.bg_color).is_equal(PICKER_CONFIG.affliction_card_color)
	assert_str(button.text).starts_with("Aflicción: Veneno (Nv 2)\n")
	assert_str(button.text).contains(POISON_BASIC.get_description(2))


func test_ac895_a_wave_grunt_gets_poisoned_and_its_bar_empties() -> void:
	_player.apply_upgrade(POISON_BASIC)
	var enemy: Enemy = _first_enemy()
	for hit: int in 4:
		_player.attack.enemy_hit.emit(enemy, 5.0, false)
	assert_float(enemy.affliction_bars.get_fill_ratio(0)).is_equal_approx(0.8, 0.0001)
	_player.attack.enemy_hit.emit(enemy, 5.0, false)
	assert_bool(enemy.debuffs.has_debuff(POISON_STATUS.id)).is_true()
	assert_float(enemy.afflictions.get_ratio(0)).is_equal(0.0)
	assert_int(enemy.affliction_bars.get_visible_row_count()).is_equal(1)
