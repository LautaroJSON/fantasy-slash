class_name StageMap
extends Node3D
## Adapter scene of a map (docs/specs/stages.md §2.2): the rest of the game
## talks to the StageMap, never to its terrain, props or lights.

@export var player_start: Marker3D
@export var portal_point: Marker3D
## Terrain collision holding a HeightMapShape3D (1 m between samples); flat
## stages leave it empty and stand on y = 0.
@export var terrain_shape: CollisionShape3D

var _data: StageData
## (x, z, radius) of every StageObstacle, gathered once in _ready.
var _obstacles: PackedVector3Array = []


func _ready() -> void:
	_collect_obstacles(self)


## Called by the StageDirector right after instancing the stage.
func setup(data: StageData) -> void:
	_data = data


func get_data() -> StageData:
	return _data


func get_player_start() -> Transform3D:
	return player_start.global_transform


func get_portal_transform() -> Transform3D:
	return portal_point.global_transform


## Height of the ground at (x, z): the terrain's height map, bilinear between
## samples (flat stages stand on y = 0).
func height_at(x: float, z: float) -> float:
	if terrain_shape == null:
		return 0.0
	var heights: HeightMapShape3D = terrain_shape.shape as HeightMapShape3D
	var local: Vector3 = terrain_shape.global_transform.affine_inverse() * Vector3(x, 0.0, z)
	var fx: float = clampf(local.x + (heights.map_width - 1) * 0.5, 0.0, heights.map_width - 1.0)
	var fz: float = clampf(local.z + (heights.map_depth - 1) * 0.5, 0.0, heights.map_depth - 1.0)
	var ix: int = mini(floori(fx), heights.map_width - 2)
	var iz: int = mini(floori(fz), heights.map_depth - 2)
	var tx: float = fx - ix
	var tz: float = fz - iz
	var data: PackedFloat32Array = heights.map_data
	var row: int = heights.map_width
	var top: float = lerpf(data[iz * row + ix], data[iz * row + ix + 1], tx)
	var bottom: float = lerpf(data[(iz + 1) * row + ix], data[(iz + 1) * row + ix + 1], tx)
	return terrain_shape.global_position.y + lerpf(top, bottom, tz)


## (x, z, radius) of the obstacles; the array is shared, do not modify it.
func get_obstacles() -> PackedVector3Array:
	return _obstacles


## Whether `point` (x, z) falls inside an obstacle grown by `margin`.
func is_blocked(point: Vector2, margin: float) -> bool:
	for obstacle: Vector3 in _obstacles:
		if point.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z + margin:
			return true
	return false


## Random point of the spawn polygon, outside the obstacles, on the ground plus
## the layout's lift. The x draw comes before the z draw (same order as the
## old spawn square, so the Arena keeps its spawns).
func random_spawn_point(rng: RandomNumberGenerator) -> Vector3:
	var layout: StageLayout = _data.layout
	var rect: Rect2 = layout.bounds()
	var point := Vector2.ZERO
	for attempt: int in maxi(layout.point_attempts, 1):
		point = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if layout.contains(point) and not is_blocked(point, layout.obstacle_margin):
			return _on_ground(point)
	return clamp_inside(_on_ground(point))


## `point` moved inside the spawn polygon and out of the obstacles; y is kept.
func clamp_inside(point: Vector3) -> Vector3:
	var layout: StageLayout = _data.layout
	var flat: Vector2 = layout.clamp_inside(Vector2(point.x, point.z))
	for obstacle: Vector3 in _obstacles:
		var center := Vector2(obstacle.x, obstacle.y)
		var reach: float = obstacle.z + layout.obstacle_margin
		var offset: Vector2 = flat - center
		if offset.length() < reach:
			flat = center + (offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT) * reach
	return Vector3(flat.x, point.y, flat.y)


func _on_ground(point: Vector2) -> Vector3:
	return Vector3(point.x, height_at(point.x, point.y) + _data.layout.spawn_lift, point.y)


func _collect_obstacles(node: Node) -> void:
	for child: Node in node.get_children():
		if child is StageObstacle:
			var obstacle: StageObstacle = child as StageObstacle
			_obstacles.append(Vector3(obstacle.global_position.x, obstacle.global_position.z, obstacle.radius))
		_collect_obstacles(child)
