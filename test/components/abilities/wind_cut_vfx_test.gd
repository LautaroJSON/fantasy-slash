extends GdUnitTestSuite
## Wind cut of Sheathe (docs/specs/wind-cut-v.md AC273-AC276; docs/specs/sheathe-visual-rework.md
## AC1043-AC1049 and AC1051, which replace AC271-AC272).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
const WIND_CUT: WindCutConfig = preload("res://data/abilities/sheathe/wind_cut_config.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/wind_cut_additive_material.tres")
const DUST_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/wind_dust_material.tres")
const CRACK_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/ground_crack_material.tres")
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


## Lowest point of a segment (its bottom edge), in the VFX's local space.
func _bottom(segment: MeshInstance3D) -> float:
	var up: Vector3 = segment.basis.y
	return segment.position.y - absf(up.y) / 2.0


func _segment(side: WindCutVfx.WallSide, index: int) -> MeshInstance3D:
	return _wind_cut.get_segment(side, index)


## Advances the VFX (after the burst) to `seconds` since the burst.
func _to(seconds: float, since_burst: Array[float]) -> void:
	_wind_cut.advance(seconds - since_burst[0])
	since_burst[0] = seconds


func test_ac1043_segments_rise_in_a_wave_higher_in_the_middle() -> void:
	_slash(SHEATHE.charge_time + STEP)
	assert_bool(_wind_cut.is_bursting()).is_true()
	assert_float(_wind_cut.global_position.y).is_equal_approx(_visual.global_position.y, TOLERANCE)
	var count: int = WIND_CUT.segment_count
	var length: float = SHEATHE.hit_range
	var slot: float = length / count
	var half_angle: float = deg_to_rad(WIND_CUT.half_angle_degrees)
	var since_burst: Array[float] = [0.0]
	var peaks: Array[float] = []
	for i: int in count:
		var rise_at: float = i * WIND_CUT.wave_step
		if i > 0:
			_to(rise_at - TOLERANCE * 10.0, since_burst)
			assert_bool(_segment(WindCutVfx.WallSide.LEFT, i).visible).override_failure_message("before rising %d" % i).is_false()
		_to(rise_at + WIND_CUT.grow_duration / 2.0, since_burst)
		var left: MeshInstance3D = _segment(WindCutVfx.WallSide.LEFT, i)
		var right: MeshInstance3D = _segment(WindCutVfx.WallSide.RIGHT, i)
		assert_bool(left.visible).is_true()
		assert_float(left.scale.y).is_equal_approx(_wind_cut.get_segment_peak_height(i) / 2.0, TOLERANCE)
		assert_float(_bottom(left)).is_equal_approx(0.0, TOLERANCE)
		_to(rise_at + WIND_CUT.grow_duration, since_burst)
		peaks.append(left.scale.y)
		assert_float(left.rotation.z).is_equal_approx(half_angle, TOLERANCE)
		assert_float(right.rotation.z).is_equal_approx(-half_angle, TOLERANCE)
		assert_float(left.position.x).is_less(0.0)
		assert_float(right.position.x).is_greater(0.0)
		assert_float(left.position.z).is_equal_approx(-(i + 0.5) * slot, TOLERANCE)
		assert_float(left.scale.z).is_equal_approx(slot * WIND_CUT.segment_fill, TOLERANCE)
		assert_float(_bottom(right)).is_equal_approx(0.0, TOLERANCE)
	var middle: int = count / 2
	assert_float(peaks[middle]).is_equal_approx(WIND_CUT.max_height, TOLERANCE)
	for i: int in count:
		assert_float(peaks[i]).is_less_equal(peaks[middle] + TOLERANCE)
	var edge: float = WIND_CUT.max_height * lerpf(WIND_CUT.edge_height_ratio, 1.0, sin(PI * 0.5 / count))
	assert_float(peaks[0]).is_equal_approx(edge, TOLERANCE)
	assert_float(peaks[count - 1]).is_equal_approx(edge, TOLERANCE)


func test_ac1043_an_uncharged_slash_raises_lower_segments() -> void:
	_slash(0.0)
	var middle: int = WIND_CUT.segment_count / 2
	_wind_cut.advance(middle * WIND_CUT.wave_step + WIND_CUT.grow_duration)
	var factor: float = SHEATHE_CONFIG.min_charge_factor
	assert_float(_segment(WindCutVfx.WallSide.LEFT, middle).scale.y).is_equal_approx(WIND_CUT.max_height * factor, TOLERANCE)
	var slot: float = SHEATHE.hit_range * factor / WIND_CUT.segment_count
	assert_float(_segment(WindCutVfx.WallSide.LEFT, middle).position.z).is_equal_approx(-(middle + 0.5) * slot, TOLERANCE)


func test_ac1044_segments_thin_out_from_the_edges_and_stay_translucent() -> void:
	_slash(SHEATHE.charge_time + STEP)
	var count: int = WIND_CUT.segment_count
	var middle: int = count / 2
	var first_fade: float = _wind_cut.get_segment_fade_start(0)
	var middle_fade: float = _wind_cut.get_segment_fade_start(middle) - middle * WIND_CUT.wave_step
	var last_fade: float = _wind_cut.get_segment_fade_start(count - 1) - (count - 1) * WIND_CUT.wave_step
	assert_float(first_fade).is_less(middle_fade)
	assert_float(last_fade).is_less(middle_fade)
	var since_burst: Array[float] = [0.0]
	var segment: MeshInstance3D = _segment(WindCutVfx.WallSide.RIGHT, 0)
	_to(first_fade + WIND_CUT.fade_duration / 2.0, since_burst)
	assert_float(segment.scale.x).is_less(WIND_CUT.wall_thickness)
	assert_float(segment.scale.y).is_less(_wind_cut.get_segment_peak_height(0))
	assert_float(segment.transparency).is_greater_equal(0.5)
	_to(first_fade + WIND_CUT.fade_duration - TOLERANCE * 10.0, since_burst)
	assert_float(segment.scale.x).is_less_equal(WindCutVfx.MIN_SIZE + TOLERANCE)
	assert_float(segment.scale.y).is_equal_approx(_wind_cut.get_segment_peak_height(0) * WIND_CUT.fade_height_ratio, 0.01)
	# Sampled over the whole burst: every visible segment stays translucent.
	var t: float = since_burst[0]
	while _wind_cut.is_playing():
		t += STEP / 2.0
		_to(t, since_burst)
		for side: int in WindCutVfx.WallSide.size():
			for i: int in count:
				var each: MeshInstance3D = _wind_cut.get_segment(side as WindCutVfx.WallSide, i)
				if each.visible:
					assert_float(each.transparency).is_greater_equal(0.5)
	for i: int in count:
		assert_bool(_segment(WindCutVfx.WallSide.LEFT, i).visible).is_false()


func _crescent_width(mesh: ArrayMesh, pair: int) -> float:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return vertices[pair * 2].distance_to(vertices[pair * 2 + 1])


func test_ac1045_the_crescent_flies_to_the_tip_and_fades() -> void:
	var crescent: MeshInstance3D = _wind_cut.get_crescent()
	var mesh: ArrayMesh = crescent.mesh as ArrayMesh
	var pairs: int = WIND_CUT.crescent_segments + 1
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_int(vertices.size()).is_equal(pairs * 2)
	assert_float(_crescent_width(mesh, WIND_CUT.crescent_segments / 2)).is_equal_approx(WIND_CUT.crescent_width, TOLERANCE)
	assert_float(_crescent_width(mesh, 0)).is_less_equal(0.01)
	assert_float(_crescent_width(mesh, pairs - 1)).is_less_equal(0.01)
	_slash(SHEATHE.charge_time + STEP)
	assert_bool(crescent.visible).is_true()
	assert_float(crescent.position.y).is_equal_approx(WIND_CUT.crescent_height, TOLERANCE)
	assert_float(crescent.position.z).is_equal_approx(-WIND_CUT.crescent_start, TOLERANCE)
	assert_float(crescent.rotation.z).is_equal_approx(deg_to_rad(WIND_CUT.crescent_roll_degrees), TOLERANCE)
	assert_float(crescent.transparency).is_equal_approx(WIND_CUT.crescent_start_transparency, TOLERANCE)
	_wind_cut.advance(WIND_CUT.crescent_travel)
	assert_float(crescent.position.z).is_equal_approx(-SHEATHE.hit_range, TOLERANCE)
	assert_float(crescent.scale.x).is_equal_approx(1.0, TOLERANCE)
	assert_float(crescent.transparency).is_greater(WIND_CUT.crescent_start_transparency)
	_wind_cut.advance(WIND_CUT.crescent_fade)
	assert_bool(crescent.visible).is_false()
	# Built once: the second cut draws the same mesh.
	_ability.reset_cooldown()
	_slash(0.0)
	assert_object(crescent.mesh).is_same(mesh)
	_wind_cut.advance(WIND_CUT.crescent_travel)
	assert_float(crescent.scale.x).is_equal_approx(WIND_CUT.crescent_min_scale, TOLERANCE)


func test_ac1046_the_echo_follows_bigger_and_fainter() -> void:
	_slash(SHEATHE.charge_time + STEP)
	var crescent: MeshInstance3D = _wind_cut.get_crescent()
	var echo: MeshInstance3D = _wind_cut.get_echo()
	assert_bool(echo.visible).is_false()
	_wind_cut.advance(WIND_CUT.crescent_travel / 2.0)
	var crescent_scale: float = crescent.scale.x
	var crescent_transparency: float = crescent.transparency
	_wind_cut.advance(WIND_CUT.echo_delay)
	assert_bool(echo.visible).is_true()
	assert_float(echo.scale.x).is_equal_approx(crescent_scale * WIND_CUT.echo_scale, TOLERANCE)
	assert_float(echo.transparency).is_greater(crescent_transparency)
	assert_object(echo.mesh).is_same(crescent.mesh)


func test_ac1047_a_broken_crack_opens_along_the_slash_and_fades() -> void:
	_slash(SHEATHE.charge_time + STEP)
	var count: int = WIND_CUT.crack_count
	var length: float = SHEATHE.hit_range
	assert_bool(_wind_cut.get_crack_piece(0).visible).is_true()
	assert_bool(_wind_cut.get_crack_piece(1).visible).is_false()
	var opened: float = (count - 1) * WIND_CUT.crack_open_step
	_wind_cut.advance(opened)
	for i: int in count:
		var piece: MeshInstance3D = _wind_cut.get_crack_piece(i)
		assert_bool(piece.visible).override_failure_message("piece %d" % i).is_true()
		assert_float(absf(piece.position.x)).is_less_equal(WIND_CUT.crack_offset + TOLERANCE)
		assert_float(absf(rad_to_deg(piece.rotation.y))).is_less_equal(WIND_CUT.crack_jitter_degrees + TOLERANCE)
		assert_float(piece.position.y).is_less_equal(0.02)
		assert_float(piece.position.z).is_between(-length, 0.0)
		assert_object(piece.mesh.surface_get_material(0)).is_same(CRACK_MATERIAL)
		assert_float(piece.transparency).is_equal(0.0)
	_wind_cut.advance(WIND_CUT.crack_duration + WIND_CUT.crack_fade / 2.0 - opened)
	assert_float(_wind_cut.get_crack_piece(0).transparency).is_equal_approx(0.5, 0.01)
	_wind_cut.advance(WIND_CUT.crack_fade)
	for i: int in count:
		assert_bool(_wind_cut.get_crack_piece(i).visible).is_false()
	assert_bool(_wind_cut.is_playing()).is_false()


func test_ac1049_a_new_cut_during_the_burst_starts_over() -> void:
	_slash(SHEATHE.charge_time + STEP)
	_wind_cut.advance(WIND_CUT.grow_duration)
	_wind_cut.play(_visual.global_position, 0.0, SHEATHE.hit_range, 1.0)
	assert_bool(_wind_cut.is_bursting()).is_false()
	assert_bool(_wind_cut.get_line().visible).is_true()
	assert_bool(_segment(WindCutVfx.WallSide.LEFT, 0).visible).is_false()
	assert_bool(_wind_cut.get_crescent().visible).is_false()


func test_ac1051_shared_materials_without_shaders() -> void:
	_slash(SHEATHE.charge_time + STEP)
	var drawn: Array[MeshInstance3D] = [_wind_cut.get_line(), _segment(WindCutVfx.WallSide.LEFT, 0), _wind_cut.get_crescent(), _wind_cut.get_echo()]
	for mesh_instance: MeshInstance3D in drawn:
		assert_object(mesh_instance.mesh.surface_get_material(0)).is_same(GLOW_MATERIAL)
		assert_object(mesh_instance.material_override).is_null()
	assert_object(_wind_cut.get_crack_piece(0).mesh.surface_get_material(0)).is_same(CRACK_MATERIAL)
	assert_int(GLOW_MATERIAL.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)
	assert_int(GLOW_MATERIAL.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_float(GLOW_MATERIAL.albedo_color.a).is_less_equal(0.5)
	assert_int(CRACK_MATERIAL.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_float(CRACK_MATERIAL.albedo_color.v).is_less_equal(0.15)


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
