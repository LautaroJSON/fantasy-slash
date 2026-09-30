class_name PortalStyleConfig
extends Resource
## Look of the rune-ring portal style (docs/specs/stages.md §4).

## How far below its rest position the ring starts when opening (metres).
@export var rise_depth: float
## Inner disc scale at the start of the opening (grows to 1).
@export var disc_start_scale: float
## Peak energy of the opening flash light, and how long it takes to fade (s).
@export var flash_energy: float
@export var flash_fade: float
## Particles: rate while open, lifetime and rising speed.
@export var particle_amount: int
@export var particle_lifetime: float
@export var particle_speed: float
