class_name ShieldGuard
extends Node
## Frontal block of the player (docs/specs/warrior-abilities-rework.md): while
## raised, a hit whose attacker stands inside the arc in front of `visual`
## loses `reduction` of its damage. Who raises it (an ability) decides the arc
## and the reduction from its own data. Grabs never reach it.

## The absorbed share of a hit, before the player's defense.
signal blocked(amount: float, attacker: Enemy)

## Its −Z is the front of the guard.
@export var visual: Node3D

var _raised: bool = false
var _reduction: float = 0.0
var _arc_degrees: float = 0.0


func raise(reduction: float, arc_degrees: float) -> void:
	_raised = true
	_reduction = clampf(reduction, 0.0, 1.0)
	_arc_degrees = arc_degrees


func lower() -> void:
	_raised = false


func is_raised() -> bool:
	return _raised


## Damage left of `raw` after the guard (the whole hit when lowered or when
## the attacker is not in front).
func absorb(raw: float, attacker: Enemy) -> float:
	if not _raised or attacker == null:
		return raw
	var facing: Vector3 = -visual.global_basis.z
	if not is_in_front(facing, visual.global_position, attacker.global_position, _arc_degrees):
		return raw
	var absorbed: float = raw * _reduction
	blocked.emit(absorbed, attacker)
	return raw - absorbed


## Whether `source` is within `arc_degrees` (centered on `facing`) seen from
## `origin`, on the flat XZ plane. A source on the origin counts as in front.
static func is_in_front(facing: Vector3, origin: Vector3, source: Vector3, arc_degrees: float) -> bool:
	var to_source := Vector3(source.x - origin.x, 0.0, source.z - origin.z)
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if to_source.is_zero_approx() or flat_facing.is_zero_approx():
		return true
	return rad_to_deg(flat_facing.angle_to(to_source)) <= arc_degrees * 0.5
