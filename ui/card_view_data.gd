class_name CardViewData
extends RefCounted
## What one upgrade card shows (docs/specs/upgrade-cards-redesign.md): built by
## the picker, drawn by UpgradeCardView.

var title: String = ""
## Small pill at the top right: roll tier, level or ascension.
var badge: String = ""
var badge_color: Color = Color.WHITE
var icon: Texture2D = null
## Description in BBCode.
var body: String = ""
## Gold price; -1 = no price strip (free pick).
var price: int = -1
var affordable: bool = true
## Frame color of the card type and the one under the mouse.
var frame_color: Color = Color.WHITE
var hover_color: Color = Color.WHITE
## Plain text of the card, for screen readers and tests.
var plain_text: String = ""
## Golden cards shimmer.
var shimmer: bool = false
