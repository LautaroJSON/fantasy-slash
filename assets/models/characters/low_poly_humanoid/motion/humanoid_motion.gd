class_name HumanoidMotion
extends RefCounted
## Procedural layer on top of the AnimationPlayer (poc/samurai-motion). Runs
## every frame right after the clips are applied:
## 1. springs: chosen joints lag behind their animated rotation and settle
##    with a little overshoot (secondary motion);
## 2. grip: during a clip with a SlashArc, the right wrist is placed so the
##    weapon's grip rides a true circular arc with the edge leading and the
##    tip whipping behind at speed (the arms are invisible, so only the hand
##    and the blade are seen);
## 3. feet: a foot inside a plant window stays on its floor spot while the
##    body lunges, then steps back into its pose.

const FOOT_KEYS: Array[String] = ["l", "r"]
const LAG_PROBE: float = 0.008
const SPRING_STEP: float = 1.0 / 120.0

var setup: HumanoidMotionSetup:
	set(value):
		setup = value
		_rebuild_springs()

var _h: LowPolyHumanoid
var _shoulder: Node3D
var _wrist: Node3D

var _spring_joints: Array[Node3D] = []
var _spring_params: Array[Vector2] = []
var _spring_rot: Array[Quaternion] = []
var _spring_vel: Array[Vector3] = []
var _springs_primed: bool = false

var _has_weapon_frame: bool = false
var _weapon_frame: Basis = Basis.IDENTITY
var _grip_origin: Vector3 = Vector3.ZERO
var _last_clip: StringName = &""
var _last_time: float = 0.0
var _last_out: Transform3D = Transform3D.IDENTITY
var _last_driven: bool = false
var _switch_from: Transform3D = Transform3D.IDENTITY
var _switch_left: float = 0.0

var _feet: Array[MeshInstance3D] = []
var _foot_rest: Array[Transform3D] = []
var _anchored: Array[bool] = [false, false]
var _anchor: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _step_left: Array[float] = [0.0, 0.0]
var _step_from: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]


func _init(humanoid: LowPolyHumanoid, feet: Array[MeshInstance3D]) -> void:
	_h = humanoid
	_shoulder = humanoid.get_joint("shoulder_r")
	_wrist = humanoid.get_joint("wrist_r")
	_feet = feet
	for foot: MeshInstance3D in feet:
		_foot_rest.append(foot.transform)


## Blade and edge directions and the grip offset, in the right wrist's frame.
func set_weapon_frame(blade: Vector3, edge: Vector3, grip_origin: Vector3) -> void:
	_weapon_frame = _frame(blade, edge)
	_grip_origin = grip_origin
	_has_weapon_frame = true


func apply(delta: float) -> void:
	if setup == null:
		return
	var playing: bool = _h.anim.is_playing() and _h.anim.current_animation != &""
	var clip: StringName = _h.anim.current_animation if playing else &""
	var t: float = _h.anim.current_animation_position if playing else 0.0
	_apply_springs(delta)
	_apply_grip(clip, t, delta)
	_apply_feet(clip, t, delta)
	_last_clip = clip
	_last_time = t


# ---------------------------------------------------------------- SPRINGS

func _rebuild_springs() -> void:
	_spring_joints.clear()
	_spring_params.clear()
	_spring_rot.clear()
	_spring_vel.clear()
	_springs_primed = false
	if setup == null:
		return
	for key: String in setup.springs:
		var joint: Node3D = _h.get_joint(key)
		if joint == null:
			continue
		_spring_joints.append(joint)
		_spring_params.append(setup.springs[key])
		_spring_rot.append(Quaternion.IDENTITY)
		_spring_vel.append(Vector3.ZERO)


func _apply_springs(delta: float) -> void:
	for i: int in _spring_joints.size():
		var target: Quaternion = _spring_joints[i].quaternion
		if not _springs_primed:
			_spring_rot[i] = target
			_spring_vel[i] = Vector3.ZERO
			continue
		var steps: int = maxi(ceili(minf(delta, 0.1) / SPRING_STEP), 1)
		var dt: float = minf(delta, 0.1) / steps
		for s: int in steps:
			_step_spring(i, target, dt)
		_spring_joints[i].quaternion = _spring_rot[i]
	_springs_primed = true


func _step_spring(i: int, target: Quaternion, dt: float) -> void:
	var q: Quaternion = _spring_rot[i]
	var err: Quaternion = target * q.inverse()
	if err.w < 0.0:
		err = -err
	var angle: float = err.get_angle()
	var pull: Vector3 = err.get_axis() * angle if angle > 0.00001 else Vector3.ZERO
	var omega: float = TAU * _spring_params[i].x
	var v: Vector3 = _spring_vel[i] + (pull * omega * omega - _spring_vel[i] * 2.0 * _spring_params[i].y * omega) * dt
	var speed: float = v.length()
	if speed > 0.000001:
		q = (Quaternion(v / speed, speed * dt) * q).normalized()
	var lag: float = q.angle_to(target)
	if lag > setup.spring_max_angle:
		q = target.slerp(q, setup.spring_max_angle / lag)
	_spring_rot[i] = q
	_spring_vel[i] = v


# ---------------------------------------------------------------- GRIP

func _apply_grip(clip: StringName, t: float, delta: float) -> void:
	var root: Transform3D = _h.global_transform.orthonormalized()
	var root_inv: Transform3D = root.affine_inverse()
	var animated: Transform3D = root_inv * _wrist.global_transform.orthonormalized()
	var desired: Transform3D = animated
	var weight: float = 0.0
	var arc: SlashArc = setup.arcs.get(clip) as SlashArc
	if arc != null and _has_weapon_frame:
		weight = arc.weight_at(t)
		if weight > 0.0:
			desired = animated.interpolate_with(_arc_pose(arc, t, root_inv), weight)
	var restarted: bool = clip != _last_clip or t < _last_time - 0.0001
	if restarted and (_last_driven or _switch_left > 0.0):
		_switch_from = _last_out
		_switch_left = setup.switch_blend
	var out: Transform3D = desired
	if _switch_left > 0.0:
		_switch_left = maxf(_switch_left - delta, 0.0)
		var s: float = 1.0 - _switch_left / setup.switch_blend
		out = _switch_from.interpolate_with(desired, smoothstep(0.0, 1.0, s))
	var driven: bool = weight > 0.0 or _switch_left > 0.0
	if driven:
		var scale: Vector3 = _wrist.global_basis.get_scale()
		var world: Transform3D = root * out
		_wrist.global_transform = Transform3D(world.basis.scaled(scale), world.origin)
	_last_out = out
	_last_driven = driven


## Wrist pose (root space) that puts the grip on `arc` at clip time `t`.
func _arc_pose(arc: SlashArc, t: float, root_inv: Transform3D) -> Transform3D:
	var center: Vector3 = root_inv * _shoulder.global_position + arc.center_offset
	var f: float = arc.progress_at(t)
	var dir: Vector3 = arc.direction_at(f)
	var rate: float = (f - arc.progress_at(t - LAG_PROBE)) / LAG_PROBE * arc.angle_rate_at(f)
	var lag: float = clampf(rate * arc.tip_lag, -arc.max_lag, arc.max_lag)
	var blade: Vector3 = dir.rotated(arc.axis, -lag)
	if arc.blade_lift != 0.0:
		blade = blade.rotated(blade.cross(arc.axis).normalized(), arc.blade_lift)
	var edge: Vector3 = arc.axis.cross(blade) * setup.edge_sign
	var basis: Basis = _frame(blade, edge) * _weapon_frame.inverse()
	var grip_point: Vector3 = center + dir * arc.radius
	return Transform3D(basis, grip_point - basis * _grip_origin)


static func _frame(forward: Vector3, side: Vector3) -> Basis:
	var x: Vector3 = forward.normalized()
	var y: Vector3 = (side - x * x.dot(side)).normalized()
	return Basis(x, y, x.cross(y))


# ---------------------------------------------------------------- FEET

func _apply_feet(clip: StringName, t: float, delta: float) -> void:
	var windows: Array = setup.plants.get(clip, [])
	for i: int in _feet.size():
		var mesh: MeshInstance3D = _feet[i]
		mesh.transform = _foot_rest[i]
		var animated: Transform3D = mesh.global_transform
		var planted: bool = _in_window(windows, FOOT_KEYS[i], t)
		if planted and not _anchored[i] and _step_left[i] <= 0.0:
			_anchored[i] = true
			_anchor[i] = animated
		if _anchored[i]:
			var stretched: bool = animated.origin.distance_to(_anchor[i].origin) > setup.plant_max_stretch
			if planted and not stretched:
				mesh.global_transform = _anchor[i]
				continue
			_anchored[i] = false
			_step_left[i] = setup.plant_step_time
			_step_from[i] = _anchor[i]
		if _step_left[i] > 0.0:
			_step_left[i] = maxf(_step_left[i] - delta, 0.0)
			var s: float = 1.0 - _step_left[i] / setup.plant_step_time
			var step: Transform3D = _step_from[i].interpolate_with(animated, smoothstep(0.0, 1.0, s))
			step.origin.y += sin(PI * s) * setup.plant_step_height
			mesh.global_transform = step


static func _in_window(windows: Array, foot: String, t: float) -> bool:
	for w: Array in windows:
		if w[0] == foot and t >= w[1] and t <= w[2]:
			return true
	return false
