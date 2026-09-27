class_name AbilitySlotSource
extends SlotSource
## An ability slot shown by an AbilitySlotView.

var _ability: AbilityComponent


func _init(ability: AbilityComponent) -> void:
	_ability = ability


func get_cooldown_ratio() -> float:
	return _ability.get_cooldown_ratio()


func get_cooldown_remaining() -> float:
	return _ability.get_cooldown_remaining()


func is_equipped() -> bool:
	return _ability.is_equipped()


func is_charging() -> bool:
	return _ability.is_charging()


func get_charge_ratio() -> float:
	return _ability.get_charge_ratio()


func is_empowered() -> bool:
	return _ability.is_empowered()


func is_ultimate() -> bool:
	return _ability.slot == AbilityData.Slot.ULTIMATE
