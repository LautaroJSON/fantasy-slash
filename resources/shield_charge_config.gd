class_name ShieldChargeConfig
extends Resource
## Tuning of the Warrior's Shield Charge (docs/specs/warrior-abilities-rework.md
## §3.1 and §5.1). Distance (HIT_RANGE), width, damage and cooldown are
## AbilityData stats; everything else lives here.

@export_group("Travel")
## Seconds the charge takes to cover HIT_RANGE (upgrades make it faster, not longer).
@export var travel_time: float
## Depth of the strip in front of the player whose enemies are dragged, in meters.
@export var capture_depth: float
## Push speed of a dragged enemy over the player's charge speed.
@export var drag_speed_factor: float
## A step that covers less than this share of the expected distance hit a wall.
@export var stall_ratio: float
## Share of the frontal damage the raised shield absorbs while charging.
@export var guard_reduction: float
## Arc in front of the player the shield covers, in degrees.
@export var guard_arc_degrees: float

@export_group("Bash")
## Depth of the rectangle the shield bash hits, in meters (width: HIT_WIDTH).
@export var bash_range: float
## Seconds from the start of the bash clip to its push (the clip's event).
@export var bash_hit_time: float
## Push speed given by the bash, in m/s.
@export var bash_knockback_speed: float
## Damage multiplier of the bash after the shield absorbed a frontal hit.
@export var absorb_damage_multiplier: float
## Size of the dust ring of an empowered bash over the normal one.
@export var empowered_ring_scale: float

@export_group("Stun")
## Seconds after the bash during which a pushed enemy hitting a wall or another
## enemy is stunned.
@export var impact_window: float
## A pushed enemy still faster than this (m/s) that stops against something collides.
@export var impact_min_speed: float
## Gap between two enemies that counts as a collision, in meters (plus their paddings).
@export var contact_distance: float
@export var stun: DebuffData
## Seconds of every stun of the charge (collisions and the empowered bash),
## unless "Contundencia" sets its own.
@export var stun_duration: float
## Enemies the bash must hit for "Impulso" to halve the cooldown left.
@export var momentum_min_hits: int

@export_group("Feel")
@export var bash_feel: StrikeFeel
@export var empowered_feel: StrikeFeel
## The shield absorbing a hit while charging.
@export var absorb_feel: StrikeFeel
## Two enemies colliding ("Martillo y yunque").
@export var impact_feel: StrikeFeel

@export_group("Body")
## Humanoid clip while charging (loop).
@export var charge_body_clip: StringName
## Humanoid clip from the bash on.
@export var bash_body_clip: StringName
