extends GdUnitTestSuite

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const PLAYER_STATS: PlayerStats = preload("res://data/classes/warrior/warrior_stats.tres")
const CONFIG: SwordSwingConfig = preload("res://data/classes/warrior/sword_swing_config.tres")
## Sweep time used by these tests: since the humanoid combo
## (docs/specs/humanoid-player-model.md) the basic attack no longer sweeps; the
## sweep is the Spin's dash slash, which passes its own arc and duration.
const SWEEP_DURATION: float = 0.25
const ANGLE_TOLERANCE: float = deg_to_rad(1.0)

var _registry: EnemyRegistry
var _player: Player
var _swing: SwordSwing
var _pivot: Node3D


func before_test() -> void:
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_swing = _player.get_node("SwordSwing") as SwordSwing
	_pivot = _player.get_node("Visual/SwordPivot") as Node3D


func _sweep() -> void:
	_swing.play(_player.stats.get_stat(PlayerStats.Stat.ATTACK_ARC), SWEEP_DURATION, 1.0)


func _half_arc() -> float:
	return deg_to_rad(_player.stats.get_stat(PlayerStats.Stat.ATTACK_ARC)) / 2.0


func test_ac89_the_blade_sweeps_across_the_attack_arc_horizontally() -> void:
	_sweep()
	var side: float = _swing.get_last_start_side()
	assert_bool(_swing.is_swinging()).is_true()
	assert_float(_swing.get_sweep_yaw()).is_equal_approx(side * _half_arc(), ANGLE_TOLERANCE)
	_swing.advance(SWEEP_DURATION / 2.0)
	assert_float(_pivot.rotation.x).is_equal_approx(CONFIG.blade_tilt, 0.0001)
	assert_float(absf(_swing.get_sweep_yaw())).is_less(_half_arc())
	_swing.advance(SWEEP_DURATION / 2.0)
	assert_float(_swing.get_sweep_yaw()).is_equal_approx(-side * _half_arc(), ANGLE_TOLERANCE)


func test_ac90_consecutive_swings_alternate_sides() -> void:
	_sweep()
	var first_side: float = _swing.get_last_start_side()
	_sweep()
	assert_float(_swing.get_last_start_side()).is_equal(-first_side)
	assert_float(_swing.get_sweep_yaw()).is_equal_approx(-first_side * _half_arc(), ANGLE_TOLERANCE)


func test_ac91_arc_upgrades_widen_the_sweep() -> void:
	var upgrade := UpgradeData.new()
	upgrade.stat = PlayerStats.Stat.ATTACK_ARC
	upgrade.amount = 30.0
	_player.stats.add_upgrade(upgrade)
	_sweep()
	var expected_half: float = deg_to_rad(PLAYER_STATS.attack_arc_degrees + 30.0) / 2.0
	assert_float(absf(_swing.get_sweep_yaw())).is_equal_approx(expected_half, ANGLE_TOLERANCE)


func test_ac92_the_sword_returns_to_the_rest_pose() -> void:
	var rest_position: Vector3 = _pivot.position
	var rest_rotation: Vector3 = _pivot.rotation
	_sweep()
	_swing.advance(SWEEP_DURATION)
	assert_bool(_swing.is_swinging()).is_false()
	_swing.advance(CONFIG.recover_duration)
	assert_vector(_pivot.position).is_equal_approx(rest_position, Vector3.ONE * 0.01)
	assert_vector(_pivot.rotation).is_equal_approx(rest_rotation, Vector3.ONE * 0.01)
