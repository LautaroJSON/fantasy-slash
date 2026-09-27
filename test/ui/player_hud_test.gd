extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const STYLE: PlayerHealthBarStyle = preload("res://data/ui/player_health_bar_style.tres")

var _arena: Node3D
var _player: Player
var _health_bar: ProgressBar
var _health_label: Label


## The ability picker stays open (tree paused), so no enemy spawns or hits.
func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_player = _arena.get_node("Player") as Player
	var hud: Hud = _arena.get_node("UI/Hud") as Hud
	_health_bar = hud.get_node("%HealthBar") as ProgressBar
	_health_label = hud.get_node("%HealthLabel") as Label
	get_tree().paused = true
	await get_tree().process_frame


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _assert_rounded(box: StyleBoxFlat, color: Color) -> void:
	assert_that(box.bg_color).is_equal(color)
	assert_int(box.corner_radius_top_left).is_equal(STYLE.corner_radius)
	assert_int(box.corner_radius_top_right).is_equal(STYLE.corner_radius)
	assert_int(box.corner_radius_bottom_left).is_equal(STYLE.corner_radius)
	assert_int(box.corner_radius_bottom_right).is_equal(STYLE.corner_radius)


func test_ac171_health_bar_is_anchored_bottom_centre() -> void:
	assert_float(_health_bar.anchor_left).is_equal(0.5)
	assert_float(_health_bar.anchor_right).is_equal(0.5)
	assert_float(_health_bar.anchor_top).is_equal(1.0)
	assert_float(_health_bar.anchor_bottom).is_equal(1.0)
	assert_float(_health_bar.offset_left).is_equal(-_health_bar.offset_right)


func test_ac172_health_bar_is_green_and_rounded() -> void:
	_assert_rounded(_health_bar.get_theme_stylebox(&"fill") as StyleBoxFlat, STYLE.fill_color)
	_assert_rounded(_health_bar.get_theme_stylebox(&"background") as StyleBoxFlat, STYLE.background_color)


# AC173 (dash bar bottom left) was replaced by AC769 (docs/specs/dash-button.md):
# the dash is a button next to the abilities, see test/ui/dash_button_test.gd.


func test_ac174_health_bar_still_tracks_health() -> void:
	# 20 raw - 3 player defense = 17.
	_player.health.receive_hit(20.0)
	assert_float(_health_bar.value).is_equal_approx(83.0, 0.0001)
	assert_str(_health_label.text).is_equal("83 / 100")


func test_ac295_buff_bar_shows_concussion_stacks_while_active() -> void:
	var concussion: BuffData = load("res://data/buffs/concussion.tres") as BuffData
	var bar: BuffBar = _arena.get_node("UI/Hud").get_node("%BuffBar") as BuffBar
	var slots: int = bar.get_child_count()
	assert_int(bar.get_visible_icon_count()).is_equal(0)
	_player.buffs.add_stack(concussion)
	_player.buffs.add_stack(concussion)
	assert_int(bar.get_visible_icon_count()).is_equal(1)
	# status-icons.md: the flat color became a glyph tinted with the buff color.
	assert_object(bar.get_icon(0).get_glyph_texture()).is_same(concussion.icon)
	assert_that(bar.get_icon(0).get_background_color()).is_equal(concussion.icon_color.darkened(bar.config.status_icon.background_darken))
	assert_str(bar.get_stack_text(0)).is_equal("2")
	_player.buffs.advance(concussion.stack_duration)
	assert_str(bar.get_stack_text(0)).is_equal("1")
	_player.buffs.advance(concussion.stack_duration)
	assert_int(bar.get_visible_icon_count()).is_equal(0)
	assert_int(bar.get_child_count()).is_equal(slots)
