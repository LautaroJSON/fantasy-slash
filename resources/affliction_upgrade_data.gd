class_name AfflictionUpgradeData
extends UpgradeCard
## Violet card: hits of one source build up one Affliction (docs/specs/affliction.md).
## Each level raises the build-up per hit; max_level 1 = not upgradeable
## (Constitution, Principle III).

## Which hits fill the bar. Future sources (charged attack, ultimate) go after these.
enum Source {
	BASIC_ATTACK,
	ABILITY,
}

@export var affliction: AfflictionData
@export var source: Source
## Highest level.
@export var max_level: int
## Build-up per hit at each level (index 0 = level 1), before source scale,
## player bonus and enemy resistance.
@export var level_values: Array[float]
## Card description for each level (index 0 = level 1).
@export var level_descriptions: Array[String]
## How the level value is shown (sandbox panel).
@export var value_format: ValueFormat


## Same Affliction and same source: one card, whatever its level.
func is_same_kind(other: UpgradeCard) -> bool:
	var card: AfflictionUpgradeData = other as AfflictionUpgradeData
	return card != null and card.affliction.id == affliction.id and card.source == source


## Build-up at `level` (1-based); 0 when level is 0.
func get_value(level: int) -> float:
	if level <= 0 or level_values.is_empty():
		return 0.0
	return level_values[mini(level, level_values.size()) - 1]


## Card text for `level` (1-based).
func get_description(level: int) -> String:
	if level_descriptions.is_empty():
		return description
	return level_descriptions[clampi(level, 1, level_descriptions.size()) - 1]


func get_group() -> UpgradeCard.Group:
	return UpgradeCard.Group.AFFLICTION
