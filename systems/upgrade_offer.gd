class_name UpgradeOffer
extends RefCounted
## Pure selection of the upgrade cards offered after a wave.


## Every card that can be offered: the player's catalog plus the upgrades of
## the equipped abilities, all with the same weight.
static func build_pool(catalog: UpgradeCatalog, ability_upgrades: Array[AbilityUpgradeData]) -> Array[UpgradeCard]:
	var pool: Array[UpgradeCard] = []
	pool.append_array(catalog.upgrades)
	pool.append_array(ability_upgrades)
	return pool


## The pool minus the banned cards.
static func without(pool: Array[UpgradeCard], banned: Array[UpgradeCard]) -> Array[UpgradeCard]:
	var available: Array[UpgradeCard] = []
	for card: UpgradeCard in pool:
		if not banned.has(card):
			available.append(card)
	return available


## The pool without the golden (unique) cards: what normal waves offer.
static func without_unique(pool: Array[UpgradeCard]) -> Array[UpgradeCard]:
	var normal: Array[UpgradeCard] = []
	for card: UpgradeCard in pool:
		if not card is AbilityUniqueUpgradeData:
			normal.append(card)
	return normal


static func only_unique(pool: Array[UpgradeCard]) -> Array[UpgradeCard]:
	var golden: Array[UpgradeCard] = []
	for card: UpgradeCard in pool:
		if card is AbilityUniqueUpgradeData:
			golden.append(card)
	return golden


## Offer after a boss: every golden card available (up to `count`), filled up
## with normal cards. Without golden cards left it is a normal offer.
static func boss_offer(pool: Array[UpgradeCard], count: int, rng: RandomNumberGenerator) -> Array[UpgradeCard]:
	var offer: Array[UpgradeCard] = pick(only_unique(pool), count, rng)
	offer.append_array(pick(without_unique(pool), count - offer.size(), rng))
	return offer


## Returns up to `count` cards, never two of the same kind.
static func pick(pool: Array[UpgradeCard], count: int, rng: RandomNumberGenerator) -> Array[UpgradeCard]:
	var candidates: Array[UpgradeCard] = []
	candidates.assign(pool)
	_shuffle(candidates, rng)
	var offer: Array[UpgradeCard] = []
	for card: UpgradeCard in candidates:
		if offer.size() >= count:
			break
		if not _has_same_kind(offer, card):
			offer.append(card)
	return offer


## Fisher-Yates with the injected RNG, so results are reproducible by seed.
static func _shuffle(items: Array[UpgradeCard], rng: RandomNumberGenerator) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: UpgradeCard = items[i]
		items[i] = items[j]
		items[j] = swap


static func _has_same_kind(offer: Array[UpgradeCard], card: UpgradeCard) -> bool:
	for offered: UpgradeCard in offer:
		if offered.is_same_kind(card):
			return true
	return false
