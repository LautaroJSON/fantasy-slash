class_name ValueFormat
extends Resource
## How a value is shown: shown text = format % (value * multiplier).

## printf-style format, e.g. "%.0f %%" or "%.1f m".
@export var format: String
## 100 for values stored as fractions but shown as percentages.
@export var multiplier: float


func format_value(value: float) -> String:
	return format % (value * multiplier)
