class_name AirSlashConfig
extends Resource
## The Berserker's air slash (docs/specs/berserker-air-slash.md): in the air,
## holding attack suspends the player with the weapon raised, charging; the
## release dives and slams a band in front. Fixed by design (no cards): its
## damage scales with the basic attack stats instead.

@export_group("Hover")
## Longest suspension, in seconds; reaching it releases the slash.
@export var hover_duration: float
## Fraction of MOVE_SPEED kept while suspended.
@export var hover_move_speed_factor: float

@export_group("Damage")
## Multiple of the basic attack damage when released at once.
@export var min_damage_factor: float
## Multiple of the basic attack damage after hover_duration of charge.
@export var max_damage_factor: float
## Length of the band hit in front of the player's feet, in meters.
@export var hit_length: float
## Width of the band hit, in meters.
@export var hit_width: float
## Initial speed of the push applied to enemies hit, in m/s.
@export var knockback_speed: float

@export_group("Dive")
## Falling speed of the dive, in m/s.
@export var dive_speed: float
## The slash lands anyway after this many seconds of dive (e.g. over a void).
@export var max_dive_duration: float
## Seconds the player stays still after landing.
@export var landing_lock: float

@export_group("Weapon")
## Weapon pivot pose while suspended (raised over the head, pointing back),
## relative to Visual.
@export var raise_position: Vector3
@export var raise_rotation: Vector3
## Weapon pivot pose at the end of the descending slash.
@export var slam_position: Vector3
@export var slam_rotation: Vector3
## Seconds the blade takes to go from the raised pose to the slam pose.
@export var slam_duration: float

@export_group("Feedback")
## Camera shake strength on impact, in [0, 1].
@export var impact_shake: float

@export_group("Affliction")
## Scale of the Affliction build-up of its hits (a basic-attack source; docs/specs/affliction.md).
@export var affliction_scale: float
