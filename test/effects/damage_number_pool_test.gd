extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const CONFIG: DamageNumberConfig = preload("res://data/ui/damage_number_config.tres")
const MATERIAL: StandardMaterial3D = preload("res://materials/damage_number_material.tres")
const CRIT_MATERIAL: StandardMaterial3D = preload("res://materials/damage_number_crit_material.tres")
const NO_CRIT_ROLL: float = 0.99
const CRIT_ROLL: float = 0.0
const POISON: DebuffData = preload("res://data/debuffs/poison.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const BLEEDING: DebuffData = preload("res://data/debuffs/bleeding.tres")
const BURST: AfflictionData = preload("res://data/afflictions/burst.tres")
const FROST_TYPE: AfflictionData = preload("res://data/afflictions/frost.tres")
const CORROSION_TYPE: AfflictionData = preload("res://data/afflictions/corrosion.tres")
const POISON_TYPE: AfflictionData = preload("res://data/afflictions/poison.tres")

var _registry: EnemyRegistry
var _player: Player
var _pool: DamageNumberPool


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	# Strikes land at the humanoid clip's hit window: the tests drive it by
	# hand, and a unit combo keeps one strike = one old swing.
	ComboDriver.drive_by_hand(_player)
	ComboDriver.use_unit_combo(_player)
	_pool = auto_free(DamageNumberPool.new())
	_pool.player = _player
	_pool.config = CONFIG
	_pool.material = MATERIAL
	_pool.crit_material = CRIT_MATERIAL
	_pool.registry = _registry
	add_child(_pool)


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func test_ac32_normal_hit_shows_a_plain_number_above_the_enemy() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	ComboDriver.strike(_player, NO_CRIT_ROLL)
	assert_int(_pool.active_count()).is_equal(1)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_str(number.get_text()).is_equal("15")
	assert_bool(number.is_crit()).is_false()
	assert_vector(number.scale).is_equal_approx(Vector3.ONE * CONFIG.normal_scale, Vector3(0.001, 0.001, 0.001))
	# readable-damage-numbers.md: born at the blade's contact point (first number
	# of the fan: no sideways offset), no longer above the head.
	var expected: Vector3 = _player.hit_impact_vfx.contact_point(enemy) + Vector3.UP * CONFIG.contact_rise
	assert_vector(number.global_position).is_equal_approx(expected, Vector3.ONE * 0.001)


func test_ac33_critical_hit_shows_a_bigger_number() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	ComboDriver.strike(_player, CRIT_ROLL)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_str(number.get_text()).is_equal("30" + CONFIG.crit_suffix)
	assert_bool(number.is_crit()).is_true()
	assert_vector(number.scale).is_equal_approx(Vector3.ONE * CONFIG.crit_pop_scale, Vector3(0.001, 0.001, 0.001))


func test_ac33_every_digit_renders_geometry() -> void:
	# Regression: emboldened fonts left some digits (e.g. "4") without geometry.
	for digit: int in 10:
		_pool.spawn(float(digit), true, Vector3.ZERO)
		var number: DamageNumber = _pool.get_last_spawned()
		assert_int(number.mesh.get_faces().size()).is_greater(0)


func test_ac34_number_rises_fades_and_returns_to_the_pool() -> void:
	_pool.spawn(15.0, false, Vector3.ZERO)
	var number: DamageNumber = _pool.get_last_spawned()
	number.advance(CONFIG.lifetime * CONFIG.fade_start * 0.9)
	assert_float(number.transparency).is_equal_approx(CONFIG.normal_transparency, 0.0001)
	assert_float(number.global_position.y).is_greater(0.0)
	number.advance(CONFIG.lifetime * 0.2)
	assert_float(number.transparency).is_greater(CONFIG.normal_transparency)
	number.advance(CONFIG.lifetime)
	assert_bool(number.is_active()).is_false()
	assert_bool(number.visible).is_false()
	assert_int(_pool.active_count()).is_equal(0)


func test_ac35_full_pool_recycles_the_oldest_number() -> void:
	for i: int in CONFIG.pool_size + 5:
		_pool.spawn(float(i), false, Vector3.ZERO)
		assert_int(_pool.active_count()).is_less_equal(CONFIG.pool_size)
	assert_int(_pool.active_count()).is_equal(CONFIG.pool_size)
	assert_str(_pool.get_last_spawned().get_text()).is_equal(str(CONFIG.pool_size + 4))


func test_ac136_normal_number_is_white_smaller_and_dimmer() -> void:
	_pool.spawn(15.0, false, Vector3.ZERO)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_str(number.get_text()).is_equal("15")
	assert_object(number.material_override).is_same(MATERIAL)
	assert_vector(number.scale).is_equal_approx(Vector3.ONE * CONFIG.normal_scale, Vector3(0.001, 0.001, 0.001))
	assert_float(number.transparency).is_equal_approx(CONFIG.normal_transparency, 0.0001)


func test_ac137_crit_number_is_white_with_suffix_and_pops() -> void:
	_pool.spawn(22.5, true, Vector3.ZERO)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_str(number.get_text()).is_equal("23!")
	assert_object(number.material_override).is_same(CRIT_MATERIAL)
	assert_float(number.transparency).is_equal_approx(0.0, 0.0001)
	assert_float(number.scale.x).is_equal_approx(CONFIG.crit_pop_scale, 0.001)
	number.advance(CONFIG.crit_pop_duration / 2.0)
	assert_float(number.scale.x).is_between(CONFIG.crit_scale + 0.001, CONFIG.crit_pop_scale - 0.001)
	number.advance(CONFIG.crit_pop_duration)
	assert_float(number.scale.x).is_equal_approx(CONFIG.crit_scale, 0.001)


func test_ac138_crit_floats_slower_and_longer() -> void:
	_pool.spawn(15.0, false, Vector3.ZERO)
	var normal: DamageNumber = _pool.get_last_spawned()
	_pool.spawn(22.5, true, Vector3.ZERO)
	var crit: DamageNumber = _pool.get_last_spawned()
	normal.advance(0.1)
	crit.advance(0.1)
	assert_float(crit.global_position.y).is_less(normal.global_position.y)
	normal.advance(0.8)
	crit.advance(0.8)
	assert_bool(normal.is_active()).is_false()
	assert_bool(crit.is_active()).is_true()
	crit.advance(0.2)
	assert_bool(crit.is_active()).is_false()


func test_ac139_fade_starts_from_each_base_transparency() -> void:
	_pool.spawn(22.5, true, Vector3.ZERO)
	var crit: DamageNumber = _pool.get_last_spawned()
	crit.advance(CONFIG.crit_lifetime * CONFIG.fade_start * 0.9)
	assert_float(crit.transparency).is_equal_approx(0.0, 0.0001)
	crit.advance(CONFIG.crit_lifetime * 0.2)
	assert_float(crit.transparency).is_between(0.001, 0.999)


func test_ac140_recycled_crit_comes_back_as_a_normal_number() -> void:
	for i: int in CONFIG.pool_size:
		_pool.spawn(22.5, true, Vector3.ZERO)
	var oldest: DamageNumber = _pool.get_last_spawned()
	for i: int in CONFIG.pool_size:
		_pool.spawn(15.0, false, Vector3.ZERO)
	assert_bool(oldest.is_crit()).is_false()
	assert_str(oldest.get_text()).is_equal("15")
	assert_object(oldest.material_override).is_same(MATERIAL)
	assert_vector(oldest.scale).is_equal_approx(Vector3.ONE * CONFIG.normal_scale, Vector3(0.001, 0.001, 0.001))
	oldest.advance(CONFIG.lifetime + 0.01)
	assert_bool(oldest.is_active()).is_false()


## docs/specs/affliction-damage-colors.md
func test_ac931_a_combo_crit_is_white_with_its_suffix_and_size() -> void:
	_spawn_enemy(Vector3(0.0, 0.0, -1.5))
	ComboDriver.strike(_player, CRIT_ROLL)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_bool(number.is_crit()).is_true()
	assert_object(number.material_override).is_same(CRIT_MATERIAL)
	assert_object(CRIT_MATERIAL.albedo_color).is_equal(Color(1, 1, 1, 1))
	assert_str(number.get_text()).ends_with(CONFIG.crit_suffix)
	assert_float(number.scale.x).is_equal_approx(CONFIG.crit_pop_scale, 0.001)
	assert_bool(number.is_over_time()).is_false()


func test_ac932_ability_and_air_slash_crits_are_white_too() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_player.basic_ability.enemy_hit.emit(enemy, 30.0, true)
	assert_object(_pool.get_last_spawned().material_override).is_same(CRIT_MATERIAL)
	assert_str(_pool.get_last_spawned().get_text()).is_equal("30" + CONFIG.crit_suffix)
	_player.air_slash.enemy_hit.emit(enemy, 12.0, true)
	assert_object(_pool.get_last_spawned().material_override).is_same(CRIT_MATERIAL)


func test_ac933_ac939_a_poison_tick_is_green_and_italic() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	enemy.debuffs.apply(POISON, 4.5)
	enemy.debuffs.advance(1.0)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_object(number.material_override).is_same(POISON.damage_number_material)
	assert_bool(number.is_crit()).is_false()
	assert_str(number.get_text()).is_equal("5")
	assert_float(number.scale.x).is_equal_approx(CONFIG.normal_scale, 0.001)
	assert_bool(number.is_over_time()).is_true()
	var italic: AABB = number.mesh.get_aabb()
	assert_float(italic.size.x).is_greater(0.0)
	_pool.spawn(5.0, false, Vector3.ZERO)
	var upright: AABB = _pool.get_last_spawned().mesh.get_aabb()
	assert_float(italic.size.x).is_not_equal(upright.size.x)


func test_ac934_burst_numbers_take_the_bar_color() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_player.afflictions.burst_hit.emit(enemy, 22.5, BURST)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_object(number.material_override).is_same(BURST.damage_number_material)
	assert_str(number.get_text()).is_equal("23")
	assert_float(number.scale.x).is_equal_approx(CONFIG.normal_scale, 0.001)
	assert_bool(number.is_over_time()).is_false()


func test_ac935_ac939_hits_stay_white_and_bleed_ticks_white_italic() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	enemy.health.setup(1000.0, 0.0)
	enemy.debuffs.apply(BLEED, 0.01)
	enemy.debuffs.advance(1.0)
	var tick: DamageNumber = _pool.get_last_spawned()
	assert_object(tick.material_override).is_same(MATERIAL)
	assert_bool(tick.is_over_time()).is_true()
	_pool.spawn(10.0, false, Vector3.ZERO)
	assert_object(_pool.get_last_spawned().material_override).is_same(MATERIAL)
	assert_bool(_pool.get_last_spawned().is_over_time()).is_false()


func test_ac937_colored_numbers_reuse_the_pool() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var children: int = _pool.get_child_count()
	for i: int in 50:
		match i % 4:
			0:
				_pool.spawn(1.0, false, Vector3.ZERO)
			1:
				_pool.spawn(2.0, true, Vector3.ZERO)
			2:
				_pool.spawn(3.0, false, Vector3.ZERO, POISON.damage_number_material, true)
			3:
				_player.afflictions.burst_hit.emit(enemy, 4.0, BURST)
	assert_int(_pool.get_child_count()).is_equal(children)
	assert_int(children).is_equal(CONFIG.pool_size)
	assert_object(MATERIAL.albedo_color).is_equal(Color(1, 1, 1, 1))


## docs/specs/affliction-name-popup.md
func test_ac951_frost_shows_its_name_in_its_color() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_player.afflictions.triggered.emit(enemy, FROST_TYPE)
	var text: DamageNumber = _pool.get_last_spawned()
	assert_str(text.get_text()).is_equal("Escarcha")
	assert_object(text.material_override).is_same(FROST_TYPE.damage_number_material)
	assert_bool(text.is_crit()).is_false()
	assert_bool(text.is_over_time()).is_false()
	assert_float(text.scale.x).is_equal_approx(CONFIG.normal_scale, 0.001)
	assert_float(text.transparency).is_equal_approx(CONFIG.normal_transparency, 0.0001)


func test_ac952_corrosion_shows_its_name_in_its_color() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_player.afflictions.triggered.emit(enemy, CORROSION_TYPE)
	var text: DamageNumber = _pool.get_last_spawned()
	assert_str(text.get_text()).is_equal("Corrosión")
	assert_object(text.material_override).is_same(CORROSION_TYPE.damage_number_material)


## affliction-name-popup.md §7: AC991 replaces AC953 (every Affliction says its name).
func test_ac991_damaging_afflictions_say_their_name_too() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	_player.afflictions.triggered.emit(enemy, POISON_TYPE)
	assert_str(_pool.get_last_spawned().get_text()).is_equal("Veneno")
	assert_object(_pool.get_last_spawned().material_override).is_same(POISON_TYPE.debuff.damage_number_material)
	_player.afflictions.triggered.emit(enemy, BURST)
	assert_str(_pool.get_last_spawned().get_text()).is_equal("Estallido")
	assert_object(_pool.get_last_spawned().material_override).is_same(BURST.damage_number_material)


func test_ac955_names_reuse_the_pool() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	var children: int = _pool.get_child_count()
	for i: int in 40:
		_player.afflictions.triggered.emit(enemy, FROST_TYPE if i % 2 == 0 else CORROSION_TYPE)
	assert_int(_pool.get_child_count()).is_equal(children)
	assert_int(_pool.active_count()).is_equal(CONFIG.pool_size)


## docs/specs/affliction-bleed.md
func test_ac965_bleeding_ticks_are_crimson_and_italic() -> void:
	var enemy: Enemy = _spawn_enemy(Vector3(0.0, 0.0, -1.5))
	enemy.health.setup(1000.0, 0.0)
	enemy.debuffs.apply(BLEEDING, 0.01)
	enemy.debuffs.advance(1.0)
	var number: DamageNumber = _pool.get_last_spawned()
	assert_object(number.material_override).is_same(BLEEDING.damage_number_material)
	assert_str(number.get_text()).is_equal("10")
	assert_bool(number.is_over_time()).is_true()
