class_name StatDisplayTable
extends Resource
## Layout and formatting of the player stats shown in the pause menu: two
## columns side by side and a block below them. Stats not listed are not shown.

@export var left_column: Array[StatDisplay]
@export var right_column: Array[StatDisplay]
@export var bottom_rows: Array[StatDisplay]


## The row of `stat` in any group, or null.
func find(stat: PlayerStats.Stat) -> StatDisplay:
	var row: StatDisplay = _find_in(left_column, stat)
	if row == null:
		row = _find_in(right_column, stat)
	if row == null:
		row = _find_in(bottom_rows, stat)
	return row


func row_count() -> int:
	return left_column.size() + right_column.size() + bottom_rows.size()


func _find_in(group: Array[StatDisplay], stat: PlayerStats.Stat) -> StatDisplay:
	for row: StatDisplay in group:
		if row.stat == stat:
			return row
	return null
