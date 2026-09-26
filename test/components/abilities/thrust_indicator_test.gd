extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const CONFIG: AbilityIndicatorConfig = preload("res://data/abilities/thrust/thrust_indicator_config.tres")
const TOLERANCE: float = 0.01

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _indicator: AbilityRectIndicator


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_ability.equip(THRUST)
	_indicator = (_ability.get_behavior() as ThrustAbility).get_indicator()


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _upgrade_ability(stat: AbilityData.Stat, amount: float) -> void:
	var upgrade := AbilityUpgradeData.new()
	upgrade.stat = stat
	upgrade.amount = amount
	_ability.add_upgrade(upgrade)


## Horizontal offset from the indicator origin to the centre of a segment.
func _offset(edge: AbilityRectIndicator.Edge) -> Vector2:
	var segment: Vector3 = _indicator.get_segment(edge).global_position
	var origin: Vector3 = _indicator.global_position
	return Vector2(segment.x - origin.x, segment.z - origin.z)


func _assert_rect(length: float, width: float, facing: Vector2) -> void:
	var left: MeshInstance3D = _indicator.get_segment(AbilityRectIndicator.Edge.LEFT)
	var far: MeshInstance3D = _indicator.get_segment(AbilityRectIndicator.Edge.FAR)
	assert_float(left.scale.z).is_equal_approx(length, TOLERANCE)
	assert_float(far.scale.x).is_equal_approx(width + CONFIG.line_width, TOLERANCE)
	var far_offset: Vector2 = _offset(AbilityRectIndicator.Edge.FAR)
	assert_float(far_offset.length()).is_equal_approx(length, TOLERANCE)
	assert_float(far_offset.normalized().dot(facing)).is_equal_approx(1.0, TOLERANCE)
	var side_gap: float = _offset(AbilityRectIndicator.Edge.LEFT).distance_to(_offset(AbilityRectIndicator.Edge.RIGHT))
	assert_float(side_gap).is_equal_approx(width, TOLERANCE)


func test_ac61_pressing_outlines_the_hitbox_towards_the_aimed_enemy() -> void:
	_spawn_enemy(Vector3(2.0, 0.0, 0.0))
	assert_bool(_indicator.is_showing()).is_false()
	assert_bool(_ability.try_cast()).is_true()
	assert_bool(_indicator.is_showing()).is_true()
	assert_bool(_indicator.visible).is_true()
	assert_int(_indicator.get_segment_count()).is_equal(4)
	_assert_rect(THRUST.hit_range, THRUST.hit_width, Vector2(1.0, 0.0))


func test_ac62_upgrades_resize_the_outline() -> void:
	_upgrade_ability(AbilityData.Stat.HIT_RANGE, 1.0)
	_upgrade_ability(AbilityData.Stat.HIT_WIDTH, 0.4)
	_ability.try_cast()
	_assert_rect(4.5, 1.4, Vector2(0.0, -1.0))


func test_ac63_holds_while_casting_then_fades_and_hides() -> void:
	_ability.try_cast()
	_indicator.advance(THRUST.cast_duration / 2.0)
	assert_float(_indicator.get_transparency()).is_equal_approx(CONFIG.start_transparency, 0.0001)
	_ability.advance(THRUST.cast_duration)
	assert_bool(_indicator.is_showing()).is_true()
	_indicator.advance(CONFIG.fade_duration / 2.0)
	assert_float(_indicator.get_transparency()).is_greater(CONFIG.start_transparency)
	assert_float(_indicator.get_transparency()).is_less(1.0)
	_indicator.advance(CONFIG.fade_duration)
	assert_bool(_indicator.is_showing()).is_false()
	assert_bool(_indicator.visible).is_false()


func test_ac64_outline_stays_in_the_world() -> void:
	_ability.try_cast()
	var placed: Vector3 = _indicator.global_position
	_player.global_position += Vector3(3.0, 0.0, 2.0)
	assert_vector(_indicator.global_position).is_equal_approx(placed, Vector3.ONE * 0.0001)
