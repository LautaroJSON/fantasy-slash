extends GdUnitTestSuite
## docs/specs/riposte-levels.md (AC1056–AC1067): "Contragolpe" with 3 levels
## and the white vortex VFX.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const PARRY_SCENE: PackedScene = preload("res://components/abilities/parry_ability.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const CONFIG: ParryConfig = preload("res://data/abilities/parry/parry_config.tres")
const VFX_CONFIG: CircleSlashVfxConfig = preload("res://data/abilities/parry/circle_slash_vfx_config.tres")
const RIPOSTE: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/riposte.tres")
const DUEL: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/duel.tres")
const CHALLENGED: DebuffData = preload("res://data/debuffs/challenged.tres")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const HIT: float = 20.0
const TOLERANCE: float = 0.001
const EDGE: float = 0.05
const FRAME: float = 1.0 / 60.0
const RANGE_SCALES: Array[float] = [1.3, 1.69, 2.366]
const DAMAGE_MULTIPLIERS: Array[float] = [1.5, 2.25, 3.9375]
const BAND_WIDTHS: Array[float] = [0.8, 1.0, 1.2]
const STREAKS: Array[int] = [4, 7, 10]
const SPARKS: Array[int] = [16, 28, 44]
const DUST: Array[int] = [0, 14, 28]
const FLASH: Array[float] = [1.0, 2.0, 3.0]
const ALL_OFF_AFTER: float = 0.6
const EARTH := Color(0.62, 0.52, 0.4)

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent


func before_test() -> void:
	Session.character_class = WARRIOR
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_player.health.setup(1000.0, 0.0)
	_ability = _player.basic_ability
	_ability.equip(PARRY)
	_ability.set_physics_process(false)
	await get_tree().physics_frame


func after_test() -> void:
	Session.character_class = null


func _spawn(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = GRUNT
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	enemy.health.setup(100000.0, 0.0)
	return enemy


func _behavior() -> ParryAbility:
	return _ability.get_behavior() as ParryAbility


func _vfx() -> CircleSlashVfx:
	return _behavior().get_slash_vfx()


func _take_riposte(level: int) -> void:
	for i: int in level:
		_player.apply_upgrade(RIPOSTE)
	assert_int(_ability.get_unique_level(RIPOSTE.id)).is_equal(level)


## Casts the parry and blocks `attacker`: the empowered riposte starts.
func _block(attacker: Enemy) -> void:
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)


func _radius(level: int) -> float:
	return _player.stats.get_stat(PlayerStats.Stat.ATTACK_RANGE) * RANGE_SCALES[level - 1]


# --- Levels


func test_ac1056_riposte_has_three_levels() -> void:
	assert_int(RIPOSTE.max_level).is_equal(3)
	assert_int(RIPOSTE.level_descriptions.size()).is_equal(3)
	assert_bool(RIPOSTE.get_description(2).contains("+30 %") and RIPOSTE.get_description(2).contains("+50 %")).is_true()
	assert_bool(RIPOSTE.get_description(3).contains("+40 %") and RIPOSTE.get_description(3).contains("+75 %")).is_true()
	for _level: int in 3:
		assert_bool(_ability.is_unique_maxed(RIPOSTE)).is_false()
		_player.apply_upgrade(RIPOSTE)
	assert_bool(_ability.is_unique_maxed(RIPOSTE)).is_true()
	_player.apply_upgrade(RIPOSTE)
	assert_int(_ability.get_unique_level(RIPOSTE.id)).is_equal(3)


func test_ac1057_the_scales_multiply_per_level() -> void:
	for level: int in [1, 2, 3]:
		assert_float(CONFIG.get_empowered_range_scale(level)).is_equal_approx(RANGE_SCALES[level - 1], TOLERANCE)
		assert_float(CONFIG.get_empowered_damage_multiplier(level)).is_equal_approx(DAMAGE_MULTIPLIERS[level - 1], TOLERANCE)
	assert_float(CONFIG.get_empowered_range_scale(9)).is_equal_approx(RANGE_SCALES[2], TOLERANCE)
	assert_float(CONFIG.get_empowered_damage_multiplier(9)).is_equal_approx(DAMAGE_MULTIPLIERS[2], TOLERANCE)


func _check_reach(level: int) -> void:
	_take_riposte(level)
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	var padding: float = attacker.get_hit_padding()
	var reach: float = _radius(level) + padding
	var inside: Enemy = _spawn(Vector3(reach - EDGE, 0.0, 0.0))
	var outside: Enemy = _spawn(Vector3(0.0, 0.0, reach + EDGE))
	var hits: Array[Enemy] = []
	_player.attack.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: hits.append(enemy))
	_block(attacker)
	assert_float(_behavior().get_empowered_radius(_ability)).is_equal_approx(_radius(level), TOLERANCE)
	_ability.advance(CONFIG.empowered_hit_time)
	assert_int(hits.count(inside)).is_equal(1)
	assert_int(hits.count(outside)).is_equal(0)


func test_ac1058_reach_at_level_1() -> void:
	_check_reach(1)


func test_ac1058_reach_at_level_2() -> void:
	_check_reach(2)


func test_ac1058_reach_at_level_3() -> void:
	_check_reach(3)


func _check_damage(level: int) -> void:
	_take_riposte(level)
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	var applied: Array[float] = []
	var ability_hits: Array[Enemy] = []
	_player.attack.enemy_hit.connect(func(_e: Enemy, amount: float, _c: bool) -> void: applied.append(amount))
	_ability.enemy_hit.connect(func(enemy: Enemy, _a: float, _c: bool) -> void: ability_hits.append(enemy))
	_block(attacker)
	_ability.advance(CONFIG.empowered_hit_time)
	var stats: StatsComponent = _player.stats
	var multiplier: float = DAMAGE_MULTIPLIERS[level - 1]
	var base: float = multiplier * DamageMath.outgoing(
		stats.get_stat(PlayerStats.Stat.DAMAGE), stats.get_stat(PlayerStats.Stat.DAMAGE_BONUS), false, stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	var crit: float = multiplier * DamageMath.outgoing(
		stats.get_stat(PlayerStats.Stat.DAMAGE), stats.get_stat(PlayerStats.Stat.DAMAGE_BONUS), true, stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	assert_int(applied.size()).is_equal(1)
	assert_bool(is_equal_approx(applied[0], base) or is_equal_approx(applied[0], crit)).override_failure_message("%f vs %f / %f" % [applied[0], base, crit]).is_true()
	assert_array(ability_hits).is_empty()


func test_ac1059_damage_at_level_1() -> void:
	_check_damage(1)


func test_ac1059_damage_at_level_2() -> void:
	_check_damage(2)


func test_ac1059_damage_at_level_3() -> void:
	_check_damage(3)


func test_ac1060_level_3_keeps_the_rest() -> void:
	_take_riposte(3)
	_player.apply_upgrade(DUEL)
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -1.5))
	var other: Enemy = _spawn(Vector3(2.0, 0.0, 0.0))
	_block(attacker)
	assert_bool(_ability.is_on_cooldown()).is_false()
	assert_bool(attacker.is_time_frozen()).is_true()
	assert_bool(other.is_time_frozen()).is_true()
	assert_bool(_player.health.is_invulnerable).is_true()
	_ability.advance(CONFIG.empowered_hit_time)
	assert_bool(other.debuffs.has_debuff(CHALLENGED.id)).is_true()
	_ability.advance(CONFIG.empowered_duration - CONFIG.empowered_hit_time - FRAME)
	assert_bool(_player.health.is_invulnerable).is_true()
	_ability.advance(2.0 * FRAME)
	assert_bool(_player.health.is_invulnerable).is_false()


# --- Vortex


## Starts the riposte at `level` and advances to the start of the sweep.
func _start_vortex(level: int) -> CircleSlashVfx:
	_take_riposte(level)
	var vfx: CircleSlashVfx = _vfx()
	vfx.set_process(false)
	_block(_spawn(Vector3(0.0, 0.0, -1.5)))
	_ability.advance(CONFIG.empowered_trail_start + FRAME)
	assert_bool(vfx.is_playing()).is_true()
	return vfx


func test_ac1061_the_vortex_follows_the_level_and_ends_in_time() -> void:
	var vfx: CircleSlashVfx = _start_vortex(2)
	assert_int(vfx.get_level()).is_equal(2)
	assert_float(vfx.get_band_inner_radius(1.0) + vfx.get_band_width()).is_equal_approx(_radius(2), TOLERANCE)
	vfx.advance(VFX_CONFIG.sweep_duration - FRAME)
	assert_float(vfx.get_head_degrees()).is_equal_approx(360.0, 360.0 * FRAME * 2.0 / VFX_CONFIG.sweep_duration)
	vfx.advance(VFX_CONFIG.fade_duration + FRAME)
	assert_bool(vfx.is_playing()).is_false()
	var hit_after_play: float = CONFIG.empowered_hit_time - CONFIG.empowered_trail_start
	assert_float(VFX_CONFIG.sweep_duration + VFX_CONFIG.fade_duration).is_less_equal(ALL_OFF_AFTER)
	assert_float(hit_after_play + vfx.get_sparks().lifetime).is_less_equal(ALL_OFF_AFTER)
	assert_float(hit_after_play + vfx.get_dust().lifetime).is_less_equal(ALL_OFF_AFTER)
	assert_float(hit_after_play + VFX_CONFIG.flash_duration).is_less_equal(ALL_OFF_AFTER)


func _check_growth(level: int) -> void:
	var vfx: CircleSlashVfx = _start_vortex(level)
	assert_float(vfx.get_band_width()).is_equal_approx(BAND_WIDTHS[level - 1], TOLERANCE)
	assert_int(vfx.get_streak_count()).is_equal(STREAKS[level - 1])
	_ability.advance(CONFIG.empowered_hit_time - CONFIG.empowered_trail_start)
	assert_int(vfx.get_sparks().amount).is_equal(SPARKS[level - 1])
	assert_bool(vfx.get_sparks().emitting).is_true()
	assert_bool(vfx.get_dust().emitting).is_equal(DUST[level - 1] > 0)
	if DUST[level - 1] > 0:
		assert_int(vfx.get_dust().amount).is_equal(DUST[level - 1])
	assert_bool(vfx.get_flash().visible).is_true()
	assert_float(vfx.get_flash().light_energy).is_equal_approx(FLASH[level - 1], 0.2)


func test_ac1062_growth_at_level_1() -> void:
	_check_growth(1)


func test_ac1062_growth_at_level_2() -> void:
	_check_growth(2)


func test_ac1062_growth_at_level_3() -> void:
	_check_growth(3)


func test_ac1063_the_band_and_the_streaks_spiral_in() -> void:
	var vfx: CircleSlashVfx = _start_vortex(1)
	var radius: float = _radius(1)
	assert_float(vfx.get_band_inner_radius(0.0) / radius).is_equal_approx(VFX_CONFIG.inner_radius_ratio, 0.02)
	assert_float(vfx.get_band_inner_radius(0.0) / radius).is_equal_approx(0.45, 0.02)
	assert_float(vfx.get_band_inner_radius(1.0)).is_equal_approx(radius - BAND_WIDTHS[0], TOLERANCE)
	for i: int in vfx.get_streak_count():
		assert_float(vfx.get_streak_radius(i, 0.0)).is_less(vfx.get_streak_radius(i, 1.0))


func test_ac1064_the_streaks_are_the_same_every_time() -> void:
	var vfx: CircleSlashVfx = _start_vortex(3)
	var radius: float = _radius(3)
	var heights: Array[float] = []
	var offsets: Array[float] = []
	for i: int in vfx.get_streak_count():
		heights.append(vfx.get_streak_height(i))
		offsets.append(vfx.get_streak_offset(i))
		var ratio: float = vfx.get_streak_radius(i, 1.0) / radius
		assert_float(ratio).is_between(0.35 - TOLERANCE, 1.05 + TOLERANCE)
		assert_float(vfx.get_streak_height(i)).is_between(0.2 - TOLERANCE, 1.6 + TOLERANCE)
	vfx.play(_player.get_node("Visual") as Node3D, radius, 3)
	for i: int in vfx.get_streak_count():
		assert_float(vfx.get_streak_height(i)).is_equal(heights[i])
		assert_float(vfx.get_streak_offset(i)).is_equal(offsets[i])


func test_ac1065_the_burst_waits_for_the_hit_on_the_ring() -> void:
	var vfx: CircleSlashVfx = _start_vortex(3)
	assert_bool(vfx.get_sparks().emitting).is_false()
	assert_bool(vfx.get_dust().emitting).is_false()
	assert_bool(vfx.get_flash().visible).is_false()
	_ability.advance(CONFIG.empowered_hit_time - CONFIG.empowered_trail_start - 2.0 * FRAME)
	assert_bool(vfx.get_sparks().emitting).is_false()
	_ability.advance(2.0 * FRAME)
	assert_bool(vfx.get_sparks().emitting).is_true()
	assert_bool(vfx.get_dust().emitting).is_true()
	assert_bool(vfx.get_flash().visible).is_true()
	assert_float(vfx.get_sparks().emission_ring_radius).is_equal_approx(_radius(3), TOLERANCE)
	assert_float(vfx.get_dust().emission_ring_radius).is_equal_approx(_radius(3), TOLERANCE)


func test_ac1066_shared_white_and_earth_materials() -> void:
	var vfx: CircleSlashVfx = _vfx()
	var ribbon: StandardMaterial3D = VFX_CONFIG.material
	var spark: StandardMaterial3D = (vfx.get_sparks().mesh as BoxMesh).material as StandardMaterial3D
	var dust: StandardMaterial3D = (vfx.get_dust().mesh as SphereMesh).material as StandardMaterial3D
	for material: StandardMaterial3D in [ribbon, spark]:
		assert_str(material.resource_path).is_not_empty()
		assert_int(material.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
		assert_int(material.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)
		assert_that(Color(material.albedo_color, 1.0)).is_equal(Color(1, 1, 1))
	assert_float(spark.albedo_color.a).is_less_equal(0.5 + TOLERANCE)
	assert_float(VFX_CONFIG.head_alpha).is_less_equal(0.5)
	assert_float(VFX_CONFIG.streak_alpha).is_less_equal(0.5)
	assert_float(VFX_CONFIG.floor_alpha).is_less_equal(0.3)
	assert_str(dust.resource_path).is_not_empty()
	assert_int(dust.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_that(Color(dust.albedo_color, 1.0)).is_equal(EARTH)
	assert_float(dust.albedo_color.a).is_less_equal(0.6 + TOLERANCE)


func test_ac1067_every_node_is_prebuilt_in_the_scene() -> void:
	var state: SceneState = PARRY_SCENE.get_state()
	var paths: Array[String] = []
	for i: int in state.get_node_count():
		paths.append(String(state.get_node_path(i)))
	for path: String in ["./SlashVfx", "./SlashVfx/Sparks", "./SlashVfx/Dust", "./SlashVfx/Flash"]:
		assert_bool(paths.has(path)).override_failure_message(path).is_true()
	var vfx: CircleSlashVfx = _start_vortex(1)
	var children: int = vfx.get_child_count()
	vfx.play(_player.get_node("Visual") as Node3D, _radius(1), 3)
	vfx.advance(VFX_CONFIG.sweep_duration)
	vfx.burst()
	assert_int(vfx.get_child_count()).is_equal(children)
	assert_int(VFX_CONFIG.get_max_streak_count()).is_equal(STREAKS[2])
