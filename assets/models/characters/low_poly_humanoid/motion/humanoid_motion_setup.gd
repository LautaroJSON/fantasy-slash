class_name HumanoidMotionSetup
extends RefCounted
## What a profile asks from the motion layer (poc/samurai-motion). Built once
## per profile, shared by every humanoid using it.

## Clip -> the arcs the grip follows during it, in time order (a load, the
## cut, a chiburi...): each one rules from the first time of its `timing`.
var arcs: Dictionary[StringName, Array] = {}
## Clip -> [[foot "l"/"r", from, to], ...]: windows (clip seconds) in which a
## foot stays planted on the floor while the body moves.
var plants: Dictionary[StringName, Array] = {}
## Joint -> (frequency Hz, damping ratio): secondary motion springs.
var springs: Dictionary[String, Vector2] = {}
## Largest angle (radians) a spring may lag behind its animated pose.
var spring_max_angle: float = deg_to_rad(16.0)
## Seconds the grip blends from the last clip's output when the clip changes.
var switch_blend: float = 0.09
## Seconds the grip blends back to the clip when the next clip has no arcs
## (leaving the combo for the guard or locomotion).
var exit_blend: float = 0.2
## Seconds the grip blends when one arc hands over to the next in a clip.
var arc_blend: float = 0.05
## Seconds the grip keeps following the new clip's own arm after leaving the
## cuts: longer than the animator's fade out of a strike (attack_exit_blend).
var exit_hold: float = 0.45
## A planted foot lets go when the body gets this far from it (metres).
var plant_max_stretch: float = 0.8
## Seconds a released foot takes to step back into its pose.
var plant_step_time: float = 0.11
## Height of that step (metres).
var plant_step_height: float = 0.07
## +1 or -1: which side of the blade's frame is the edge.
var edge_sign: float = 1.0
