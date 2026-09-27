extends GdUnitTestSuite
## docs/specs/affliction.md: the Affliction rows under an enemy's floating
## health bar (AfflictionBarRow).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const CONFIG: AfflictionConfig = preload("res://data/combat/affliction_config.tres")
const BAR_CONFIG: HealthBarConfig = preload("res://data/ui/enemy_health_bar_config.tres")
const POISON_BASIC: AfflictionUpgradeData = preload("res://data/afflictions/cards/poison_basic_attack.tres")
const BURST_BASIC: AfflictionUpgradeData = preload("res://data/afflictions/cards/burst_basic_attack.tres")
const FROST_ABILITY: AfflictionUpgradeData = preload("res://data/afflictions/cards/frost_ability.tres")

var _player: Player
var _enemy: Enemy


func before_test() -> void:
	Session.character_class = WARRIOR
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = registry
	add_child(_player)
	_enemy = auto_free(ENEMY_SCENE.instantiate())
	_enemy.registry = registry
	add_child(_enemy)
	_enemy.activate(Vector3(0.0, 0.0, -3.0), _player)


func after_test() -> void:
	Session.character_class = null


func _rows() -> AfflictionBarRow:
	return _enemy.affliction_bars


func test_ac883_one_empty_row_per_affliction() -> void:
	assert_int(_rows().get_visible_row_count()).is_equal(0)
	_player.apply_upgrade(POISON_BASIC)
	assert_int(_rows().get_visible_row_count()).is_equal(1)
	assert_bool(_rows().get_fill(0).visible).is_false()
	var background: MeshInstance3D = _rows().get_background(0)
	assert_float(background.position.y).is_less(-BAR_CONFIG.size.y / 2.0)
	_enemy.afflictions.add_buildup(0, 10.0)
	assert_object(_rows().get_fill(0).material_override).is_same(POISON_BASIC.affliction.bar_material)


func test_ac884_three_rows_stacked_in_order() -> void:
	_player.apply_upgrade(POISON_BASIC)
	_player.apply_upgrade(BURST_BASIC)
	_player.apply_upgrade(FROST_ABILITY)
	assert_int(_rows().get_visible_row_count()).is_equal(3)
	for slot: int in 3:
		_enemy.afflictions.add_buildup(slot, 10.0)
	var first: float = _rows().get_background(0).position.y
	for slot: int in range(1, 3):
		var gap: float = _rows().get_background(slot - 1).position.y - _rows().get_background(slot).position.y
		assert_float(gap).is_equal_approx(CONFIG.bar_height + CONFIG.bar_gap, 0.0001)
	assert_float(first).is_equal_approx(-(BAR_CONFIG.size.y / 2.0 + CONFIG.bar_gap + CONFIG.bar_height / 2.0), 0.0001)
	assert_object(_rows().get_fill(1).material_override).is_same(BURST_BASIC.affliction.bar_material)
	assert_object(_rows().get_fill(2).material_override).is_same(FROST_ABILITY.affliction.bar_material)


func test_ac885_the_fill_covers_the_ratio_from_the_left() -> void:
	_player.apply_upgrade(POISON_BASIC)
	_enemy.afflictions.add_buildup(0, 40.0)
	var fill: MeshInstance3D = _rows().get_fill(0)
	var width: float = BAR_CONFIG.size.x * 0.4
	assert_float(fill.scale.x).is_equal_approx(width, 0.0001)
	assert_float(fill.position.x - width / 2.0).is_equal_approx(-BAR_CONFIG.size.x / 2.0, 0.0001)


func test_ac886_a_triggering_row_flashes_full_then_empties() -> void:
	_player.apply_upgrade(POISON_BASIC)
	_enemy.afflictions.add_buildup(0, 100.0)
	var fill: MeshInstance3D = _rows().get_fill(0)
	assert_object(fill.material_override).is_same(CONFIG.flash_material)
	assert_float(fill.scale.x).is_equal_approx(BAR_CONFIG.size.x, 0.0001)
	_enemy.afflictions.advance(CONFIG.flash_duration + 0.01)
	assert_bool(fill.visible).is_false()
	_enemy.afflictions.add_buildup(0, 10.0)
	assert_object(fill.material_override).is_same(POISON_BASIC.affliction.bar_material)


func test_ac887_rows_follow_the_health_bar_visibility() -> void:
	_player.apply_upgrade(POISON_BASIC)
	assert_bool(_rows().is_visible_in_tree()).is_false()
	_enemy.health.receive_hit(1.0)
	assert_bool(_rows().is_visible_in_tree()).is_true()
	_enemy.health_bar.set_suppressed(true)
	assert_bool(_rows().is_visible_in_tree()).is_false()
