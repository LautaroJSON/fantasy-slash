extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
const WIND_CUT: WindCutConfig = preload("res://data/abilities/sheathe/wind_cut_config.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/wind_cut_additive_material.tres")
const DUST_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/wind_dust_material.tres")
const STEP: float = 0.05
const TOLERANCE: float = 0.0001

var _player: Player
var _ability: AbilityComponent
var _visual: Node3D
var _wind_cut: WindCutVfx


func before_test() -> void:
	Session.character_class = SAMURAI
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = registry
	add_child(_player)
	_ability = _player.basic_ability
	_visual = _player.get_node("Visual") as Node3D
	_ability.set_physics_process(false)
	_ability.equip(SHEATHE)
	_wind_cut = (_ability.get_behavior() as SheatheAbility).get_wind_cut()
	await get_tree().physics_frame


func after_test() -> void:
	Session.character_class = null


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


## Charges for `seconds`, releases and lets the slash land; the VFX is then
## driven by hand.
func _slash(seconds: float) -> void:
	_ability.try_cast()
	_advance(seconds)
	_ability.release_charge()
	_advance(SHEATHE.cast_duration + STEP)
	_wind_cut.set_process(false)


## Lowest point of a wall (its bottom edge), in the VFX's local space.
func _wall_bottom(wall: MeshInstance3D) -> float:
	var up: Vector3 = wall.basis.y
	return wall.position.y - absf(up.y) / 2.0


func test_ac271_the_walls_rise_from_the_slash_line_opening_upwards_in_a_v() -> void:
	_slash(SHEATHE.charge_time + STEP)
	assert_bool(_wind_cut.is_playing()).is_true()
	assert_float(_wind_cut.global_position.y).is_equal_approx(_visual.global_position.y, TOLERANCE)
	var half_angle: float = deg_to_rad(WIND_CUT.half_angle_degrees)
	var left: MeshInstance3D = _wind_cut.get_wall(WindCutVfx.Wall.LEFT)
	var right: MeshInstance3D = _wind_cut.get_wall(WindCutVfx.Wall.RIGHT)
	assert_float(left.rotation.z).is_equal_approx(half_angle, TOLERANCE)
	assert_float(right.rotation.z).is_equal_approx(-half_angle, TOLERANCE)
	assert_float(_wind_cut.get_wall_length()).is_equal_approx(SHEATHE.hit_range, TOLERANCE)
	_wind_cut.advance(WIND_CUT.grow_duration / 2.0)
	assert_float(_wall_bottom(left)).is_equal_approx(0.0, TOLERANCE)
	assert_float(left.position.x).is_less(0.0)
	assert_float(right.position.x).is_greater(0.0)
	assert_float(left.position.z).is_equal_approx(-SHEATHE.hit_range / 2.0, TOLERANCE)
	_wind_cut.advance(WIND_CUT.grow_duration / 2.0)
	assert_float(_wind_cut.get_wall_height()).is_equal_approx(WIND_CUT.max_height, TOLERANCE)
	assert_float(_wall_bottom(right)).is_equal_approx(0.0, TOLERANCE)


func test_ac271_an_uncharged_slash_raises_lower_walls() -> void:
	_slash(0.0)
	_wind_cut.advance(WIND_CUT.grow_duration)
	var factor: float = SHEATHE_CONFIG.min_charge_factor
	assert_float(_wind_cut.get_wall_height()).is_equal_approx(WIND_CUT.max_height * factor, TOLERANCE)
	assert_float(_wind_cut.get_wall_length()).is_equal_approx(SHEATHE.hit_range * factor, TOLERANCE)


func test_ac272_the_walls_stay_translucent_additive_and_hide_after_fading() -> void:
	_slash(SHEATHE.charge_time + STEP)
	var left: MeshInstance3D = _wind_cut.get_wall(WindCutVfx.Wall.LEFT)
	assert_float(left.transparency).is_greater_equal(0.5)
	_wind_cut.advance(WIND_CUT.grow_duration + WIND_CUT.fade_duration / 2.0)
	assert_float(left.transparency).is_greater_equal(0.5)
	assert_bool(left.visible).is_true()
	_wind_cut.advance(WIND_CUT.fade_duration / 2.0 + STEP)
	assert_bool(_wind_cut.is_playing()).is_false()
	assert_bool(left.visible).is_false()
	assert_object(left.mesh.surface_get_material(0)).is_same(GLOW_MATERIAL)
	assert_int(GLOW_MATERIAL.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)
	assert_int(GLOW_MATERIAL.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_float(GLOW_MATERIAL.albedo_color.a).is_less_equal(0.5)
	assert_float(GLOW_MATERIAL.albedo_color.r).is_equal(1.0)
	assert_float(GLOW_MATERIAL.albedo_color.g).is_equal(1.0)
	assert_float(GLOW_MATERIAL.albedo_color.b).is_equal(1.0)


func test_ac273_sparks_burst_once_along_the_whole_slash() -> void:
	var sparks: CPUParticles3D = _wind_cut.get_sparks()
	assert_bool(sparks.emitting).is_false()
	_slash(SHEATHE.charge_time + STEP)
	assert_bool(sparks.emitting).is_true()
	assert_bool(sparks.one_shot).is_true()
	assert_int(sparks.amount).is_equal(WIND_CUT.spark_amount)
	assert_float(sparks.emission_box_extents.z).is_equal_approx(SHEATHE.hit_range / 2.0, TOLERANCE)
	assert_float(sparks.position.z).is_equal_approx(-SHEATHE.hit_range / 2.0, TOLERANCE)
	assert_object(sparks.mesh.surface_get_material(0)).is_same(GLOW_MATERIAL)


func test_ac274_dust_rises_once_from_the_ground_along_the_slash() -> void:
	var dust: CPUParticles3D = _wind_cut.get_dust()
	_slash(SHEATHE.charge_time + STEP)
	assert_bool(dust.emitting).is_true()
	assert_bool(dust.one_shot).is_true()
	assert_int(dust.amount).is_equal(WIND_CUT.dust_amount)
	assert_float(dust.position.y).is_equal(0.0)
	assert_float(dust.emission_box_extents.z).is_equal_approx(SHEATHE.hit_range / 2.0, TOLERANCE)
	assert_object(dust.mesh.surface_get_material(0)).is_same(DUST_MATERIAL)
	assert_vector(Vector3(DUST_MATERIAL.albedo_color.r, DUST_MATERIAL.albedo_color.g, DUST_MATERIAL.albedo_color.b)).is_equal_approx(Vector3(0.62, 0.52, 0.4), Vector3.ONE * 0.001)


func test_ac275_a_flash_bursts_at_the_tip_and_dies_out() -> void:
	_slash(SHEATHE.charge_time + STEP)
	var flash: MeshInstance3D = _wind_cut.get_flash()
	var light: OmniLight3D = _wind_cut.get_flash_light()
	assert_vector(flash.position).is_equal_approx(Vector3(0.0, WIND_CUT.flash_height, -SHEATHE.hit_range), Vector3.ONE * TOLERANCE)
	assert_bool(flash.visible).is_true()
	assert_bool(light.visible).is_true()
	assert_float(light.light_energy).is_equal_approx(WIND_CUT.flash_energy, TOLERANCE)
	assert_float(light.omni_range).is_equal(WIND_CUT.flash_range)
	_wind_cut.advance(WIND_CUT.flash_duration / 2.0)
	assert_float(light.light_energy).is_equal_approx(WIND_CUT.flash_energy / 2.0, TOLERANCE)
	_wind_cut.advance(WIND_CUT.flash_duration / 2.0)
	assert_float(light.light_energy).is_equal_approx(0.0, TOLERANCE)
	assert_float(flash.scale.x).is_equal_approx(WIND_CUT.flash_radius, TOLERANCE)
	_wind_cut.advance(WIND_CUT.grow_duration + WIND_CUT.fade_duration)
	assert_bool(flash.visible).is_false()
	assert_bool(light.visible).is_false()


func test_ac276_two_slashes_reuse_the_same_nodes() -> void:
	var children: int = _wind_cut.get_child_count()
	var sparks: CPUParticles3D = _wind_cut.get_sparks()
	_slash(0.0)
	_ability.reset_cooldown()
	_slash(SHEATHE.charge_time + STEP)
	assert_int(_wind_cut.get_child_count()).is_equal(children)
	assert_object(_wind_cut.get_sparks()).is_same(sparks)
