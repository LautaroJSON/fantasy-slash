extends GdUnitTestSuite
## El Titán (docs/specs/boss-titan.md). Level 1: 333 health, 22 damage,
## no defense, 70 % armour; each hand 30 % of the health (99.9). Values from
## early-power-curve (§6.2).
## Single-move tests use a copy of its stats whose config keeps one move.

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const TITAN_STATS: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const TITAN: TitanConfig = preload("res://data/enemies/configs/titan_boss.tres")
const RAGE: RageConfig = preload("res://data/enemies/rage/rage_config.tres")
const SLAM: int = 0
const SWEEP: int = 1
const STOMP: int = 2
## Raw hit that removes 100 with no armour (the Titán has no defense at level 1).
const HIT: float = 100.0
## Breaks a full hand (99.9) without taking the Titán below its phase-2 threshold.
const BREAK_HIT: float = 110.0
## Health of a hand at level 1.
const HAND_HEALTH: float = 99.9

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


func _stats(only: int) -> EnemyStats:
	if only < 0:
		return TITAN_STATS
	var stats: EnemyStats = TITAN_STATS.duplicate() as EnemyStats
	var config: TitanConfig = TITAN.duplicate() as TitanConfig
	config.moves = [TITAN.moves[only]] as Array[BossMoveData]
	stats.behavior_config = config
	return stats


func _spawn(only: int, at: Vector3, level: int = 1) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = _stats(only)
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, _player, level)
	return enemy


func _titan(enemy: Enemy) -> TitanBehavior:
	return enemy.get_behavior() as TitanBehavior


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Right hand resting on the player after a slam (player invulnerable).
func _rest_right_hand() -> Enemy:
	_player.health.is_invulnerable = true
	var enemy: Enemy = _spawn(SLAM, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(110)
	assert_bool(_titan(enemy).is_hand_resting(false)).is_true()
	return enemy


func _hand_scale(enemy: Enemy, left: bool) -> float:
	return (enemy.get_hands().get_node("LeftHand" if left else "RightHand") as Node3D).scale.x


func test_ac479_the_body_is_armoured() -> void:
	var enemy: Enemy = _spawn(SLAM, Vector3(0.0, 0.0, -30.0))
	await _physics_frames(2)
	assert_float(enemy.health.receive_hit(HIT)).is_equal_approx(30.0, 0.001)


func test_ac480_hits_near_a_resting_hand_skip_the_armour_and_hurt_it() -> void:
	var enemy: Enemy = await _rest_right_hand()
	assert_float(enemy.health.receive_hit(HAND_HEALTH / 2.0)).is_equal_approx(HAND_HEALTH / 2.0, 0.001)
	assert_float(_titan(enemy).get_hand_health(false)).is_equal_approx(HAND_HEALTH / 2.0, 0.001)
	assert_float(_titan(enemy).get_hand_health(true)).is_equal_approx(HAND_HEALTH, 0.001)


func test_ac480_a_raised_hand_is_not_a_weak_point() -> void:
	_player.health.is_invulnerable = true
	var enemy: Enemy = _spawn(SLAM, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(40)
	assert_float(enemy.health.receive_hit(HIT)).is_equal_approx(30.0, 0.001)
	assert_float(_titan(enemy).get_hand_health(false)).is_equal_approx(HAND_HEALTH, 0.001)


func test_ac481_each_hand_has_a_share_of_the_health() -> void:
	var enemy: Enemy = _spawn(SLAM, Vector3(0.0, 0.0, -30.0))
	assert_float(_titan(enemy).get_hand_health(true)).is_equal_approx(TITAN.hand_health_fraction * TITAN_STATS.max_health, 0.001)
	assert_float(_titan(enemy).get_hand_health(false)).is_equal_approx(HAND_HEALTH, 0.001)


func test_ac482_a_hurt_hand_shrinks_and_shakes() -> void:
	var enemy: Enemy = await _rest_right_hand()
	# Half the hand's health.
	enemy.health.receive_hit(HAND_HEALTH / 2.0)
	var expected: float = TITAN_STATS.hands_config.hand_scale * TITAN.hand_size_for(0.5)
	assert_float(_hand_scale(enemy, false)).is_equal_approx(expected, 0.0001)
	assert_bool(enemy.get_hands().is_hand_shaking(false)).is_true()
	assert_float(_hand_scale(enemy, true)).is_equal_approx(TITAN_STATS.hands_config.hand_scale, 0.0001)


func test_ac483_a_broken_hand_disappears_and_stuns() -> void:
	var enemy: Enemy = await _rest_right_hand()
	enemy.health.receive_hit(BREAK_HIT)
	assert_bool(_titan(enemy).is_hand_broken(false)).is_true()
	assert_bool(enemy.get_hands().is_hand_visible(false)).is_false()
	assert_bool(_titan(enemy).is_stunned()).is_true()
	await _physics_frames(1)
	assert_float(enemy.get_body().position.y).is_less(enemy.get_body_rest_height() - 0.1)
	assert_float(enemy.health.receive_hit(HIT)).is_equal_approx(100.0, 0.001)
	await _physics_frames(int(TITAN.break_stun_time * 60.0) + 2)
	assert_bool(_titan(enemy).is_stunned()).is_false()
	assert_float(enemy.get_body().position.y).is_equal_approx(enemy.get_body_rest_height(), 0.0001)
	assert_int(_titan(enemy).get_phase()).is_not_equal(BossBehavior.Phase.TRANSITION)


func test_ac484_moves_switch_to_the_hand_left_and_only_stomp_without_hands() -> void:
	var enemy: Enemy = await _rest_right_hand()
	enemy.health.receive_hit(BREAK_HIT)
	await _physics_frames(int((TITAN.break_stun_time + TITAN_STATS.attack_interval) * 60.0) + 5)
	assert_int(_titan(enemy).get_phase()).is_equal(BossBehavior.Phase.OTHER)
	assert_bool(_titan(enemy).is_move_hand_left()).is_true()
	# Both hands broken (forced): only the stomp remains.
	var full: Enemy = _spawn(-1, Vector3(10.0, 0.0, -6.0))
	_titan(full)._break_hand(0)
	_titan(full)._break_hand(1)
	await _physics_frames(int((TITAN.break_stun_time + TITAN_STATS.attack_interval) * 60.0) + 5)
	assert_int(_titan(full).get_phase()).is_equal(BossBehavior.Phase.SHOCKWAVE)


func test_ac485_the_impact_point_locks_before_the_slam() -> void:
	_spawn(SLAM, Vector3(0.0, 0.0, -6.0))
	# Locked at 60 % of the 1.4 s windup (~50 frames): stepping away after it avoids the hit.
	await _physics_frames(60)
	_player.global_position = Vector3(5.0, 0.0, 0.0)
	await _physics_frames(60)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac485_standing_in_the_circle_takes_the_slam_once() -> void:
	_spawn(SLAM, Vector3(0.0, 0.0, -6.0))
	await _physics_frames(110)
	assert_float(_player.health.current_health).is_equal_approx(59.0, 0.0001)
	await _physics_frames(90)
	assert_float(_player.health.current_health).is_equal_approx(59.0, 0.0001)


func test_ac486_the_hand_rests_on_the_impact_point() -> void:
	var enemy: Enemy = await _rest_right_hand()
	var hand: Vector3 = enemy.get_hands().get_hand_global_position(false)
	var impact: Vector3 = _titan(enemy).get_impact_point()
	assert_float(Vector2(hand.x - impact.x, hand.z - impact.z).length()).is_less(0.5)
	await _physics_frames(int(TITAN.moves[SLAM].hand_rest_time * 60.0))
	assert_bool(_titan(enemy).is_hand_resting(false)).is_false()


func test_ac487_the_sweep_hits_a_grounded_player_in_the_arc() -> void:
	_spawn(SWEEP, Vector3(0.0, 0.0, -5.0))
	await _physics_frames(100)
	assert_float(_player.health.current_health).is_equal_approx(70.0, 0.0001)


func test_ac487_jumping_over_the_sweep_avoids_it() -> void:
	var platform: StaticBody3D = auto_free(TestWorld.make_box(Vector3(2.0, 0.5, 2.0), Vector3(0.0, 0.25, 0.0)))
	add_child(platform)
	_player.global_position = Vector3(0.0, 0.6, 0.0)
	_spawn(SWEEP, Vector3(0.0, 0.0, -5.0))
	await _physics_frames(100)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


func test_ac487_behind_the_titan_the_sweep_misses() -> void:
	_spawn(SWEEP, Vector3(0.0, 0.0, -5.0))
	await _physics_frames(71)
	_player.global_position = Vector3(0.0, 0.0, -10.0)
	await _physics_frames(40)
	assert_float(_player.health.current_health).is_equal_approx(100.0, 0.0001)


## Takes the Titán (player out of reach) to phase 2, armour aside.
func _enter_phase_two(enemy: Enemy) -> void:
	enemy.health.damage_reduction = 0.0
	enemy.health.receive_hit(enemy.health.max_health * 0.6 + enemy.health.defense + 1.0)
	await _physics_frames(int(TITAN.phase_two.transition_time * 60.0) + 5)


func _max_rings(enemy: Enemy, frames: int) -> int:
	var most: int = 0
	for i: int in frames:
		await get_tree().physics_frame
		var active: int = 0
		for ring: int in enemy.get_shockwave_count():
			if _titan(enemy).is_ring_active(ring):
				active += 1
		most = maxi(most, active)
	return most


func test_ac488_stomp_rings_by_phase() -> void:
	_player.health.is_invulnerable = true
	var enemy: Enemy = _spawn(STOMP, Vector3(0.0, 0.0, -10.0))
	assert_int(await _max_rings(enemy, 240)).is_equal(1)
	var second: Enemy = _spawn(STOMP, Vector3(40.0, 0.0, -40.0))
	await _physics_frames(2)
	await _enter_phase_two(second)
	second.global_position = Vector3(0.0, 0.0, -10.0)
	assert_int(await _max_rings(second, 300)).is_equal(3)


func test_ac489_phase_two_at_forty_percent_keeps_broken_hands() -> void:
	var enemy: Enemy = _spawn(-1, Vector3(0.0, 0.0, -40.0))
	await _physics_frames(2)
	_titan(enemy)._break_hand(1)
	await _physics_frames(int(TITAN.break_stun_time * 60.0) + 3)
	enemy.health.damage_reduction = 0.0
	enemy.health.receive_hit(enemy.health.max_health * 0.6 + enemy.health.defense + 1.0)
	await _physics_frames(2)
	assert_int(_titan(enemy).get_phase()).is_equal(BossBehavior.Phase.TRANSITION)
	assert_float(enemy.health.receive_hit(HIT)).is_equal_approx(0.0, 0.0001)
	await _physics_frames(int(TITAN.phase_two.transition_time * 60.0) + 3)
	assert_int(_titan(enemy).get_boss_phase()).is_equal(2)
	var expected: float = TITAN_STATS.hands_config.hand_scale * TITAN.phase_two.phase_two_hand_scale
	assert_float(_hand_scale(enemy, true)).is_equal_approx(expected, 0.0001)
	assert_bool(enemy.get_hands().is_hand_visible(false)).is_false()
	assert_bool(_titan(enemy).is_hand_broken(false)).is_true()


func test_ac492_scales_with_level_and_rage() -> void:
	var enemy: Enemy = _spawn(-1, Vector3(0.0, 0.0, -40.0), 5)
	enemy.enrage(RAGE, 2)
	var expected := EnemyStats.new()
	TITAN_STATS.write_scaled(5, expected)
	RAGE.write_raged(2, expected)
	assert_float(enemy.get_scaled_stats().damage).is_equal_approx(expected.damage, 0.0001)
	assert_float(enemy.health.max_health).is_equal_approx(expected.max_health, 0.0001)
	assert_float(_titan(enemy).get_hand_health(true)).is_equal_approx(expected.max_health * TITAN.hand_health_fraction, 0.001)


func test_ac493_activate_restores_the_hands_and_the_armour() -> void:
	var enemy: Enemy = await _rest_right_hand()
	enemy.health.receive_hit(BREAK_HIT)
	assert_bool(_titan(enemy).is_stunned()).is_true()
	enemy.activate(Vector3(0.0, 0.0, -40.0), _player)
	assert_bool(_titan(enemy).is_stunned()).is_false()
	assert_bool(_titan(enemy).is_hand_broken(false)).is_false()
	assert_bool(enemy.get_hands().is_hand_visible(false)).is_true()
	assert_float(_hand_scale(enemy, false)).is_equal_approx(TITAN_STATS.hands_config.hand_scale, 0.0001)
	assert_float(_titan(enemy).get_hand_health(false)).is_equal_approx(HAND_HEALTH, 0.001)
	assert_float(enemy.health.receive_hit(HIT)).is_equal_approx(30.0, 0.001)
