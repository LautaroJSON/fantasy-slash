class_name StatDisplay
extends Resource
## How one stat is shown to the player: shown value = format % (value * multiplier).

@export var stat: PlayerStats.Stat
@export var label: String
## printf-style format, e.g. "%.0f %%" or "%.1f m".
@export var format: String
## 100 for stats stored as fractions but shown as percentages.
@export var multiplier: float


func format_value(value: float) -> String:
	return format % (value * multiplier)
