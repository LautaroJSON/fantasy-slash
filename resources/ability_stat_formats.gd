class_name AbilityStatFormats
extends Resource
## How each ability stat is shown (sandbox panel). Indexed by AbilityData.Stat.

@export var formats: Array[ValueFormat]


func format_value(stat: AbilityData.Stat, value: float) -> String:
	return formats[stat].format_value(value)
