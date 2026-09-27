extends GdUnitTestSuite
## docs/specs/status-icons.md: status rows of the common enemies drawn in
## screen space (EnemyStatusOverlay), the "+" overflow slot in every container
## and the arena wiring.

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const BOSS_BAR_SCENE: PackedScene = preload("res://ui/boss_health_bar.tscn")
const CONFIG: EnemyStatusOverlayConfig = preload("res://data/ui/enemy_status_overlay_config.tres")
const BOSS_BAR_CONFIG: BossBarConfig = preload("res://data/ui/boss_bar_config.tres")
const BUFF_BAR_CONFIG: BuffBarConfig = preload("res://data/ui/buff_bar_config.tres")
const GROUP_AI: GroupAIConfig = preload("res://data/enemies/group_ai_config.tres")
const RAGE_CONFIG: RageConfig = preload("res://data/enemies/rage/rage_config.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const WEAKEN: DebuffData = preload("res://data/debuffs/weaken.tres")
const RAGE: DebuffData = preload("res://data/debuffs/rage.tres")
const CONCUSSION: BuffData = preload("res://data/buffs/concussion.tres")
const CAMERA_POSITION: Vector3 = Vector3(0.0, 2.2, 6.0)
const PIXEL_TOLERANCE: float = 1.0
## Camera distance at which the 1 m bar spans about 150 px (1152 × 648 test window).
const CLOSE_DISTANCE: float = 5.0

var _camera: Camera3D
var _registry: EnemyRegistry
var _overlay: EnemyStatusOverlay


func before_test() -> void:
	_camera = auto_free(Camera3D.new())
	add_child(_camera)
	_camera.global_position = CAMERA_POSITION
	_camera.current = true
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_overlay = auto_free(EnemyStatusOverlay.new())
	_overlay.config = CONFIG
	add_child(_overlay)
	_overlay.registry = _registry


func _spawn(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


## Test statuses with their own ids, so each one is a separate icon.
func _test_debuffs(count: int) -> Array[DebuffData]:
	var list: Array[DebuffData] = []
	for i: int in count:
		var data: DebuffData = WEAKEN.duplicate() as DebuffData
		data.id = StringName("test_debuff_%d" % i)
		list.append(data)
	return list


func _expected_bar_width(enemy: Enemy) -> float:
	var center: Vector3 = enemy.health_bar.global_position
	var half: Vector3 = _camera.global_basis.x * (CONFIG.health_bar.size.x / 2.0)
	return _camera.unproject_position(center + half).distance_to(_camera.unproject_position(center - half))


func test_ac909_a_never_hit_enemy_shows_its_row_over_the_bar() -> void:
	var enemy: Enemy = _spawn(Vector3.ZERO)
	enemy.debuffs.apply(WEAKEN, 0.1)
	_overlay.update_rows()
	assert_bool(enemy.health_bar.visible).is_false()
	assert_int(_overlay.get_visible_row_count()).is_equal(1)
	assert_object(_overlay.get_row_enemy(0)).is_same(enemy)
	var row: StatusIconRow = _overlay.get_row(0)
	assert_bool(row.visible).is_true()
	assert_int(row.get_visible_icon_count()).is_equal(1)
	var expected: Vector2 = _camera.unproject_position(enemy.health_bar.global_position) + CONFIG.row_offset_px
	var center: Vector2 = _overlay.get_row_center(0)
	assert_float(center.distance_to(expected)).is_less_equal(PIXEL_TOLERANCE)


func test_ac910_no_row_without_statuses_for_bosses_behind_or_spawning() -> void:
	var plain: Enemy = _spawn(Vector3(-2.0, 0.0, 0.0))
	var boss: Enemy = _spawn(Vector3(2.0, 0.0, 0.0))
	boss.health_bar.set_suppressed(true)
	boss.debuffs.apply(WEAKEN, 0.1)
	var behind: Enemy = _spawn(Vector3(0.0, 0.0, 12.0))
	behind.debuffs.apply(WEAKEN, 0.1)
	var rising: Enemy = _spawn(Vector3(0.0, 0.0, -3.0))
	rising.begin_spawn_in(GROUP_AI)
	rising.debuffs.apply(WEAKEN, 0.1)
	_overlay.update_rows()
	assert_bool(plain.debuffs.get_active().is_empty()).is_true()
	assert_bool(rising.is_spawning_in()).is_true()
	assert_int(_overlay.get_visible_row_count()).is_equal(0)
	var shown: Enemy = _spawn(Vector3(0.0, 0.0, -1.0))
	shown.debuffs.apply(BLEED, 0.01)
	_overlay.update_rows()
	assert_int(_overlay.get_visible_row_count()).is_equal(1)
	shown.deactivate()
	_overlay.update_rows()
	assert_int(_overlay.get_visible_row_count()).is_equal(0)
	assert_bool(_overlay.get_row(0).visible).is_false()


func test_ac911_rows_are_created_once_and_capped() -> void:
	var children: int = _overlay.get_child_count()
	assert_int(children).is_equal(CONFIG.max_rows)
	assert_int(_overlay.get_row(0).get_child_count()).is_equal(CONFIG.icons_per_bar + 1)
	var enemies: Array[Enemy] = []
	for i: int in CONFIG.max_rows + 2:
		var enemy: Enemy = _spawn(Vector3(float(i % 7) - 3.0, 0.0, -float(i / 7) * 2.0))
		enemy.debuffs.apply(WEAKEN, 0.1)
		enemies.append(enemy)
	_overlay.update_rows()
	assert_int(_overlay.get_visible_row_count()).is_equal(CONFIG.max_rows)
	for step: int in 100:
		var enemy: Enemy = enemies[step % enemies.size()]
		if step % 2 == 0:
			enemy.debuffs.clear()
		else:
			enemy.debuffs.apply(BLEED, 0.01)
		_overlay.update_rows()
	assert_int(_overlay.get_child_count()).is_equal(children)
	assert_int(_overlay.get_row(0).get_child_count()).is_equal(CONFIG.icons_per_bar + 1)


func test_ac912_icons_are_rewritten_only_when_the_statuses_change() -> void:
	var enemy: Enemy = _spawn(Vector3.ZERO)
	enemy.debuffs.apply(WEAKEN, 0.1)
	_overlay.update_rows()
	var writes: int = _overlay.get_content_write_count()
	for i: int in 10:
		_overlay.update_rows()
	assert_int(_overlay.get_content_write_count()).is_equal(writes)
	enemy.debuffs.apply(WEAKEN, 0.1)
	_overlay.update_rows()
	assert_int(_overlay.get_content_write_count()).is_equal(writes + 1)
	assert_str(_overlay.get_row(0).icon(0).get_stack_text()).is_equal("2")
	enemy.debuffs.advance(1.0)
	_overlay.update_rows()
	assert_int(_overlay.get_content_write_count()).is_equal(writes + 1)
	assert_float(_overlay.get_row(0).icon(0).get_clock_fraction()).is_equal_approx(0.75, 0.0001)


func test_ac917_icons_span_the_bar_width() -> void:
	assert_float(CONFIG.icon_side(150.0)).is_equal_approx(27.6, 0.0001)
	assert_float(CONFIG.icon_side(40.0)).is_equal(CONFIG.min_icon_size_px)
	assert_float(CONFIG.icon_side(400.0)).is_equal(CONFIG.max_icon_size_px)
	assert_float(CONFIG.min_icon_size_px).is_equal(14.0)
	assert_float(CONFIG.max_icon_size_px).is_equal(32.0)
	var enemy: Enemy = _spawn(Vector3.ZERO)
	enemy.debuffs.apply(WEAKEN, 0.1)
	_overlay.update_rows()
	var bar_width: float = _expected_bar_width(enemy)
	assert_float(_overlay.get_row(0).get_side()).is_equal_approx(CONFIG.icon_side(bar_width), PIXEL_TOLERANCE)
	# Closer, so the bar spans between the min and max sizes: five slots and
	# their gaps measure the bar.
	_camera.global_position = Vector3(0.0, enemy.health_bar.global_position.y, CLOSE_DISTANCE)
	_overlay.update_rows()
	bar_width = _expected_bar_width(enemy)
	var side: float = _overlay.get_row(0).get_side()
	assert_float(side).is_greater(CONFIG.min_icon_size_px)
	assert_float(side).is_less(CONFIG.max_icon_size_px)
	var five: float = 5.0 * side + 4.0 * CONFIG.spacing_px
	assert_float(five).is_equal_approx(bar_width, 2.0 * PIXEL_TOLERANCE)
	enemy.global_position.z -= 0.01
	_overlay.update_rows()
	assert_float(_overlay.get_row(0).get_side()).is_equal(side)


func test_ac918_overflow_in_the_enemy_row() -> void:
	var enemy: Enemy = _spawn(Vector3.ZERO)
	var extra: Array[DebuffData] = _test_debuffs(7)
	for i: int in 5:
		enemy.debuffs.apply(extra[i], 0.01)
	_overlay.update_rows()
	var row: StatusIconRow = _overlay.get_row(0)
	assert_int(row.get_visible_icon_count()).is_equal(5)
	assert_bool(row.is_overflow_visible()).is_false()
	enemy.debuffs.apply(extra[5], 0.01)
	enemy.debuffs.apply(extra[6], 0.01)
	_overlay.update_rows()
	assert_int(row.get_visible_icon_count()).is_equal(4)
	assert_bool(row.is_overflow_visible()).is_true()
	for i: int in 4:
		assert_object(row.icon(i).get_glyph_texture()).is_same(extra[i].icon)
	assert_that(row.get_overflow().get_border_color()).is_equal(Color(0, 0, 0))
	enemy.debuffs.remove(extra[5].id)
	enemy.debuffs.remove(extra[6].id)
	_overlay.update_rows()
	assert_int(row.get_visible_icon_count()).is_equal(5)
	assert_bool(row.is_overflow_visible()).is_false()


func test_ac918_overflow_in_the_buff_bar_and_the_boss_bar() -> void:
	var buffs := BuffComponent.new()
	add_child(auto_free(buffs))
	var bar: BuffBar = auto_free(BuffBar.new())
	bar.config = BUFF_BAR_CONFIG
	add_child(bar)
	bar.setup(buffs)
	for i: int in 7:
		var data: BuffData = CONCUSSION.duplicate() as BuffData
		data.id = StringName("test_buff_%d" % i)
		buffs.add_stack(data)
	assert_int(bar.get_visible_icon_count()).is_equal(5)
	assert_bool(bar.get_row().is_overflow_visible()).is_true()
	var boss: Enemy = _spawn(Vector3.ZERO)
	var boss_bar: BossHealthBar = auto_free(BOSS_BAR_SCENE.instantiate())
	add_child(boss_bar)
	boss_bar.setup(BOSS_BAR_CONFIG)
	boss_bar.track(boss)
	for data: DebuffData in _test_debuffs(9):
		boss.debuffs.apply(data, 0.01)
	assert_int(boss_bar.get_visible_debuff_count()).is_equal(7)
	assert_bool(boss_bar.get_debuff_row().is_overflow_visible()).is_true()


func test_ac916_the_arena_overlay_shows_rage_before_any_hit() -> void:
	var arena: Node3D = auto_free(ARENA_SCENE.instantiate())
	add_child(arena)
	get_tree().paused = true
	await get_tree().process_frame
	var hud: Hud = arena.get_node("UI/Hud") as Hud
	var registry: EnemyRegistry = arena.get_node("EnemyRegistry") as EnemyRegistry
	assert_object(hud.enemy_registry).is_same(registry)
	var overlay: EnemyStatusOverlay = hud.get_node("%EnemyStatusOverlay") as EnemyStatusOverlay
	assert_object(overlay.registry).is_same(registry)
	var player: Player = arena.get_node("Player") as Player
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = registry
	arena.add_child(enemy)
	var ahead: Vector3 = player.global_position - player.global_basis.z * 4.0
	enemy.activate(ahead, player)
	enemy.enrage(RAGE_CONFIG, 1)
	overlay.update_rows()
	get_tree().paused = false
	assert_bool(enemy.health_bar.visible).is_false()
	var found: bool = false
	for i: int in overlay.get_visible_row_count():
		if overlay.get_row_enemy(i) == enemy:
			found = true
			assert_object(overlay.get_row(i).icon(0).get_glyph_texture()).is_same(RAGE.icon)
	assert_bool(found).is_true()
