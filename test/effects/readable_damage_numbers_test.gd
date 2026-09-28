extends GdUnitTestSuite
## Damage numbers stay in frame next to tall bosses
## (docs/specs/readable-damage-numbers.md, AC997–AC1004 and AC1015–AC1016;
## AC996 lives in boss_body_test.gd, where it replaces AC150).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const GRUNT_STATS: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const TITAN_STATS: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const CONFIG: DamageNumberConfig = preload("res://data/ui/damage_number_config.tres")
const MATERIAL: StandardMaterial3D = preload("res://materials/damage_number_material.tres")
const CRIT_MATERIAL: StandardMaterial3D = preload("res://materials/damage_number_crit_material.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
## An ability without the hit impact (the thrust, removed by warrior-abilities-rework.md).
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const POISON: DebuffData = preload("res://data/debuffs/poison.tres")
const BURST: AfflictionData = preload("res://data/afflictions/burst.tres")
const FROST: AfflictionData = preload("res://data/afflictions/frost.tres")
const NUMBER_MATERIALS: Array[String] = [
	"res://materials/damage_number_material.tres",
	"res://materials/damage_number_crit_material.tres",
	"res://materials/afflictions/bleeding_damage_number_material.tres",
	"res://materials/afflictions/burst_damage_number_material.tres",
	"res://materials/afflictions/corrosion_damage_number_material.tres",
	"res://materials/afflictions/frost_damage_number_material.tres",
	"res://materials/afflictions/poison_damage_number_material.tres",
]
const TOLERANCE: float = 0.001

var _registry: EnemyRegistry
var _player: Player
var _pool: DamageNumberPool
var _camera: Camera3D


func before_test() -> void:
	Session.character_class = SAMURAI
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_player.basic_ability.set_physics_process(false)
	_pool = auto_free(DamageNumberPool.new())
	_pool.player = _player
	_pool.config = CONFIG
	_pool.material = MATERIAL
	_pool.crit_material = CRIT_MATERIAL
	_pool.registry = _registry
	add_child(_pool)
	_camera = auto_free(Camera3D.new())
	add_child(_camera)
	_camera.global_position = Vector3(0.0, 3.0, 6.0)
	_camera.make_current()


func after_test() -> void:
	Session.character_class = null


func _spawn(stats: EnemyStats, at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	enemy.set_physics_process(false)
	return enemy


func _contact(enemy: Enemy) -> Vector3:
	return _player.hit_impact_vfx.contact_point(enemy) + Vector3.UP * CONFIG.contact_rise


## Every check starts the fan at its center, so the number has no offset.
func _restart_fan() -> void:
	_pool.set("_fan_index", 0)


func _last_position() -> Vector3:
	return _pool.get_last_spawned().global_position


func test_ac997_blade_abilities_use_the_contact_point_and_the_rest_the_anchor() -> void:
	var titan: Enemy = _spawn(TITAN_STATS, Vector3(0.0, 0.0, -3.0))
	_player.basic_ability.equip(SHEATHE)
	_restart_fan()
	_player.basic_ability.report_hit(titan, 10.0, false)
	assert_vector(_last_position()).is_equal_approx(_contact(titan), Vector3.ONE * TOLERANCE)
	var without_impact: AbilityData = PARRY.duplicate() as AbilityData
	without_impact.shows_hit_impact = false
	_player.basic_ability.equip(without_impact)
	_restart_fan()
	_player.basic_ability.report_hit(titan, 10.0, false)
	assert_vector(_last_position()).is_equal_approx(_pool.anchor_spawn_point(titan), Vector3.ONE * TOLERANCE)
	_restart_fan()
	_player.air_slash.enemy_hit.emit(titan, 10.0, false)
	assert_vector(_last_position()).is_equal_approx(_pool.anchor_spawn_point(titan), Vector3.ONE * TOLERANCE)


func test_ac998_the_anchor_is_the_head_capped_at_anchor_max_height() -> void:
	var grunt: Enemy = _spawn(GRUNT_STATS, Vector3(-3.0, 0.0, -3.0))
	var titan: Enemy = _spawn(TITAN_STATS, Vector3(3.0, 0.0, -6.0))
	var grunt_head: Vector3 = grunt.global_position + Vector3.UP * CONFIG.spawn_height * GRUNT_STATS.body_scale
	var titan_cap: Vector3 = titan.global_position + Vector3.UP * CONFIG.anchor_max_height
	assert_float(CONFIG.spawn_height * GRUNT_STATS.body_scale).is_less(CONFIG.anchor_max_height)
	assert_vector(_pool.anchor_spawn_point(grunt)).is_equal_approx(grunt_head, Vector3.ONE * TOLERANCE)
	assert_vector(_pool.anchor_spawn_point(titan)).is_equal_approx(titan_cap, Vector3.ONE * TOLERANCE)


## Addendum: Affliction names moved to chest height (AC1015).
func test_ac999_status_ticks_and_bursts_use_the_anchor() -> void:
	var titan: Enemy = _spawn(TITAN_STATS, Vector3(0.0, 0.0, -3.0))
	var anchor: Vector3 = _pool.anchor_spawn_point(titan)
	_restart_fan()
	_registry.enemy_debuff_ticked.emit(titan, 3.0, POISON)
	assert_vector(_last_position()).is_equal_approx(anchor, Vector3.ONE * TOLERANCE)
	_restart_fan()
	_player.afflictions.burst_hit.emit(titan, 20.0, BURST)
	assert_vector(_last_position()).is_equal_approx(anchor, Vector3.ONE * TOLERANCE)


func test_ac1000_consecutive_numbers_fan_out_to_both_sides() -> void:
	var slots: Array[int] = []
	for index: int in 6:
		slots.append(DamageNumberPool.fan_slot(index, 5))
	assert_array(slots).is_equal([0, 1, -1, 2, -2, 0])
	var grunt: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -3.0))
	var anchor: Vector3 = _pool.anchor_spawn_point(grunt)
	var right: Vector3 = _camera.global_basis.x
	for expected_slot: int in [0, 1, -1, 2, -2, 0]:
		_player.air_slash.enemy_hit.emit(grunt, 5.0, false)
		var expected: Vector3 = anchor + right * (expected_slot * CONFIG.fan_step) + Vector3.UP * (absi(expected_slot) * CONFIG.fan_rise_step)
		assert_vector(_last_position()).is_equal_approx(expected, Vector3.ONE * TOLERANCE)


func test_ac1001_the_fan_follows_the_camera_right_on_the_ground_plane() -> void:
	_camera.global_basis = Basis(Vector3.UP, deg_to_rad(90.0)) * Basis(Vector3.RIGHT, deg_to_rad(-30.0))
	var grunt: Enemy = _spawn(GRUNT_STATS, Vector3(0.0, 0.0, -3.0))
	var anchor: Vector3 = _pool.anchor_spawn_point(grunt)
	_restart_fan()
	_player.air_slash.enemy_hit.emit(grunt, 5.0, false)
	_player.air_slash.enemy_hit.emit(grunt, 5.0, false)
	var sideways: Vector3 = _last_position() - anchor - Vector3.UP * CONFIG.fan_rise_step
	var right := Vector3(_camera.global_basis.x.x, 0.0, _camera.global_basis.x.z).normalized()
	assert_vector(sideways).is_equal_approx(right * CONFIG.fan_step, Vector3.ONE * TOLERANCE)
	assert_float(sideways.y).is_equal_approx(0.0, TOLERANCE)


func test_ac1002_every_number_material_keeps_a_fixed_screen_size() -> void:
	for path: String in NUMBER_MATERIALS:
		var material: StandardMaterial3D = load(path)
		assert_bool(material.fixed_size).override_failure_message(path).is_true()
		assert_bool(material.no_depth_test).override_failure_message(path).is_true()
		assert_int(material.billboard_mode).override_failure_message(path).is_equal(BaseMaterial3D.BILLBOARD_ENABLED)


func test_ac1004_the_config_drops_spread_and_sets_the_new_fields() -> void:
	var names: Array[String] = []
	for property: Dictionary in CONFIG.get_property_list():
		names.append(String(property.name))
	assert_array(names).not_contains(["spread"])
	for field: String in ["anchor_max_height", "contact_rise", "fan_step", "fan_slots", "fan_rise_step"]:
		assert_float(float(CONFIG.get(field))).override_failure_message(field).is_greater(0.0)


func test_ac1015_affliction_names_sit_at_chest_height() -> void:
	var grunt: Enemy = _spawn(GRUNT_STATS, Vector3(-3.0, 0.0, -3.0))
	var titan: Enemy = _spawn(TITAN_STATS, Vector3(3.0, 0.0, -6.0))
	var grunt_chest: Vector3 = grunt.global_position + Vector3.UP * CONFIG.name_height * GRUNT_STATS.body_scale
	var titan_chest: Vector3 = titan.global_position + Vector3.UP * CONFIG.name_max_height
	_restart_fan()
	_player.afflictions.triggered.emit(grunt, FROST)
	assert_str(_pool.get_last_spawned().get_text()).is_equal(FROST.title)
	assert_vector(_last_position()).is_equal_approx(grunt_chest, Vector3.ONE * TOLERANCE)
	_restart_fan()
	_player.afflictions.triggered.emit(titan, FROST)
	assert_vector(_last_position()).is_equal_approx(titan_chest, Vector3.ONE * TOLERANCE)
	_restart_fan()
	_registry.enemy_debuff_ticked.emit(titan, 3.0, POISON)
	assert_vector(_last_position()).is_equal_approx(_pool.anchor_spawn_point(titan), Vector3.ONE * TOLERANCE)


func test_ac1016_names_sit_below_the_anchor_cap() -> void:
	assert_float(CONFIG.name_height).is_greater(0.0)
	assert_float(CONFIG.name_max_height).is_greater(0.0)
	assert_float(CONFIG.name_max_height).is_less(CONFIG.anchor_max_height)
