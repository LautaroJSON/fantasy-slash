class_name StatusIconConfig
extends Resource
## Shared look of every buff and debuff icon (LoL style): tinted background and
## glyph, cooldown clock, frame, stack count and the "+" overflow slot
## (docs/specs/status-icons.md).

## How much the status color is darkened for the icon background (0..1).
@export var background_darken: float
## How much the status color is lightened for the glyph (0..1).
@export var glyph_lighten: float
## Gap between the glyph and the icon edge, as a fraction of the side.
@export var glyph_margin: float
## Width of the frame as a fraction of the icon side, so small icons (common
## enemies) get a thinner frame than the HUD ones.
@export var border_ratio: float
## The frame never gets thinner than this, in pixels.
@export var min_border_px: float
## The frame never gets thicker than this, in pixels.
@export var max_border_px: float
@export var debuff_border_color: Color
@export var buff_border_color: Color
## Font size of the stack count, as a fraction of the side.
@export var stack_font_ratio: float
@export var overflow_background_color: Color
@export var overflow_border_color: Color
## Text of the overflow slot ("+").
@export var overflow_text: String
@export var overflow_text_color: Color
## Font size of the overflow text, as a fraction of the side.
@export var overflow_font_ratio: float
## Translucent sector over the icon covering the time still left.
@export var clock: CooldownClockConfig
## Outline style of the stack count and the overflow text.
@export var cooldown_text: CooldownTextConfig


## Pure: frame width in pixels for an icon of `side` pixels.
func border_width(side: float) -> float:
	return clampf(side * border_ratio, min_border_px, max_border_px)


## Pure: font size in pixels for a side and a ratio, never below 1.
static func font_size(side: float, ratio: float) -> int:
	return maxi(roundi(side * ratio), 1)
