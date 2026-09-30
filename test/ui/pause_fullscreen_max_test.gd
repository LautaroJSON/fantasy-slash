extends GdUnitTestSuite
## docs/specs/pause-fullscreen-max-upgrades.md: full-screen pause, two upgrade
## columns and the "Max" buttons (per row and per section).

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const CONFIG: PauseMenuConfig = preload("res://data/ui/pause_menu_config.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const AFFLICTION_CATALOG: AfflictionCatalog = preload("res://data/afflictions/affliction_catalog.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const DEFENSE_UPGRADE: UpgradeData = preload("res://data/upgrades/defense.tres")
const CONCUSSIVE: AbilityUniqueUpgradeData = preload("res://data/abilities/shield_charge/unique/concussive.tres")
const POISON: AfflictionUpgradeData = preload("res://data/afflictions/cards/poison_basic_attack.tres")

var _arena: Node3D
var _player: Player
var _pause: PauseMenu
var _panel: UpgradePanel


func before_test() -> void:
	Session.mode = GameSession.Mode.SANDBOX
	Session.sandbox_request = null
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_player = _arena.get_node("Player") as Player
	_pause = _arena.get_node("UI/PauseMenu") as PauseMenu
	_panel = _pause.get_upgrade_panel()
	await get_tree().process_frame
	(_arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHIELD_CHARGE)
	_pause.open()


func after_test() -> void:
	Session.mode = GameSession.Mode.NORMAL
	Session.sandbox_request = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _cards_of(group: UpgradeCard.Group) -> Array[UpgradeCard]:
	var cards: Array[UpgradeCard] = []
	for card: UpgradeCard in (_arena.get_node("WaveManager") as WaveManager).get_card_pool():
		if card.get_group() == group:
			cards.append(card)
	return cards


func _all_maxed(group: UpgradeCard.Group) -> bool:
	for card: UpgradeCard in _cards_of(group):
		if not _player.is_maxed(card):
			return false
	return true


func _none_taken(group: UpgradeCard.Group) -> bool:
	for card: UpgradeCard in _cards_of(group):
		if _player.count_upgrade(card) > 0:
			return false
	return true


## One Affliction card per type, in catalog order.
func _one_card_per_type() -> Array[AfflictionUpgradeData]:
	var cards: Array[AfflictionUpgradeData] = []
	var types: Array[StringName] = []
	for card: AfflictionUpgradeData in AFFLICTION_CATALOG.cards:
		if not types.has(card.affliction.id):
			types.append(card.affliction.id)
			cards.append(card)
	return cards


# --- Layout -----------------------------------------------------------------

func test_ac1361_the_panel_fills_the_screen_minus_the_margin() -> void:
	await _frames(2)
	var screen: Rect2 = _pause.get_global_rect()
	var panel: Rect2 = _pause.get_panel().get_global_rect()
	var margin: float = CONFIG.screen_margin
	assert_float(margin).is_equal(16.0)
	assert_float(panel.position.x).is_equal_approx(screen.position.x + margin, 1.0)
	assert_float(panel.position.y).is_equal_approx(screen.position.y + margin, 1.0)
	assert_float(panel.end.x).is_equal_approx(screen.end.x - margin, 1.0)
	assert_float(panel.end.y).is_equal_approx(screen.end.y - margin, 1.0)


func test_ac1362_the_upgrade_list_uses_the_free_height() -> void:
	_pause.select_tab(PauseMenu.Tab.UPGRADES)
	await _frames(2)
	assert_float(_panel.get_scroll().size.y).is_greater_equal(_pause.get_global_rect().size.y * 0.5)


func test_ac1363_sections_go_to_their_column() -> void:
	assert_int(_panel.get_section_column(UpgradeCard.Group.OFFENSE)).is_equal(0)
	assert_int(_panel.get_section_column(UpgradeCard.Group.DEFENSE)).is_equal(0)
	assert_int(_panel.get_section_column(UpgradeCard.Group.ABILITY)).is_equal(1)
	assert_int(_panel.get_section_column(UpgradeCard.Group.AFFLICTION)).is_equal(1)


# --- Max per row ------------------------------------------------------------

func test_ac1364_row_max_takes_a_stat_card_to_its_cap() -> void:
	_panel.max_card(DAMAGE_UPGRADE)
	assert_int(_player.count_upgrade(DAMAGE_UPGRADE)).is_equal(DAMAGE_UPGRADE.max_stacks)
	var expected: float = PLAYER_STATS.damage + DAMAGE_UPGRADE.max_stacks * DAMAGE_UPGRADE.amount
	assert_float(_player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(expected, 0.0001)
	assert_str(_pause.get_value_text(PlayerStats.Stat.DAMAGE)).is_equal("%.1f" % expected)
	assert_bool(_panel.is_max_enabled(DAMAGE_UPGRADE)).is_false()
	assert_bool(_panel.is_plus_enabled(DAMAGE_UPGRADE)).is_false()
	assert_bool(_panel.is_max_enabled(DEFENSE_UPGRADE)).is_true()


func test_ac1365_row_max_takes_a_golden_card_to_its_max_level() -> void:
	_panel.max_card(CONCUSSIVE)
	assert_int(_player.basic_ability.get_unique_level(CONCUSSIVE.id)).is_equal(CONCUSSIVE.max_level)


func test_ac1366_row_max_on_afflictions_respects_the_type_cap() -> void:
	_panel.max_card(POISON)
	assert_int(_player.count_upgrade(POISON)).is_equal(POISON.max_level)
	var per_type: Array[AfflictionUpgradeData] = _one_card_per_type()
	var config: AfflictionConfig = _player.afflictions.config
	assert_int(per_type.size()).is_greater(config.max_types)
	for i: int in config.max_types:
		_panel.max_card(per_type[i])
	var extra: AfflictionUpgradeData = per_type[config.max_types]
	_panel.max_card(extra)
	assert_int(_player.count_upgrade(extra)).is_equal(0)
	assert_int(_player.afflictions.get_type_count()).is_equal(config.max_types)


# --- Max per section --------------------------------------------------------

func test_ac1367_offense_max_only_touches_offense() -> void:
	_panel.max_group(UpgradeCard.Group.OFFENSE)
	assert_bool(_all_maxed(UpgradeCard.Group.OFFENSE)).is_true()
	assert_bool(_none_taken(UpgradeCard.Group.DEFENSE)).is_true()
	assert_bool(_none_taken(UpgradeCard.Group.ABILITY)).is_true()
	assert_bool(_none_taken(UpgradeCard.Group.AFFLICTION)).is_true()


func test_ac1368_defense_max_only_touches_defense() -> void:
	_panel.max_group(UpgradeCard.Group.DEFENSE)
	assert_bool(_all_maxed(UpgradeCard.Group.DEFENSE)).is_true()
	assert_bool(_none_taken(UpgradeCard.Group.OFFENSE)).is_true()
	assert_bool(_none_taken(UpgradeCard.Group.ABILITY)).is_true()


func test_ac1369_ability_max_includes_the_golden_cards() -> void:
	_panel.max_group(UpgradeCard.Group.ABILITY)
	assert_bool(_all_maxed(UpgradeCard.Group.ABILITY)).is_true()
	for unique: AbilityUniqueUpgradeData in SHIELD_CHARGE.unique_upgrades:
		assert_int(_player.basic_ability.get_unique_level(unique.id)).is_equal(unique.max_level)
	assert_bool(_none_taken(UpgradeCard.Group.OFFENSE)).is_true()


func test_ac1370_only_affliction_has_no_section_max() -> void:
	assert_bool(_panel.has_group_max_button(UpgradeCard.Group.OFFENSE)).is_true()
	assert_bool(_panel.has_group_max_button(UpgradeCard.Group.DEFENSE)).is_true()
	assert_bool(_panel.has_group_max_button(UpgradeCard.Group.ABILITY)).is_true()
	assert_bool(_panel.has_group_max_button(UpgradeCard.Group.AFFLICTION)).is_false()


func test_ac1371_each_max_emits_once() -> void:
	var emitted: Array[int] = [0]
	_panel.upgrades_changed.connect(func() -> void: emitted[0] += 1)
	_panel.max_card(DAMAGE_UPGRADE)
	assert_int(emitted[0]).is_equal(1)
	_panel.max_group(UpgradeCard.Group.DEFENSE)
	assert_int(emitted[0]).is_equal(2)


func test_ac1372_normal_mode_has_no_max_buttons() -> void:
	_pause.close()
	Session.mode = GameSession.Mode.NORMAL
	_player.apply_upgrade(DAMAGE_UPGRADE)
	_pause.open()
	assert_bool(_panel.is_editable()).is_false()
	for group: int in UpgradeCard.Group.size():
		assert_bool(_panel.has_group_max_button(group)).is_false()
	# The editable rows were queue_free()d when the list turned read-only.
	await get_tree().process_frame
