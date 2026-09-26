extends GdUnitTestSuite
## El Verdugo (docs/specs/boss-verdugo.md). Damage 18, player defense 3.
## Single-move tests use a copy of its stats whose BossConfig keeps one move.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const BOSS: BossConfig = preload("res://data/enemies/configs/verdugo_boss.tres")
const RAGE: RageConfig = preload("res://data/enemies/rage/rage_config.tres")
const COMBO: int = 0
const SHOCKWAVE: int = 1
const GRAB: int = 2
const LETHAL_HIT: float = 100000.0

var _registry: EnemyRegistry
var _player: Player


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(80.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)


func after_test() -> void:
	for action: StringName in [Player.ACTION_FORWARD, Player.ACTION_ATTACK, Player.ACTION_DASH]:
		Input.action_release(action)


## The Verdugo with only move `only` (−1 keeps the whole repertoire).
func _stats(only: int) -> EnemyStats:
	if only < 0:
		return VERDUGO
	var stats: EnemyStats = VERDUGO.duplicate() as EnemyStats
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


func _boss(enemy: Enemy) -> BossBehavior:
	return enemy.get_behavior() as BossBehavior


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Takes the boss (with the player out of every move's reach) into phase 2.
func _enter_phase_two(enemy: Enemy) -> void:
	enemy.health.receive_hit(enemy.health.max_health * 0.5 + enemy.health.defense + 1.0)
	await _physics_frames(int(BOSS.phase_two.transition_time * 60.0) + 5)


func test_ac461_triple_slash_hits_three_times() -> void:
	_spawn(COMBO, Vector3(0.0, 0.0, -3.0))
	await _physics_frames(30)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)
	await _physics_frames(15)
	assert_float(_player.health.current_health).is_equal_approx(85.0, 0.0001)
	await _physics_frames(45)
	assert_float(_player.health.current_health).is_equal_approx(70.0, 0.0001)
	await _physics_frames(40)
	assert_float(_player.health.current_health).is_equal_approx(44.2, 0.0001)


func test_ac462_steps_forward_before_each_hit() -> void:
	var enemy: Enemy = _spawn(COMBO, Vector3(0.0, 0.0, -3.0))
	var advance: float = (BOSS.moves[COMBO] as ComboMoveData).advance_distance
	await _physics_frames(40)
	assert_float(enemy.global_position.z).is_equal_approx(-3.0 + advance, 0.1)
	await _physics_frames(45)
	assert_float(enemy.global_position.z).is_equal_approx(-3.0 + 2.0 * advance, 0.1)


func test_ac463_each_hit_is_checked_on_its_own() -> void:
	_spawn(COMBO, Vector3(0.0, 0.0, -3.0))
	await _physics_frames(45)
	assert_float(_player.health.current_health).is_equal_approx(85.0, 0.0001)
	_player.global_position = Vector3(12.0, 0.0, 0.0)
	await _physics_frames(100)
	assert_float(_player.health.current_health).is_equal_approx(85.0, 0.0001)


func test_ac464_the_ring_hits_a_grounded_player_once() -> void:
	var enemy: Enemy = _spawn(SHOCKWAVE, Vector3(0.0, 0.0, -6.0))
	var wave: ShockwaveMoveData = BOSS.moves[SHOCKWAVE] as ShockwaveMoveData
	await _physics_frames(80)
	assert_bool(_boss(enemy).is_ring_active(0)).is_true()
	var radius: float = _boss(enemy).get_ring_radius(0)
	await _physics_frames(6)
	assert_float(_boss(enemy).get_ring_radius(0) - radius).is_equal_approx(wave.speed * 6.0 / 60.0, 0.01)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)
	await _physics_frames(30)
	assert_float(_player.health.current_health).is_equal_approx(81.4, 0.0001)
	await _physics_frames(60)
	assert_float(_player.health.current_health).is_equal_approx(81.4, 0.0001)


func test_ac465_jumping_over_or_dashing_through_avoids_the_ring() -> void:
	# A 0.5 m platform keeps the player's feet above clear_height.
	var platform: StaticBody3D = auto_free(TestWorld.make_box(Vector3(2.0, 0.5, 2.0), Vector3(0.0, 0.25, 0.0)))
	add_child(platform)
	_player.global_position = Vector3(0.0, 0.6, 0.0)
	_spawn(SHOCKWAVE, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(130)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac465_dash_iframes_avoid_the_ring() -> void:
	_spawn(SHOCKWAVE, Vector3(0.0, 0.0, -6.0))
	_player.health.is_invulnerable = true
	await _physics_frames(130)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac466_the_ring_mesh_follows_the_radius_and_hides() -> void:
	var enemy: Enemy = _spawn(SHOCKWAVE, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(90)
	var ring: MeshInstance3D = enemy.get_shockwave(0)
	assert_bool(ring.visible).is_true()
	assert_float(ring.global_basis.x.length()).is_equal_approx(_boss(enemy).get_ring_radius(0), 0.01)
	await _physics_frames(80)
	assert_bool(ring.visible).is_false()


func test_ac467_the_grab_holds_then_slams() -> void:
	var enemy: Enemy = _spawn(GRAB, Vector3(0.0, 0.0, -3.5))
	await _physics_frames(65)
	assert_int(_boss(enemy).get_phase()).is_equal(BossBehavior.Phase.HOLD)
	assert_bool(_player.is_held()).is_true()
	var start: Vector3 = _player.global_position
	var attacks: Array[int] = [0]
	_player.attack_performed.connect(func() -> void: attacks[0] += 1)
	Input.action_press(Player.ACTION_FORWARD)
	Input.action_press(Player.ACTION_ATTACK)
	Input.action_press(Player.ACTION_DASH)
	await _physics_frames(20)
	Input.action_release(Player.ACTION_FORWARD)
	Input.action_release(Player.ACTION_ATTACK)
	Input.action_release(Player.ACTION_DASH)
	assert_float(Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()).is_less(0.01)
	assert_int(attacks[0]).is_equal(0)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)
	await _physics_frames(70)
	assert_bool(_player.is_held()).is_false()
	assert_float(_player.health.current_health).is_equal_approx(58.0, 0.0001)


func test_ac468_a_dodged_grab_leaves_it_exposed() -> void:
	var enemy: Enemy = _spawn(GRAB, Vector3(0.0, 0.0, -3.5))
	_player.health.is_invulnerable = true
	var grab: GrabMoveData = BOSS.moves[GRAB] as GrabMoveData
	var recovery_frames: int = 0
	for i: int in 240:
		await get_tree().physics_frame
		if _boss(enemy).get_phase() == BossBehavior.Phase.RECOVERY:
			recovery_frames += 1
		elif recovery_frames > 0:
			break
	assert_bool(_player.is_held()).is_false()
	assert_int(recovery_frames).is_between(int(grab.miss_recovery_time * 60.0) - 2, int(grab.miss_recovery_time * 60.0) + 2)


func test_ac469_player_hold_api_and_release_on_deactivation() -> void:
	_player.begin_hold(0.5)
	assert_bool(_player.is_held()).is_true()
	await _physics_frames(35)
	assert_bool(_player.is_held()).is_false()
	_player.begin_hold(5.0)
	_player.end_hold()
	assert_bool(_player.is_held()).is_false()
	var enemy: Enemy = _spawn(GRAB, Vector3(0.0, 0.0, -3.5))
	await _physics_frames(65)
	assert_bool(_player.is_held()).is_true()
	enemy.deactivate()
	assert_bool(_player.is_held()).is_false()


func test_ac470_phase_two_starts_once_after_an_invulnerable_pause() -> void:
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


func test_ac471_phase_two_is_faster_and_harder() -> void:
	var enemy: Enemy = _spawn(COMBO, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	assert_int(_boss(enemy).get_boss_phase()).is_equal(2)
	var hands: EnemyHands = enemy.get_hands()
	var expected_scale: float = VERDUGO.hands_config.hand_scale * BOSS.phase_two.phase_two_hand_scale
	assert_float((hands.get_node("RightHand") as Node3D).scale.x).is_equal_approx(expected_scale, 0.0001)
	# First windup: 0.6 × 0.75 = 0.45 s (27 frames); four hits in all.
	enemy.global_position = Vector3(0.0, 0.0, -3.0)
	var hits: int = 0
	var first_hit: int = -1
	var last_health: float = _player.health.current_health
	for frame: int in 240:
		await get_tree().physics_frame
		if _player.health.current_health < last_health:
			hits += 1
			if first_hit < 0:
				first_hit = frame
			last_health = _player.health.current_health
	assert_int(hits).is_equal(4)
	assert_int(first_hit).is_between(25, 30)


func test_ac471_phase_two_slam_sends_two_rings() -> void:
	var enemy: Enemy = _spawn(SHOCKWAVE, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	enemy.global_position = Vector3(0.0, 0.0, -8.0)
	var both: bool = false
	for i: int in 150:
		await get_tree().physics_frame
		if _boss(enemy).is_ring_active(0) and _boss(enemy).is_ring_active(1):
			both = true
	assert_bool(both).is_true()


func test_ac472_never_the_same_move_twice_in_a_row() -> void:
	_player.health.is_invulnerable = true
	var enemy: Enemy = _spawn(-1, Vector3(0.0, 0.0, -3.5))
	_boss(enemy).set_seed(472)
	# Every move reaches at 3.5 m or less (the shockwave with its close_weight).
	var sequence: Array[int] = []
	var was_chasing: bool = true
	for i: int in 1500:
		await get_tree().physics_frame
		var chasing: bool = _boss(enemy).get_phase() == BossBehavior.Phase.CHASE
		if was_chasing and not chasing:
			sequence.append(_boss(enemy).get_move_index())
		was_chasing = chasing
	assert_int(sequence.size()).is_greater_equal(5)
	for i: int in range(1, sequence.size()):
		assert_int(sequence[i]).is_not_equal(sequence[i - 1])


func test_ac473_far_uses_the_shockwave_close_uses_slash_or_grab() -> void:
	var far: Enemy = _spawn(-1, Vector3(0.0, 0.0, -10.0))
	await _physics_frames(2)
	assert_int(_boss(far).get_phase()).is_equal(BossBehavior.Phase.SHOCKWAVE)
	far.deactivate()
	# At 2 m the slash (3) and the grab (2) are far likelier than the shockwave
	# (close_weight 1): 30 seeded choices.
	var close: Enemy = _spawn(-1, Vector3(0.0, 0.0, -2.0))
	var melee: int = 0
	var waves: int = 0
	for seed_value: int in 30:
		close.activate(Vector3(0.0, 0.0, -2.0), _player)
		_boss(close).set_seed(seed_value)
		await _physics_frames(2)
		match _boss(close).get_phase():
			BossBehavior.Phase.COMBO, BossBehavior.Phase.GRAB:
				melee += 1
			BossBehavior.Phase.SHOCKWAVE:
				waves += 1
	assert_int(melee + waves).is_equal(30)
	assert_int(melee).is_greater(waves * 2)


func test_ac475_scales_with_level_and_rage() -> void:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = VERDUGO
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, -30.0), _player, 5)
	enemy.enrage(RAGE, 2)
	var expected := EnemyStats.new()
	VERDUGO.write_scaled(5, expected)
	RAGE.write_raged(2, expected)
	assert_float(enemy.get_scaled_stats().damage).is_equal_approx(expected.damage, 0.0001)
	assert_float(enemy.health.max_health).is_equal_approx(expected.max_health, 0.0001)


func test_ac476_activate_resets_the_boss() -> void:
	var enemy: Enemy = _spawn(SHOCKWAVE, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	await _enter_phase_two(enemy)
	enemy.global_position = Vector3(0.0, 0.0, -6.0)
	await _physics_frames(60)
	enemy.activate(Vector3(0.0, 0.0, -30.0), _player)
	assert_int(_boss(enemy).get_boss_phase()).is_equal(1)
	assert_int(_boss(enemy).get_phase()).is_equal(BossBehavior.Phase.CHASE)
	assert_float((enemy.get_hands().get_node("RightHand") as Node3D).scale.x).is_equal_approx(VERDUGO.hands_config.hand_scale, 0.0001)
	for i: int in enemy.get_shockwave_count():
		assert_bool(enemy.get_shockwave(i).visible).is_false()
		assert_bool(_boss(enemy).is_ring_active(i)).is_false()


func test_ac477_dying_while_held_releases_the_player() -> void:
	_spawn(GRAB, Vector3(0.0, 0.0, -3.5))
	await _physics_frames(65)
	assert_bool(_player.is_held()).is_true()
	_player.health.receive_hit(LETHAL_HIT)
	assert_bool(_player.is_held()).is_false()
