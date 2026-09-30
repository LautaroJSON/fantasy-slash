class_name StageSequence
extends Resource
## Order of the stages of a run; the last one is static (docs/specs/stages.md).

@export var stages: Array[StageData]


## Pure.
func count() -> int:
	return stages.size()


## Pure: whether `index` is the last stage (its boss opens no portal).
func is_last(index: int) -> bool:
	return index == stages.size() - 1


## Pure: the stage at `index`, or null outside the sequence.
func get_stage(index: int) -> StageData:
	if index < 0 or index >= stages.size():
		return null
	return stages[index]
