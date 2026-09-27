class_name DashVfxModule
extends Node3D
## Base of one dash effect (docs/specs/dash-feel.md §2.4). DashVfxHost
## instantiates the modules listed in the class DashVfxSet, calls setup() once
## (build every node there: pooling, Principle V) and forwards the dash events.


func setup(_player: Player) -> void:
	pass


func dash_started(_dash: DashComponent) -> void:
	pass


## Every dash step, after the body moved.
func dash_step(_dash: DashComponent) -> void:
	pass


func dash_ended(_dash: DashComponent, _cancelled: bool) -> void:
	pass
