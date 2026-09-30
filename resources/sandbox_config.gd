class_name SandboxConfig
extends Resource
## Sandbox arena control (docs/specs/sandbox-arena-control.md): caps of the
## summon panel, respawn delay, dummy turning and the request used when the
## sandbox starts.

## Most enemies of one regular type summoned at once (their pools grow to it).
@export var max_regular_count: int
## Most bosses of one kind summoned at once.
@export var max_boss_count: int
## Seconds between clearing the group and summoning it again (Respawn).
@export var respawn_delay: float
## Degrees per second a dummy turns to face the player.
@export var dummy_turn_speed: float
## Default request: index in the summon list, count, level and options.
@export var default_entry: int
@export var default_count: int
@export var default_level: int
@export var default_immortal: bool
@export var default_dummy: bool
@export var default_respawn: bool
