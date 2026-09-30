class_name WaveManager
extends Node
## Run loop: first the basic ability is chosen (from the class pool), then infinite waves: spawn a
## wave, wait until it is cleared, offer upgrade cards (player and ability,
## minus the banned ones, plus the red ban card every few waves), apply the
## choice and start the next wave. The last wave of each stage is a random boss
## challenge of that stage, and only clearing one offers the golden (unique)
## cards. The enemy types, the bosses and the spawn area come from the StageMap in
## play (docs/specs/stages.md).

## A boss challenge spawned; the HUD shows one bar per boss.
signal boss_wave_started(bosses: Array[Enemy])
## The boss of a stage that is not the last was cleared (cards included): no
## wave starts until the StageDirector moves the run to the next stage.
signal stage_cleared
## The sandbox cleared the arena: the HUD drops its boss bars
## (docs/specs/sandbox-arena-control.md).
signal bosses_cleared

@export var config: WaveConfig
@export var catalog: UpgradeCatalog
## Violet Affliction cards, offered next to the stat cards (docs/specs/affliction.md).
@export var affliction_catalog: AfflictionCatalog
@export var ban_rules: CardBanRules
## Pace of the enemies: slower without Rage (docs/specs/enemy-pace.md).
@export var pace: EnemyPaceConfig
## Buff of the enemies once no upgrades are left (docs/specs/enemy-rage.md).
@export var rage: RageConfig
## One pool per regular enemy type of any stage (matched through
## EnemyPool.spawn_entry against the stage's enemy_types; docs/specs/enemy-types.md).
@export var pools: Array[EnemyPool]
## Pool of the horde's fodder (docs/specs/fodder-minion.md); they do not go through `pools`.
@export var horde_pool: EnemyPool
## One pool per boss challenge (matched through EnemyPool.challenge).
@export var boss_pools: Array[EnemyPool]
@export var registry: EnemyRegistry
## Attack turns and spawn-in of the enemies (docs/specs/enemy-group-ai.md).
@export var coordinator: AttackCoordinator
## How walking enemies steer around the stage's obstacles (docs/specs/stages.md).
@export var obstacle_avoidance: ObstacleAvoidanceConfig
@export var player: Player
@export var run_state: RunState
@export var picker: UpgradePicker
@export var ability_picker: AbilityPicker
@export var ban_picker: UpgradeBanPicker
## Caps, respawn delay and default group of the sandbox (docs/specs/sandbox-arena-control.md).
@export var sandbox_config: SandboxConfig
## Gold and prices (docs/specs/gold-system.md). Without them every pick is free.
@export var wallet: GoldWallet
@export var shop: ShopConfig
## Quality tiers of the white cards (docs/specs/upgrade-cards-redesign.md).
@export var rolls: RollConfig

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Every card that can be offered; rebuilt when an ability is equipped.
var _card_pool: Array[UpgradeCard] = []
## Spawn points already used this wave, kept apart by min_spawn_separation.
var _spawned_this_wave: Array[Vector3] = []
## Enemies activated by the last spawn (reused buffer).
var _spawned_enemies: Array[Enemy] = []
## Enemies of each StageData.enemy_types entry spawned this wave (reused buffer).
var _type_counts: Array[int] = []
## Pool of each StageData.enemy_types entry, same order (filled by set_stage).
var _type_pools: Array[EnemyPool] = []
## Cards still to pick after the current wave (WaveConfig.picks_for_wave).
var _picks_left: int = 0
## Shop of the current wave (docs/specs/gold-system.md): open, offer on sale, and
## the rerolls and heals bought this wave.
var _shop_open: bool = false
var _shop_offer: Array[UpgradeCard] = []
var _rerolls: int = 0
var _heals: int = 0
## Fodder still to come out this wave, and the ones alive now.
var _horde_remaining: int = 0
var _horde_alive: int = 0
## Seconds until the next group comes out (< 0 = none scheduled).
var _refill_left: float = -1.0
## StageMap in play, set by the StageDirector, and whether it is the last one.
var _stage: StageMap
var _stage_is_last: bool = true
## What the sandbox can summon (built on first use) and the group in play.
var _roster: SandboxRoster
var _sandbox_request: SandboxSpawnRequest
## Seconds until the sandbox group comes back (< 0 = none scheduled).
var _sandbox_respawn_left: float = -1.0


func _ready() -> void:
	_rng.randomize()
	registry.enemy_killed.connect(_on_enemy_killed)
	registry.all_dead.connect(_on_all_dead)
	picker.upgrade_chosen.connect(_on_upgrade_chosen)
	picker.ban_requested.connect(_on_ban_requested)
	picker.upgrade_bought.connect(_on_upgrade_bought)
	picker.reroll_requested.connect(_on_reroll_requested)
	picker.heal_requested.connect(_on_heal_requested)
	picker.shop_closed.connect(_on_shop_closed)
	ability_picker.ability_chosen.connect(_on_ability_chosen)
	ban_picker.ban_chosen.connect(_on_ban_chosen)
	ban_picker.ban_cancelled.connect(_on_ban_cancelled)
	# Deferred so every node of the level (player position included) is ready.
	offer_abilities.call_deferred()


## Only the abilities of the player's class are offered.
func offer_abilities() -> void:
	ability_picker.show_choices(player.get_character_class().abilities.get_for_slot(AbilityData.Slot.BASIC))


## The StageDirector hands over the stage in play (docs/specs/stages.md):
## its enemy types, bosses and spawn area are used from now on.
func set_stage(stage: StageMap, is_last: bool) -> void:
	_stage = stage
	_stage_is_last = is_last
	_match_type_pools()


func get_stage() -> StageMap:
	return _stage


## Every enemy of the wave spawns at the level given by WaveConfig. The boss
## wave of the stage draws one of its challenges at random.
func start_wave() -> void:
	var stage_data: StageData = _stage.get_data()
	if _is_boss_wave() and not stage_data.boss_challenges.is_empty():
		var index: int = _rng.randi_range(0, stage_data.boss_challenges.size() - 1)
		start_boss_wave(stage_data.boss_challenges[index])
		return
	run_state.set_challenge("")
	_spawn_mix(config.enemies_for_wave(run_state.wave))
	_start_horde()


## Seeds the draw of the wave mix (tests).
func set_seed(value: int) -> void:
	_rng.seed = value


## Spawns `challenge` as the current wave (public so tests can pick the challenge).
func start_boss_wave(challenge: BossChallengeData) -> void:
	run_state.set_challenge(challenge.title)
	_horde_remaining = 0
	_refill_left = -1.0
	_spawn_from(_pool_for(challenge), challenge.count)
	for boss: Enemy in _spawned_enemies:
		if not boss.summon_requested.is_connected(_on_summon_requested):
			boss.summon_requested.connect(_on_summon_requested)
	boss_wave_started.emit(_spawned_enemies)


## Every card of the run, banned ones included.
func get_card_pool() -> Array[UpgradeCard]:
	return _card_pool


## Cards that can still be offered: the pool minus the banned ones and the
## cards already at their cap (max_stacks / max_level).
func get_available_pool() -> Array[UpgradeCard]:
	var available: Array[UpgradeCard] = []
	for card: UpgradeCard in UpgradeOffer.without(_card_pool, run_state.get_banned()):
		if not player.is_maxed(card):
			available.append(card)
	return available


## Golden cards only after a boss wave; the rest of the time they are left out.
func build_offer() -> Array[UpgradeCard]:
	var picked: Array[UpgradeCard]
	if run_state.is_boss_wave():
		picked = UpgradeOffer.boss_offer(get_available_pool(), config.cards_per_offer, _rng)
	else:
		picked = UpgradeOffer.pick(UpgradeOffer.without_unique(get_available_pool()), config.cards_per_offer, _rng)
	return UpgradeRoll.roll_offer(picked, rolls, _rng)


func _spawn_from(source: EnemyPool, count: int) -> void:
	_spawned_this_wave.clear()
	_spawned_enemies.clear()
	if source == null:
		return
	for i: int in count:
		var enemy: Enemy = source.acquire()
		if enemy == null:
			return
		_place(enemy, _pick_spawn_position())


## Regular wave: each enemy's type is drawn from the stage's enemy_types
## (EnemySpawnTable); an exhausted pool falls back to entry 0.
func _spawn_mix(count: int) -> void:
	_spawned_this_wave.clear()
	_spawned_enemies.clear()
	_type_counts.fill(0)
	var types: Array[EnemySpawnEntry] = _stage.get_data().enemy_types
	for i: int in count:
		var index: int = EnemySpawnTable.pick(types, run_state.wave, _type_counts, _rng.randf())
		if _type_pools[index].available_count() == 0:
			index = 0
		var enemy: Enemy = _type_pools[index].acquire()
		if enemy == null:
			return
		_type_counts[index] += 1
		_place(enemy, _pick_spawn_position())


func _place(enemy: Enemy, at: Vector3) -> void:
	_place_at_level(enemy, at, config.enemy_level_for(run_state.wave), run_state.get_rage_level())


func _place_at_level(enemy: Enemy, at: Vector3, level: int, rage_level: int) -> void:
	_spawned_this_wave.append(at)
	enemy.activate(at, player, level)
	enemy.set_obstacles(_stage.get_obstacles(), obstacle_avoidance)
	enemy.enrage(rage, rage_level)
	if pace != null:
		enemy.apply_pace(pace, rage_level)
	if coordinator != null:
		enemy.begin_spawn_in(coordinator.config)
	_spawned_enemies.append(enemy)


func _match_type_pools() -> void:
	_type_pools.clear()
	var types: Array[EnemySpawnEntry] = _stage.get_data().enemy_types
	for entry: EnemySpawnEntry in types:
		var found: EnemyPool = null
		for type_pool: EnemyPool in pools:
			if type_pool.spawn_entry == entry:
				found = type_pool
		if found == null:
			push_error("WaveManager: no pool for enemy type '%s'." % entry.resource_path)
		_type_pools.append(found)
	_type_counts.resize(types.size())


func _pool_for(challenge: BossChallengeData) -> EnemyPool:
	for boss_pool: EnemyPool in boss_pools:
		if boss_pool.challenge == challenge:
			return boss_pool
	push_error("WaveManager: no boss pool for challenge '%s'." % challenge.title)
	return null


## Random point of the stage's spawn area, min_spawn_distance to the layout's
## max_spawn_distance (0 = no cap) from the player and min_spawn_separation from
## this wave's other spawns.
func _pick_spawn_position() -> Vector3:
	var candidate := Vector3.ZERO
	for attempt: int in config.spawn_attempts:
		candidate = _stage.random_spawn_point(_rng)
		if _is_in_player_ring(candidate) and _is_apart_from_spawned(candidate):
			return candidate
	return candidate


func _is_in_player_ring(point: Vector3) -> bool:
	var distance: float = Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length()
	var max_distance: float = _stage.get_data().layout.max_spawn_distance
	return distance >= config.min_spawn_distance and (max_distance <= 0.0 or distance <= max_distance)


func _is_apart_from_spawned(point: Vector3) -> bool:
	for other: Vector3 in _spawned_this_wave:
		if point.distance_to(other) < config.min_spawn_separation:
			return false
	return true


func _on_ability_chosen(ability: AbilityData) -> void:
	player.basic_ability.equip(ability)
	_card_pool = UpgradeOffer.build_pool(catalog, ability.upgrades)
	_card_pool.append_array(ability.unique_upgrades)
	if affliction_catalog != null:
		_card_pool.append_array(affliction_catalog.cards)
	if Session.is_sandbox():
		spawn_sandbox(Session.get_sandbox_request(sandbox_config))
		return
	start_wave()


func _on_enemy_killed(enemy: Enemy) -> void:
	run_state.add_kill()
	if _is_horde_member(enemy):
		_horde_alive -= 1
		if _horde_remaining > 0 and _horde_alive <= config.horde.refill_below and _refill_left < 0.0:
			_refill_left = config.horde.refill_delay


## Sandbox has no waves: the group comes back only with Respawn (upgrades are
## picked from the pause menu). A run with every card maxed or banned skips the
## cards and starts Rage; deferred so the last enemy finishes its own death
## before the pool reuses it.
func _on_all_dead() -> void:
	if player.health.is_dead():
		return
	if Session.is_sandbox():
		_schedule_sandbox_respawn()
		return
	if _horde_remaining > 0:
		_refill_left = -1.0
		spawn_horde_group.call_deferred()
		return
	var offer: Array[UpgradeCard] = build_offer()
	if offer.is_empty():
		run_state.start_rage()
		_advance_wave.call_deferred()
		return
	if is_shop_wave():
		_open_shop(offer)
		return
	_picks_left = config.picks_for_wave(run_state.wave, run_state.is_boss_wave())
	picker.show_offer(offer, ban_rules.is_offered(run_state.wave, run_state.ban_count()))


## True when this wave's cards are sold (docs/specs/gold-system.md): the wave is
## past the free picks and the level has a wallet and prices.
func is_shop_wave() -> bool:
	return shop != null and wallet != null and run_state.wave > shop.free_picks_until_wave


func is_shop_open() -> bool:
	return _shop_open


func _open_shop(offer: Array[UpgradeCard]) -> void:
	_shop_open = true
	_shop_offer = offer
	_rerolls = 0
	_heals = 0
	_refresh_shop()


## Shows the shop again with current prices, gold and offer.
func _refresh_shop() -> void:
	var prices: Array[int] = []
	for card: UpgradeCard in _shop_offer:
		prices.append(ShopPricing.card_price(card, run_state.wave, player.count_upgrade(card), shop, rolls))
	var heal_price: int = -1
	if player.health.get_health_ratio() < 1.0:
		heal_price = ShopPricing.heal_price(_heals, shop)
	var heal_amount: int = roundi(minf(player.health.max_health * shop.heal_fraction, player.health.max_health - player.health.current_health))
	var ban_price: int = -1
	if ban_rules.is_offered(run_state.wave, run_state.ban_count()):
		ban_price = ShopPricing.ban_price(run_state.ban_count(), shop)
	picker.show_shop(_shop_offer, prices, wallet.get_gold(), ShopPricing.reroll_price(_rerolls, shop), heal_price, ban_price, heal_amount)


func _on_upgrade_bought(card: UpgradeCard) -> void:
	var price: int = ShopPricing.card_price(card, run_state.wave, player.count_upgrade(card), shop, rolls)
	if not wallet.try_spend(price):
		return
	player.apply_upgrade(card)
	_shop_offer.erase(card)
	_refresh_shop()


func _on_reroll_requested() -> void:
	if not wallet.try_spend(ShopPricing.reroll_price(_rerolls, shop)):
		return
	_rerolls += 1
	_shop_offer = build_offer()
	_refresh_shop()


func _on_heal_requested() -> void:
	if not wallet.try_spend(ShopPricing.heal_price(_heals, shop)):
		return
	_heals += 1
	player.health.heal(player.health.max_health * shop.heal_fraction)
	_refresh_shop()


func _on_shop_closed() -> void:
	_shop_open = false
	_shop_offer = []
	_advance_wave()


func _on_upgrade_chosen(upgrade: UpgradeCard) -> void:
	player.apply_upgrade(upgrade)
	_finish_pick()


## One pick is spent: the next one opens a fresh offer (without the ban card),
## and the wave advances when none is left or nothing can be offered
## (Rage only starts on the first offer, docs/specs/early-power-curve.md).
func _finish_pick() -> void:
	_picks_left -= 1
	if _picks_left <= 0:
		_advance_wave()
		return
	var offer: Array[UpgradeCard] = build_offer()
	if offer.is_empty():
		_advance_wave()
		return
	picker.show_offer(offer, false)


func _on_ban_requested() -> void:
	ban_picker.show_choices(get_available_pool(), run_state.ban_count(), ban_rules.max_bans)


func _on_ban_cancelled() -> void:
	picker.reopen()


## Banning replaces one of this wave's picks; in the shop it costs gold instead.
func _on_ban_chosen(card: UpgradeCard) -> void:
	if _shop_open:
		if not wallet.try_spend(ShopPricing.ban_price(run_state.ban_count(), shop)):
			picker.reopen()
			return
		run_state.ban(card)
		_shop_offer.erase(card)
		_refresh_shop()
		return
	run_state.ban(card)
	_finish_pick()


## After the boss of a stage that is not the last, the run waits for the
## portal (stage_cleared); after the boss of the last stage, a new lap of its
## waves starts (docs/specs/stages.md).
func _advance_wave() -> void:
	if run_state.is_boss_wave() and not _stage_is_last:
		stage_cleared.emit()
		return
	var lap_over: bool = run_state.is_boss_wave()
	run_state.next_wave()
	if lap_over:
		run_state.set_stage(run_state.get_stage_index())
	start_wave()


func _is_boss_wave() -> bool:
	return run_state.is_stage_boss_wave(_stage.get_data().regular_waves)


## A boss calls minions (docs/specs/boss-colmena.md): each one comes from the
## pool of its type (free during a boss wave), around the boss and away from
## the player, with the wave's level, Rage, pace and spawn-in. Entries whose
## pool is exhausted are skipped.
func _on_summon_requested(boss: Enemy, summon: SummonData) -> void:
	var colmena: ColmenaBehavior = boss.get_behavior() as ColmenaBehavior
	_spawned_this_wave.clear()
	for stats: EnemyStats in summon.stats:
		var source: EnemyPool = _pool_for_stats(stats)
		if source == null or source.available_count() == 0:
			continue
		var minion: Enemy = source.acquire()
		_place_minion(minion, _pick_summon_position(boss.global_position, summon))
		if colmena != null:
			colmena.add_minion(minion)


## Any regular pool of the run (not only the stage's types) can lend a minion.
func _pool_for_stats(stats: EnemyStats) -> EnemyPool:
	for type_pool: EnemyPool in pools:
		if type_pool.spawn_entry != null and type_pool.spawn_entry.stats == stats:
			return type_pool
	return null


## Random point between summon.min_radius and max_radius from `center`, at
## least min_player_distance from the player, apart from this batch and inside
## the stage's spawn area.
func _pick_summon_position(center: Vector3, summon: SummonData) -> Vector3:
	var candidate := center
	for attempt: int in config.spawn_attempts:
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(summon.min_radius, summon.max_radius)
		candidate = center + Vector3(sin(angle), 0.0, cos(angle)) * radius
		candidate = _stage.clamp_inside(Vector3(candidate.x, center.y, candidate.z))
		var from_player := Vector2(candidate.x - player.global_position.x, candidate.z - player.global_position.z)
		if from_player.length() >= summon.min_player_distance and _is_apart_from_spawned(candidate):
			return candidate
	return candidate


## In the sandbox a minion takes the group's level and immortality, never the
## dummy option (docs/specs/sandbox-arena-control.md).
func _place_minion(minion: Enemy, at: Vector3) -> void:
	if _sandbox_request == null:
		_place(minion, at)
		return
	_place_at_level(minion, at, _sandbox_request.level, 0)
	minion.set_sandbox_options(_sandbox_request.immortal, false, sandbox_config.dummy_turn_speed)


func _physics_process(delta: float) -> void:
	_advance_horde_refill(delta)
	_advance_sandbox_respawn(delta)


## Everything the sandbox can summon (built on first use from the pools).
func get_roster() -> SandboxRoster:
	if _roster == null:
		_roster = SandboxRoster.build(pools, horde_pool, boss_pools, sandbox_config)
	return _roster


## Sandbox (docs/specs/sandbox-arena-control.md): replaces the enemies in play
## with `request` (its entry, count, level and options), without Rage and
## around the player like a wave. Bosses get their HUD bars and summons.
func spawn_sandbox(request: SandboxSpawnRequest) -> void:
	clear_arena()
	_sandbox_request = request
	var entry: SandboxRoster.Entry = get_roster().get_entry(request.entry)
	_spawned_this_wave.clear()
	_spawned_enemies.clear()
	for i: int in mini(request.count, entry.max_count):
		var enemy: Enemy = entry.pool.acquire()
		if enemy == null:
			break
		_place_at_level(enemy, _pick_spawn_position(), request.level, 0)
		enemy.set_sandbox_options(request.immortal, request.dummy, sandbox_config.dummy_turn_speed)
	if entry.is_boss:
		_start_sandbox_bosses(entry)
	else:
		run_state.set_challenge("")


## Sends every active enemy back to its pool without counting kills.
func clear_arena() -> void:
	_sandbox_respawn_left = -1.0
	_horde_remaining = 0
	_refill_left = -1.0
	while registry.alive_count() > 0:
		registry.get_active()[0].return_to_pool()
	run_state.set_challenge("")
	bosses_cleared.emit()


func is_sandbox_respawn_scheduled() -> bool:
	return _sandbox_respawn_left >= 0.0


func _start_sandbox_bosses(entry: SandboxRoster.Entry) -> void:
	run_state.set_challenge(entry.title)
	for boss: Enemy in _spawned_enemies:
		if not boss.summon_requested.is_connected(_on_summon_requested):
			boss.summon_requested.connect(_on_summon_requested)
	boss_wave_started.emit(_spawned_enemies)


func _schedule_sandbox_respawn() -> void:
	if _sandbox_request != null and _sandbox_request.respawn:
		_sandbox_respawn_left = sandbox_config.respawn_delay


func _advance_sandbox_respawn(delta: float) -> void:
	if _sandbox_respawn_left < 0.0:
		return
	_sandbox_respawn_left -= delta
	if _sandbox_respawn_left <= 0.0:
		spawn_sandbox(_sandbox_request)


## Fodder still to come out this wave.
func get_horde_remaining() -> int:
	return _horde_remaining


## Fodder alive now.
func get_horde_alive() -> int:
	return _horde_alive


## Sets the fodder total of the wave that starts and brings out its first groups.
func _start_horde() -> void:
	_horde_remaining = 0
	_horde_alive = 0
	_refill_left = -1.0
	if config.horde == null or horde_pool == null:
		return
	_horde_remaining = config.horde.total_for(run_state.wave, _is_boss_wave())
	for i: int in config.horde.initial_groups:
		spawn_horde_group()


## Brings out one group of fodder around a point away from the player and from
## this wave's spawns, cut to what is left and to max_alive. Returns how many
## came out.
func spawn_horde_group() -> int:
	if config.horde == null or horde_pool == null or _horde_remaining <= 0:
		return 0
	var horde: HordeConfig = config.horde
	var count: int = mini(horde.group_size(_rng.randf()), mini(_horde_remaining, horde.max_alive - _horde_alive))
	if count <= 0:
		return 0
	var center: Vector3 = _pick_spawn_position()
	var spawned: int = 0
	for i: int in count:
		var fodder: Enemy = horde_pool.acquire()
		if fodder == null:
			break
		var at: Vector3 = center + horde.member_offset(i)
		_place(fodder, _stage.clamp_inside(Vector3(at.x, center.y, at.z)))
		spawned += 1
	_horde_remaining -= spawned
	_horde_alive += spawned
	return spawned


func _advance_horde_refill(delta: float) -> void:
	if _refill_left < 0.0:
		return
	_refill_left -= delta
	if _refill_left <= 0.0:
		_refill_left = -1.0
		spawn_horde_group()


func _is_horde_member(enemy: Enemy) -> bool:
	return config.horde != null and enemy.stats == config.horde.entry.stats
