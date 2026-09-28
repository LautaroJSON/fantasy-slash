class_name CircleSlashVfxConfig
extends Resource
## Circular slash of the Parry's empowered riposte
## (docs/specs/parry-riposte-rework.md §2.6): a flat white ribbon around the
## player whose head sweeps 360° with the blade and whose tail fades.

## Segments of the whole circle (the ribbon uses the ones its arc covers).
@export var segments: int
## Height of the ribbon over the player's feet, in meters (the blade's height).
@export var height: float
## Width of the ribbon, inward from the hit radius, in meters.
@export var band_width: float
## Alpha at the head of the ribbon (Principle II: ≤ 0.5); the tail is 0.
@export var head_alpha: float
## Degrees of arc behind the head that still show (the fading tail).
@export var tail_degrees: float
## Seconds the head takes to go around once.
@export var sweep_duration: float
## Seconds the ribbon takes to fade out once the head has gone around.
@export var fade_duration: float
## Shared unshaded, vertex-colored translucent material.
@export var material: StandardMaterial3D
