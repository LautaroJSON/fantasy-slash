extends GdUnitTestSuite
## Enemies with an AttackCoordinator (docs/specs/enemy-group-ai.md). Wave 1:
## 2 attackers. "Blockers" are target-less enemies holding both tokens (with
## their attack marked as started, so the tokens never time out).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CONFIG: GroupAIConfig = preload("res://data/enemies/group_ai_config.tres")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const CHARGER: EnemyStats = preload("res://data/enemies/charger_stats.tres")
const LEAPER: EnemyStats = preload("res://data/enemies/leaper_stats.tres")
const HARASSER: EnemyStats = preload("res://data/enemies/harasser_stats.tres")

var _registry: EnemyRegistry
var _coordinator: AttackCoordinator
var _player: Player


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(80.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_player.health.is_invulnerable = true
	_coordinator = auto_free(AttackCoordinator.new())
	_coordinator.config = CONFIG
	_coordinator.registry = _registry
	_coordinator.player = _player
	add_child(_coordinator)


func _spawn(stats: EnemyStats, at: Vector3, with_coordinator: bool = true) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	enemy.registry = _registry
	if with_coordinator:
		enemy.coordinator = _coordinator
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _block_tokens() -> void:
	for i: int in 2:
		var blocker: Enemy = auto_free(ENEMY_SCENE.instantiate())
		blocker.registry = _registry
		blocker.coordinator = _coordinator
		add_child(blocker)
		blocker.activate(Vector3(30.0 + 3.0 * i, 0.0, 30.0), null)
		_coordinator.advance(CONFIG.token_gap)
		assert_bool(_coordinator.request_token(blocker)).is_true()
		blocker.begin_attack()
	_coordinator.advance(CONFIG.token_gap)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _flat_distance(enemy: Enemy) -> float:
	return Vector2(enemy.global_position.x - _player.global_position.x, enemy.global_position.z - _player.global_position.z).length()


func _bearing(enemy: Enemy) -> float:
	return atan2(enemy.global_position.x - _player.global_position.x, enemy.global_position.z - _player.global_position.z)


func test_ac446_never_more_attackers_than_tokens() -> void:
	var grunts: Array[Enemy] = []
	for at: Vector3 in [Vector3(0, 0, -3), Vector3(3, 0, 0), Vector3(0, 0, 3), Vector3(-3, 0, 0)]:
		grunts.append(_spawn(GRUNT, at))
	var attacked: Array[bool] = [false, false, false, false]
	for frame: int in 360:
		await get_tree().physics_frame
		var swinging: int = 0
		for i: int in grunts.size():
			var phase: MeleeBehavior.Phase = (grunts[i].get_behavior() as MeleeBehavior).get_phase()
			if phase == MeleeBehavior.Phase.WINDUP or phase == MeleeBehavior.Phase.ACTIVE:
				swinging += 1
				attacked[i] = true
		assert_int(swinging).is_less_equal(CONFIG.max_attackers_for(0))
	for i: int in attacked.size():
		assert_bool(attacked[i]).is_true()


func test_ac447_a_grunt_without_token_waits_on_the_ring() -> void:
	_block_tokens()
	var grunt: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -7.0))
	await _physics_frames(120)
	var wait_distance: float = GRUNT.attack_range + CONFIG.wait_margin
	assert_float(_flat_distance(grunt)).is_between(wait_distance - 0.5, wait_distance + 0.5)
	assert_bool(grunt.get_behavior().is_attacking()).is_false()
	var to_player: Vector3 = (_player.global_position - grunt.global_position) * Vector3(1, 0, 1)
	assert_float(grunt.get_facing().dot(to_player.normalized())).is_greater(0.95)


func test_ac448_other_types_hold_back_without_token() -> void:
	_block_tokens()
	var charger: Enemy = _spawn(CHARGER, Vector3(0.0, 0.0, -5.0))
	var leaper: Enemy = _spawn(LEAPER, Vector3(6.0, 0.0, 0.0))
	var harasser: Enemy = _spawn(HARASSER, Vector3(0.0, 0.0, 4.0))
	await _physics_frames(40)
	assert_bool(charger.get_behavior().is_attacking()).is_false()
	assert_bool(leaper.get_behavior().is_attacking()).is_false()
	assert_int((harasser.get_behavior() as HarasserBehavior).get_phase()).is_equal(HarasserBehavior.Phase.ORBIT)


func test_ac449_without_coordinator_it_attacks_as_before() -> void:
	_block_tokens()
	var grunt: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -1.5), false)
	await _physics_frames(3)
	assert_int((grunt.get_behavior() as MeleeBehavior).get_phase()).is_equal(MeleeBehavior.Phase.WINDUP)


func test_ac450_waiting_grunts_spread_around_the_player() -> void:
	_block_tokens()
	var grunts: Array[Enemy] = []
	for at: Vector3 in [Vector3(-1, 0, -8), Vector3(0, 0, -8), Vector3(1, 0, -8), Vector3(0.5, 0, -9.5)]:
		grunts.append(_spawn(GRUNT, at))
	await _physics_frames(240)
	var min_gap: float = TAU
	for i: int in grunts.size():
		for j: int in range(i + 1, grunts.size()):
			min_gap = minf(min_gap, absf(angle_difference(_bearing(grunts[i]), _bearing(grunts[j]))))
	assert_float(min_gap).is_greater_equal(0.8 * TAU / CONFIG.slot_count)


func test_ac452_walking_enemies_push_apart() -> void:
	_block_tokens()
	var a: Enemy = _spawn(GRUNT, Vector3(0.0, 0.0, -12.0))
	var b: Enemy = _spawn(GRUNT, Vector3(0.2, 0.0, -12.0))
	await _physics_frames(60)
	var gap: float = Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
	assert_float(gap).is_greater_equal(0.8 * CONFIG.separation_radius)


## enemy-level-pace (AC563): after the first pair ends, the next attacker only
## starts its windup once the returned token has rested.
func test_ac563_the_next_pair_waits_for_the_rest() -> void:
	var grunts: Array[Enemy] = []
	for at: Vector3 in [Vector3(0, 0, -3), Vector3(3, 0, 0), Vector3(0, 0, 3)]:
		grunts.append(_spawn(GRUNT, at))
	var attacked: Array[bool] = [false, false, false]
	var first_end: int = -1
	var third_start: int = -1
	for frame: int in 400:
		await get_tree().physics_frame
		for i: int in grunts.size():
			var attacking: bool = grunts[i].get_behavior().is_attacking()
			if attacking and not attacked[i]:
				attacked[i] = true
				if first_end >= 0 and third_start < 0:
					third_start = frame
			if not attacking and attacked[i] and first_end < 0:
				first_end = frame
		if third_start >= 0:
			break
	assert_int(first_end).is_not_equal(-1)
	assert_int(third_start).is_not_equal(-1)
	assert_int(third_start - first_end).is_greater_equal(int(CONFIG.rest_for(1, 0) * 60.0) - 1)
