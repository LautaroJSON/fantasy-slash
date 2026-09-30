extends RefCounted
## Builders shared by physics-based tests. Not a test suite (no `_test` suffix).

const WORLD_LAYER: int = 1


## Static floor whose top surface is at y = 0.
static func make_floor(size: float) -> StaticBody3D:
	return make_box(Vector3(size, 1.0, size), Vector3(0.0, -0.5, 0.0))


static func make_box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = position
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body


## The arena's waves without the horde of fodder (docs/specs/fodder-minion.md):
## the run tests that count enemies or clear a wave verify the regular mix.
static func without_horde(arena: Node) -> void:
	(arena.get_node("WaveManager") as WaveManager).horde_pool = null


## The run with only the Arena stage (docs/specs/stages.md §7): the arena tests
## that check the old spawn square or a boss followed by the next wave. Call it
## before adding the arena to the tree.
static func arena_only(arena: Node) -> void:
	(arena.get_node("StageDirector") as StageDirector).sequence = load("res://test/data/arena_only_sequence.tres")
