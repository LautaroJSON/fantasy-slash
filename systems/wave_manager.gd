class_name WaveManager
extends Node
## Run loop: first the basic ability is chosen (from the class pool), then infinite waves: spawn a
## wave, wait until it is cleared, offer upgrade cards (player and ability,
## minus the banned ones, plus the red ban card every few waves), apply the
## choice and start the next wave. Every boss_wave_interval waves the wave is a
## random boss challenge, and only clearing one offers the golden (unique) cards.

## A boss challenge spawned; the HUD shows one bar per boss.
signal boss_wave_started(bosses: Array[Enemy])

@export var config: WaveConfig
@export var catalog: UpgradeCatalog
@export var ban_rules: CardBanRules
## Pace of the enemies: slower without Rage (docs/specs/enemy-pace.md).
@export var pace: EnemyPaceConfig
## Buff of the enemies once no upgrades are left (docs/specs/enemy-rage.md).
@export var rage: RageConfig
## One pool per regular enemy type (matched through EnemyPool.spawn_entry
## against WaveConfig.enemy_types; docs/specs/enemy-types.md).
@export var pools: Array[EnemyPool]
## One pool per boss challenge (matched through EnemyPool.challenge).
@export var boss_pools: Array[EnemyPool]
@export var registry: EnemyRegistry
## Attack turns and spawn-in of the enemies (docs/specs/enemy-group-ai.md).
@export var coordinator: AttackCoordinator
@export var player: Player
@export var run_state: RunState
@export var picker: UpgradePicker
@export var ability_picker: AbilityPicker
@export var ban_picker: UpgradeBanPicker

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Every card that can be offered; rebuilt when an ability is equipped.
var _card_pool: Array[UpgradeCard] = []
## Spawn points already used this wave, kept apart by min_spawn_separation.
var _spawned_this_wave: Array[Vector3] = []
## Enemies activated by the last spawn (reused buffer).
var _spawned_enemies: Array[Enemy] = []
## Enemies of each WaveConfig.enemy_types entry spawned this wave (reused buffer).
var _type_counts: Array[int] = []
## Pool of each WaveConfig.enemy_types entry, same order (filled in _ready).
var _type_pools: Array[EnemyPool] = []


func _ready() -> void:
	_rng.randomize()
	_match_type_pools()
	registry.enemy_killed.connect(_on_enemy_killed)
	registry.all_dead.connect(_on_all_dead)
	picker.upgrade_chosen.connect(_on_upgrade_chosen)
	picker.ban_requested.connect(_on_ban_requested)
	ability_picker.ability_chosen.connect(_on_ability_chosen)
	ban_picker.ban_chosen.connect(_on_ban_chosen)
	ban_picker.ban_cancelled.connect(_on_ban_cancelled)
	# Deferred so every node of the level (player position included) is ready.
	offer_abilities.call_deferred()


## Only the abilities of the player's class are offered.
func offer_abilities() -> void:
	ability_picker.show_choices(player.get_character_class().abilities.get_for_slot(AbilityData.Slot.BASIC))


## Every enemy of the wave spawns at the level given by WaveConfig. Boss waves
## draw one challenge at random.
func start_wave() -> void:
	if config.is_boss_wave(run_state.wave) and not config.boss_challenges.is_empty():
		var index: int = _rng.randi_range(0, config.boss_challenges.size() - 1)
		start_boss_wave(config.boss_challenges[index])
		return
	run_state.set_challenge("")
	_spawn_mix(config.enemies_per_wave)


## Seeds the draw of the wave mix (tests).
func set_seed(value: int) -> void:
	_rng.seed = value


## Spawns `challenge` as the current wave (public so tests can pick the challenge).
func start_boss_wave(challenge: BossChallengeData) -> void:
	run_state.set_challenge(challenge.title)
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
	if run_state.is_boss_wave():
		return UpgradeOffer.boss_offer(get_available_pool(), config.cards_per_offer, _rng)
	return UpgradeOffer.pick(UpgradeOffer.without_unique(get_available_pool()), config.cards_per_offer, _rng)


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


## Regular wave: each enemy's type is drawn from WaveConfig.enemy_types
## (EnemySpawnTable); an exhausted pool falls back to entry 0.
func _spawn_mix(count: int) -> void:
	_spawned_this_wave.clear()
	_spawned_enemies.clear()
	_type_counts.fill(0)
	for i: int in count:
		var index: int = EnemySpawnTable.pick(config.enemy_types, run_state.wave, _type_counts, _rng.randf())
		if _type_pools[index].available_count() == 0:
			index = 0
		var enemy: Enemy = _type_pools[index].acquire()
		if enemy == null:
			return
		_type_counts[index] += 1
		_place(enemy, _pick_spawn_position())


func _place(enemy: Enemy, at: Vector3) -> void:
	_spawned_this_wave.append(at)
	enemy.activate(at, player, config.enemy_level_for(run_state.wave))
	enemy.enrage(rage, run_state.get_rage_level())
	if pace != null:
		enemy.apply_pace(pace, run_state.get_rage_level())
	if coordinator != null:
		enemy.begin_spawn_in(coordinator.config)
	_spawned_enemies.append(enemy)


func _match_type_pools() -> void:
	_type_pools.clear()
	for entry: EnemySpawnEntry in config.enemy_types:
		var found: EnemyPool = null
		for type_pool: EnemyPool in pools:
			if type_pool.spawn_entry == entry:
				found = type_pool
		if found == null:
			push_error("WaveManager: no pool for enemy type '%s'." % entry.resource_path)
		_type_pools.append(found)
	_type_counts.resize(config.enemy_types.size())


func _pool_for(challenge: BossChallengeData) -> EnemyPool:
	for boss_pool: EnemyPool in boss_pools:
		if boss_pool.challenge == challenge:
			return boss_pool
	push_error("WaveManager: no boss pool for challenge '%s'." % challenge.title)
	return null


## Random point inside the spawn square, at least min_spawn_distance from the
## player and min_spawn_separation from this wave's other spawns.
func _pick_spawn_position() -> Vector3:
	var candidate := Vector3.ZERO
	for attempt: int in config.spawn_attempts:
		candidate = _random_point()
		if _is_far_from_player(candidate) and _is_apart_from_spawned(candidate):
			return candidate
	return candidate


func _random_point() -> Vector3:
	var extent: float = config.spawn_half_extent
	return Vector3(_rng.randf_range(-extent, extent), 0.0, _rng.randf_range(-extent, extent))


func _is_far_from_player(point: Vector3) -> bool:
	var offset := Vector2(point.x - player.global_position.x, point.z - player.global_position.z)
	return offset.length() >= config.min_spawn_distance


func _is_apart_from_spawned(point: Vector3) -> bool:
	for other: Vector3 in _spawned_this_wave:
		if point.distance_to(other) < config.min_spawn_separation:
			return false
	return true


func _on_ability_chosen(ability: AbilityData) -> void:
	player.basic_ability.equip(ability)
	_card_pool = UpgradeOffer.build_pool(catalog, ability.upgrades)
	_card_pool.append_array(ability.unique_upgrades)
	start_wave()


func _on_enemy_killed(_enemy: Enemy) -> void:
	run_state.add_kill()


## Sandbox skips the cards (upgrades are picked from the pause menu), and so
## does a run with every card maxed or banned (which also starts Rage);
## deferred so the last enemy finishes its own death before the pool reuses it.
func _on_all_dead() -> void:
	if player.health.is_dead():
		return
	if Session.is_sandbox():
		_advance_wave.call_deferred()
		return
	var offer: Array[UpgradeCard] = build_offer()
	if offer.is_empty():
		run_state.start_rage()
		_advance_wave.call_deferred()
		return
	picker.show_offer(offer, ban_rules.is_offered(run_state.wave, run_state.ban_count()))


func _on_upgrade_chosen(upgrade: UpgradeCard) -> void:
	player.apply_upgrade(upgrade)
	_advance_wave()


func _on_ban_requested() -> void:
	ban_picker.show_choices(get_available_pool(), run_state.ban_count(), ban_rules.max_bans)


func _on_ban_cancelled() -> void:
	picker.reopen()


## Banning replaces this wave's upgrade.
func _on_ban_chosen(card: UpgradeCard) -> void:
	run_state.ban(card)
	_advance_wave()


func _advance_wave() -> void:
	run_state.next_wave()
	start_wave()


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
		_place(minion, _pick_summon_position(boss.global_position, summon))
		if colmena != null:
			colmena.add_minion(minion)


func _pool_for_stats(stats: EnemyStats) -> EnemyPool:
	for i: int in config.enemy_types.size():
		if config.enemy_types[i].stats == stats:
			return _type_pools[i]
	return null


## Random point between summon.min_radius and max_radius from `center`, at
## least min_player_distance from the player, apart from this batch and inside
## the spawn square.
func _pick_summon_position(center: Vector3, summon: SummonData) -> Vector3:
	var candidate := center
	var extent: float = config.spawn_half_extent
	for attempt: int in config.spawn_attempts:
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(summon.min_radius, summon.max_radius)
		candidate = center + Vector3(sin(angle), 0.0, cos(angle)) * radius
		candidate = Vector3(clampf(candidate.x, -extent, extent), center.y, clampf(candidate.z, -extent, extent))
		var from_player := Vector2(candidate.x - player.global_position.x, candidate.z - player.global_position.z)
		if from_player.length() >= summon.min_player_distance and _is_apart_from_spawned(candidate):
			return candidate
	return candidate
