class_name DashAfterimageConfig
extends Resource
## Afterimages of the dash: translucent copies of the body left behind while
## the player is invulnerable (docs/specs/dash-feel.md, module A).

## Copies per dash (the pool holds this many).
@export var count: int
## Fraction of the dash (0 → 1) at which each copy is left; one per copy.
@export var fractions: PackedFloat32Array
## Seconds each copy takes to fade out.
@export var lifetime: float
## Transparency of a fresh copy (0 = invisible, 1 = opaque).
@export var start_alpha: float
