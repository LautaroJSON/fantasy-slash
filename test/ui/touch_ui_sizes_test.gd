extends GdUnitTestSuite
## docs/specs/mobile-touch-controls.md: every menu button is tall enough to tap.

const MIN_TOUCH_HEIGHT: float = 44.0
const SCENES: Array[String] = [
	"res://ui/main_menu.tscn", "res://ui/pause_menu.tscn", "res://ui/upgrade_panel.tscn", "res://ui/sandbox_enemy_panel.tscn",
	"res://ui/upgrade_picker.tscn", "res://ui/upgrade_ban_picker.tscn", "res://ui/ability_picker.tscn",
	"res://ui/game_over_screen.tscn",
]


## Templates (cards, sandbox +/- buttons) are Buttons in these scenes, so the
## instances built from them are covered too.
func test_ac1111_every_menu_button_is_at_least_44_px_tall() -> void:
	var checked: int = 0
	for path: String in SCENES:
		var state: SceneState = (load(path) as PackedScene).get_state()
		for node: int in state.get_node_count():
			if state.get_node_type(node) != &"Button":
				continue
			checked += 1
			var height: float = _min_height(state, node)
			assert_float(height).override_failure_message("%s/%s is %.0f px tall" % [path, state.get_node_name(node), height]) \
				.is_greater_equal(MIN_TOUCH_HEIGHT)
	assert_int(checked).is_greater(0)


func _min_height(state: SceneState, node: int) -> float:
	for property: int in state.get_node_property_count(node):
		if state.get_node_property_name(node, property) == &"custom_minimum_size":
			return (state.get_node_property_value(node, property) as Vector2).y
	return 0.0
