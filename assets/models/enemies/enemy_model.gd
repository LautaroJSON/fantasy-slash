class_name EnemyModel
extends Node3D
## Base of the own model of an enemy type (docs/specs/enemy-models.md). A subclass
## builds, ONCE per type, its meshes, materials and clip libraries (`Shared`, kept
## in a static cache and shared by every pooled instance) and, per instance, only
## hangs those meshes on a tree of joints:
##
##   Flinch (Node3D)           pivot of the hit reaction
##   └─ Hips (Node3D)          hips and pivot of the whole body
##      └─ Torso, Head and the joints of the type
##   Motion (AnimationPlayer)  body clips
##   Overlay (AnimationPlayer) only the hit reaction, on Flinch
##   Fx (Node3D)               particle emitters
##
## The behaviors never talk to it: `Enemy` connects the signals of `EnemyHands`
## (windup, strike, pose, rest) to on_windup, on_strike, on_pose and on_rest.
## The model is only visual: no gameplay value depends on it.

## What a type builds once and every instance reuses.
class Shared extends RefCounted:
	var meshes: Dictionary[StringName, Mesh] = {}
	var materials: Dictionary[StringName, Material] = {}
	var motion: AnimationLibrary
	var overlay: AnimationLibrary
	var hand_left: Mesh
	var hand_right: Mesh
	var triangles: int = 0

const JOINT_FLINCH: StringName = &"Flinch"
const JOINT_HIPS: StringName = &"Hips"
const JOINT_TORSO: StringName = &"Torso"
const JOINT_HEAD: StringName = &"Head"
const CLIP_IDLE: StringName = &"idle"
const CLIP_WALK: StringName = &"walk"
const CLIP_WINDUP: StringName = &"windup"
const CLIP_STRIKE: StringName = &"strike"
const CLIP_RECOVER: StringName = &"recover"
const CLIP_HIT: StringName = &"hit"
const STRAFE_LEFT: StringName = &"strafe_l"
const STRAFE_RIGHT: StringName = &"strafe_r"
const MATERIAL_BODY: StringName = &"body"
const MATERIAL_GLOW_ON: StringName = &"glow_on"
const MATERIAL_GLOW_OFF: StringName = &"glow_off"
const MOTION_LIBRARY: StringName = &""
## Seconds a clip takes to blend into the previous pose.
const ACTION_BLEND: float = 0.08
const LOCOMOTION_BLEND: float = 0.15
## Below this speed (m/s) the model stands still.
const STILL_SPEED: float = 0.1
const EMIT_THRESHOLD: float = 0.5

## Shared data of every type, built the first time one instance of it loads.
static var _shared_by_type: Dictionary[StringName, Shared] = {}

## Speed (m/s) at which the `walk` clip plays at its nominal speed (a measure of the asset).
@export var walk_reference_speed: float = 3.0
## Seconds the `recover` clip takes (Enemy sets it from EnemyHandsConfig.return_time).
var recover_seconds: float = 0.25
## Animated by the clips (see EnemyClipKit): the emitters switch on above EMIT_THRESHOLD.
var emit_0: float = 0.0:
	set = _set_emit_0
var emit_1: float = 0.0:
	set = _set_emit_1

var _shared: Shared
var _joints: Dictionary[StringName, Node3D] = {}
var _motion: AnimationPlayer
var _overlay: AnimationPlayer
var _fx: Node3D
var _emitters: Array[CPUParticles3D] = []
var _glow_parts: Array[MeshInstance3D] = []
var _flinch: Node3D
## A windup, strike or pose is playing: locomotion waits for the `recover` clip.
var _in_action: bool = false
var _locomotion_clip: StringName = &""
## Speed of the clip that plays (length / seconds asked) and of real time (hit lag, slows).
var _clip_speed: float = 1.0
var _time_scale: float = 1.0


func _ready() -> void:
	_shared = get_shared(_type_id(), self)
	_build_tree(_shared)
	_add_players(_shared)
	_flinch = _joints[JOINT_FLINCH]
	_motion.animation_finished.connect(_on_motion_finished)
	reset()


## Shared data of the type `id`, built by `builder` the first time.
static func get_shared(id: StringName, builder: EnemyModel) -> Shared:
	if not _shared_by_type.has(id):
		var shared := Shared.new()
		builder._build_shared(shared)
		_shared_by_type[id] = shared
	return _shared_by_type[id]


# --- To override --------------------------------------------------------------

## Whether the glow points light up with the windup (the Escudero lights its
## interior only when the guard is down).
func _alerts_on_windup() -> bool:
	return true


## Whether the glow points are lit while `pose` is held (they keep their state by default).
func _alert_for_pose(_pose: StringName) -> bool:
	return is_alert()


## Unique id of the type (keys the shared cache).
func _type_id() -> StringName:
	return &""


## Fills meshes, materials, hand meshes and both clip libraries. Runs once per type.
func _build_shared(_shared_data: Shared) -> void:
	pass


## Hangs the shared meshes on the joint tree: Flinch → Hips → … and the Fx node.
func _build_tree(_shared_data: Shared) -> void:
	pass


# --- Public interface ---------------------------------------------------------

## Plays `clip` stretched to last `seconds` (speed = length / seconds).
func play(clip: StringName, blend: float, seconds: float) -> void:
	if not has_clip(clip):
		return
	var length: float = _motion.get_animation(clip).length
	_clip_speed = length / seconds if seconds > 0.0 else 1.0
	_apply_speed()
	_motion.play(clip, blend)


func has_clip(clip_name: StringName) -> bool:
	return _motion != null and _motion.has_animation(clip_name)


## Moves like the enemy: `idle` when still, `walk` going forward (its speed
## follows the real one), `strafe_l` / `strafe_r` when the sideways part
## dominates and the model has them. `local_velocity` is in the enemy's space
## (−Z is forward). Ignored while an action plays.
func set_locomotion(local_velocity: Vector3) -> void:
	if _in_action:
		return
	var flat := Vector2(local_velocity.x, local_velocity.z)
	var speed: float = flat.length()
	if speed < STILL_SPEED:
		_loop_clip(CLIP_IDLE, 1.0)
		return
	var clip: StringName = CLIP_WALK
	if absf(flat.x) > absf(flat.y):
		var strafe: StringName = STRAFE_LEFT if flat.x < 0.0 else STRAFE_RIGHT
		if has_clip(strafe):
			clip = strafe
	_loop_clip(clip, speed / walk_reference_speed)


func on_windup(clip: StringName, duration: float) -> void:
	_in_action = true
	if _alerts_on_windup():
		set_alert(true)
	play(_resolve_clip(clip, CLIP_WINDUP), ACTION_BLEND, duration)


func on_strike(clip: StringName, duration: float) -> void:
	_in_action = true
	play(_resolve_clip(clip, CLIP_STRIKE), ACTION_BLEND, duration)


## A held pose (`stunned`, `airborne`, `guard_down`, `transition`, `exposed`).
func on_pose(pose: StringName, duration: float) -> void:
	_in_action = true
	set_alert(_alert_for_pose(pose))
	play(pose, ACTION_BLEND, duration)


## The hands go back to rest: the body recovers and then walks again.
func on_rest() -> void:
	if not _in_action:
		return
	set_alert(false)
	play(CLIP_RECOVER, ACTION_BLEND, recover_seconds)


## The hit reaction: a short shake of `Flinch` that never interrupts the body clip.
func on_hit() -> void:
	if _overlay.has_animation(CLIP_HIT):
		_overlay.play(CLIP_HIT, 0.0)


## A boss entered `phase` (1 or 2). Bosses with a phase-dependent look override it.
func on_phase(_phase: int) -> void:
	pass


## Emitter switches animated by the clips (1 = on): the first and second emitter of the model.
## Nothing else turns an emitter on.
func _set_emit_0(level: float) -> void:
	emit_0 = level
	_apply_emit(0, level)


func _set_emit_1(level: float) -> void:
	emit_1 = level
	_apply_emit(1, level)


func _apply_emit(index: int, level: float) -> void:
	if index < _emitters.size():
		_emitters[index].emitting = level > EMIT_THRESHOLD


## Lights or turns off the glow points (a danger cue that is on during the windup).
func set_alert(on: bool) -> void:
	var material: Material = _shared.materials.get(MATERIAL_GLOW_ON if on else MATERIAL_GLOW_OFF)
	for part: MeshInstance3D in _glow_parts:
		part.material_override = material


func is_alert() -> bool:
	return not _glow_parts.is_empty() and _glow_parts[0].material_override == _shared.materials.get(MATERIAL_GLOW_ON)


## Speed of the clips relative to real time (hit lag, slows and time dilation).
func set_time_scale(new_scale: float) -> void:
	_time_scale = new_scale
	_apply_speed()


## Back to the initial state: idle, glow off, emitters off, `Flinch` at identity.
func reset() -> void:
	_in_action = false
	_clip_speed = 1.0
	_time_scale = 1.0
	_apply_speed()
	_overlay.stop()
	_flinch.rotation = Vector3.ZERO
	_flinch.scale = Vector3.ONE
	emit_0 = 0.0
	emit_1 = 0.0
	for emitter: CPUParticles3D in _emitters:
		emitter.emitting = false
	set_alert(false)
	on_phase(1)
	_motion.play(CLIP_IDLE, 0.0)
	_motion.seek(0.0, true)
	_locomotion_clip = CLIP_IDLE


func get_hand_mesh(left: bool) -> Mesh:
	return _shared.hand_left if left else _shared.hand_right


func get_hand_material() -> Material:
	return _shared.materials[MATERIAL_BODY]


## The hands of the enemy that wears the model (a model may dress them up, e.g. a glow on
## a blade). The base does nothing.
func bind_hands(_hands: EnemyHands) -> void:
	pass


func get_joint(joint_name: StringName) -> Node3D:
	return _joints.get(joint_name)


## Name of the body clip playing.
func get_current_clip() -> StringName:
	return _motion.assigned_animation


## Speed the current clip plays at, including the time scale.
func get_clip_speed() -> float:
	return _motion.speed_scale


## Seconds the current clip takes at its current speed.
func get_clip_seconds() -> float:
	return _motion.current_animation_length / _motion.speed_scale if _motion.speed_scale > 0.0 else INF


func get_shared_data() -> Shared:
	return _shared


func get_motion_player() -> AnimationPlayer:
	return _motion


func get_overlay_player() -> AnimationPlayer:
	return _overlay


func get_emitters() -> Array[CPUParticles3D]:
	return _emitters


# --- Helpers for the subclasses ----------------------------------------------

func _add_joint(parent: Node3D, joint_name: StringName, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.position = at
	parent.add_child(joint)
	_joints[joint_name] = joint
	return joint


## A part of the body: a shared mesh with a shared material and no shadow.
func _add_part(parent: Node3D, part_name: StringName, mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


## A part that lights up during the windup.
func _add_glow_part(parent: Node3D, part_name: StringName, mesh: Mesh, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part: MeshInstance3D = _add_part(parent, part_name, mesh, _shared.materials[MATERIAL_GLOW_OFF], at)
	_glow_parts.append(part)
	return part


func _add_fx_root() -> Node3D:
	_fx = Node3D.new()
	_fx.name = &"Fx"
	add_child(_fx)
	return _fx


## A small emitter under `Fx`, off until a clip turns it on.
func _add_emitter(emitter_name: StringName, config: EnemyParticlesConfig, mesh: Mesh, at: Vector3) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.name = emitter_name
	emitter.position = at
	emitter.emitting = false
	emitter.amount = config.amount
	emitter.lifetime = config.lifetime
	emitter.direction = config.direction
	emitter.spread = config.spread_degrees
	emitter.initial_velocity_min = config.speed_min
	emitter.initial_velocity_max = config.speed_max
	emitter.gravity = config.gravity
	emitter.local_coords = not config.world_space
	emitter.mesh = mesh
	emitter.scale_amount_min = config.size
	emitter.scale_amount_max = config.size
	if config.emission_radius > 0.0:
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		emitter.emission_sphere_radius = config.emission_radius
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(emitter)
	_emitters.append(emitter)
	return emitter


## `<clip>_<phase>` when the model has it, else the generic `phase` clip.
func _resolve_clip(clip: StringName, phase: StringName) -> StringName:
	var candidate := StringName("%s_%s" % [clip, phase])
	return candidate if has_clip(candidate) else phase


func _loop_clip(clip: StringName, speed: float) -> void:
	_clip_speed = speed
	_apply_speed()
	if clip != _locomotion_clip:
		_locomotion_clip = clip
		_motion.play(clip, LOCOMOTION_BLEND)


func _apply_speed() -> void:
	_motion.speed_scale = _clip_speed * _time_scale
	_overlay.speed_scale = _time_scale


func _add_players(shared: Shared) -> void:
	_motion = AnimationPlayer.new()
	_motion.name = &"Motion"
	_motion.add_animation_library(MOTION_LIBRARY, shared.motion)
	add_child(_motion)
	_overlay = AnimationPlayer.new()
	_overlay.name = &"Overlay"
	_overlay.add_animation_library(MOTION_LIBRARY, shared.overlay)
	add_child(_overlay)


func _on_motion_finished(finished: StringName) -> void:
	if finished == CLIP_RECOVER:
		_in_action = false
		_locomotion_clip = &""


## The hit reaction shared by the types: a short squash and tilt of Flinch
## (0.3 s, never stretched). `strength` scales the tilt and the squash.
func _standard_overlay(strength: float = 1.0) -> AnimationLibrary:
	var kit := EnemyClipKit.new({&"flinch": ^"Flinch"}, {}, [&"flinch"])
	var library := AnimationLibrary.new()
	var squash := {"flinch": Vector3(-6, 0, 3) * strength, "flinch:s": Vector3.ONE + Vector3(0.06, -0.08, 0.06) * strength}
	var rebound := {"flinch": Vector3(3, 0, -2) * strength, "flinch:s": Vector3.ONE + Vector3(-0.02, 0.03, -0.02) * strength}
	library.add_animation(CLIP_HIT, kit.make_clip([[0.0, {}], [0.06, squash], [0.14, rebound], [0.3, {}]], false, {}, 0.3))
	return library
