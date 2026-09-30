class_name EnemyClipKit
extends RefCounted
## Bakes the clips of an enemy model (docs/specs/enemy-models.md, Principle VIII).
## A clip is a list of keys `[time, pose]`; a pose lists only what departs from
## the rest pose, by joint name:
##   "torso": Vector3        rotation in degrees
##   "hips:p": Vector3       position offset from the rest position, in meters
##   "hips:s": Vector3|float scale multiplier
##   "emit:Puff": bool       an emitter (by node name) is on in this pose; absent = off
## Everything is sampled at BAKE_FPS through a monotone cubic (no overshoot,
## continuous speed) and each joint may lag `overlap[joint]` seconds behind the
## hips (the hips lead, torso and head follow). Every clip animates the same
## tracks, so switching clips never leaves a joint at a stale value.

const BAKE_FPS: float = 60.0

## Joint name → path of its Node3D, relative to the animation root.
var _paths: Dictionary[StringName, NodePath]
## Joints whose position is animated → rest position.
var _rests: Dictionary[StringName, Vector3]
## Joints whose scale is animated.
var _scaled: Array[StringName]
## Emitter names the clips switch, in the order the model creates them (emit_0, emit_1).
var _emitters: Array[StringName]


func _init(paths: Dictionary[StringName, NodePath], rests: Dictionary[StringName, Vector3],
		scaled: Array[StringName], emitters: Array[StringName] = []) -> void:
	_paths = paths
	_rests = rests
	_scaled = scaled
	_emitters = emitters


func make_clip(keys: Array, loop: bool = false, overlap: Dictionary = {}, length: float = 1.0) -> Animation:
	var clip := Animation.new()
	clip.length = length
	clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for joint: StringName in _paths:
		var delay: float = overlap.get(joint, 0.0)
		var path: String = String(_paths[joint])
		_bake(clip, path + ":rotation", keys, String(joint), Vector3.ZERO, PI / 180.0, Vector3.ZERO, delay)
		if _rests.has(joint):
			_bake(clip, path + ":position", keys, "%s:p" % joint, Vector3.ZERO, 1.0, _rests[joint], delay)
		if _scaled.has(joint):
			_bake(clip, path + ":scale", keys, "%s:s" % joint, Vector3.ONE, 1.0, Vector3.ZERO, delay)
	for index: int in _emitters.size():
		_add_emitter_track(clip, index, _emitters[index], keys)
	return clip


## Dense keys of one Vector3 property: value = base + pose[key] * factor.
func _bake(clip: Animation, property_path: String, keys: Array, key: String, fallback: Vector3,
		factor: float, base: Vector3, delay: float) -> void:
	var track: int = clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, NodePath(property_path))
	clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	var curves: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	for pose_key: Array in keys:
		var value: Vector3 = _as_vector(pose_key[1].get(key, fallback))
		for axis: int in 3:
			curves[axis].append(Vector2(pose_key[0], value[axis]))
	var frames: int = maxi(ceili(clip.length * BAKE_FPS), 1)
	for frame: int in frames + 1:
		var time: float = minf(frame / BAKE_FPS, clip.length)
		var sample_time: float = clampf(time - delay, 0.0, clip.length)
		var sampled := Vector3(
			SlashArc.monotone_cubic(curves[0], sample_time),
			SlashArc.monotone_cubic(curves[1], sample_time),
			SlashArc.monotone_cubic(curves[2], sample_time))
		clip.track_insert_key(track, time, base + sampled * factor)


## A float track `emit_<index>` (1 = on, 0 = off): it blends like any number when
## one clip fades into another, and the model turns the emitter on above 0.5.
func _add_emitter_track(clip: Animation, index: int, emitter: StringName, keys: Array) -> void:
	var track: int = clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, NodePath(".:emit_%d" % index))
	clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	var key: String = "emit:%s" % emitter
	for pose_key: Array in keys:
		var on: bool = pose_key[1].get(key, false)
		clip.track_insert_key(track, pose_key[0], 1.0 if on else 0.0)



func _as_vector(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	return Vector3.ONE * float(value)


## Keys of a two-legged gait for a loop of 1 s (left foot forward at 0, right foot
## forward at 0.5). `p`: stride and lift of the feet (m), bob and sway of the hips (m),
## hip_twist and torso_twist (degrees), pitch (trunk lean, negative = forward), dip
## (extra lean at each footfall) and head_pitch. `extras` are poses merged into the
## keys at 0, 0.25, 0.5 and 0.75 (the key at 1.0 repeats the one at 0). `axis` is
## the foot travel axis: Vector3.BACK for walking, Vector3.RIGHT for a side step.
static func gait_keys(p: Dictionary, extras: Array = [{}, {}, {}, {}], axis: Vector3 = Vector3.BACK) -> Array:
	var stride: float = p["stride"]
	var lift: float = p["lift"]
	var bob: float = p["bob"]
	var sway: float = p["sway"]
	var twist: float = p["hip_twist"]
	var torso_twist: float = p["torso_twist"]
	var pitch: float = p["pitch"]
	var dip: float = p["dip"]
	var head_pitch: float = p["head_pitch"]
	var contact_left := {
		"hips:p": Vector3(0.0, -bob, 0.0), "hips": Vector3(0, -twist, 0), "torso": Vector3(pitch - dip, torso_twist, 0),
		"head": Vector3(head_pitch, -torso_twist * 0.5, 0), "foot_l:p": -axis * stride, "foot_r:p": axis * stride}
	var pass_right := {
		"hips:p": Vector3(sway, bob * 0.6, 0.0), "hips": Vector3.ZERO, "torso": Vector3(pitch, 0, 4),
		"head": Vector3(head_pitch, 0, 0), "foot_l:p": Vector3.ZERO, "foot_r:p": Vector3.UP * lift}
	var contact_right := {
		"hips:p": Vector3(0.0, -bob, 0.0), "hips": Vector3(0, twist, 0), "torso": Vector3(pitch - dip, -torso_twist, 0),
		"head": Vector3(head_pitch, torso_twist * 0.5, 0), "foot_l:p": axis * stride, "foot_r:p": -axis * stride}
	var pass_left := {
		"hips:p": Vector3(-sway, bob * 0.6, 0.0), "hips": Vector3.ZERO, "torso": Vector3(pitch, 0, -4),
		"head": Vector3(head_pitch, 0, 0), "foot_l:p": Vector3.UP * lift, "foot_r:p": Vector3.ZERO}
	var poses: Array[Dictionary] = [contact_left, pass_right, contact_right, pass_left]
	for index: int in 4:
		poses[index].merge(extras[index], true)
	return [[0.0, poses[0]], [0.25, poses[1]], [0.5, poses[2]], [0.75, poses[3]], [1.0, poses[0]]]
