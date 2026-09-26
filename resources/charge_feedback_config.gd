class_name ChargeFeedbackConfig
extends Resource
## Feedback of a charged ability (held down): one milestone every
## milestone_interval seconds of charge and one when the charge is full. Each
## milestone shakes the camera and makes the player's body tremble, stronger
## with every milestone and strongest at full charge.

## Seconds of charge between milestones.
@export var milestone_interval: float
## Camera shake strength (0..1) of the first milestone.
@export var base_shake: float
## Shake added by each following milestone.
@export var step_shake: float
## Shake at full charge (also the cap of the growing shake).
@export var full_shake: float
## Body tremor amplitude of the first milestone, in meters.
@export var base_tremor: float
## Tremor amplitude added by each following milestone, in meters.
@export var step_tremor: float
## Tremor amplitude at full charge (also the cap), in meters.
@export var full_tremor: float
## Seconds the body trembles after a milestone (the amplitude decays to 0).
@export var tremor_duration: float
## Tremor oscillations per second.
@export var tremor_frequency: float
## Camera shake strength (0..1) when an ability gains an empowered cast.
@export var empowered_shake: float


## Camera shake of milestone `index` (1-based).
func shake_for(index: int, is_full: bool) -> float:
	if is_full:
		return full_shake
	return minf(base_shake + step_shake * (index - 1), full_shake)


## Peak body tremor of milestone `index` (1-based), in meters.
func tremor_for(index: int, is_full: bool) -> float:
	if is_full:
		return full_tremor
	return minf(base_tremor + step_tremor * (index - 1), full_tremor)
