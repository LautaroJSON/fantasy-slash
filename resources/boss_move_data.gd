class_name BossMoveData
extends Resource
## One move of a boss repertoire and when it may be chosen
## (docs/specs/boss-verdugo.md). Subclasses hold what the move does.

## Chosen with `weight` between these distances to the target, in meters.
@export var min_range: float
@export var max_range: float
@export var weight: float
## Weight below min_range (0 = never chosen that close).
@export var close_weight: float
@export var in_phase_one: bool
@export var in_phase_two: bool
## Needs a hand (a boss whose hands are all broken cannot use it; see boss-titan.md).
@export var needs_hand: bool
## Weight used instead when no hands are left (0 = keep `weight`).
@export var handless_weight: float


## Pure: chance weight at `distance` in boss phase `phase` (1 or 2) with
## `hands_left` hands.
func weight_at(distance: float, phase: int, hands_left: int = 2) -> float:
	if needs_hand and hands_left <= 0:
		return 0.0
	if (phase == 1 and not in_phase_one) or (phase == 2 and not in_phase_two):
		return 0.0
	if distance > max_range:
		return 0.0
	if distance < min_range:
		return close_weight
	if hands_left <= 0 and handless_weight > 0.0:
		return handless_weight
	return weight
