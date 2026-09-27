class_name SprintConfig
extends Resource
## Control feel of the sprint and the stamina bar (docs/specs/sprint-stamina.md).
## Not upgradeable: the sprint's speed, cost and the stamina pool are stats.

## Longest gap, in seconds, between the two forward taps of a double tap.
@export var double_tap_window: float
## Stamina needed to start sprinting (no one-frame sprints on an empty bar).
@export var stamina_to_start_sprint: float
## Seconds without spending before the stamina starts to regenerate.
@export var stamina_regen_delay: float
