class_name StageTransitionConfig
extends Resource
## Fade and banner between stages (docs/specs/stages.md §5).

## Seconds fading to the fade colour.
@export var fade_out: float
## Seconds held on the fade colour (the stage is swapped at its start).
@export var hold: float
## Seconds fading back in.
@export var fade_in: float
## Seconds the banner stays up once the fade is over (and at the start of the run).
@export var banner_duration: float
## Seconds the banner takes to fade out at its end.
@export var banner_fade: float
@export var fade_color: Color
## Banner title; %d is the stage number (1-based).
@export var banner_title_format: String
@export var title_font_size: int
@export var name_font_size: int
@export var subtitle_font_size: int
@export var text_color: Color
## Dark outline so the banner reads over a bright sky.
@export var outline_color: Color
@export var outline_size: int
