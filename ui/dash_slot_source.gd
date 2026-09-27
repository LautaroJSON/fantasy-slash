class_name DashSlotSource
extends SlotSource
## The dash shown by an AbilitySlotView (docs/specs/dash-button.md): only its
## cooldown; it is never locked, charged or empowered.

var _dash: DashComponent


func _init(dash: DashComponent) -> void:
	_dash = dash


func get_cooldown_ratio() -> float:
	return _dash.get_cooldown_ratio()


func get_cooldown_remaining() -> float:
	return _dash.get_cooldown_remaining()
