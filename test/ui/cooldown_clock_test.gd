extends GdUnitTestSuite
## docs/specs/cooldown-clock.md: sector geometry and the ability slot clock.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SWIFT_STRIKE: AbilityData = preload("res://data/abilities/swift_strike/swift_strike.tres")
const SLOT_CONFIG: AbilitySlotViewConfig = preload("res://data/ui/ability_slot_view_config.tres")
const STEPS: int = 48
const HALF: float = 10.0
const TOLERANCE: float = 0.0001

var _player: Player


func before_test() -> void:
	Session.character_class = SAMURAI
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = registry
	add_child(_player)
	await get_tree().physics_frame


func after_test() -> void:
	Session.character_class = null


func _sector(fraction: float, shape: CooldownClock.Shape) -> PackedVector2Array:
	var points := PackedVector2Array()
	CooldownClock.build_sector(points, Vector2.ZERO, HALF, fraction, shape, STEPS)
	return points


func _has_point(points: PackedVector2Array, expected: Vector2) -> bool:
	for point: Vector2 in points:
		if point.distance_to(expected) < TOLERANCE:
			return true
	return false


func _make_slot() -> AbilitySlotView:
	var slot: AbilitySlotView = auto_free(AbilitySlotView.new())
	slot.config = SLOT_CONFIG
	var key := Label.new()
	slot.add_child(key)
	slot.key_label = key
	add_child(slot)
	slot.setup(_player.basic_ability)
	return slot


func test_ac346_circle_sector() -> void:
	assert_int(_sector(0.0, CooldownClock.Shape.CIRCLE).size()).is_equal(0)
	var quarter: PackedVector2Array = _sector(0.25, CooldownClock.Shape.CIRCLE)
	assert_vector(quarter[0]).is_equal(Vector2.ZERO)
	for point: Vector2 in quarter:
		assert_float(point.x).is_less_equal(TOLERANCE)
		assert_float(point.y).is_less_equal(TOLERANCE)
	assert_bool(_has_point(quarter, Vector2(-HALF, 0.0))).is_true()
	assert_bool(_has_point(quarter, Vector2(0.0, -HALF))).is_true()
	var full: PackedVector2Array = _sector(1.0, CooldownClock.Shape.CIRCLE)
	assert_int(full.size()).is_equal(STEPS)
	assert_bool(_has_point(full, Vector2.ZERO)).is_false()
	for point: Vector2 in full:
		assert_float(point.length()).is_equal_approx(HALF, TOLERANCE)


func test_ac347_square_sector_reaches_the_corners() -> void:
	var half_turn: PackedVector2Array = _sector(0.5, CooldownClock.Shape.SQUARE)
	assert_bool(_has_point(half_turn, Vector2(-HALF, HALF))).is_true()
	assert_bool(_has_point(half_turn, Vector2(-HALF, -HALF))).is_true()
	for point: Vector2 in half_turn:
		assert_float(point.x).is_less_equal(TOLERANCE)
	var eighth: PackedVector2Array = _sector(0.125, CooldownClock.Shape.SQUARE)
	assert_vector(eighth[1]).is_equal_approx(Vector2(-HALF, -HALF), Vector2.ONE * TOLERANCE)
	assert_vector(eighth[eighth.size() - 1]).is_equal_approx(Vector2(0.0, -HALF), Vector2.ONE * TOLERANCE)
	for i: int in range(1, eighth.size()):
		assert_float(eighth[i].y).is_equal_approx(-HALF, TOLERANCE)


func test_ac348_ability_clock_replaces_the_cooldown_ring() -> void:
	_player.basic_ability.equip(SWIFT_STRIKE)
	var slot: AbilitySlotView = _make_slot()
	slot.advance(0.0)
	assert_float(slot.get_clock_fraction()).is_equal(0.0)
	_player.basic_ability.try_cast()
	slot.advance(0.0)
	assert_float(slot.get_clock_fraction()).is_equal_approx(1.0, TOLERANCE)
	_player.basic_ability.reduce_cooldown(1.5)
	slot.advance(0.0)
	assert_float(slot.get_clock_fraction()).is_equal_approx(0.75, TOLERANCE)
	_player.basic_ability.reduce_cooldown(10.0)
	slot.advance(0.0)
	assert_float(slot.get_clock_fraction()).is_equal(0.0)
	var names: Array[String] = []
	for property: Dictionary in SLOT_CONFIG.get_property_list():
		names.append(property["name"])
	assert_array(names).not_contains(["cooldown_ring_color"])
	assert_array(names).contains(["clock"])


func test_ac348_no_clock_while_charging() -> void:
	_player.basic_ability.equip(SHEATHE)
	var slot: AbilitySlotView = _make_slot()
	_player.basic_ability.try_cast()
	slot.advance(0.0)
	assert_bool(slot.is_showing_charge()).is_true()
	assert_float(slot.get_clock_fraction()).is_equal(0.0)


func test_ac352_frame_config() -> void:
	assert_float(SLOT_CONFIG.frame_width).is_equal(3.0)
	assert_that(SLOT_CONFIG.frame_color).is_equal(Color(0.08, 0.1, 0.12, 1))


func test_ac353_charge_ring_stays_inside_the_frame() -> void:
	_player.basic_ability.equip(SHEATHE)
	var slot: AbilitySlotView = _make_slot()
	var radius: float = slot.get_radius()
	var ring_radius: float = slot.get_charge_ring_radius()
	assert_float(ring_radius).is_equal_approx(radius - SLOT_CONFIG.frame_width - SLOT_CONFIG.ring_width / 2.0, TOLERANCE)
	assert_float(ring_radius + SLOT_CONFIG.ring_width / 2.0).is_less_equal(radius - SLOT_CONFIG.frame_width + TOLERANCE)
