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

@export_group("Zoom")
## Degrees the view narrows at the first milestone (held until the release).
@export var zoom_base_deg: float
## Degrees added by each following milestone.
@export var zoom_step_deg: float
## Degrees narrowed at full charge (also the cap of the growing zoom).
@export var zoom_full_deg: float
## Seconds the view takes to reach each milestone's zoom.
@export var zoom_blend: float
## Seconds the view takes to widen back when the charge ends without a burst.
@export var zoom_return: float
## Degrees the view widens past the base when the charged strike bursts out.
@export var unleash_kick_deg: float
## Seconds that kick takes to settle back to the base.
@export var unleash_kick_return: float


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


## Degrees the view narrows at milestone `index` (1-based).
func zoom_for(index: int, is_full: bool) -> float:
	if is_full:
		return zoom_full_deg
	return minf(zoom_base_deg + zoom_step_deg * (index - 1), zoom_full_deg)
