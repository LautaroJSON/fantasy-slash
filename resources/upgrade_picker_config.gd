class_name UpgradePickerConfig
extends Resource
## Look of the upgrade cards.

## Background of ability upgrade cards.
@export var ability_card_color: Color
## Background of ability upgrade cards under the mouse.
@export var ability_card_hover_color: Color
## Text of ability upgrade cards.
@export var ability_card_font_color: Color
## Background of the red "ban an upgrade" card.
@export var ban_card_color: Color
## Background of the ban card under the mouse.
@export var ban_card_hover_color: Color
## Text of the ban card.
@export var ban_card_font_color: Color
## Background of unique ability upgrade cards (gold).
@export var unique_card_color: Color
## Background of unique ability upgrade cards under the mouse.
@export var unique_card_hover_color: Color
## Text of unique ability upgrade cards.
@export var unique_card_font_color: Color
## Background of the violet Affliction cards (docs/specs/affliction.md).
@export var affliction_card_color: Color
## Background of Affliction cards under the mouse.
@export var affliction_card_hover_color: Color
## Text of Affliction cards.
@export var affliction_card_font_color: Color
## Frame drawn around the card that has the focus (gamepad and keyboard navigation).
@export var focus_border_color: Color
## Width of the focus frame, in pixels.
@export var focus_border_width: int
## Frame of the white cards (player stats).
@export var common_card_color: Color
## Frame of the white cards under the mouse.
@export var common_card_hover_color: Color
## Dark panel inside every card frame.
@export var card_panel_color: Color
## Card title.
@export var card_title_color: Color
## Card description.
@export var card_body_color: Color
## Price strip when the gold is enough, and when it is not.
@export var card_price_color: Color
@export var card_unaffordable_color: Color
## Entrance of the cards: they rise from below, tilted in a fan, and land one after
## another. It lasts `card_enter_total` seconds in all and the cards cannot be hovered
## or pressed until the last one lands, so a click spammed while fighting does not
## pick a card by accident (a press that began before that never counts).
@export var card_enter_total: float
## Delay between one card and the next.
@export var card_enter_stagger: float
## Pixels a card rises from, and degrees the outer cards tilt at the start.
@export var card_enter_rise: float
@export var card_enter_tilt: float
## Brightness of the cards that are not under the focus or the mouse.
@export var card_unfocused_brightness: float
## Green of the heal button: its frame and the health it gives.
@export var heal_color: Color
