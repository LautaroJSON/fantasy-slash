class_name HoshoConfig
extends Resource
## Sheathe's unique upgrade "Hosho" (docs/specs/sheathe-upgrades-rework.md
## §2.2): every combo strike that hits builds a Compensation charge; enough
## charges make the ability ready and empowered (cast on a tap, at full charge,
## with damage_multiplier times the damage).

## Charges that grant the empowered Sheathe (the last one is not shown: the
## katana's glow takes over).
@export var charges_needed: int
## Damage of the empowered Sheathe over a full manual one.
@export var damage_multiplier: float
## HUD buff that shows the charges (never expires).
@export var charge_buff: BuffData
