class_name StageLayout
extends Resource
## Where enemies may appear in a stage (docs/specs/stages.md §2.5).

## Spawn area on the ground (X, Z), clockwise.
@export var spawn_polygon: PackedVector2Array
## A spawn farther than this from the player is rejected; 0 = no cap.
@export var max_spawn_distance: float
## Height added to the terrain at a spawn point (gravity settles the enemy).
@export var spawn_lift: float
## Clearance kept between a spawn point and an obstacle's circle.
@export var obstacle_margin: float
## Random points tried per spawn before keeping the last one.
@export var point_attempts: int


## Pure: whether `point` lies inside the spawn polygon.
func contains(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, spawn_polygon)


## Pure: bounding rectangle of the spawn polygon.
func bounds() -> Rect2:
	if spawn_polygon.is_empty():
		return Rect2()
	var rect := Rect2(spawn_polygon[0], Vector2.ZERO)
	for point: Vector2 in spawn_polygon:
		rect = rect.expand(point)
	return rect


## Pure: `point` itself when inside, else the nearest point on the polygon's edge.
func clamp_inside(point: Vector2) -> Vector2:
	if spawn_polygon.size() < 3 or contains(point):
		return point
	var best: Vector2 = spawn_polygon[0]
	var best_distance: float = INF
	for i: int in spawn_polygon.size():
		var candidate: Vector2 = Geometry2D.get_closest_point_to_segment(point, spawn_polygon[i], spawn_polygon[(i + 1) % spawn_polygon.size()])
		var distance: float = point.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
