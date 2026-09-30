class_name CoinSpawner
extends Node3D
## Drops a coin where an enemy dies and moves the coins on the floor
## (docs/specs/gold-system.md). Coins are pooled: past `max_coins_on_floor` a
## drop adds its value to the nearest coin, so no gold is lost.

@export var config: GoldConfig
@export var registry: EnemyRegistry
@export var wallet: GoldWallet
@export var player: Player
@export var run_state: RunState
@export var coin_scene: PackedScene
## Optional: with it and stage_change_auto_collect, the coins left are collected when a stage is cleared.
@export var wave_manager: WaveManager

var _coins: Array[Coin] = []


func _ready() -> void:
	for i: int in config.max_coins_on_floor:
		var coin: Coin = coin_scene.instantiate() as Coin
		add_child(coin)
		coin.setup(config)
		coin.collected.connect(_on_coin_collected)
		_coins.append(coin)
	registry.enemy_killed.connect(_on_enemy_killed)
	if wave_manager != null and config.stage_change_auto_collect:
		wave_manager.stage_cleared.connect(collect_all)


func _physics_process(delta: float) -> void:
	if player.health.is_dead():
		return
	var radius: float = player.stats.get_stat(PlayerStats.Stat.PICKUP_RADIUS)
	for coin: Coin in _coins:
		coin.advance(delta, player.global_position, radius)


## Number of coins on the floor.
func active_count() -> int:
	var count: int = 0
	for coin: Coin in _coins:
		if coin.is_active():
			count += 1
	return count


## Total gold lying on the floor.
func floor_gold() -> int:
	var total: int = 0
	for coin: Coin in _coins:
		if coin.is_active():
			total += coin.get_value()
	return total


## Drops a coin worth `value` at `at`.
func drop(value: int, at: Vector3) -> void:
	var free: Coin = _free_coin()
	if free != null:
		free.activate(value, at)
		return
	var nearest: Coin = _nearest_active(at)
	if nearest != null:
		nearest.add_value(value)


## Adds every coin on the floor to the wallet (stage change).
func collect_all() -> void:
	for coin: Coin in _coins:
		if coin.is_active():
			coin.collect()


## Gold of a coin dropped by `enemy` on the current wave.
func value_for(enemy: Enemy) -> int:
	var multiplier: float = 1.0
	if enemy.stats.hud_health_bar:
		multiplier = config.boss_multiplier
	elif enemy.stats.token_group == EnemyStats.AttackTokenGroup.FODDER:
		multiplier = config.fodder_multiplier
	return config.coin_value(run_state.wave, multiplier)


func _on_enemy_killed(enemy: Enemy) -> void:
	if Session.is_sandbox():
		return
	drop(value_for(enemy), enemy.global_position)


func _on_coin_collected(coin: Coin) -> void:
	wallet.add(coin.get_value())


func _free_coin() -> Coin:
	for coin: Coin in _coins:
		if not coin.is_active():
			return coin
	return null


func _nearest_active(at: Vector3) -> Coin:
	var best: Coin = null
	var best_distance: float = INF
	for coin: Coin in _coins:
		if not coin.is_active():
			continue
		var distance: float = coin.global_position.distance_squared_to(at)
		if distance < best_distance:
			best_distance = distance
			best = coin
	return best
