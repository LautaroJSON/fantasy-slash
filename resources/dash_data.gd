class_name DashData
extends Resource
## The dash of a class (docs/specs/dash-feel.md): the clip it plays, optional
## extra rules (a DashBehavior scene) and the VFX it shows. Its numbers
## (distance, speed, cooldown) stay stats in PlayerStats.

## Humanoid clip of the dash in the class profile.
@export var clip: StringName
## Scene whose root is a DashBehavior; null = the standard dash.
@export var behavior: PackedScene
## VFX modules shown while dashing.
@export var vfx_set: DashVfxSet
