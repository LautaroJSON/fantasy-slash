class_name ShieldGuard
extends Node
## Frontal block of the player (docs/specs/warrior-abilities-rework.md): while
## raised, a hit whose attacker stands inside the arc in front of `visual`
## loses `reduction` of its damage. Who raises it (an ability) decides the arc
## and the reduction from its own data. Grabs never reach it.

## The absorbed share of a hit, before the player's defense.
signal blocked(amount: float, attacker: Enemy)

## Node of the shield model its size pivots on (the hand holds it there).
const GRIP: NodePath = ^"Grip"

enum ShieldPop { NONE, POP, SHRINK }

## Its −Z is the front of the guard.
@export var visual: Node3D

## The class shield model, set by the Player when the class has one
## (docs/specs/parry-riposte-rework.md §2.2): an ability may make it pop
## bigger while it is raised. Purely visual: the arc and the reduction do not
## depend on it.
var shield: Node3D = null:
	set(value):
		shield = value
		_shield_rest = value.transform if value != null else Transform3D.IDENTITY
		_shield_grip = (value.get_node(GRIP) as Node3D).position if value != null and value.has_node(GRIP) else Vector3.ZERO


var _raised: bool = false
var _reduction: float = 0.0
var _arc_degrees: float = 0.0
var _shield_rest: Transform3D = Transform3D.IDENTITY
var _shield_grip: Vector3 = Vector3.ZERO
var _shield_scale: float = 1.0
var _pop: ShieldPop = ShieldPop.NONE
var _pop_elapsed: float = 0.0
var _pop_scale: float = 1.0
var _hold_scale: float = 1.0
var _pop_time: float = 0.0
var _settle_time: float = 0.0
var _shrink_time: float = 0.0
var _shrink_from: float = 1.0


func _process(delta: float) -> void:
	advance_shield(delta)


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


## The shield grows to `pop_scale` in `pop_time`, settles on `hold_scale` by
## `settle_time` and holds it until shrink_shield().
func pop_shield(pop_scale: float, hold_scale: float, pop_time: float, settle_time: float) -> void:
	_pop = ShieldPop.POP
	_pop_elapsed = 0.0
	_pop_scale = pop_scale
	_hold_scale = hold_scale
	_pop_time = pop_time
	_settle_time = settle_time
	advance_shield(0.0)


## The shield goes back to its size in `shrink_time` (nothing if it never grew).
func shrink_shield(shrink_time: float) -> void:
	if _pop != ShieldPop.POP:
		return
	_pop = ShieldPop.SHRINK
	_pop_elapsed = 0.0
	_shrink_time = shrink_time
	_shrink_from = _shield_scale
	advance_shield(0.0)


func get_shield_scale() -> float:
	return _shield_scale


## Advances the shield's size (called every frame; tests call it by hand).
func advance_shield(delta: float) -> void:
	if _pop == ShieldPop.NONE:
		return
	_pop_elapsed += delta
	if _pop == ShieldPop.POP:
		_set_shield_scale(_pop_curve(_pop_elapsed))
	elif _pop_elapsed >= _shrink_time:
		_pop = ShieldPop.NONE
		_set_shield_scale(1.0)
	else:
		_set_shield_scale(lerpf(_shrink_from, 1.0, _pop_elapsed / _shrink_time))


func _pop_curve(t: float) -> float:
	if t < _pop_time:
		return lerpf(1.0, _pop_scale, t / _pop_time)
	if t < _settle_time:
		return lerpf(_pop_scale, _hold_scale, (t - _pop_time) / (_settle_time - _pop_time))
	return _hold_scale


## Scales the shield about its Grip, so the hand keeps holding it.
func _set_shield_scale(value: float) -> void:
	_shield_scale = value
	if shield == null:
		return
	var pivot := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * value), _shield_grip - _shield_grip * value)
	shield.transform = _shield_rest * pivot
