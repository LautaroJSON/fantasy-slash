class_name DashVfxSet
extends Resource
## VFX modules of the dash (docs/specs/dash-feel.md §2.4): each entry is a
## scene whose root is a DashVfxModule. Removing an entry removes that effect.

@export var modules: Array[PackedScene]
