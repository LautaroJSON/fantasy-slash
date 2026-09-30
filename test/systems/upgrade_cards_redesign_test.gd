extends GdUnitTestSuite
## Rolls, categories and look of the upgrade cards (docs/specs/upgrade-cards-redesign.md, AC1426-AC1438).

const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const ROLLS: RollConfig = preload("res://data/upgrades/roll_config.tres")
const SHOP: ShopConfig = preload("res://data/economy/shop_config.tres")
const PICKER_SCENE: PackedScene = preload("res://ui/upgrade_picker.tscn")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const RULES: CombatRules = preload("res://data/combat/combat_rules.tres")
const BLEEDING: AfflictionUpgradeData = preload("res://data/afflictions/cards/bleeding_basic_attack.tres")
const POISON_ABILITY: AfflictionUpgradeData = preload("res://data/afflictions/cards/poison_ability.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const EPSILON: float = 0.0001

## Stat -> category of every white card.
const CATEGORIES: Dictionary = {
	PlayerStats.Stat.DAMAGE: UpgradeData.Category.DAMAGE,
	PlayerStats.Stat.CRIT_CHANCE: UpgradeData.Category.DAMAGE,
	PlayerStats.Stat.CRIT_DAMAGE: UpgradeData.Category.DAMAGE,
	PlayerStats.Stat.DAMAGE_BONUS: UpgradeData.Category.DAMAGE,
	PlayerStats.Stat.ATTACK_SPEED: UpgradeData.Category.DAMAGE,
	PlayerStats.Stat.ATTACK_RANGE: UpgradeData.Category.DAMAGE,
	PlayerStats.Stat.DEFENSE: UpgradeData.Category.DEFENSE,
	PlayerStats.Stat.MAX_HEALTH: UpgradeData.Category.DEFENSE,
	PlayerStats.Stat.LIFESTEAL: UpgradeData.Category.UTILITY,
	PlayerStats.Stat.MOVE_SPEED: UpgradeData.Category.UTILITY,
	PlayerStats.Stat.PICKUP_RADIUS: UpgradeData.Category.UTILITY,
	PlayerStats.Stat.AFFLICTION_BUILDUP: UpgradeData.Category.UTILITY,
}


func _card_for(stat: PlayerStats.Stat) -> UpgradeData:
	for card: UpgradeData in CATALOG.upgrades:
		if card.stat == stat:
			return card
	return null


func _picker() -> UpgradePicker:
	var picker: UpgradePicker = auto_free(PICKER_SCENE.instantiate()) as UpgradePicker
	picker.rolls = ROLLS
	add_child(picker)
	return picker


func _first_body(picker: UpgradePicker) -> RichTextLabel:
	return _find_body(picker.get_card_buttons()[0])


func _find_body(node: Node) -> RichTextLabel:
	for child: Node in node.find_children("*", "RichTextLabel", true, false):
		return child as RichTextLabel
	return null


func _first_title(button: Button) -> String:
	return (button.find_child("Title", true, false) as Label).text


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_ac1426_every_white_card_has_its_category_and_four_ascending_rolls() -> void:
	assert_int(CATALOG.upgrades.size()).is_equal(CATEGORIES.size())
	for card: UpgradeData in CATALOG.upgrades:
		assert_int(card.category).override_failure_message(card.title).is_equal(CATEGORIES[card.stat])
		assert_int(card.roll_amounts.size()).override_failure_message(card.title).is_equal(4)
		assert_float(card.roll_amounts[1]).override_failure_message(card.title).is_equal_approx(card.amount, EPSILON)
		for tier: int in range(1, 4):
			assert_float(card.roll_amounts[tier]).override_failure_message(card.title).is_greater(card.roll_amounts[tier - 1])


func test_ac1427_a_roll_follows_the_weights_and_is_reproducible_by_seed() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var counts: Array[int] = [0, 0, 0, 0]
	var first: Array[int] = []
	for i: int in 10000:
		var tier: int = UpgradeRoll.roll_tier(ROLLS, rng)
		counts[tier] += 1
		if i < 20:
			first.append(tier)
	assert_float(counts[0] / 10000.0).is_equal_approx(0.50, 0.03)
	assert_float(counts[1] / 10000.0).is_equal_approx(0.30, 0.03)
	assert_float(counts[2] / 10000.0).is_equal_approx(0.15, 0.03)
	assert_float(counts[3] / 10000.0).is_equal_approx(0.05, 0.02)
	rng.seed = 7
	for i: int in 20:
		assert_int(UpgradeRoll.roll_tier(ROLLS, rng)).is_equal(first[i])


func test_ac1427_rolling_an_offer_keeps_the_other_cards_and_the_catalog_untouched() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var damage: UpgradeData = _card_for(PlayerStats.Stat.DAMAGE)
	var offer: Array[UpgradeCard] = [damage, PARRY.upgrades[0]]
	var rolled: Array[UpgradeCard] = UpgradeRoll.roll_offer(offer, ROLLS, rng)
	assert_object(rolled[1]).is_same(PARRY.upgrades[0])
	assert_object(rolled[0]).is_not_same(damage)
	assert_int((rolled[0] as UpgradeData).roll_tier).is_between(0, 3)
	assert_int(damage.roll_tier).is_equal(-1)
	assert_float(damage.amount).is_equal_approx(damage.roll_amounts[1], EPSILON)


func test_ac1428_the_number_takes_the_color_and_name_of_its_roll() -> void:
	var damage: UpgradeData = _card_for(PlayerStats.Stat.DAMAGE)
	for tier: int in 4:
		var picker: UpgradePicker = _picker()
		var offer: Array[UpgradeCard] = [damage.rolled(tier)]
		picker.show_offer(offer, false)
		assert_str(_first_body(picker).text).contains(ROLLS.color_of(tier).to_html(false))
		var pills: Array[String] = []
		for label: Node in picker.get_card_buttons()[0].find_children("*", "Label", true, false):
			pills.append((label as Label).text)
		assert_array(pills).contains([ROLLS.name_of(tier)])
	assert_array([ROLLS.color_of(0), ROLLS.color_of(1), ROLLS.color_of(2), ROLLS.color_of(3)]).contains_exactly([Color.WHITE, ROLLS.color_of(1), ROLLS.color_of(2), ROLLS.color_of(3)])
	assert_bool(ROLLS.color_of(1) == ROLLS.color_of(2)).is_false()


func test_ac1429_applying_a_rolled_card_adds_its_rolled_value() -> void:
	var stats: StatsComponent = auto_free(StatsComponent.new()) as StatsComponent
	stats.base_stats = PLAYER_STATS
	stats.rules = RULES
	var damage: UpgradeData = _card_for(PlayerStats.Stat.DAMAGE)
	var before: float = PLAYER_STATS.damage
	stats.add_upgrade(damage.rolled(3))
	assert_float(stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(before + damage.roll_amounts[3], EPSILON)
	stats.add_upgrade(damage.rolled(0))
	assert_float(stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(before + damage.roll_amounts[3] + damage.roll_amounts[0], EPSILON)


func test_ac1430_the_price_follows_the_tier_of_the_roll() -> void:
	var damage: UpgradeData = _card_for(PlayerStats.Stat.DAMAGE)
	var expected: Array[int] = [36, 60, 90, 150]
	for tier: int in 4:
		assert_int(ShopPricing.card_price(damage.rolled(tier), 1, 0, SHOP, ROLLS)).is_equal(expected[tier])
	assert_int(ShopPricing.card_price(damage, 1, 0, SHOP, ROLLS)).is_equal(60)
	assert_int(ShopPricing.card_price(damage, 1, 0, SHOP)).is_equal(60)


func test_ac1431_rolled_copies_count_as_the_same_stat() -> void:
	var stats: StatsComponent = auto_free(StatsComponent.new()) as StatsComponent
	stats.base_stats = PLAYER_STATS
	stats.rules = RULES
	var damage: UpgradeData = _card_for(PlayerStats.Stat.DAMAGE)
	stats.add_upgrade(damage.rolled(1))
	stats.add_upgrade(damage.rolled(2))
	assert_int(stats.count_upgrade(damage)).is_equal(2)
	assert_bool(damage.rolled(0).is_same_kind(damage.rolled(3))).is_true()
	stats.remove_upgrade(damage)
	assert_int(stats.count_upgrade(damage)).is_equal(1)
	var pool: Array[UpgradeCard] = []
	pool.assign(CATALOG.upgrades)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in 30:
		var offer: Array[UpgradeCard] = UpgradeRoll.roll_offer(UpgradeOffer.pick(pool, 3, rng), ROLLS, rng)
		for a: int in offer.size():
			for b: int in range(a + 1, offer.size()):
				assert_bool(offer[a].is_same_kind(offer[b])).is_false()


func test_ac1432_ascension_copies_reduce_the_rolled_value() -> void:
	var stats: StatsComponent = auto_free(StatsComponent.new()) as StatsComponent
	stats.base_stats = PLAYER_STATS
	stats.rules = RULES
	var damage: UpgradeData = _card_for(PlayerStats.Stat.DAMAGE)
	for i: int in damage.max_stacks:
		stats.add_upgrade(damage.rolled(1))
	var before: float = stats.get_stat(PlayerStats.Stat.DAMAGE)
	stats.add_upgrade(damage.rolled(3))
	assert_float(stats.get_stat(PlayerStats.Stat.DAMAGE) - before).is_equal_approx(damage.roll_amounts[3] * damage.ascension_factor, EPSILON)


func test_ac1433_affliction_cards_are_titled_by_affliction_and_highlight_their_source() -> void:
	var picker: UpgradePicker = _picker()
	var offer: Array[UpgradeCard] = [BLEEDING, POISON_ABILITY]
	picker.show_offer(offer, false)
	var buttons: Array[Button] = picker.get_card_buttons()
	assert_str(_first_title(buttons[0])).is_equal("Aflicción: %s" % BLEEDING.affliction.title)
	assert_str(_find_body(buttons[0]).text).contains("golpes")
	assert_str(_find_body(buttons[0]).text).contains(BLEEDING.affliction.title)
	assert_str(_find_body(buttons[0]).get_parsed_text()).starts_with("Tus golpes acumulan %s." % BLEEDING.affliction.title)
	assert_str(_find_body(buttons[1]).text).contains("habilidades")
	assert_str(_find_body(buttons[1]).text).not_contains("Se acumula con")


func test_ac1434_blue_cards_are_titled_by_the_ability() -> void:
	var picker: UpgradePicker = _picker()
	var offer: Array[UpgradeCard] = [PARRY.upgrades[0]]
	picker.show_offer(offer, false)
	assert_str(_first_title(picker.get_card_buttons()[0])).is_equal("Habilidad: %s" % PARRY.title)


func test_ac1435_every_card_is_a_focusable_button() -> void:
	var picker: UpgradePicker = _picker()
	var offer: Array[UpgradeCard] = [_card_for(PlayerStats.Stat.DAMAGE).rolled(0), _card_for(PlayerStats.Stat.MAX_HEALTH).rolled(1), PARRY.upgrades[0]]
	picker.show_offer(offer, true)
	assert_int(picker.get_card_buttons().size()).is_equal(3)
	for button: Button in picker.get_card_buttons():
		assert_object(button).is_instanceof(UpgradeCardView)
		assert_int(button.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_bool(picker.get_ban_button().has_focus() or picker.get_card_buttons()[0].has_focus()).is_true()
	assert_bool(picker.has_ban_card()).is_true()


func test_ac1436_cards_rise_in_a_fan_and_land_after_one_second() -> void:
	var picker: UpgradePicker = _picker()
	var damage: UpgradeData = _card_for(PlayerStats.Stat.DAMAGE)
	var offer: Array[UpgradeCard] = [damage.rolled(0), damage.rolled(1)]
	picker.show_offer(offer, false)
	var buttons: Array[Button] = picker.get_card_buttons()
	assert_float(buttons[1].modulate.a).is_less(1.0)
	assert_float(buttons[0].position.y).is_greater(50.0)
	assert_float(buttons[0].rotation).is_not_equal(0.0)
	await get_tree().create_timer(1.5).timeout
	assert_float(buttons[0].modulate.a).is_equal_approx(1.0, 0.01)
	assert_float(buttons[1].modulate.a).is_equal_approx(1.0, 0.01)
	assert_float(buttons[0].scale.x).is_equal(1.0)
	assert_float(buttons[0].position.y).is_equal_approx(0.0, 0.01)
	assert_float(buttons[1].rotation).is_equal_approx(0.0, 0.001)
	assert_bool(picker.is_locked()).is_false()
	assert_float(buttons[1].modulate.r).is_equal_approx(picker.config.card_unfocused_brightness, 0.02)
	assert_float(buttons[1].scale.x).is_equal_approx(1.0, 0.02)


func test_ac1437_golden_cards_shimmer() -> void:
	var picker: UpgradePicker = _picker()
	var unique: AbilityUniqueUpgradeData = null
	for ability_unique: AbilityUniqueUpgradeData in PARRY.unique_upgrades:
		unique = ability_unique
		break
	var offer: Array[UpgradeCard] = [unique, _card_for(PlayerStats.Stat.DAMAGE).rolled(0)]
	picker.show_offer(offer, false)
	var buttons: Array[Button] = picker.get_card_buttons()
	assert_bool((buttons[0] as UpgradeCardView).is_shimmering()).is_true()
	assert_bool((buttons[1] as UpgradeCardView).is_shimmering()).is_false()


func test_ac1438_roll_tables_and_price_factors_live_in_data() -> void:
	assert_array(ROLLS.weights).is_equal([50.0, 30.0, 15.0, 5.0])
	assert_array(ROLLS.price_factors).is_equal([0.6, 1.0, 1.5, 2.5])
	assert_array(_card_for(PlayerStats.Stat.DAMAGE).roll_amounts).is_equal([1.0, 3.0, 6.0, 9.0])
	assert_array(_card_for(PlayerStats.Stat.CRIT_CHANCE).roll_amounts).is_equal([0.01, 0.03, 0.06, 0.10])
	assert_array(_card_for(PlayerStats.Stat.AFFLICTION_BUILDUP).roll_amounts).is_equal([0.03, 0.07, 0.12, 0.20])


func test_ac1439_the_stat_number_has_the_size_of_the_text_and_long_descriptions_scroll() -> void:
	var picker: UpgradePicker = _picker()
	var offer: Array[UpgradeCard] = [_card_for(PlayerStats.Stat.DAMAGE).rolled(2), PARRY.unique_upgrades[0]]
	picker.show_offer(offer, false)
	var buttons: Array[Button] = picker.get_card_buttons()
	assert_str(_find_body(buttons[0]).text).not_contains("font_size")
	assert_bool(_find_body(buttons[1]).scroll_active).is_true()
	assert_float(buttons[0].custom_minimum_size.x).is_equal(buttons[1].custom_minimum_size.x)
	assert_float(buttons[0].custom_minimum_size.x).is_greater(200.0)
	assert_float(buttons[0].custom_minimum_size.y).is_less(400.0)


func test_ac1440_a_press_spammed_while_the_offer_opens_does_not_pick_a_card() -> void:
	var picker: UpgradePicker = _picker()
	var chosen: Array[UpgradeCard] = []
	picker.upgrade_chosen.connect(func(card: UpgradeCard) -> void: chosen.append(card))
	var offer: Array[UpgradeCard] = [_card_for(PlayerStats.Stat.DAMAGE).rolled(0), _card_for(PlayerStats.Stat.MAX_HEALTH).rolled(0)]
	picker.show_offer(offer, false)
	var card: UpgradeCardView = picker.get_card_buttons()[0] as UpgradeCardView
	assert_float(picker.config.card_enter_total).is_equal(1.0)
	assert_bool(picker.is_locked()).is_true()
	card.pressed.emit()
	assert_int(chosen.size()).is_equal(0)
	assert_bool(picker.is_open()).is_true()
	# A press that began while locked never counts, even if it is released after the lock.
	card.button_down.emit()
	await get_tree().create_timer(1.3).timeout
	assert_bool(picker.is_locked()).is_false()
	card.pressed.emit()
	assert_int(chosen.size()).is_equal(0)
	card.pressed.emit()
	assert_int(chosen.size()).is_equal(1)


func test_ac1444_a_card_that_cannot_be_bought_takes_no_hover_or_focus() -> void:
	var picker: UpgradePicker = _picker()
	var damage: UpgradeData = _card_for(PlayerStats.Stat.DAMAGE)
	var offer: Array[UpgradeCard] = [damage.rolled(0), damage.rolled(1)]
	var prices: Array[int] = [10, 999]
	picker.show_shop(offer, prices, 50, 25, 40, -1)
	await get_tree().create_timer(1.3).timeout
	var cards: Array[Button] = picker.get_card_buttons()
	assert_bool(cards[1].disabled).is_true()
	assert_int(cards[1].focus_mode).is_equal(Control.FOCUS_NONE)
	var before: float = cards[0].modulate.r
	cards[1].mouse_entered.emit()
	await get_tree().create_timer(0.3).timeout
	assert_float(cards[0].modulate.r).is_equal_approx(before, 0.01)
	cards[0].mouse_entered.emit()
	await get_tree().create_timer(0.3).timeout
	assert_float(cards[0].modulate.r).is_equal_approx(1.0, 0.01)


func test_ac1445_cards_show_no_hover_look_while_they_enter() -> void:
	var picker: UpgradePicker = _picker()
	var offer: Array[UpgradeCard] = [_card_for(PlayerStats.Stat.DAMAGE).rolled(0)]
	picker.show_offer(offer, false)
	var card: Button = picker.get_card_buttons()[0]
	assert_bool(picker.is_locked()).is_true()
	assert_object(card.get_theme_stylebox(&"hover")).is_same(card.get_theme_stylebox(&"normal"))
	await get_tree().create_timer(1.3).timeout
	assert_object(card.get_theme_stylebox(&"hover")).is_not_same(card.get_theme_stylebox(&"normal"))


func test_ac1446_the_shop_shows_the_gold_and_its_buttons_have_icon_and_price() -> void:
	var picker: UpgradePicker = _picker()
	var offer: Array[UpgradeCard] = [_card_for(PlayerStats.Stat.DAMAGE).rolled(0)]
	var prices: Array[int] = [10]
	var rerolls: Array[int] = []
	picker.reroll_requested.connect(func() -> void: rerolls.append(1))
	picker.show_shop(offer, prices, 240, 25, 40, -1, 60)
	assert_str((picker.find_child("GoldLabel", true, false) as Label).text).is_equal("240")
	assert_object((picker.find_child("GoldIcon", true, false) as TextureRect).texture).is_not_null()
	var reroll: Button = picker.get_reroll_button()
	assert_str((reroll.find_child("Price", true, false) as Label).text).is_equal("25")
	assert_bool((reroll.find_child("Coin", true, false) as Control).visible).is_true()
	assert_object((reroll.find_child("Icon", true, false) as TextureRect).texture).is_not_null()
	assert_str((picker.get_heal_button().find_child("Price", true, false) as Label).text).is_equal("40")
	# The gold buttons wait for the entrance too.
	reroll.pressed.emit()
	assert_int(rerolls.size()).is_equal(0)
	await get_tree().create_timer(1.3).timeout
	reroll.pressed.emit()
	assert_int(rerolls.size()).is_equal(1)


func test_ac1447_the_gold_pill_has_no_word_and_the_heal_button_is_green_with_its_amount() -> void:
	var picker: UpgradePicker = _picker()
	var offer: Array[UpgradeCard] = [_card_for(PlayerStats.Stat.DAMAGE).rolled(0)]
	var prices: Array[int] = [10]
	picker.show_shop(offer, prices, 240, 25, 40, -1, 60)
	assert_object(picker.find_child("GoldCaption", true, false)).is_null()
	var pill: StyleBoxFlat = (picker.find_child("GoldPanel", true, false) as PanelContainer).get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_int(pill.corner_radius_top_left).is_greater(20)
	assert_int(pill.border_width_left).is_equal(0)
	var heal: Button = picker.get_heal_button()
	var frame: StyleBoxFlat = heal.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_that(frame.border_color).is_equal(picker.config.heal_color)
	assert_str((heal.find_child("Amount", true, false) as Label).text).is_equal("+60")
	assert_bool((heal.find_child("Amount", true, false) as Control).visible).is_true()
	assert_str((heal.find_child("Price", true, false) as Label).text).is_equal("40")
	var reroll_frame: StyleBoxFlat = picker.get_reroll_button().get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_that(reroll_frame.border_color).is_not_equal(picker.config.heal_color)
	assert_float(picker.get_reroll_button().custom_minimum_size.y).is_greater_equal(60.0)
