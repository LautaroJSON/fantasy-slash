class_name EnemyParticlesConfig
extends Resource
## Parameters of one small particle emitter of an enemy model (spores, dust,
## steam, sparks). The model builds a CPUParticles3D from it once; a clip turns
## it on and off (docs/specs/enemy-models.md).

@export var amount: int
@export var lifetime: float
## Emission direction (local to the emitter).
@export var direction: Vector3
@export var spread_degrees: float
@export var speed_min: float
@export var speed_max: float
## Acceleration in m/s² (positive Y rises).
@export var gravity: Vector3
## Edge of the particle in meters (the emitter mesh is 1 m wide).
@export var size: float
## Particles keep their world position after leaving the emitter.
@export var world_space: bool
## Emission volume (radius of a sphere), 0 = a point.
@export var emission_radius: float
