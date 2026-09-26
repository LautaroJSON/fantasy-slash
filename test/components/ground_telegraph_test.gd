extends GdUnitTestSuite
## GroundTelegraph (docs/specs/enemy-ground-telegraph.md).

const CONFIG: TelegraphConfig = preload("res://data/enemies/telegraph_config.tres")
const MATERIAL: StandardMaterial3D = preload("res://materials/vfx/telegraph_material.tres")
const DUST: StandardMaterial3D = preload("res://materials/vfx/wind_dust_material.tres")
const EPS := Vector3(0.001, 0.001, 0.001)

var _telegraph: GroundTelegraph


func before_test() -> void:
	_telegraph = auto_free(GroundTelegraph.new())
	_telegraph.config = CONFIG
	_telegraph.material = MATERIAL
	_telegraph.dust_material = DUST
	_telegraph.set_physics_process(false)
	add_child(_telegraph)
	_telegraph.prepare_arcs([90.0] as Array[float])


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


func test_ac500_sector_size_facing_and_fill() -> void:
	_telegraph.show_sector(Vector3(1.0, 0.0, 2.0), Vector3.RIGHT, 3.0, 90.0, 1.0)
	var base: MeshInstance3D = _telegraph.get_base()
	assert_bool(base.visible).is_true()
	assert_float(base.global_basis.x.length()).is_equal_approx(3.0, 0.001)
	assert_vector((-base.global_basis.z).normalized()).is_equal_approx(Vector3.RIGHT, EPS)
	assert_vector(_flat(base.global_position)).is_equal_approx(Vector3(1.0, 0.0, 2.0), EPS)
	assert_float(_telegraph.get_fill_ratio()).is_equal_approx(0.0, 0.0001)
	_telegraph.advance(0.5)
	assert_float(_telegraph.get_fill_ratio()).is_equal_approx(0.5, 0.0001)
	assert_float(_telegraph.get_fill().global_basis.x.length()).is_equal_approx(1.5, 0.001)
	_telegraph.advance(0.5)
	assert_float(_telegraph.get_fill().global_basis.x.length()).is_equal_approx(3.0, 0.001)


func test_ac501_line_from_the_origin_along_the_direction() -> void:
	_telegraph.show_line(Vector3.ZERO, Vector3.FORWARD, 6.0, 2.0, 1.0)
	var base: MeshInstance3D = _telegraph.get_base()
	assert_float(base.global_basis.x.length()).is_equal_approx(2.0, 0.001)
	assert_float(base.global_basis.z.length()).is_equal_approx(6.0, 0.001)
	assert_vector(_flat(base.global_position)).is_equal_approx(Vector3(0.0, 0.0, -3.0), EPS)
	_telegraph.advance(0.25)
	var fill: MeshInstance3D = _telegraph.get_fill()
	assert_float(fill.global_basis.z.length()).is_equal_approx(1.5, 0.001)
	assert_vector(_flat(fill.global_position)).is_equal_approx(Vector3(0.0, 0.0, -0.75), EPS)


func test_ac502_circle_grows_from_the_centre_and_follows() -> void:
	_telegraph.show_circle(Vector3(2.0, 0.0, 0.0), 2.0, 1.0)
	assert_float(_telegraph.get_base().global_basis.x.length()).is_equal_approx(2.0, 0.001)
	_telegraph.advance(0.5)
	assert_float(_telegraph.get_fill().global_basis.x.length()).is_equal_approx(1.0, 0.001)
	_telegraph.move_center(Vector3(-1.0, 0.0, 4.0))
	assert_vector(_flat(_telegraph.get_base().global_position)).is_equal_approx(Vector3(-1.0, 0.0, 4.0), EPS)
	assert_vector(_flat(_telegraph.get_fill().global_position)).is_equal_approx(Vector3(-1.0, 0.0, 4.0), EPS)


func test_ac503_flash_fills_brightens_fades_and_hides() -> void:
	_telegraph.show_circle(Vector3.ZERO, 2.0, 1.0)
	_telegraph.advance(0.2)
	_telegraph.flash(true)
	assert_float(_telegraph.get_fill_ratio()).is_equal_approx(1.0, 0.0001)
	assert_float(_telegraph.get_fill().transparency).is_equal_approx(CONFIG.flash_transparency, 0.0001)
	assert_bool(_telegraph.get_dust().emitting).is_true()
	_telegraph.advance(CONFIG.flash_time + CONFIG.fade_time * 0.5)
	assert_float(_telegraph.get_fill().transparency).is_greater(CONFIG.flash_transparency)
	assert_bool(_telegraph.is_showing()).is_true()
	_telegraph.advance(CONFIG.fade_time)
	assert_bool(_telegraph.is_showing()).is_false()
	assert_bool(_telegraph.get_base().visible).is_false()


func test_ac503_flash_without_dust() -> void:
	_telegraph.show_sector(Vector3.ZERO, Vector3.FORWARD, 2.0, 90.0, 1.0)
	_telegraph.flash(false)
	assert_bool(_telegraph.get_dust().emitting).is_false()


func test_ac504_clear_and_cached_sectors() -> void:
	_telegraph.show_sector(Vector3.ZERO, Vector3.FORWARD, 2.0, 90.0, 1.0)
	_telegraph.clear()
	assert_bool(_telegraph.is_showing()).is_false()
	assert_bool(_telegraph.get_fill().visible).is_false()
	_telegraph.prepare_arcs([90.0, 90.2, 120.0] as Array[float])
	assert_int(_telegraph.get_sector_count()).is_equal(2)
	_telegraph.show_sector(Vector3.ZERO, Vector3.FORWARD, 2.0, 120.0, 1.0)
	var mesh: Mesh = _telegraph.get_base().mesh
	_telegraph.show_sector(Vector3.ZERO, Vector3.BACK, 4.0, 120.0, 1.0)
	assert_object(_telegraph.get_base().mesh).is_same(mesh)
	assert_int(_telegraph.get_sector_count()).is_equal(2)


## Regression: the line kept its width and length only along ±Z (it was scaled
## in world axes); it must hold in any direction.
func test_ac501_line_keeps_its_size_in_any_direction() -> void:
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3(1.0, 0.0, 1.0).normalized(), Vector3(-1.0, 0.0, 1.0).normalized()]:
		_telegraph.show_line(Vector3(2.0, 0.0, -1.0), direction, 6.0, 2.0, 1.0)
		var base: MeshInstance3D = _telegraph.get_base()
		assert_float(base.global_basis.x.length()).is_equal_approx(2.0, 0.001)
		assert_float(base.global_basis.z.length()).is_equal_approx(6.0, 0.001)
		assert_float(base.global_basis.x.dot(base.global_basis.z)).is_equal_approx(0.0, 0.001)
		assert_vector((-base.global_basis.z).normalized()).is_equal_approx(direction, EPS)
		assert_vector(_flat(base.global_position)).is_equal_approx(Vector3(2.0, 0.0, -1.0) + direction * 3.0, EPS)
		_telegraph.advance(0.5)
		var fill: MeshInstance3D = _telegraph.get_fill()
		assert_float(fill.global_basis.z.length()).is_equal_approx(3.0, 0.001)
		assert_vector((-fill.global_basis.z).normalized()).is_equal_approx(direction, EPS)
