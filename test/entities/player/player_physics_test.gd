extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")

var _player: Player


func before_test() -> void:
	_add_static(TestWorld.make_floor(60.0))
	_player = auto_free(PLAYER_SCENE.instantiate())
	add_child(_player)


func _add_static(body: StaticBody3D) -> void:
	auto_free(body)
	add_child(body)


func after_test() -> void:
	Input.action_release(&"move_forward")


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_ac17_jump_from_the_floor_uses_jump_velocity() -> void:
	await _physics_frames(20)
	assert_bool(_player.is_on_floor()).is_true()
	var movement: MovementComponent = _player.get_node("MovementComponent") as MovementComponent
	movement.jump()
	assert_float(_player.velocity.y).is_equal_approx(PLAYER_STATS.jump_velocity, 0.0001)


func test_ac17_jump_in_the_air_does_nothing() -> void:
	await _physics_frames(20)
	var movement: MovementComponent = _player.get_node("MovementComponent") as MovementComponent
	movement.jump()
	await _physics_frames(5)
	assert_bool(_player.is_on_floor()).is_false()
	var vertical_before: float = _player.velocity.y
	movement.jump()
	assert_float(_player.velocity.y).is_equal_approx(vertical_before, 0.0001)


func test_ac18_player_falling_from_height_lands_within_two_seconds() -> void:
	_player.global_position = Vector3(0.0, 5.0, 0.0)
	await _physics_frames(120)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.global_position.y).is_equal_approx(0.0, 0.05)


func test_ac18_player_cannot_cross_a_wall() -> void:
	_add_static(TestWorld.make_box(Vector3(10.0, 3.0, 1.0), Vector3(0.0, 1.5, -3.0)))
	await _physics_frames(20)
	Input.action_press(&"move_forward")
	await _physics_frames(120)
	# Wall inner face is at z = -2.5 and the capsule radius is 0.4.
	assert_float(_player.global_position.z).is_greater(-2.5)
