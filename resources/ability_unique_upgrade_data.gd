class_name AbilityUniqueUpgradeData
extends UpgradeCard
## Unique ability upgrade: changes how an ability works instead of a number.
## Each level has its own value and card text. max_level 1 = not upgradeable
## (Constitution, Principle III: "Mejoras únicas de habilidad").

## Structural id the ability's behavior looks for.
@export var id: StringName
## Highest level; 1 means the upgrade cannot be improved further.
@export var max_level: int
## Value of the effect at each level (index 0 = level 1). Empty for binary effects.
@export var level_values: Array[float]
## Card description for each level (index 0 = level 1).
@export var level_descriptions: Array[String]
## Debuff applied by the effect, when it applies one.
@export var debuff: DebuffData
## Buff granted by the effect, when it grants one.
@export var buff: BuffData
## How the level value is shown (sandbox panel). Null for binary effects.
@export var value_format: ValueFormat


func is_same_kind(other: UpgradeCard) -> bool:
	var unique: AbilityUniqueUpgradeData = other as AbilityUniqueUpgradeData
	return unique != null and unique.id == id


## Value at `level` (1-based); 0 when the effect has no value or level is 0.
func get_value(level: int) -> float:
	if level <= 0 or level_values.is_empty():
		return 0.0
	return level_values[mini(level, level_values.size()) - 1]


## Card text for `level` (1-based).
func get_description(level: int) -> String:
	if level_descriptions.is_empty():
		return description
	return level_descriptions[clampi(level, 1, level_descriptions.size()) - 1]
