class_name ComboMoveData
extends BossMoveData
## A chain of telegraphed hits; the boss steps forward before each one.

@export var steps: Array[EnemyAttackData]
## Meters the boss steps towards the target before each hit.
@export var advance_distance: float
## Hits appended to the chain in phase 2.
@export var phase_two_extra_steps: Array[EnemyAttackData]


## Pure: hits in the chain for boss phase `phase`.
func step_count(phase: int) -> int:
	return steps.size() + (phase_two_extra_steps.size() if phase == 2 else 0)


## Pure: hit `index` of the chain (phase 2 extras come after the base steps).
func step_at(index: int) -> EnemyAttackData:
	if index < steps.size():
		return steps[index]
	return phase_two_extra_steps[index - steps.size()]
