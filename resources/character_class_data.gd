class_name CharacterClassData
extends Resource
## A playable class. Each class is one weapon type, fixed forever: choosing the
## class is choosing the weapon. Defines the base stats and the ability pool.

@export var title: String
@export_multiline var description: String
## Initial values of the player stats for this class (upgrades add on top).
@export var base_stats: PlayerStats
## Abilities that can be chosen at the start of a run with this class.
@export var abilities: AbilityCatalog
## The class weapon, fixed: it defines the model and the basic attack sweep.
@export var weapon: WeaponData
## The class air slash (docs/specs/berserker-air-slash.md); null = none, the
## basic attack is used in the air too.
@export var air_slash: AirSlashConfig
