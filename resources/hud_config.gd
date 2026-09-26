class_name HudConfig
extends Resource
## Texts of the in-game HUD that the Hud rewrites at runtime.

## Dash bar label while the dash is ready (the remaining seconds replace it during the cooldown).
@export var dash_ready_text: String
@export var cooldown_text: CooldownTextConfig
