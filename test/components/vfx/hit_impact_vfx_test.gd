extends GdUnitTestSuite
## Impact VFX where the blade crosses an enemy (docs/specs/hit-impact-vfx.md,
## AC931–AC937, AC939–AC941). The ability sources are in hit_impact_abilities_test.gd.

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const CONFIG: HitImpactVfxConfig = preload("res://data/player/hit_impact_vfx_config.tres")
const GLOW: StandardMaterial3D = preload("res://materials/vfx/hit_impact_material.tres")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const SCRIPTS: Array[String] = ["res://components/vfx/hit_impact_vfx.gd", "res://components/vfx/hit_impact_vfx_host.gd"]
const NO_CRIT_ROLL: float = 0.99
const CRIT_ROLL: float = 0.0
const RADIUS: float = 0.4
const TOLERANCE: float = 0.01
const MAX_ANGLE_DEGREES: float = 5.0

var _registry: EnemyRegistry
var _player: Player
var _host: HitImpactVfxHost


func before_test() -> void:
	Input.action_release(&"dash")
	Session.character_class = WARRIOR
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	ComboDriver.drive_by_hand(_player)
	(_player.get_node("Hitstop") as HitstopComponent).set_physics_process(false)
	_host = _player.get_node("HitImpactVfx") as HitImpactVfxHost
	_host.set_physics_process(false)
	_stop_effect_processing()


func after_test() -> void:
	Session.character_class = null


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	enemy.set_physics_process(false)
	return enemy


## Effects are advanced by hand, never by real frames.
func _stop_effect_processing() -> void:
	for effect: HitImpactVfx in _host.get_pool():
		effect.set_process(false)


func _playing() -> Array[HitImpactVfx]:
	var playing: Array[HitImpactVfx] = []
	for effect: HitImpactVfx in _host.get_pool():
		if effect.is_playing():
			playing.append(effect)
	return playing


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_ac931_the_config_has_every_field_set_and_the_scripts_no_tuneable_literals() -> void:
	for property: Dictionary in CONFIG.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		assert_float(float(CONFIG.get(property.name))).override_failure_message(property.name).is_greater(0.0)
	var literal := RegEx.create_from_string("\\b\\d+\\.\\d+\\b")
	for path: String in SCRIPTS:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("const") or line.strip_edges().begins_with("#"):
				continue
			for found: RegExMatch in literal.search_all(line):
				assert_array(["0.0", "1.0", "0.5", "2.0"]).override_failure_message(path + ": " + line).contains([found.get_string()])


func test_ac932_a_combo_strike_shows_one_impact_per_enemy_hit() -> void:
	var left: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.2))
	var right: Enemy = _spawn_enemy(Vector3(0.15, 0.0, -2.1))
	var left_at: Vector3 = left.global_position
	var right_at: Vector3 = right.global_position
	var hits: Array[Enemy] = []
	_player.attack.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: hits.append(enemy))
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	assert_int(hits.size()).is_equal(2)
	assert_int(_host.get_active_count()).is_equal(2)
	var playing: Array[HitImpactVfx] = _playing()
	var near_left: int = 0
	for effect: HitImpactVfx in playing:
		var to_left: float = _flat_distance(effect.global_position, left_at)
		var to_right: float = _flat_distance(effect.global_position, right_at)
		var nearest: float = minf(to_left, to_right)
		assert_float(nearest).is_equal_approx(left.get_hit_padding(), TOLERANCE)
		if to_left < to_right:
			near_left += 1
	assert_int(near_left).is_equal(1)


func test_ac933_the_impact_lies_on_the_enemy_surface_on_the_blade_side() -> void:
	var enemy_pos := Vector3(1.0, 0.0, 2.0)
	var blade_a := Vector3(3.0, 1.0, 1.0)
	var blade_b := Vector3(3.0, 1.2, 3.0)
	var player_pos := Vector3(1.0, 0.0, 5.0)
	var point: Vector3 = HitImpactVfxHost.impact_point(enemy_pos, RADIUS, blade_a, blade_b, player_pos, CONFIG.min_height, CONFIG.max_height)
	assert_float(_flat_distance(point, enemy_pos)).is_equal_approx(RADIUS, TOLERANCE)
	var blade_point: Vector3 = HitImpactVfxHost.closest_blade_point(enemy_pos, blade_a, blade_b)
	var to_blade := Vector2(blade_point.x - enemy_pos.x, blade_point.z - enemy_pos.z)
	var to_point := Vector2(point.x - enemy_pos.x, point.z - enemy_pos.z)
	assert_float(to_point.dot(to_blade)).is_greater(0.0)
	assert_vector(point).is_equal_approx(Vector3(1.0 + RADIUS, 1.1, 2.0), Vector3.ONE * TOLERANCE)


func test_ac934_the_impact_height_follows_the_blade_within_the_limits() -> void:
	var player_pos := Vector3(0.0, 0.0, 3.0)
	var inside: Vector3 = HitImpactVfxHost.impact_point(Vector3.ZERO, RADIUS, Vector3(-1.0, 1.1, 1.0), Vector3(1.0, 1.1, 1.0), player_pos, CONFIG.min_height, CONFIG.max_height)
	var low: Vector3 = HitImpactVfxHost.impact_point(Vector3.ZERO, RADIUS, Vector3(-1.0, 0.1, 1.0), Vector3(1.0, 0.1, 1.0), player_pos, CONFIG.min_height, CONFIG.max_height)
	var high: Vector3 = HitImpactVfxHost.impact_point(Vector3.ZERO, RADIUS, Vector3(-1.0, 2.6, 1.0), Vector3(1.0, 2.6, 1.0), player_pos, CONFIG.min_height, CONFIG.max_height)
	assert_float(inside.y).is_equal_approx(1.1, TOLERANCE)
	assert_float(low.y).is_equal_approx(CONFIG.min_height, TOLERANCE)
	assert_float(high.y).is_equal_approx(CONFIG.max_height, TOLERANCE)
	var raised: Vector3 = HitImpactVfxHost.impact_point(Vector3(0.0, 2.0, 0.0), RADIUS, Vector3(-1.0, 3.1, 1.0), Vector3(1.0, 3.1, 1.0), player_pos, CONFIG.min_height, CONFIG.max_height)
	assert_float(raised.y).is_equal_approx(3.1, TOLERANCE)


func test_ac935_a_blade_on_the_enemy_axis_puts_the_impact_towards_the_player() -> void:
	var player_pos := Vector3(0.0, 0.0, 3.0)
	var point: Vector3 = HitImpactVfxHost.impact_point(Vector3.ZERO, RADIUS, Vector3(-1.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), player_pos, CONFIG.min_height, CONFIG.max_height)
	assert_vector(point).is_equal_approx(Vector3(0.0, 1.0, RADIUS), Vector3.ONE * TOLERANCE)


func test_ac936_the_shard_follows_the_tip_motion_or_lies_flat_across_the_normal() -> void:
	var normal := Vector3.BACK
	var motion := Vector3(0.1, -0.2, 0.05)
	var cut: Vector3 = HitImpactVfxHost.cut_direction(motion, normal, CONFIG.min_tip_speed)
	var tangent: Vector3 = (motion - normal * motion.dot(normal)).normalized()
	assert_float(rad_to_deg(cut.angle_to(tangent))).is_less(MAX_ANGLE_DEGREES)
	var effect: HitImpactVfx = _host.get_pool()[0]
	effect.play(Vector3(0.0, 1.0, RADIUS), normal, cut, false)
	assert_float(rad_to_deg(effect.global_basis.x.angle_to(tangent))).is_less(MAX_ANGLE_DEGREES)
	var still: Vector3 = HitImpactVfxHost.cut_direction(Vector3(0.0, 0.0, 0.2), normal, CONFIG.min_tip_speed)
	assert_float(still.y).is_equal_approx(0.0, TOLERANCE)
	assert_float(still.dot(normal)).is_equal_approx(0.0, TOLERANCE)
	assert_float(still.length()).is_equal_approx(1.0, TOLERANCE)


func test_ac936_the_impact_faces_the_camera() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.global_position = Vector3(3.0, 2.5, 4.0)
	camera.make_current()
	_host.show_impact(enemy, false)
	var effect: HitImpactVfx = _playing()[0]
	var to_camera: Vector3 = (camera.global_position - effect.global_position).normalized()
	assert_float(rad_to_deg(effect.global_basis.z.angle_to(to_camera))).is_less(MAX_ANGLE_DEGREES)
	assert_float(absf(effect.global_basis.x.normalized().dot(to_camera))).is_less(TOLERANCE)


func test_ac937_a_critical_hit_is_white_bigger_and_crossed() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_host.show_impact(enemy, true)
	var crit: HitImpactVfx = _playing()[0]
	assert_bool(crit.is_crit()).is_true()
	assert_object(crit.get_shard().material_override).is_same(GLOW)
	assert_object(crit.get_sparks().material_override).is_same(GLOW)
	assert_bool(crit.get_cross_shard().visible).is_true()
	assert_float(crit.global_basis.get_scale().x).is_equal_approx(CONFIG.crit_scale, TOLERANCE)
	assert_float(rad_to_deg(crit.get_cross_shard().rotation.z)).is_equal_approx(CONFIG.crit_cross_angle, TOLERANCE)
	_host.show_impact(enemy, false)
	var normal: HitImpactVfx = null
	for effect: HitImpactVfx in _playing():
		if not effect.is_crit():
			normal = effect
	assert_object(normal.get_shard().material_override).is_same(GLOW)
	assert_bool(normal.get_cross_shard().visible).is_false()
	assert_float(normal.global_basis.get_scale().x).is_equal_approx(1.0, TOLERANCE)


func test_ac937_a_critical_combo_strike_shows_the_critical_impact() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	ComboDriver.strike(_player, CRIT_ROLL)
	assert_bool(_playing()[0].is_crit()).is_true()


func test_ac939_the_pool_never_grows_and_reuses_the_oldest_impact() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	assert_int(_host.get_child_count()).is_equal(CONFIG.pool_size)
	var pool: Array[HitImpactVfx] = _host.get_pool()
	for index: int in CONFIG.pool_size:
		_host.show_impact(enemy, false)
		for effect: HitImpactVfx in pool:
			effect.advance(CONFIG.duration / (CONFIG.pool_size * 4.0))
	assert_int(_host.get_active_count()).is_equal(CONFIG.pool_size)
	var oldest: HitImpactVfx = pool[0]
	assert_float(oldest.get_elapsed()).is_greater(pool[1].get_elapsed())
	_host.show_impact(enemy, false)
	assert_float(oldest.get_elapsed()).is_equal(0.0)
	for extra: int in 3:
		_host.show_impact(enemy, false)
	assert_int(_host.get_child_count()).is_equal(CONFIG.pool_size)
	assert_int(_host.get_active_count()).is_equal(CONFIG.pool_size)


func test_ac940_the_impact_grows_then_ends_after_its_duration() -> void:
	var effect: HitImpactVfx = _host.get_pool()[0]
	effect.play(Vector3(0.0, 1.0, RADIUS), Vector3.BACK, Vector3.RIGHT, false)
	assert_bool(effect.get_flash_light().visible).is_true()
	effect.advance(CONFIG.grow_time)
	assert_float(effect.get_shard().scale.x).is_equal_approx(CONFIG.shard_length, TOLERANCE)
	assert_float(effect.get_shard().scale.y).is_equal_approx(CONFIG.shard_width, TOLERANCE)
	effect.advance(CONFIG.duration - CONFIG.grow_time)
	assert_bool(effect.is_playing()).is_false()
	assert_bool(effect.get_shard().visible).is_false()
	assert_bool(effect.get_cross_shard().visible).is_false()
	assert_bool(effect.get_flash().visible).is_false()
	assert_bool(effect.get_flash_light().visible).is_false()
	assert_float(effect.get_flash_light().light_energy).is_equal_approx(0.0, TOLERANCE)


func test_ac941_the_material_is_white_unshaded_additive_and_translucent() -> void:
	assert_int(GLOW.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_int(GLOW.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)
	assert_int(GLOW.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_float(GLOW.albedo_color.a).is_less_equal(0.5)
	assert_bool(GLOW.albedo_color.is_equal_approx(Color(1, 1, 1, 0.5))).is_true()
