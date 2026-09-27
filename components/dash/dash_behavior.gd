class_name DashBehavior
extends Node
## Base of the extra rules of a class dash (docs/specs/dash-feel.md §2.5).
## Instantiated by DashComponent.equip() from DashData.behavior and driven by
## it; every hook does nothing by default, which is the standard dash.
## E.g. a dash that hits what it crosses (step), an air variant (started and
## get_clip with dash.is_airborne()), or a block that replaces the dash
## (can_start false, plus its own action).


## Extra rules on top of the cooldown; false refuses the dash (no cooldown, no iframes).
func can_start(_dash: DashComponent) -> bool:
	return true


## After the dash started (iframes on, body turned).
func started(_dash: DashComponent) -> void:
	pass


## Every dash step, after the body moved.
func step(_dash: DashComponent, _delta: float) -> void:
	pass


## The dash is over; `cancelled` when something cut it short.
func ended(_dash: DashComponent, _cancelled: bool) -> void:
	pass


## Humanoid clip of the running dash.
func get_clip(_dash: DashComponent, default_clip: StringName) -> StringName:
	return default_clip
