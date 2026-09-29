extends GdUnitTestSuite
## Perfect dodge detection (docs/specs/perfect-dodge.md, AC1171–AC1176, AC1182).
## The dash lasts 0.2 s (12 frames); a hit is placed by waiting physics frames
## after try_dash.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CONFIG: PerfectDodgeConfig = preload("res://data/player/perfect_dodge_config.tres")
const FODDER: EnemyStats = preload("res://data/enemies/fodder_stats.tres")
const HIT: float = 8.0
const TOLERANCE: float = 0.0001

var _registry: EnemyRegistry
var _player: Player
var _attacker: Enemy
var _dodges: Array[Enemy] = []


func before_test() -> void:
	Session.character_class = load("res://data/classes/warrior/warrior.tres") as CharacterClassData
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_attacker = _spawn(null, Vector3(20.0, 0.0, 20.0))
	_dodges.clear()
	_player.perfect_dodge.perfect_dodged.connect(func(attacker: Enemy) -> void: _dodges.append(attacker))


func after_test() -> void:
	Session.character_class = null


func _spawn(stats: EnemyStats, at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	if stats != null:
		enemy.stats = stats
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	enemy.set_physics_process(false)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _dash() -> void:
	_player.dash.reset_cooldown()
	assert_bool(_player.dash.try_dash(Vector3.RIGHT)).is_true()


func test_ac1171_hit_evaded_is_emitted_only_by_a_hit_on_an_invulnerable_owner() -> void:
	var evaded: Array[float] = []
	_player.health.hit_evaded.connect(func(raw: float, _attacker: Enemy) -> void: evaded.append(raw))
	_player.health.is_invulnerable = true
	assert_float(_player.health.receive_hit_from(HIT, _attacker)).is_equal(0.0)
	assert_array(evaded).is_equal([HIT])
	# receive_hit and true damage never emit it.
	_player.health.receive_hit(HIT)
	_player.health.receive_true_damage(HIT)
	assert_int(evaded.size()).is_equal(1)
	_player.health.is_invulnerable = false
	assert_float(_player.health.receive_hit_from(HIT, _attacker)).is_greater(0.0)
	assert_int(evaded.size()).is_equal(1)
	# Dead: nothing, even if the flag is up.
	_player.health.receive_hit(100000.0)
	_player.health.is_invulnerable = true
	_player.health.receive_hit_from(HIT, _attacker)
	assert_int(evaded.size()).is_equal(1)


func test_ac1172_a_hit_early_in_the_dash_is_a_perfect_dodge() -> void:
	_dash()
	await _physics_frames(3)
	var before: float = _player.health.current_health
	assert_float(_player.health.receive_hit_from(HIT, _attacker)).is_equal(0.0)
	assert_array(_dodges).is_equal([_attacker])
	assert_float(_player.health.current_health).is_equal(before)


func test_ac1173_a_hit_after_the_window_is_dodged_but_not_perfect() -> void:
	var short: PerfectDodgeConfig = CONFIG.duplicate() as PerfectDodgeConfig
	short.perfect_window = 0.1
	_player.perfect_dodge.config = short
	_dash()
	await _physics_frames(9)
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_float(_player.health.receive_hit_from(HIT, _attacker)).is_equal(0.0)
	assert_int(_dodges.size()).is_equal(0)
	assert_float(CONFIG.effective_window(0.14)).is_equal_approx(0.14, TOLERANCE)
	assert_float(CONFIG.effective_window(0.5)).is_equal_approx(CONFIG.perfect_window, TOLERANCE)


func test_ac1174_one_per_dash_and_min_interval_between_dodges() -> void:
	_dash()
	await _physics_frames(3)
	_player.health.receive_hit_from(HIT, _attacker)
	_player.health.receive_hit_from(HIT, _attacker)
	assert_int(_dodges.size()).is_equal(1)
	await _physics_frames(14)
	assert_bool(_player.dash.is_dashing()).is_false()
	_dash()
	await _physics_frames(3)
	assert_float(_player.perfect_dodge.get_time_since_last()).is_less(CONFIG.min_interval)
	_player.health.receive_hit_from(HIT, _attacker)
	assert_int(_dodges.size()).is_equal(1)


func test_ac1175_invulnerability_without_a_dash_or_after_it_is_not_perfect() -> void:
	# The Parry riposte invulnerability: no running dash.
	_player.health.is_invulnerable = true
	_player.health.receive_hit_from(HIT, _attacker)
	assert_int(_dodges.size()).is_equal(0)
	_player.health.is_invulnerable = false
	# Right after the dash the hit lands.
	_dash()
	await _physics_frames(16)
	assert_bool(_player.health.is_invulnerable).is_false()
	assert_float(_player.health.receive_hit_from(HIT, _attacker)).is_greater(0.0)
	assert_int(_dodges.size()).is_equal(0)


func test_ac1176_a_fodder_hit_counts_too() -> void:
	var fodder: Enemy = _spawn(FODDER, Vector3(22.0, 0.0, 20.0))
	_dash()
	await _physics_frames(3)
	_player.health.receive_hit_from(FODDER.damage, fodder)
	assert_array(_dodges).is_equal([fodder])


func test_ac1182_the_config_is_valid_and_assigned_to_the_player() -> void:
	assert_float(CONFIG.perfect_window).is_greater(0.0)
	assert_float(CONFIG.enemy_time_scale).is_between(0.0, 1.0, false, false)
	assert_float(CONFIG.slow_duration).is_greater(0.0)
	assert_str(CONFIG.popup_text).is_not_empty()
	assert_object(_player.perfect_dodge.config).is_same(CONFIG)


func test_ac1183_a_perfect_dodge_kicks_the_field_of_view() -> void:
	var camera: ThirdPersonCamera = _player.get_camera()
	assert_float(CONFIG.fov_kick_return).is_greater(0.0)
	_dash()
	await _physics_frames(3)
	_player.health.receive_hit_from(HIT, _attacker)
	assert_array(_dodges).is_equal([_attacker])
	assert_float(camera.get_fov()).is_greater_equal(camera.get_base_fov() + CONFIG.fov_kick_degrees - 0.01)


func test_ac1173_the_window_counts_from_the_start_of_a_long_invulnerability() -> void:
	# Invulnerable for 1 s (the movement still lasts 0.2 s): only the first
	# perfect_window seconds of it are perfect.
	var upgrade := UpgradeData.new()
	upgrade.stat = PlayerStats.Stat.DASH_INVULNERABILITY
	upgrade.amount = 1.0 - _player.stats.get_stat(PlayerStats.Stat.DASH_INVULNERABILITY)
	_player.stats.add_upgrade(upgrade)
	_dash()
	await _physics_frames(30)
	assert_bool(_player.dash.is_dashing()).is_false()
	assert_bool(_player.health.is_invulnerable).is_true()
	assert_float(_player.health.receive_hit_from(HIT, _attacker)).is_equal(0.0)
	assert_int(_dodges.size()).is_equal(0)
	await _physics_frames(45)
	assert_bool(_player.health.is_invulnerable).is_false()
