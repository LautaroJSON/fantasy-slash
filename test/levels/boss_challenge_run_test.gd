extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const SWIFT_STRIKE: AbilityData = preload("res://data/abilities/swift_strike/swift_strike.tres")
const RESET: AbilityUniqueUpgradeData = preload("res://data/abilities/swift_strike/unique/reset.tres")
const EXECUTE: AbilityUniqueUpgradeData = preload("res://data/abilities/swift_strike/unique/execute.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const TITAN: BossChallengeData = preload("res://data/enemies/boss_challenges/titan.tres")
const COLMENA: BossChallengeData = preload("res://data/enemies/boss_challenges/colmena.tres")
const COLMENA_BOSS: ColmenaConfig = preload("res://data/enemies/configs/colmena_boss.tres")
const PACE: EnemyPaceConfig = preload("res://data/enemies/enemy_pace_config.tres")
const VERDUGO: BossChallengeData = preload("res://data/enemies/boss_challenges/verdugo.tres")
const LETHAL_HIT: float = 100000.0
## Offers checked to be sure normal waves never draw a golden card. If golden
## cards leaked in (~25 % per offer), 30 clean offers would happen < 0.1 % of runs.
const OFFER_SAMPLES: int = 30

var _arena: Node3D
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _picker: UpgradePicker
var _wave_manager: WaveManager
var _wave_label: Label


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	_wave_label = _arena.get_node("UI/Hud").get_node("%WaveLabel") as Label
	get_tree().paused = true
	await get_tree().process_frame
	var ability_picker: AbilityPicker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	ability_picker.choose(SWIFT_STRIKE)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		# boss-colmena: a shielded boss (the Colmena) must die too.
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


## Clears waves 1-3 (choosing damage) so wave 4, a boss wave, is running.
func _reach_wave_4() -> void:
	for i: int in 3:
		_kill_all_active()
		_picker.choose(DAMAGE_UPGRADE)
	assert_int(_run_state.wave).is_equal(4)


## Clears the running wave and forces `challenge` as the next one (the offer of
## the cleared wave is simply replaced by the boss offer later).
func _force_boss(challenge: BossChallengeData) -> void:
	_kill_all_active()
	_wave_manager.start_boss_wave(challenge)


func _count_unique(cards: Array[UpgradeCard]) -> int:
	return UpgradeOffer.only_unique(cards).size()


func test_ac146_boss_waves_are_every_fourth() -> void:
	for wave: int in [4, 8, 12]:
		assert_bool(WAVE_CONFIG.is_boss_wave(wave)).is_true()
	for wave: int in [1, 3, 5]:
		assert_bool(WAVE_CONFIG.is_boss_wave(wave)).is_false()


func test_ac151_wave_4_spawns_only_level_2_bosses() -> void:
	_reach_wave_4()
	var active: Array[Enemy] = _registry.get_active()
	# boss-verdugo: any challenge of the list, with its own count.
	var challenge: BossChallengeData = null
	for candidate: BossChallengeData in WAVE_CONFIG.boss_challenges:
		if candidate.stats == active[0].stats:
			challenge = candidate
	assert_object(challenge).is_not_null()
	assert_int(active.size()).is_equal(challenge.count)
	for enemy: Enemy in active:
		assert_object(enemy.stats).is_same(challenge.stats)
		assert_int(enemy.level).is_equal(2)
	assert_bool(_run_state.is_boss_wave()).is_true()


func test_ac151_waves_3_and_5_are_regular_waves() -> void:
	for i: int in 2:
		_kill_all_active()
		_picker.choose(DAMAGE_UPGRADE)
	assert_int(_run_state.wave).is_equal(3)
	for enemy: Enemy in _registry.get_active():
		assert_bool(_is_regular_type(enemy.stats)).is_true()
	_kill_all_active()
	_picker.choose(DAMAGE_UPGRADE)
	_kill_all_active()
	_picker.choose(DAMAGE_UPGRADE)
	assert_int(_run_state.wave).is_equal(5)
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_per_wave)
	for enemy: Enemy in _registry.get_active():
		assert_bool(_is_regular_type(enemy.stats)).is_true()
	assert_bool(_run_state.is_boss_wave()).is_false()


## boss-colmena (AC545): there are no twins any more; the minions of one call
## must appear apart instead.
func test_ac152_ac545_summoned_minions_spawn_apart() -> void:
	var colmena: ColmenaBehavior = await _force_colmena_and_wait_summon()
	var minions: Array[Enemy] = colmena.get_minions()
	assert_int(minions.size()).is_greater_equal(2)
	for i: int in minions.size():
		for j: int in range(i + 1, minions.size()):
			assert_float(minions[i].global_position.distance_to(minions[j].global_position)).is_greater_equal(WAVE_CONFIG.min_spawn_separation - 0.01)


func test_ac153_normal_waves_never_offer_golden_cards() -> void:
	for i: int in OFFER_SAMPLES:
		assert_int(_count_unique(_wave_manager.build_offer())).is_equal(0)


func test_ac154_clearing_a_boss_offers_every_golden_card() -> void:
	_force_boss(TITAN)
	_kill_all_active()
	var offered: Array[UpgradeCard] = _picker.get_offered()
	assert_int(offered.size()).is_equal(WAVE_CONFIG.cards_per_offer)
	assert_bool(offered.has(EXECUTE)).is_true()
	assert_bool(offered.has(RESET)).is_true()
	assert_int(_count_unique(offered)).is_equal(2)


func test_ac155_boss_offer_is_normal_without_golden_cards_left() -> void:
	_run_state.ban(EXECUTE)
	_player.apply_upgrade(RESET)
	_force_boss(TITAN)
	_kill_all_active()
	var offered: Array[UpgradeCard] = _picker.get_offered()
	assert_int(offered.size()).is_equal(WAVE_CONFIG.cards_per_offer)
	assert_int(_count_unique(offered)).is_equal(0)


func test_ac156_hud_names_the_boss_challenge() -> void:
	assert_str(_wave_label.text).is_equal("Oleada 1")
	_reach_wave_4()
	assert_str(_wave_label.text).is_equal("Oleada 4 · %s" % _run_state.challenge_title)
	_kill_all_active()
	_picker.choose(DAMAGE_UPGRADE)
	assert_str(_wave_label.text).is_equal("Oleada 5")


## enemy-types: regular waves mix the types of WaveConfig.enemy_types.
func _is_regular_type(stats: EnemyStats) -> bool:
	for entry: EnemySpawnEntry in WAVE_CONFIG.enemy_types:
		if entry.stats == stats:
			return true
	return false


func test_ac456_bosses_come_out_of_the_floor_and_skip_the_turns() -> void:
	_force_boss(TITAN)
	for enemy: Enemy in _registry.get_active():
		assert_bool(enemy.is_spawning_in()).is_true()
		assert_bool(enemy.uses_attack_tokens()).is_false()


func test_ac474_the_verdugo_challenge() -> void:
	assert_bool(WAVE_CONFIG.boss_challenges.has(VERDUGO)).is_true()
	_force_boss(VERDUGO)
	var active: Array[Enemy] = _registry.get_active()
	assert_int(active.size()).is_equal(1)
	var boss: Enemy = active[0]
	assert_object(boss.stats).is_same(VERDUGO.stats)
	assert_str(boss.stats.display_name).is_equal("Verdugo")
	assert_bool(boss.stats.hud_health_bar).is_true()
	assert_bool(boss.is_spawning_in()).is_true()
	assert_bool(boss.uses_attack_tokens()).is_false()
	assert_bool(boss.get_behavior() is BossBehavior).is_true()


func test_ac490_ac540_the_boss_rotation() -> void:
	assert_bool(WAVE_CONFIG.boss_challenges.has(TITAN)).is_true()
	assert_bool(WAVE_CONFIG.boss_challenges.has(COLMENA)).is_true()
	assert_bool(WAVE_CONFIG.boss_challenges.has(VERDUGO)).is_true()
	assert_int(WAVE_CONFIG.boss_challenges.size()).is_equal(3)
	assert_object(_arena.get_node_or_null("BossPoolTitan")).is_not_null()
	assert_object(_arena.get_node_or_null("BossPoolColossus")).is_null()
	assert_bool(ResourceLoader.exists("res://data/enemies/colossus_stats.tres")).is_false()
	assert_object(_arena.get_node_or_null("BossPoolColmena")).is_not_null()
	assert_object(_arena.get_node_or_null("BossPoolTwins")).is_null()
	assert_bool(ResourceLoader.exists("res://data/enemies/twin_stats.tres")).is_false()


func test_ac491_the_titan_challenge() -> void:
	_force_boss(TITAN)
	var active: Array[Enemy] = _registry.get_active()
	assert_int(active.size()).is_equal(1)
	var boss: Enemy = active[0]
	assert_object(boss.stats).is_same(TITAN.stats)
	assert_str(boss.stats.display_name).is_equal("Titán")
	assert_bool(boss.stats.hud_health_bar).is_true()
	assert_bool(boss.is_spawning_in()).is_true()
	assert_bool(boss.uses_attack_tokens()).is_false()
	assert_bool(boss.get_behavior() is TitanBehavior).is_true()


func test_ac526_boss_waves_come_at_the_slow_pace() -> void:
	_force_boss(TITAN)
	for enemy: Enemy in _registry.get_active():
		# enemy-level-pace (AC560): bosses take the pace of their level too.
		assert_float(enemy.get_windup_scale()).is_equal_approx(PACE.windup_scale_for(enemy.level, 0), 0.0001)


## Forces the Colmena and waits until its first call brought minions.
func _force_colmena_and_wait_summon() -> ColmenaBehavior:
	_force_boss(COLMENA)
	# Clearing wave 1 opened the card picker, which pauses the game.
	get_tree().paused = false
	var colmena: ColmenaBehavior = _registry.get_active()[0].get_behavior() as ColmenaBehavior
	for i: int in 400:
		await get_tree().physics_frame
		if colmena.get_minion_count() > 0:
			break
	return colmena


func test_ac537_the_colmena_calls_minions_from_the_type_pools() -> void:
	var colmena: ColmenaBehavior = await _force_colmena_and_wait_summon()
	var boss: Enemy = colmena.enemy
	assert_str(boss.stats.display_name).is_equal("Colmena")
	assert_bool(boss.uses_attack_tokens()).is_false()
	var batch: SummonData = COLMENA_BOSS.summon_phase_one
	assert_int(colmena.get_minion_count()).is_equal(batch.stats.size())
	for minion: Enemy in colmena.get_minions():
		assert_bool(batch.stats.has(minion.stats)).is_true()
		assert_int(minion.level).is_equal(boss.level)
		assert_bool(minion.is_spawning_in()).is_true()
		assert_bool(minion.uses_attack_tokens()).is_true()
		var from_boss: float = Vector2(minion.global_position.x - boss.global_position.x, minion.global_position.z - boss.global_position.z).length()
		assert_float(from_boss).is_less_equal(batch.max_radius + 0.01)
		var from_player: float = Vector2(minion.global_position.x - _player.global_position.x, minion.global_position.z - _player.global_position.z).length()
		assert_float(from_player).is_greater_equal(batch.min_player_distance - 0.01)


func test_ac538_clearing_minions_then_the_colmena_ends_the_wave() -> void:
	var colmena: ColmenaBehavior = await _force_colmena_and_wait_summon()
	var boss: Enemy = colmena.enemy
	var minions: Array[Enemy] = []
	minions.assign(colmena.get_minions())
	for minion: Enemy in minions:
		minion.health.receive_hit(LETHAL_HIT)
	await get_tree().physics_frame
	assert_bool(colmena.is_exposed()).is_true()
	boss.health.receive_hit(LETHAL_HIT)
	assert_int(_registry.alive_count()).is_equal(0)
	var offered: Array[UpgradeCard] = _picker.get_offered()
	assert_bool(offered.has(EXECUTE)).is_true()


func test_ac539_the_colmena_dying_takes_its_minions() -> void:
	var colmena: ColmenaBehavior = await _force_colmena_and_wait_summon()
	var boss: Enemy = colmena.enemy
	assert_int(colmena.get_minion_count()).is_greater(0)
	boss.health.is_invulnerable = false
	boss.health.receive_hit(LETHAL_HIT)
	assert_int(_registry.alive_count()).is_equal(0)
	assert_bool(_picker.is_open()).is_true()
