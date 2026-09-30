class_name Coin
extends Node3D
## A gold coin on the floor (docs/specs/gold-system.md). It never expires: it
## waits until the player comes within the pickup radius, then flies to the
## player and adds its value to the wallet. Pooled by CoinSpawner.

signal collected(coin: Coin)

var _value: int = 0
var _active: bool = false
var _pull_speed: float = 0.0
var _config: GoldConfig


func setup(config: GoldConfig) -> void:
	_config = config
	deactivate()


func activate(value: int, at: Vector3) -> void:
	_value = value
	_pull_speed = 0.0
	global_position = at + Vector3(0.0, _config.rest_height, 0.0)
	_active = true
	show()


func deactivate() -> void:
	_active = false
	hide()


func is_active() -> bool:
	return _active


func get_value() -> int:
	return _value


func add_value(amount: int) -> void:
	_value += amount


## One frame. `player_position` and `radius` come from CoinSpawner (the player and its stat).
func advance(delta: float, player_position: Vector3, radius: float) -> void:
	if not _active:
		return
	rotate_y(_config.spin_speed * delta)
	var target: Vector3 = player_position + Vector3(0.0, _config.rest_height, 0.0)
	var offset: Vector3 = target - global_position
	var distance: float = offset.length()
	if distance <= _config.collect_distance:
		collect()
		return
	if distance > radius and _pull_speed <= 0.0:
		return
	_pull_speed += _config.magnet_acceleration * delta
	var step: float = maxf(_pull_speed, _config.magnet_speed) * delta
	global_position += offset / distance * minf(step, distance)


func collect() -> void:
	_active = false
	hide()
	collected.emit(self)
