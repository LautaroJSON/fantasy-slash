extends GdUnitTestSuite
## docs/specs/status-icons.md: the LoL-style status icon (StatusIconView), its
## row with the "+" overflow slot (StatusIconRow) and the status data.

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CONFIG: StatusIconConfig = preload("res://data/ui/status_icon_config.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const WEAKEN: DebuffData = preload("res://data/debuffs/weaken.tres")
const RAGE: DebuffData = preload("res://data/debuffs/rage.tres")
const SHIELD: DebuffData = preload("res://data/debuffs/shield.tres")
const CONCUSSION: BuffData = preload("res://data/buffs/concussion.tres")
const ICON_DIR: String = "res://assets/icons/status/"
const DEBUFF_DIR: String = "res://data/debuffs/"
const BUFF_DIR: String = "res://data/buffs/"
const BACKGROUND_PATH: String = "M0 0h512v512H0z"
const TOLERANCE: float = 0.0001


func _spawn_idle_enemy() -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	add_child(enemy)
	enemy.activate(Vector3.ZERO, null)
	return enemy


func _view(side: float = 36.0) -> StatusIconView:
	var view: StatusIconView = auto_free(StatusIconView.create(CONFIG, side))
	add_child(view)
	return view


func _first_debuff(enemy: Enemy) -> DebuffComponent.ActiveDebuff:
	return enemy.debuffs.get_active()[0]


func test_ac901_five_children_in_order_and_no_time_label() -> void:
	var view: StatusIconView = _view()
	assert_int(view.get_child_count()).is_equal(5)
	assert_object(view.get_child(0)).is_instanceof(ColorRect)
	assert_object(view.get_child(1)).is_instanceof(TextureRect)
	assert_object(view.get_child(2)).is_same(view.get_clock())
	assert_int(view.get_clock().shape).is_equal(CooldownClock.Shape.SQUARE)
	assert_object(view.get_child(3)).is_instanceof(Control)
	assert_object(view.get_child(4)).is_instanceof(Label)
	var labels: int = 0
	for child: Node in view.get_children():
		if child is Label:
			labels += 1
	assert_int(labels).is_equal(1)
	var enemy: Enemy = _spawn_idle_enemy()
	enemy.debuffs.apply(WEAKEN, 0.1)
	view.show_debuff(_first_debuff(enemy))
	view.set_remaining(0.5, true)
	view.show_overflow()
	assert_int(view.get_child_count()).is_equal(5)


func test_ac902_colors_texture_and_frame() -> void:
	var view: StatusIconView = _view()
	var enemy: Enemy = _spawn_idle_enemy()
	enemy.debuffs.apply(WEAKEN, 0.1)
	view.show_debuff(_first_debuff(enemy))
	assert_str(view.get_glyph_texture().resource_path).is_equal(ICON_DIR + "cracked_shield.svg")
	assert_that(view.get_glyph_color()).is_equal(WEAKEN.icon_color.lightened(CONFIG.glyph_lighten))
	assert_that(view.get_background_color()).is_equal(WEAKEN.icon_color.darkened(CONFIG.background_darken))
	assert_that(view.get_border_color()).is_equal(CONFIG.debuff_border_color)
	for data: DebuffData in [RAGE, SHIELD] as Array[DebuffData]:
		enemy.debuffs.clear()
		enemy.debuffs.apply(data, 1.0)
		view.show_debuff(_first_debuff(enemy))
		assert_that(view.get_border_color()).is_equal(CONFIG.buff_border_color)
	var player_buffs := BuffComponent.new()
	add_child(auto_free(player_buffs))
	player_buffs.add_stack(CONCUSSION)
	view.show_buff(player_buffs.get_active()[0])
	assert_that(view.get_border_color()).is_equal(CONFIG.buff_border_color)


func test_ac903_stacks() -> void:
	var view: StatusIconView = _view()
	var enemy: Enemy = _spawn_idle_enemy()
	var expected: Array[String] = ["1", "2", "3", "3"]
	for text: String in expected:
		enemy.debuffs.apply(WEAKEN, 0.1)
		view.show_debuff(_first_debuff(enemy))
		assert_str(view.get_stack_text()).is_equal(text)
	enemy.debuffs.clear()
	enemy.debuffs.apply(BLEED, 0.01)
	view.show_debuff(_first_debuff(enemy))
	assert_str(view.get_stack_text()).is_empty()
	var player_buffs := BuffComponent.new()
	add_child(auto_free(player_buffs))
	player_buffs.add_stack(CONCUSSION)
	player_buffs.add_stack(CONCUSSION)
	view.show_buff(player_buffs.get_active()[0])
	assert_str(view.get_stack_text()).is_equal("2")


func test_ac904_the_clock_starts_covered_and_clears() -> void:
	var view: StatusIconView = _view()
	var enemy: Enemy = _spawn_idle_enemy()
	enemy.debuffs.apply(WEAKEN, 0.1)
	view.show_debuff(_first_debuff(enemy))
	assert_float(view.get_clock_fraction()).is_equal_approx(1.0, TOLERANCE)
	enemy.debuffs.advance(1.5)
	view.update_debuff_time(_first_debuff(enemy))
	assert_float(view.get_clock_fraction()).is_equal_approx(0.625, TOLERANCE)
	enemy.debuffs.advance(2.4)
	view.update_debuff_time(_first_debuff(enemy))
	assert_float(view.get_clock_fraction()).is_equal_approx(0.025, TOLERANCE)
	enemy.debuffs.apply(WEAKEN, 0.1)
	view.update_debuff_time(_first_debuff(enemy))
	assert_float(view.get_clock_fraction()).is_equal_approx(1.0, TOLERANCE)
	enemy.debuffs.clear()
	enemy.debuffs.apply(BLEED, 0.01)
	view.show_debuff(_first_debuff(enemy))
	assert_float(view.get_clock_fraction()).is_equal_approx(1.0, TOLERANCE)
	enemy.debuffs.clear()
	enemy.debuffs.apply(RAGE, 1.0)
	view.show_debuff(_first_debuff(enemy))
	assert_bool(view.get_clock().visible).is_false()
	enemy.debuffs.advance(10.0)
	view.update_debuff_time(_first_debuff(enemy))
	assert_bool(view.get_clock().visible).is_false()


func test_ac905_every_status_has_an_icon_and_a_color() -> void:
	var paths: Array[String] = []
	for file: String in DirAccess.get_files_at(DEBUFF_DIR):
		if file.ends_with(".tres"):
			paths.append(DEBUFF_DIR + file)
	for file: String in DirAccess.get_files_at(BUFF_DIR):
		if file.ends_with(".tres"):
			paths.append(BUFF_DIR + file)
	assert_int(paths.size()).is_greater_equal(5)
	for path: String in paths:
		var data: Resource = load(path)
		var icon: Texture2D = data.get(&"icon") as Texture2D
		var color: Color = data.get(&"icon_color") as Color
		assert_object(icon).override_failure_message(path + " has no icon").is_not_null()
		assert_str(icon.resource_path).override_failure_message(path).starts_with(ICON_DIR)
		assert_float(color.a).override_failure_message(path).is_equal(1.0)
	for file: String in DirAccess.get_files_at(ICON_DIR):
		if file.ends_with(".svg"):
			var text: String = FileAccess.get_file_as_string(ICON_DIR + file)
			assert_bool(text.contains(BACKGROUND_PATH)).override_failure_message(file).is_false()


func test_ac908_source_md_credits_every_svg() -> void:
	var source: String = FileAccess.get_file_as_string(ICON_DIR + "SOURCE.md")
	assert_str(source).contains("CC BY 3.0")
	var svgs: int = 0
	for file: String in DirAccess.get_files_at(ICON_DIR):
		if not file.ends_with(".svg"):
			continue
		svgs += 1
		var line: String = _line_with(source, "`" + file + "`")
		assert_str(line).override_failure_message(file + " is not listed").is_not_empty()
		assert_str(line).contains("https://game-icons.net/")
	# 5 from status-icons.md + 3 from affliction.md (poison, frost, corrosion).
	assert_int(svgs).is_equal(8)


func test_ac913_revision_bumps_with_every_change() -> void:
	var enemy: Enemy = _spawn_idle_enemy()
	var start: int = enemy.debuffs.revision
	enemy.debuffs.apply(WEAKEN, 0.1)
	assert_int(enemy.debuffs.revision).is_equal(start + 1)
	enemy.debuffs.apply(WEAKEN, 0.1)
	assert_int(enemy.debuffs.revision).is_equal(start + 2)
	enemy.debuffs.apply(BLEED, 0.01)
	enemy.debuffs.remove(BLEED.id)
	assert_int(enemy.debuffs.revision).is_equal(start + 4)
	enemy.debuffs.advance(10.0)
	assert_int(enemy.debuffs.revision).is_equal(start + 5)
	enemy.debuffs.apply(RAGE, 1.0)
	enemy.debuffs.clear()
	assert_int(enemy.debuffs.revision).is_equal(start + 7)
	enemy.debuffs.clear()
	assert_int(enemy.debuffs.revision).is_equal(start + 7)


func test_ac915_colors_do_not_change() -> void:
	assert_that(BLEED.icon_color).is_equal(Color(0.55, 0.05, 0.05))
	assert_that(WEAKEN.icon_color).is_equal(Color(0.55, 0.35, 0.8))
	assert_that(RAGE.icon_color).is_equal(Color(0.9, 0.1, 0.1))
	assert_that(SHIELD.icon_color).is_equal(Color(0.95, 0.78, 0.25))
	assert_that(CONCUSSION.icon_color).is_equal(Color(0.55, 0.85, 0.25))
	assert_bool(RAGE.is_beneficial).is_true()
	assert_bool(SHIELD.is_beneficial).is_true()
	assert_bool(BLEED.is_beneficial).is_false()
	assert_bool(WEAKEN.is_beneficial).is_false()


func test_ac918_row_overflow_takes_the_last_slot() -> void:
	var row: StatusIconRow = auto_free(StatusIconRow.create(CONFIG, 5, 20.0, 3))
	add_child(row)
	assert_int(row.set_shown(5)).is_equal(5)
	assert_int(row.get_visible_icon_count()).is_equal(5)
	assert_bool(row.is_overflow_visible()).is_false()
	for total: int in [6, 7]:
		assert_int(row.set_shown(total)).is_equal(4)
		assert_int(row.get_visible_icon_count()).is_equal(4)
		assert_bool(row.is_overflow_visible()).is_true()
		assert_float(row.get_shown_width()).is_equal_approx(5 * 20.0 + 4 * 3.0, TOLERANCE)
	var plus: StatusIconView = row.get_overflow()
	assert_bool(plus.is_overflow()).is_true()
	assert_that(plus.get_border_color()).is_equal(CONFIG.overflow_border_color)
	assert_str(plus.get_stack_text()).is_equal(CONFIG.overflow_text)
	assert_bool(plus.get_glyph_texture() == null).is_true()
	assert_bool(plus.get_clock().visible).is_false()
	assert_int(row.get_child(row.get_child_count() - 1).get_index()).is_equal(plus.get_index())
	assert_int(row.set_shown(5)).is_equal(5)
	assert_bool(row.is_overflow_visible()).is_false()
	assert_int(row.get_child_count()).is_equal(6)


func test_ac919_the_frame_is_thinner_on_small_icons() -> void:
	assert_float(CONFIG.border_width(14.0)).is_equal(1.0)
	assert_float(CONFIG.border_width(28.0)).is_equal_approx(1.12, TOLERANCE)
	assert_float(CONFIG.border_width(36.0)).is_equal_approx(1.44, TOLERANCE)
	assert_float(CONFIG.border_width(64.0)).is_equal(1.5)
	var small: StatusIconView = _view(14.0)
	var big: StatusIconView = _view(36.0)
	assert_float(small.get_border_width()).is_less(big.get_border_width())
	small.set_side(36.0)
	assert_float(small.get_border_width()).is_equal(big.get_border_width())


func test_ac914_the_3d_icons_are_gone() -> void:
	var enemy: Enemy = _spawn_idle_enemy()
	assert_bool(enemy.has_node("HealthBar/DebuffIcons")).is_false()
	var removed: Array[String] = [
		"res://components/debuff_icon_row.gd",
		"res://resources/debuff_icon_config.gd",
		"res://data/ui/debuff_icon_config.tres",
		"res://materials/debuff_bleed_material.tres",
		"res://materials/debuff_weaken_material.tres",
		"res://materials/debuff_rage_material.tres",
		"res://materials/debuff_shield_material.tres",
	]
	for path: String in removed:
		assert_bool(FileAccess.file_exists(path)).override_failure_message(path).is_false()
	var has_material_field: bool = false
	for property: Dictionary in DebuffData.new().get_property_list():
		if property["name"] == "icon_material":
			has_material_field = true
	assert_bool(has_material_field).is_false()
	var needles: Array[String] = ["DebuffIconRow", "DebuffIconConfig", "debuff_icon_row", "debuff_icon_config", "icon_material", "debuff_bleed_material", "debuff_weaken_material", "debuff_rage_material", "debuff_shield_material"]
	for dir: String in ["res://components", "res://entities", "res://resources", "res://data", "res://ui", "res://systems", "res://levels", "res://materials", "res://effects"]:
		_assert_no_reference(dir, needles)


func _assert_no_reference(dir: String, needles: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if not (file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres")):
			continue
		var text: String = FileAccess.get_file_as_string(dir + "/" + file)
		for needle: String in needles:
			assert_bool(text.contains(needle)).override_failure_message(dir + "/" + file + " references " + needle).is_false()
	for sub: String in DirAccess.get_directories_at(dir):
		_assert_no_reference(dir + "/" + sub, needles)


func _line_with(text: String, needle: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(needle):
			return line
	return ""
