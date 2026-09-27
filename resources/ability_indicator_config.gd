class_name AbilityIndicatorConfig
extends Resource
## Look and timing of an ability's hitbox area on the ground (a white, very
## transparent fill: at most 0.3 opacity at rest and 0.5 in a pulse, Principle II).

## Vertical thickness of the flat fill, in meters.
@export var line_thickness: float
## Height above the player's feet, in meters (avoids z-fighting with the floor).
@export var ground_offset: float
## Seconds the area takes to fade out after the hit.
@export var fade_duration: float
## Transparency while casting and at the start of the fade (0 = opaque, 1 = invisible).
@export var start_transparency: float
## Transparency of the short pulse on each charge milestone (charged abilities).
@export var pulse_transparency: float
## Seconds the pulse takes to return to the previous transparency (0 = no pulse).
@export var pulse_duration: float
