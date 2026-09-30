extends GdUnitTestSuite
## Walking around a stage's obstacles (docs/specs/stages.md §2.5, AC1308–AC1310).

const CONFIG: ObstacleAvoidanceConfig = preload("res://data/enemies/obstacle_avoidance_config.tres")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
## A column of radius 0.75 two metres ahead of the walker.
const COLUMN := Vector3(0.0, -2.0, 0.75)
const STEP: float = 0.1
const WALK_SPEED: float = 3.0
const MAX_STEPS: int = 200


func test_ac1308_nothing_ahead_keeps_the_heading() -> void:
	var obstacles: PackedVector3Array = [Vector3(5.0, 5.0, 0.75), Vector3(0.0, 4.0, 0.75)]
	var heading: Vector3 = ObstacleSteering.steer(Vector3.ZERO, Vector3.FORWARD, obstacles, CONFIG)
	assert_vector(heading).is_equal(Vector3.FORWARD)
	assert_vector(ObstacleSteering.steer(Vector3.ZERO, Vector3.FORWARD, PackedVector3Array(), CONFIG)).is_equal(Vector3.FORWARD)


func test_ac1308_an_obstacle_ahead_bends_the_heading() -> void:
	var obstacles: PackedVector3Array = [COLUMN]
	var heading: Vector3 = ObstacleSteering.steer(Vector3(0.2, 0.0, 0.0), Vector3.FORWARD, obstacles, CONFIG)
	assert_float(heading.x).is_greater(0.0)
	assert_float(heading.length()).is_equal_approx(1.0, 0.0001)
	var mirrored: Vector3 = ObstacleSteering.steer(Vector3(-0.2, 0.0, 0.0), Vector3.FORWARD, obstacles, CONFIG)
	assert_float(mirrored.x).is_less(0.0)


## Kinematic walk towards a goal behind a column: it gets there without
## entering the column (the steering alone never traps a walker in the open).
func test_ac1309_a_walker_goes_around_a_column() -> void:
	var obstacles: PackedVector3Array = [COLUMN]
	var goal := Vector3(0.0, 0.0, -5.0)
	var position := Vector3(0.05, 0.0, 1.0)
	var arrived: bool = false
	for i: int in MAX_STEPS:
		var direction: Vector3 = (goal - position).normalized()
		position += ObstacleSteering.steer(position, direction, obstacles, CONFIG) * WALK_SPEED * STEP
		assert_float(Vector2(position.x - COLUMN.x, position.z - COLUMN.y).length()).is_greater(COLUMN.z)
		if position.distance_to(goal) < 0.5:
			arrived = true
			break
	assert_bool(arrived).is_true()


func test_ac1310_a_leap_never_lands_inside_an_obstacle() -> void:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate()) as Enemy
	add_child(enemy)
	var obstacles: PackedVector3Array = [COLUMN]
	enemy.set_obstacles(obstacles, CONFIG)
	for point: Vector3 in [Vector3(0.0, 1.0, -2.0), Vector3(0.3, 0.0, -2.2), Vector3(-0.5, 0.0, -1.6)]:
		var landing: Vector3 = enemy.clear_of_obstacles(point)
		assert_float(Vector2(landing.x - COLUMN.x, landing.z - COLUMN.y).length()).is_greater_equal(COLUMN.z + CONFIG.margin - 0.001)
		assert_float(landing.y).is_equal(point.y)
	var free_point := Vector3(4.0, 0.0, 4.0)
	assert_vector(enemy.clear_of_obstacles(free_point)).is_equal(free_point)
