class_name SlotSource
extends RefCounted
## What a HUD action button (AbilitySlotView) shows: an ability or the dash
## (docs/specs/dash-button.md). Base class: override every method.


## 1 right after use, 0 when ready.
func get_cooldown_ratio() -> float:
	return 0.0


func get_cooldown_remaining() -> float:
	return 0.0


## False draws the button locked (grey).
func is_equipped() -> bool:
	return true


func is_charging() -> bool:
	return false


func get_charge_ratio() -> float:
	return 0.0


## True draws the gold frame.
func is_empowered() -> bool:
	return false


## True uses the ultimate's size and font.
func is_ultimate() -> bool:
	return false
