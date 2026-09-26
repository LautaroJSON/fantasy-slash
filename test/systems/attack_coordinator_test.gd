extends GdUnitTestSuite
## AttackCoordinator tokens and places (docs/specs/enemy-group-ai.md).
## Wave 1 (no RunState): 2 attackers, 0.35 s between grants.

const TestWorld := preload("res://test/helpers/test_world.gd")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CONFIG: GroupAIConfig = preload("res://data/enemies/group_ai_config.tres")
## boss-colmena (AC543): the Verdugo stands for a boss.
const BOSS: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const LETHAL_HIT: float = 100000.0

var _registry: EnemyRegistry
var _coordinator: AttackCoordinator
var _center: Node3D


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_center = auto_free(Node3D.new())
	add_child(_center)
	_coordinator = auto_free(AttackCoordinator.new())
	_coordinator.config = CONFIG
	_coordinator.registry = _registry
	_coordinator.player = _center
	add_child(_coordinator)


## Enemies without a target: they stand still, so only the coordinator acts.
func _enemy(at: Vector3 = Vector3(10.0, 0.0, 10.0), stats: EnemyStats = null) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	if stats != null:
		enemy.stats = stats
	enemy.registry = _registry
	enemy.coordinator = _coordinator
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


func test_ac440_a_third_attacker_waits_for_a_free_token() -> void:
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	var c: Enemy = _enemy()
	assert_bool(_coordinator.request_token(a)).is_true()
	_coordinator.advance(CONFIG.token_gap)
	assert_bool(_coordinator.request_token(b)).is_true()
	_coordinator.advance(CONFIG.token_gap)
	assert_bool(_coordinator.request_token(c)).is_false()
	assert_int(_coordinator.get_holder_count()).is_equal(2)
	_coordinator.release_token(a)
	assert_bool(_coordinator.request_token(c)).is_true()


func test_ac441_grants_are_token_gap_apart() -> void:
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	assert_bool(_coordinator.request_token(a)).is_true()
	assert_bool(_coordinator.request_token(b)).is_false()
	_coordinator.advance(CONFIG.token_gap * 0.5)
	assert_bool(_coordinator.request_token(b)).is_false()
	_coordinator.advance(CONFIG.token_gap * 0.5 + 0.001)
	assert_bool(_coordinator.request_token(b)).is_true()


func test_ac442_tokens_go_first_come_first_served() -> void:
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	var c: Enemy = _enemy()
	var d: Enemy = _enemy()
	_coordinator.request_token(a)
	_coordinator.advance(CONFIG.token_gap)
	_coordinator.request_token(b)
	assert_bool(_coordinator.request_token(c)).is_false()
	assert_bool(_coordinator.request_token(d)).is_false()
	_coordinator.release_token(a)
	_coordinator.advance(CONFIG.token_gap)
	assert_bool(_coordinator.request_token(d)).is_false()
	assert_bool(_coordinator.request_token(c)).is_true()
	assert_int(_coordinator.get_queue_index(d)).is_equal(0)
	_coordinator.withdraw(d)
	assert_int(_coordinator.get_queue_index(d)).is_equal(-1)


func test_ac442_unrenewed_requests_leave_the_queue() -> void:
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	_coordinator.request_token(a)
	_coordinator.request_token(b)
	assert_int(_coordinator.get_queue_index(b)).is_equal(0)
	for i: int in AttackCoordinator.STALE_REQUEST_FRAMES + 2:
		await get_tree().physics_frame
	assert_int(_coordinator.get_queue_index(b)).is_equal(-1)


func test_ac443_tokens_come_back() -> void:
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	# Unused token: taken back after token_approach_timeout.
	assert_bool(_coordinator.request_token(a)).is_true()
	_coordinator.advance(CONFIG.token_approach_timeout + 0.01)
	assert_bool(_coordinator.has_token(a)).is_false()
	# A started attack keeps it until the attack ends.
	assert_bool(_coordinator.request_token(a)).is_true()
	a.begin_attack()
	_coordinator.advance(CONFIG.token_approach_timeout + 0.01)
	assert_bool(_coordinator.has_token(a)).is_true()
	a.end_attack()
	assert_bool(_coordinator.has_token(a)).is_false()
	# Death and deactivation.
	assert_bool(_coordinator.request_token(b)).is_true()
	b.health.receive_hit(LETHAL_HIT)
	assert_bool(_coordinator.has_token(b)).is_false()
	_coordinator.advance(CONFIG.token_gap)
	assert_bool(_coordinator.request_token(a)).is_true()
	a.deactivate()
	assert_bool(_coordinator.has_token(a)).is_false()


func test_ac445_ac496_bosses_ignore_the_tokens() -> void:
	var boss: Enemy = _enemy(Vector3(10.0, 0.0, 10.0), BOSS)
	assert_bool(boss.uses_attack_tokens()).is_false()
	assert_bool(boss.can_start_attack()).is_true()
	assert_int(_coordinator.get_holder_count()).is_equal(0)


func test_ac451_places_are_never_shared_and_freed_on_death() -> void:
	var a: Enemy = _enemy(Vector3(0.0, 0.0, 5.0))
	var b: Enemy = _enemy(Vector3(0.1, 0.0, 5.0))
	var slot_a: int = _coordinator.claim_slot(a)
	var slot_b: int = _coordinator.claim_slot(b)
	assert_int(slot_a).is_equal(0)
	assert_int(slot_b).is_not_equal(slot_a)
	assert_int(slot_b).is_not_equal(-1)
	a.health.receive_hit(LETHAL_HIT)
	assert_int(_coordinator.get_slot(a)).is_equal(-1)
	assert_int(_coordinator.claim_slot(b)).is_equal(0)


func test_ac561_a_token_rests_after_an_attack_that_started() -> void:
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	var c: Enemy = _enemy()
	assert_bool(_coordinator.request_token(a)).is_true()
	a.begin_attack()
	_coordinator.advance(CONFIG.token_gap)
	assert_bool(_coordinator.request_token(b)).is_true()
	b.begin_attack()
	_coordinator.advance(CONFIG.token_gap)
	a.end_attack()
	assert_int(_coordinator.get_resting_count()).is_equal(1)
	# One holder and one resting token: still full.
	assert_bool(_coordinator.request_token(c)).is_false()
	_coordinator.advance(CONFIG.rest_for(a.level, 0) - 0.05)
	assert_bool(_coordinator.request_token(c)).is_false()
	_coordinator.advance(0.1)
	assert_int(_coordinator.get_resting_count()).is_equal(0)
	assert_bool(_coordinator.request_token(c)).is_true()


func test_ac562_an_unused_token_does_not_rest() -> void:
	var a: Enemy = _enemy()
	var b: Enemy = _enemy()
	var c: Enemy = _enemy()
	_coordinator.request_token(a)
	_coordinator.advance(CONFIG.token_gap)
	_coordinator.request_token(b)
	_coordinator.advance(CONFIG.token_gap)
	# Cancelled before its windup started.
	a.end_attack()
	assert_int(_coordinator.get_resting_count()).is_equal(0)
	assert_bool(_coordinator.request_token(c)).is_true()
