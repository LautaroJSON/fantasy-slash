class_name AbilityCatalog
extends Resource
## Every ability that can be chosen at the start of a run.

@export var abilities: Array[AbilityData]


func get_for_slot(slot: AbilityData.Slot) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for ability: AbilityData in abilities:
		if ability.slot == slot:
			result.append(ability)
	return result
