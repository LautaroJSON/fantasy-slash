extends GdUnitTestSuite
## Coins on the floor and the shop of the arena (docs/specs/gold-system.md, AC1396-AC1425).

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const GOLD: GoldConfig = preload("res://data/economy/gold_config.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const LETHAL_HIT: float = 100000.0
const FAR: Vector3 = Vector3(60.0, 0.0, 0.0)

var _arena: Node3D
var _registry: EnemyRegistry
var _run_state: RunState
var _picker: UpgradePicker
var _wave_manager: WaveManager
var _player: Player
var _wallet: GoldWallet
var _spawner: CoinSpawner


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	preload("res://test/helpers/test_world.gd").without_horde(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	_player = _arena.get_node("Player") as Player
	_wallet = _arena.get_node("GoldWallet") as GoldWallet
	_spawner = _arena.get_node("CoinSpawner") as CoinSpawner
	get_tree().paused = true
	await get_tree().process_frame
	(_arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHIELD_CHARGE)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


## Sends the run to `wave`, starts it and kills everything: the shop opens.
func _open_shop_on_wave(wave: int) -> void:
	_kill_all_active()
	if _picker.is_open():
		_picker.close_shop()
	while _run_state.wave < wave:
		_run_state.next_wave()
	_wave_manager.start_wave()
	_kill_all_active()


func test_ac1396_a_dead_enemy_drops_a_coin_with_the_configured_value() -> void:
	var enemy: Enemy = _registry.get_active()[0]
	var expected: int = _spawner.value_for(enemy)
	enemy.health.is_invulnerable = false
	enemy.health.receive_hit(LETHAL_HIT)
	assert_int(_spawner.active_count()).is_equal(1)
	assert_int(_spawner.floor_gold()).is_equal(expected)


func test_ac1397_a_coin_stays_on_the_floor_out_of_reach() -> void:
	_spawner.drop(10, _player.global_position + FAR)
	for i: int in 30:
		_spawner._physics_process(1.0)
	assert_int(_spawner.active_count()).is_equal(1)
	assert_int(_wallet.get_gold()).is_equal(0)


func test_ac1398_a_coin_inside_the_radius_flies_to_the_player() -> void:
	var radius: float = _player.stats.get_stat(PlayerStats.Stat.PICKUP_RADIUS)
	_spawner.drop(12, _player.global_position + Vector3(radius - 0.5, 0.0, 0.0))
	for i: int in 60:
		_spawner._physics_process(0.1)
	assert_int(_spawner.active_count()).is_equal(0)
	assert_int(_wallet.get_gold()).is_equal(12)


func test_ac1399_a_coin_outside_the_radius_does_not_move() -> void:
	var at: Vector3 = _player.global_position + FAR
	_spawner.drop(5, at)
	_spawner._physics_process(0.5)
	for child: Node in _spawner.get_children():
		var coin: Coin = child as Coin
		if coin.is_active():
			assert_float(coin.global_position.x).is_equal_approx(at.x, 0.001)


func test_ac1402_a_drop_past_the_cap_keeps_the_total_gold() -> void:
	var extra: int = 5
	for i: int in GOLD.max_coins_on_floor + extra:
		_spawner.drop(2, _player.global_position + FAR + Vector3(float(i) * 0.01, 0.0, 0.0))
	assert_int(_spawner.active_count()).is_equal(GOLD.max_coins_on_floor)
	assert_int(_spawner.floor_gold()).is_equal(2 * (GOLD.max_coins_on_floor + extra))


func test_ac1416_clearing_a_stage_collects_the_coins_left() -> void:
	_spawner.drop(7, _player.global_position + FAR)
	_wave_manager.stage_cleared.emit()
	assert_int(_spawner.active_count()).is_equal(0)
	assert_int(_wallet.get_gold()).is_equal(7)


func test_ac1411_early_waves_still_give_free_picks() -> void:
	_kill_all_active()
	assert_bool(_picker.is_open()).is_true()
	assert_bool(_picker.is_shop()).is_false()


func test_ac1405_the_shop_sells_cards_for_gold() -> void:
	_open_shop_on_wave(5)
	assert_bool(_picker.is_shop()).is_true()
	var card: UpgradeCard = _picker.get_offered()[0]
	var price: int = _picker.get_price_of(card)
	assert_int(price).is_greater(0)
	var before: int = _player.count_upgrade(card)
	_picker.buy(card)
	assert_int(_player.count_upgrade(card)).is_equal(before)
	_wallet.add(price + 10)
	_wave_manager._refresh_shop()
	_picker.buy(card)
	assert_int(_player.count_upgrade(card)).is_equal(before + 1)
	assert_int(_wallet.get_gold()).is_equal(10)
	assert_bool(_picker.is_open()).is_true()


func test_ac1406_a_card_without_the_gold_is_disabled() -> void:
	_open_shop_on_wave(5)
	for button: Button in _picker.get_card_buttons():
		assert_bool(button.disabled).is_true()


func test_ac1407_closing_the_shop_without_buying_advances_the_wave() -> void:
	_open_shop_on_wave(5)
	var wave: int = _run_state.wave
	_picker.close_shop()
	assert_int(_run_state.wave).is_equal(wave + 1)
	assert_bool(_picker.is_open()).is_false()


func test_ac1408_reroll_costs_gold_and_gets_more_expensive() -> void:
	_open_shop_on_wave(5)
	var shop: ShopConfig = _wave_manager.shop
	_wallet.add(1000)
	_picker.request_reroll()
	assert_int(_wallet.get_gold()).is_equal(1000 - ShopPricing.reroll_price(0, shop))
	var after_first: int = _wallet.get_gold()
	_picker.request_reroll()
	assert_int(after_first - _wallet.get_gold()).is_equal(ShopPricing.reroll_price(1, shop))


func test_ac1409_rerolls_reset_on_the_next_wave() -> void:
	_open_shop_on_wave(5)
	_wallet.add(1000)
	_picker.request_reroll()
	_open_shop_on_wave(_run_state.wave + 1)
	var before: int = _wallet.get_gold()
	_picker.request_reroll()
	assert_int(before - _wallet.get_gold()).is_equal(ShopPricing.reroll_price(0, _wave_manager.shop))


func test_ac1410_heal_costs_gold_and_does_not_overheal() -> void:
	_open_shop_on_wave(5)
	_player.health.receive_true_damage(_player.health.max_health * 0.5)
	_wave_manager._refresh_shop()
	_wallet.add(1000)
	_picker.request_heal()
	var shop: ShopConfig = _wave_manager.shop
	assert_int(_wallet.get_gold()).is_equal(1000 - ShopPricing.heal_price(0, shop))
	assert_float(_player.health.get_health_ratio()).is_equal_approx(0.5 + shop.heal_fraction, 0.001)
	for i: int in 4:
		_picker.request_heal()
	assert_float(_player.health.get_health_ratio()).is_less_equal(1.0)


func test_ac1417_a_new_run_starts_without_gold() -> void:
	assert_int(_wallet.get_gold()).is_equal(0)
