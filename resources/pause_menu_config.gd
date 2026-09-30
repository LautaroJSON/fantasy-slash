class_name PauseMenuConfig
extends Resource
## Texts and sizes of the pause menu tabs (docs/specs/sandbox-arena-control.md).

## Title of each upgrade section, indexed by UpgradeCard.Group.
@export var group_titles: Array[String]
## Shown in a section with no card taken (normal mode).
@export var empty_group_text: String
## Title of the active buffs block.
@export var buffs_title: String
## One active buff: title, stacks and seconds left, e.g. "%s ×%d · %.1f s".
@export var buff_entry_format: String
## Shown when no buff is active.
@export var no_buffs_text: String
## Run line in sandbox, where the wave does not advance ("%d enemigos eliminados").
@export var sandbox_run_format: String
## Equivalent wave next to the level in the enemy tab ("≈ oleada %d").
@export var wave_hint_format: String
## Live enemies in the enemy tab ("Activos: %d").
@export var alive_format: String
## Tab switching hint: previous and next prompts ("%s / %s  Cambiar pestaña").
@export var tab_hint_format: String
## Gap between the full-screen pause panel and the screen edges, in pixels
## (docs/specs/pause-fullscreen-max-upgrades.md).
@export var screen_margin: float
## Upgrade sections shown in the right column; the rest go to the left one.
@export var right_column_groups: Array[UpgradeCard.Group]
## Sections with a "Max" button next to their title (sandbox).
@export var max_section_groups: Array[UpgradeCard.Group]
## Text of the "Max" buttons (rows and sections).
@export var max_button_text: String
