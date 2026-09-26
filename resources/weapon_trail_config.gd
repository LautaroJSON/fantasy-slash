class_name WeaponTrailConfig
extends Resource
## Look and length of the ribbon that follows the weapon's blade while it
## attacks (basic attack and abilities alike).

## Seconds each sample of the ribbon lasts before it disappears.
@export var lifetime: float
## Vertex alpha of the newest sample (the tail fades to 0).
@export var head_alpha: float
## Size of the ring buffer of samples (allocated once).
@export var max_samples: int
