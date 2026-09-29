extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const DISPLAY_TABLE: StatDisplayTable = preload("res://data/ui/stat_display_table.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const LETHAL_HIT: float = 100000.0
const LEFT_COLUMN: Array[PlayerStats.Stat] = [
	PlayerStats.Stat.DAMAGE, PlayerStats.Stat.CRIT_CHANCE, PlayerStats.Stat.CRIT_DAMAGE,
	PlayerStats.Stat.LIFESTEAL, PlayerStats.Stat.DAMAGE_BONUS,
]
# Adapted (sprint-stamina.md): the max stamina joins the right column.
const RIGHT_COLUMN: Array[PlayerStats.Stat] = [PlayerStats.Stat.MAX_HEALTH, PlayerStats.Stat.DEFENSE, PlayerStats.Stat.STAMINA_MAX, PlayerStats.Stat.AFFLICTION_BUILDUP]
const BOTTOM_ROWS: Array[PlayerStats.Stat] = [
	PlayerStats.Stat.ATTACK_SPEED, PlayerStats.Stat.MOVE_SPEED, PlayerStats.Stat.ATTACK_RANGE,
]
const HIDDEN_STATS: Array[PlayerStats.Stat] = [
	PlayerStats.Stat.ATTACK_ARC, PlayerStats.Stat.DASH_COOLDOWN,
	PlayerStats.Stat.DASH_DISTANCE, PlayerStats.Stat.JUMP_VELOCITY, PlayerStats.Stat.DASH_SPEED,
	PlayerStats.Stat.STAMINA_REGEN, PlayerStats.Stat.SPRINT_STAMINA_COST, PlayerStats.Stat.SPRINT_SPEED_FACTOR,
]

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _picker: UpgradePicker
var _pause: PauseMenu


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	preload("res://test/helpers/test_world.gd").without_horde(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_pause = _arena.get_node("UI/PauseMenu") as PauseMenu
	await get_tree().process_frame
	# The run starts once the ability is chosen.
	var ability_picker: AbilityPicker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	ability_picker.choose(SHIELD_CHARGE)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		# boss-colmena: a shielded boss (the Colmena) must die too.
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


func test_ac26_pause_is_bound_to_escape() -> void:
	var escape_bound: bool = false
	for event: InputEvent in InputMap.action_get_events(&"pause"):
		var key: InputEventKey = event as InputEventKey
		if key != null and key.physical_keycode == KEY_ESCAPE:
			escape_bound = true
	assert_bool(escape_bound).is_true()


func test_ac233_display_table_lists_the_upgradeable_stats_once() -> void:
	assert_array(_stats_of(DISPLAY_TABLE.left_column)).is_equal(LEFT_COLUMN)
	assert_array(_stats_of(DISPLAY_TABLE.right_column)).is_equal(RIGHT_COLUMN)
	assert_array(_stats_of(DISPLAY_TABLE.bottom_rows)).is_equal(BOTTOM_ROWS)
	for hidden: PlayerStats.Stat in HIDDEN_STATS:
		assert_object(DISPLAY_TABLE.find(hidden)).is_null()


func test_ac26_percent_stats_are_shown_as_percentages() -> void:
	var crit_row: StatDisplay = DISPLAY_TABLE.find(PlayerStats.Stat.CRIT_CHANCE)
	assert_str(crit_row.format_value(0.05)).is_equal("5 %")


func test_ac234_crit_damage_is_shown_as_a_percentage() -> void:
	var crit_damage_row: StatDisplay = DISPLAY_TABLE.find(PlayerStats.Stat.CRIT_DAMAGE)
	assert_str(crit_damage_row.format_value(1.0)).is_equal("100 %")
	assert_str(crit_damage_row.format_value(3.0)).is_equal("300 %")


func test_ac26_pause_shows_stats_wave_and_kills() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	active[0].health.receive_hit(LETHAL_HIT)
	_player.stats.add_upgrade(DAMAGE_UPGRADE)
	_pause.toggle()
	assert_bool(_pause.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(_pause.get_stat_row_count()).is_equal(DISPLAY_TABLE.row_count())
	assert_str(_pause.get_value_text(PlayerStats.Stat.DAMAGE)).is_equal("19.0")
	assert_str(_pause.get_value_text(PlayerStats.Stat.CRIT_CHANCE)).is_equal("5 %")
	assert_str(_pause.get_value_text(PlayerStats.Stat.CRIT_DAMAGE)).is_equal("100 %")
	assert_str(_pause.get_run_text()).is_equal("Oleada 1 · 1 enemigos eliminados")


func test_ac26_resuming_leaves_the_game_exactly_as_it_was() -> void:
	await _physics_frames(30)
	_pause.toggle()
	var player_position: Vector3 = _player.global_position
	var player_health: float = _player.health.current_health
	var enemy: Enemy = _registry.get_active()[0]
	var enemy_position: Vector3 = enemy.global_position
	await _physics_frames(90)
	assert_vector(_player.global_position).is_equal(player_position)
	assert_vector(enemy.global_position).is_equal(enemy_position)
	assert_float(_player.health.current_health).is_equal(player_health)
	_pause.toggle()
	assert_bool(_pause.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_ac27_pause_is_ignored_while_choosing_an_upgrade() -> void:
	_kill_all_active()
	assert_bool(_picker.is_open()).is_true()
	_pause.toggle()
	assert_bool(_pause.is_open()).is_false()
	assert_bool(_picker.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()


func test_ac112_normal_mode_hides_the_sandbox_ui() -> void:
	_pause.open()
	assert_bool(_pause.get_sandbox_panel().visible).is_false()
	assert_bool(_player.health.death_protected).is_false()


func test_ac166_hud_has_no_mode_label() -> void:
	var hud: Hud = _arena.get_node("UI/Hud") as Hud
	assert_object(hud.get_node_or_null("%SandboxLabel")).is_null()


func test_ac167_pause_shows_the_normal_mode() -> void:
	_pause.open()
	assert_str(_pause.get_mode_text()).is_equal("Modo de juego: Normal")


func test_ac169_mode_label_sits_in_the_top_left_corner() -> void:
	var label: Label = _pause.get_node("%ModeLabel") as Label
	assert_object(label.get_parent()).is_same(_pause)
	assert_float(label.anchor_left).is_equal(0.0)
	assert_float(label.anchor_top).is_equal(0.0)
	_pause.open()
	assert_bool(label.is_visible_in_tree()).is_true()


func test_ac27_pause_is_ignored_on_game_over() -> void:
	_player.health.receive_hit(LETHAL_HIT)
	_pause.toggle()
	assert_bool(_pause.is_open()).is_false()
	assert_bool(get_tree().paused).is_true()


func _stats_of(rows: Array[StatDisplay]) -> Array[PlayerStats.Stat]:
	var stats: Array[PlayerStats.Stat] = []
	for row: StatDisplay in rows:
		stats.append(row.stat)
	return stats


func _labels_in(grid_name: String) -> Array[String]:
	var labels: Array[String] = []
	var grid: GridContainer = _pause.get_node("%" + grid_name) as GridContainer
	for i: int in range(0, grid.get_child_count(), 2):
		labels.append((grid.get_child(i) as Label).text)
	return labels


func test_ac233_pause_lays_out_two_columns_and_a_block_below() -> void:
	_pause.toggle()
	assert_array(_labels_in("LeftGrid")).is_equal(["Daño", "Probabilidad de crítico", "Daño crítico", "Robo de vida", "Bono de daño"])
	assert_array(_labels_in("RightGrid")).is_equal(["Vida máxima", "Defensa", "Estamina máxima", "Acum. Aflicción"])
	assert_array(_labels_in("BottomGrid")).is_equal(["Velocidad de ataque", "Velocidad de movimiento", "Rango"])
