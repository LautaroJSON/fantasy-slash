extends GdUnitTestSuite
## Dash VFX modules (docs/specs/dash-feel.md): AC788-AC797 and AC800.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const VFX_SET: DashVfxSet = preload("res://data/player/dash/dash_vfx_set.tres")
const AFTERIMAGE_SCENE: PackedScene = preload("res://components/dash/vfx/dash_afterimage_vfx.tscn")
const SPEED_LINES_SCENE: PackedScene = preload("res://components/dash/vfx/dash_speed_lines_vfx.tscn")
const DUST_SCENE: PackedScene = preload("res://components/dash/vfx/dash_dust_vfx.tscn")
const FOV_SCENE: PackedScene = preload("res://components/dash/vfx/dash_fov_kick_vfx.tscn")
const AFTERIMAGE: DashAfterimageConfig = preload("res://data/player/dash/dash_afterimage_config.tres")
const SPEED_LINES: DashSpeedLinesConfig = preload("res://data/player/dash/dash_speed_lines_config.tres")
const FOV: DashFovKickConfig = preload("res://data/player/dash/dash_fov_kick_config.tres")
const AFTERIMAGE_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/dash_afterimage_material.tres")
const ADDITIVE_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/wind_cut_additive_material.tres")
const DUST_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/wind_dust_material.tres")
const BODY_MESHES: int = 6

var _player: Player
var _host: DashVfxHost


func before_test() -> void:
	Input.action_release(&"dash")
	Input.action_release(&"ability_basic")
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(200.0))
	add_child(floor_body)
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	Session.character_class = SAMURAI
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = registry
	add_child(_player)
	_host = _player.get_node("DashVfx") as DashVfxHost
	await _physics_frames(10)


func after_test() -> void:
	Input.action_release(&"dash")
	Input.action_release(&"ability_basic")
	Session.character_class = null


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await _physics_frames(ceili(seconds * Engine.physics_ticks_per_second))


func _module(script: Script) -> DashVfxModule:
	for module: DashVfxModule in _host.get_modules():
		if module.get_script() == script:
			return module
	return null


func _afterimage() -> DashAfterimageVfx:
	return _module(preload("res://components/dash/vfx/dash_afterimage_vfx.gd")) as DashAfterimageVfx


func _speed_lines() -> DashSpeedLinesVfx:
	return _module(preload("res://components/dash/vfx/dash_speed_lines_vfx.gd")) as DashSpeedLinesVfx


func _dust() -> DashDustVfx:
	return _module(preload("res://components/dash/vfx/dash_dust_vfx.gd")) as DashDustVfx


func _dash_and_wait() -> void:
	assert_bool(_player.dash.try_dash(Vector3.FORWARD)).is_true()
	while _player.dash.is_dashing():
		await get_tree().physics_frame


func _wait_ready() -> void:
	while _player.dash.get_cooldown_remaining() > 0.0:
		await get_tree().physics_frame


func _count_nodes(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count_nodes(child)
	return total


func test_ac788_the_set_lists_the_four_modules_and_each_is_optional() -> void:
	assert_array(VFX_SET.modules).is_equal([AFTERIMAGE_SCENE, SPEED_LINES_SCENE, DUST_SCENE, FOV_SCENE])
	assert_int(_host.get_modules().size()).is_equal(4)
	var without_lines := DashVfxSet.new()
	without_lines.modules.assign([AFTERIMAGE_SCENE, DUST_SCENE, FOV_SCENE])
	_host.setup(without_lines)
	await get_tree().process_frame
	assert_int(_host.get_modules().size()).is_equal(3)
	assert_object(_speed_lines()).is_null()
	await _dash_and_wait()
	assert_bool(_afterimage().is_copy_visible(0)).is_true()


func test_ac789_afterimages_are_left_along_the_dash_and_fade() -> void:
	var afterimage: DashAfterimageVfx = _afterimage()
	_player.dash.try_dash(Vector3.FORWARD)
	await get_tree().physics_frame
	var shown_during: int = 0
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	for i: int in AFTERIMAGE.count:
		if afterimage.is_copy_visible(i):
			shown_during += 1
	assert_int(shown_during).is_equal(AFTERIMAGE.count)
	assert_int(afterimage.get_copy_meshes(0).size()).is_equal(BODY_MESHES)
	assert_float(afterimage.get_copy_alpha(AFTERIMAGE.count - 1)).is_less_equal(AFTERIMAGE.start_alpha + 0.001)
	assert_float(afterimage.get_copy_alpha(AFTERIMAGE.count - 1)).is_greater(0.0)
	var first: MeshInstance3D = afterimage.get_copy_meshes(0)[0]
	var last: MeshInstance3D = afterimage.get_copy_meshes(AFTERIMAGE.count - 1)[0]
	assert_float(first.global_position.distance_to(last.global_position)).is_greater(0.5)
	await _seconds(AFTERIMAGE.lifetime + 0.05)
	for i: int in AFTERIMAGE.count:
		assert_bool(afterimage.is_copy_visible(i)).is_false()


func test_ac790_the_afterimage_pool_exists_from_the_start() -> void:
	var afterimage: DashAfterimageVfx = _afterimage()
	var nodes: int = _count_nodes(afterimage)
	assert_int(nodes).is_equal(1 + AFTERIMAGE.count * BODY_MESHES)
	for i: int in 5:
		await _dash_and_wait()
		await _wait_ready()
	assert_int(_count_nodes(afterimage)).is_equal(nodes)


func test_ac791_speed_lines_follow_the_dash_and_fade() -> void:
	var lines: DashSpeedLinesVfx = _speed_lines()
	_player.dash.try_dash(Vector3.RIGHT)
	await _physics_frames(2)
	assert_int(lines.get_lines().size()).is_equal(SPEED_LINES.count)
	for line: MeshInstance3D in lines.get_lines():
		assert_bool(line.visible).is_true()
		var axis: Vector3 = line.global_basis.z.normalized()
		assert_float(absf(axis.dot(_player.dash.get_direction()))).is_greater(cos(deg_to_rad(5.0)))
		var behind: Vector3 = line.global_position - _player.global_position
		assert_float(behind.dot(_player.dash.get_direction())).is_less(0.0)
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await _seconds(SPEED_LINES.fade + 0.05)
	for line: MeshInstance3D in lines.get_lines():
		assert_bool(line.visible).is_false()


func test_ac792_dust_bursts_on_the_floor_only() -> void:
	var dust: DashDustVfx = _dust()
	_player.dash.try_dash(Vector3.FORWARD)
	assert_bool(dust.get_take_off().emitting).is_true()
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	assert_bool(dust.get_landing().emitting).is_true()
	await _seconds(0.6)
	await _wait_ready()
	_player.velocity.y = 6.0
	await _physics_frames(6)
	assert_bool(_player.is_on_floor()).is_false()
	await _seconds(0.5)
	assert_bool(dust.get_take_off().emitting).is_false()
	_player.dash.try_dash(Vector3.FORWARD)
	assert_bool(dust.get_take_off().emitting).is_false()


func test_ac793_the_fov_kicks_and_returns_without_adding_up() -> void:
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	var base: float = camera.get_base_fov()
	_player.dash.try_dash(Vector3.FORWARD)
	assert_float(camera.get_fov()).is_equal_approx(base + FOV.fov_add, 0.01)
	await _seconds(FOV.return_time + 0.05)
	assert_float(camera.get_fov()).is_equal_approx(base, 0.1)
	camera.kick_fov(FOV.fov_add, FOV.return_time)
	camera.kick_fov(FOV.fov_add, FOV.return_time)
	assert_float(camera.get_fov()).is_equal_approx(base + FOV.fov_add, 0.01)


func test_ac794_materials() -> void:
	assert_float(AFTERIMAGE.start_alpha).is_less_equal(0.35)
	assert_int(AFTERIMAGE_MATERIAL.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_int(AFTERIMAGE_MATERIAL.transparency).is_not_equal(BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_that(Color(AFTERIMAGE_MATERIAL.albedo_color, 1.0)).is_equal(Color(1, 1, 1))
	assert_float(SPEED_LINES.alpha).is_less_equal(0.5)
	var afterimage: DashAfterimageVfx = _afterimage()
	assert_object((afterimage.get_copy_meshes(0)[0] as MeshInstance3D).material_override).is_same(AFTERIMAGE_MATERIAL)
	assert_object(_speed_lines().get_lines()[0].material_override).is_same(ADDITIVE_MATERIAL)
	assert_object((_dust().get_take_off().mesh as SphereMesh).material).is_same(DUST_MATERIAL)


func test_ac795_modules_read_their_config() -> void:
	var two := AFTERIMAGE.duplicate() as DashAfterimageConfig
	two.count = 2
	two.fractions = PackedFloat32Array([0.2, 0.8])
	var module: DashAfterimageVfx = auto_free(AFTERIMAGE_SCENE.instantiate() as DashAfterimageVfx)
	module.config = two
	add_child(module)
	module.setup(_player)
	assert_int(module.get_copy_count()).is_equal(2)
	assert_int(module.get_child_count()).is_equal(2 * BODY_MESHES)


func test_ac796_a_dash_cut_by_an_ability_ends_the_vfx() -> void:
	_player.basic_ability.equip(SHEATHE)
	_player.dash.try_dash(Vector3.FORWARD)
	await _physics_frames(2)
	_player.dash.cancel()
	assert_bool(_dust().get_landing().emitting).is_true()
	await _seconds(SPEED_LINES.fade + 0.05)
	for line: MeshInstance3D in _speed_lines().get_lines():
		assert_bool(line.visible).is_false()


func test_ac800_dashes_create_no_nodes() -> void:
	await _dash_and_wait()
	await _wait_ready()
	var nodes: int = _count_nodes(_player)
	for i: int in 10:
		await _dash_and_wait()
		await _wait_ready()
	assert_int(_count_nodes(_player)).is_equal(nodes)
