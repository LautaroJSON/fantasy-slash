class_name ObstacleSteering
extends RefCounted
## Pure steering around a stage's round obstacles (docs/specs/stages.md §2.5):
## a walk heading that would pass through an obstacle ahead bends sideways,
## more the closer and the more centred the obstacle is. Distance maths only.


## `direction` bent around `obstacles` ((x, z, radius) each) seen from
## `position`. Keeps the length of `direction`; unchanged when nothing is ahead.
static func steer(position: Vector3, direction: Vector3, obstacles: PackedVector3Array, config: ObstacleAvoidanceConfig) -> Vector3:
	var flat := Vector2(direction.x, direction.z)
	var length: float = flat.length()
	if obstacles.is_empty() or is_zero_approx(length):
		return direction
	var forward: Vector2 = flat / length
	var left := Vector2(-forward.y, forward.x)
	var push := Vector2.ZERO
	for obstacle: Vector3 in obstacles:
		var to_obstacle := Vector2(obstacle.x - position.x, obstacle.y - position.z)
		var ahead: float = to_obstacle.dot(forward)
		if ahead <= 0.0 or ahead > config.lookahead + obstacle.z:
			continue
		var side: float = to_obstacle.dot(left)
		var clearance: float = obstacle.z + config.margin
		if absf(side) >= clearance:
			continue
		var centred: float = 1.0 - absf(side) / clearance
		var near: float = 1.0 - clampf((ahead - obstacle.z) / config.lookahead, 0.0, 1.0)
		var away: Vector2 = -left if side > 0.0 else left
		push += away * centred * near * config.strength
	if push.is_zero_approx():
		return direction
	var bent: Vector2 = (forward + push).normalized() * length
	return Vector3(bent.x, direction.y, bent.y)
