class_name PortalStyle
extends Node3D
## Base of a portal's look (docs/specs/stages.md §4): another style is another
## scene whose root extends this class.


## The portal starts opening; it lasts `duration` seconds.
func play_open(_duration: float) -> void:
	pass


## The portal is fully open.
func play_idle() -> void:
	pass


## Steps the style's animation (called by the Portal every frame).
func advance(_delta: float) -> void:
	pass
