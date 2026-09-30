extends GdUnitTestSuite
## El Rey (docs/specs/boss-king.md). Damage 20; a hit takes 20 × its multiplier minus the player defense.
## Single-move tests use a copy of its stats whose BossConfig keeps one move.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const KING: EnemyStats = preload("res://data/enemies/king_stats.tres")
const BOSS: BossConfig = preload("res://data/enemies/configs/king_boss.tres")
const RAGE: RageConfig = preload("res://data/enemies/rage/rage_config.tres")
const SLASH: int = 0
const THRUST: int = 1
const SPIN: int = 2
const OATH: int = 3
const JUDGMENT: int = 4

var _registry: EnemyRegistry
var _player: Player
## Health of the player at the start of a test.
var _start: float = 0.0



func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(80.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_start = _player.health.current_health


## The King with only move `only` (−1 keeps the whole repertoire).
func _stats(only: int) -> EnemyStats:
	if only < 0:
		return KING
	var stats: EnemyStats = KING.duplicate() as EnemyStats
	var config: BossConfig = BOSS.duplicate() as BossConfig
	config.moves = [BOSS.moves[only]] as Array[BossMoveData]
	stats.behavior_config = config
	return stats


func _spawn(only: int, at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = _stats(only)
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _boss(enemy: Enemy) -> KingBehavior:
	return enemy.get_behavior() as KingBehavior


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Damage the player takes from a King hit of `multiplier`.
func _dmg(multiplier: float) -> float:
	return KING.damage * multiplier - _player.health.defense


## Takes the boss (with the player out of every move's reach) into phase 2.
func _enter_phase_two(enemy: Enemy) -> void:
	enemy.health.receive_hit(enemy.health.max_health * 0.5 + enemy.health.defense + 1.0)
	await _physics_frames(int(BOSS.phase_two.transition_time * 60.0) + 5)


## Frames (out of `count`) in which the player's health dropped, and by how much each time.
func _hits_in(count: int) -> Array[float]:
	var hits: Array[float] = []
	var last: float = _player.health.current_health
	for frame: int in count:
		await get_tree().physics_frame
		if _player.health.current_health < last:
			hits.append(last - _player.health.current_health)
			last = _player.health.current_health
	return hits


func test_ac1244_triple_slash_hits_three_times() -> void:
	_spawn(SLASH, Vector3(0.0, 0.0, -3.0))
	await _physics_frames(30)
	assert_float(_player.health.current_health).is_equal_approx(_start, 0.0001)
	await _physics_frames(30)
	assert_float(_player.health.current_health).is_equal_approx(_start - _dmg(1.0), 0.0001)
	await _physics_frames(50)
	assert_float(_player.health.current_health).is_equal_approx(_start - 2.0 * _dmg(1.0), 0.0001)
	await _physics_frames(75)
	assert_float(_player.health.current_health).is_equal_approx(_start - 2.0 * _dmg(1.0) - _dmg(1.7), 0.0001)


func test_ac1245_each_slash_is_checked_on_its_own_and_phase_two_adds_a_fourth() -> void:
	var first: Enemy = _spawn(SLASH, Vector3(0.0, 0.0, -3.0))
	await _physics_frames(60)
	assert_float(_player.health.current_health).is_equal_approx(_start - _dmg(1.0), 0.0001)
	_player.global_position = Vector3(14.0, 0.0, 0.0)
	await _physics_frames(150)
	assert_float(_player.health.current_health).is_equal_approx(_start - _dmg(1.0), 0.0001)
	first.deactivate()
	var enemy: Enemy = _spawn(SLASH, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	_player.global_position = Vector3.ZERO
	_player.health.heal(1000.0)
	enemy.global_position = Vector3(0.0, 0.0, -3.0)
	var hits: Array[float] = await _hits_in(240)
	assert_int(hits.size()).is_equal(4)


func test_ac1246_the_thrust_shows_a_strip_and_locks_its_direction() -> void:
	var enemy: Enemy = _spawn(THRUST, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(20)
	assert_int(enemy.get_telegraph().get_shape()).is_equal(GroundTelegraph.Shape.LINE)
	await _physics_frames(35)
	var locked: Vector3 = _boss(enemy).get_thrust_direction()
	assert_float(locked.z).is_greater(0.99)
	var thrust: ThrustMoveData = BOSS.moves[THRUST] as ThrustMoveData
	await _physics_frames(30)
	assert_float(enemy.global_position.z).is_less_equal(-6.0 + thrust.thrust_distance + 0.1)
	assert_float(enemy.global_position.z).is_greater(-3.0)


func test_ac1247_the_thrust_hits_once_and_can_be_sidestepped_or_dashed() -> void:
	_spawn(THRUST, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(90)
	assert_float(_player.health.current_health).is_equal_approx(_start - _dmg(1.8), 0.0001)
	await _physics_frames(30)
	assert_float(_player.health.current_health).is_equal_approx(_start - _dmg(1.8), 0.0001)


func test_ac1247_sidestepping_or_dashing_avoids_the_thrust() -> void:
	_spawn(THRUST, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(40)
	_player.global_position = Vector3(5.0, 0.0, 0.0)
	await _physics_frames(80)
	assert_float(_player.health.current_health).is_equal_approx(_start, 0.0001)


func test_ac1247_dash_iframes_avoid_the_thrust() -> void:
	_spawn(THRUST, Vector3(0.0, 0.0, -6.0))
	_player.health.is_invulnerable = true
	await _physics_frames(90)
	assert_float(_player.health.current_health).is_equal_approx(_start, 0.0001)


func test_ac1248_phase_two_chains_a_second_thrust() -> void:
	var enemy: Enemy = _spawn(THRUST, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	enemy.global_position = Vector3(0.0, 0.0, -8.0)
	var hits: Array[float] = await _hits_in(300)
	assert_int(hits.size()).is_equal(2)


func test_ac1249_the_spin_hits_even_a_jumper_but_not_dash_iframes_or_distance() -> void:
	# A 0.5 m platform keeps the player's feet well above the floor.
	var platform: StaticBody3D = auto_free(TestWorld.make_box(Vector3(2.0, 0.5, 2.0), Vector3(0.0, 0.25, 0.0)))
	add_child(platform)
	_player.global_position = Vector3(0.0, 0.6, 0.0)
	var enemy: Enemy = _spawn(SPIN, Vector3(0.0, 0.0, -3.0))
	await _physics_frames(20)
	assert_int(enemy.get_telegraph().get_shape()).is_equal(GroundTelegraph.Shape.SECTOR)
	assert_float(enemy.get_telegraph().get_arc()).is_equal_approx(360.0, 0.01)
	await _physics_frames(50)
	assert_float(_player.health.current_health).is_equal_approx(_start - _dmg(1.5), 0.0001)


func test_ac1249_the_spin_misses_with_iframes_or_out_of_its_radius() -> void:
	_player.health.is_invulnerable = true
	var first: Enemy = _spawn(SPIN, Vector3(0.0, 0.0, -3.0))
	await _physics_frames(80)
	assert_float(_player.health.current_health).is_equal_approx(_start, 0.0001)
	first.deactivate()
	_player.health.is_invulnerable = false
	var enemy: Enemy = _spawn(SPIN, Vector3(0.0, 0.0, -3.0))
	await _physics_frames(20)
	_player.global_position = Vector3(0.0, 0.0, 9.0)
	await _physics_frames(80)
	assert_float(_player.health.current_health).is_equal_approx(_start, 0.0001)
	assert_object(enemy).is_not_null()


func test_ac1250_the_ring_hits_a_grounded_player_once() -> void:
	var enemy: Enemy = _spawn(OATH, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(90)
	assert_bool(_boss(enemy).is_ring_active(0)).is_true()
	assert_float(_player.health.current_health).is_equal_approx(_start, 0.0001)
	await _physics_frames(40)
	assert_float(_player.health.current_health).is_equal_approx(_start - _dmg(1.2), 0.0001)
	await _physics_frames(80)
	assert_float(_player.health.current_health).is_equal_approx(_start - _dmg(1.2), 0.0001)


func test_ac1250_the_ring_misses_with_iframes_and_phase_two_sends_two() -> void:
	_player.health.is_invulnerable = true
	var first: Enemy = _spawn(OATH, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(140)
	assert_float(_player.health.current_health).is_equal_approx(_start, 0.0001)
	first.deactivate()
	var enemy: Enemy = _spawn(OATH, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	enemy.global_position = Vector3(0.0, 0.0, -8.0)
	var both: bool = false
	for i: int in 200:
		await get_tree().physics_frame
		if _boss(enemy).is_ring_active(0) and _boss(enemy).is_ring_active(1):
			both = true
	assert_bool(both).is_true()


func test_ac1251_the_judgment_is_phase_two_only_slow_and_heavy() -> void:
	var enemy: Enemy = _spawn(JUDGMENT, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	assert_int(_boss(enemy).get_phase()).is_equal(BossBehavior.Phase.CHASE)
	await _enter_phase_two(enemy)
	_player.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, -4.0)
	var first_hit: int = -1
	var last: float = _player.health.current_health
	for frame: int in 240:
		await get_tree().physics_frame
		if _player.health.current_health < last and first_hit < 0:
			first_hit = frame
			assert_float(last - _player.health.current_health).is_equal_approx(_dmg(3.0), 0.0001)
	# 2.0 s × 0.8 = 1.6 s of windup (96 frames), a few of them already spent on the choice.
	assert_int(first_hit).is_between(90, 106)


func test_ac1251_out_of_the_sector_the_judgment_misses() -> void:
	var enemy: Enemy = _spawn(JUDGMENT, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	enemy.global_position = Vector3(0.0, 0.0, -4.0)
	await _physics_frames(50)
	_player.global_position = Vector3(12.0, 0.0, 0.0)
	await _physics_frames(200)
	assert_float(_player.health.current_health).is_equal_approx(_start, 0.0001)


func test_ac1252_dash_iframes_avoid_the_judgment() -> void:
	var enemy: Enemy = _spawn(JUDGMENT, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	_player.health.is_invulnerable = true
	enemy.global_position = Vector3(0.0, 0.0, -4.0)
	await _physics_frames(200)
	assert_float(_player.health.current_health).is_equal_approx(_start, 0.0001)


func test_ac1253_phase_two_starts_once_after_an_invulnerable_pause() -> void:
	var enemy: Enemy = _spawn(-1, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	enemy.health.receive_hit(enemy.health.max_health * 0.5 + enemy.health.defense + 1.0)
	await _physics_frames(2)
	assert_int(_boss(enemy).get_phase()).is_equal(BossBehavior.Phase.TRANSITION)
	assert_float(enemy.health.receive_hit(100.0)).is_equal_approx(0.0, 0.0001)
	await _physics_frames(int(BOSS.phase_two.transition_time * 60.0) + 3)
	assert_int(_boss(enemy).get_boss_phase()).is_equal(2)
	assert_float(enemy.health.receive_hit(100.0)).is_greater(0.0)
	enemy.health.heal(enemy.health.max_health)
	enemy.health.receive_hit(enemy.health.max_health * 0.6)
	await _physics_frames(5)
	assert_int(_boss(enemy).get_phase()).is_not_equal(BossBehavior.Phase.TRANSITION)


func test_ac1254_phase_two_is_faster_and_the_hands_grow() -> void:
	var enemy: Enemy = _spawn(SLASH, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	var expected_scale: float = KING.hands_config.hand_scale * BOSS.phase_two.phase_two_hand_scale
	assert_float((enemy.get_hands().get_node("RightHand") as Node3D).scale.x).is_equal_approx(expected_scale, 0.0001)
	# First windup: 0.7 × 0.8 = 0.56 s (34 frames).
	enemy.global_position = Vector3(0.0, 0.0, -3.0)
	var first_hit: int = -1
	var last: float = _player.health.current_health
	for frame: int in 60:
		await get_tree().physics_frame
		if _player.health.current_health < last and first_hit < 0:
			first_hit = frame
	assert_int(first_hit).is_between(31, 38)


func test_ac1255_the_king_has_no_armour() -> void:
	var enemy: Enemy = _spawn(-1, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	assert_float(enemy.health.damage_reduction).is_equal_approx(0.0, 0.0001)
	assert_float(enemy.health.receive_hit(100.0)).is_equal_approx(100.0, 0.0001)
	enemy.health.heal(enemy.health.max_health)
	await _enter_phase_two(enemy)
	assert_float(enemy.health.damage_reduction).is_equal_approx(0.0, 0.0001)
	assert_float(enemy.health.receive_hit(100.0)).is_equal_approx(100.0, 0.0001)


func test_ac1256_never_the_same_move_twice_in_a_row() -> void:
	_player.health.is_invulnerable = true
	var enemy: Enemy = _spawn(-1, Vector3(0.0, 0.0, -3.5))
	_boss(enemy).set_seed(1256)
	var sequence: Array[int] = []
	var was_chasing: bool = true
	for i: int in 2400:
		await get_tree().physics_frame
		var chasing: bool = _boss(enemy).get_phase() == BossBehavior.Phase.CHASE
		if was_chasing and not chasing:
			sequence.append(_boss(enemy).get_move_index())
		was_chasing = chasing
	assert_int(sequence.size()).is_greater_equal(5)
	for i: int in range(1, sequence.size()):
		assert_int(sequence[i]).is_not_equal(sequence[i - 1])


func test_ac1258_scales_with_level_and_rage() -> void:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = KING
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, -30.0), _player, 5)
	enemy.enrage(RAGE, 2)
	var expected := EnemyStats.new()
	KING.write_scaled(5, expected)
	RAGE.write_raged(2, expected)
	assert_float(enemy.get_scaled_stats().damage).is_equal_approx(expected.damage, 0.0001)
	assert_float(enemy.health.max_health).is_equal_approx(expected.max_health, 0.0001)


func test_ac1259_activate_resets_the_boss() -> void:
	var enemy: Enemy = _spawn(OATH, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	enemy.global_position = Vector3(0.0, 0.0, -6.0)
	await _physics_frames(60)
	enemy.activate(Vector3(0.0, 0.0, -30.0), _player)
	assert_int(_boss(enemy).get_boss_phase()).is_equal(1)
	assert_int(_boss(enemy).get_phase()).is_equal(BossBehavior.Phase.CHASE)
	assert_float((enemy.get_hands().get_node("RightHand") as Node3D).scale.x).is_equal_approx(KING.hands_config.hand_scale, 0.0001)
	for i: int in enemy.get_shockwave_count():
		assert_bool(enemy.get_shockwave(i).visible).is_false()
		assert_bool(_boss(enemy).is_ring_active(i)).is_false()


func test_ac1260_the_sector_warnings_cover_the_spin_and_the_judgment() -> void:
	var enemy: Enemy = _spawn(-1, Vector3(0.0, 0.0, -30.0))
	var arcs: Array[float] = _boss(enemy).get_telegraph_arcs()
	assert_bool(arcs.has(360.0)).is_true()
	assert_bool(arcs.has(90.0)).is_true()
	assert_bool(arcs.has(110.0)).is_true()
