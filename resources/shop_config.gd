class_name ShopConfig
extends Resource
## Prices of the shop opened after each wave (docs/specs/gold-system.md).
## Every price is `base × growth^n`, rounded.

## Waves up to this one still give free picks, as before the gold system.
@export var free_picks_until_wave: int
## Price of a card on wave 1 with no copies taken.
@export var card_base_price: int
## Growth of card prices per wave.
@export var card_growth_per_wave: float
## Growth of a card's price per copy already taken.
@export var card_growth_per_copy: float
## Multiplies the price of golden (unique) cards.
@export var unique_price_factor: float
## Price of the first reroll of a wave; it resets every wave.
@export var reroll_base_price: int
@export var reroll_growth: float
## Price of the first heal of a wave; it resets every wave.
@export var heal_base_price: int
@export var heal_growth: float
## Fraction of max health a heal gives.
@export var heal_fraction: float
## Price of the ban card, growing with the bans already used.
@export var ban_base_price: int
@export var ban_growth: float
