extends GdUnitTestSuite
## docs/specs/warrior-abilities-rework.md §4.3: the frontal block (AC812–AC815).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const ARC: float = 120.0
const HIT: float = 20.0
const TOLERANCE: float = 0.001
const BEHAVIOR_DIR: String = "res://components/enemies/"

var _registry: EnemyRegistry
var _player: Player


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_player.health.setup(1000.0, 0.0)


func _spawn(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = GRUNT
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


func _at_degrees(degrees: float) -> Vector3:
	var angle: float = deg_to_rad(degrees)
	return Vector3(sin(angle), 0.0, -cos(angle)) * 3.0


func _guard() -> ShieldGuard:
	return _player.get_node("ShieldGuard") as ShieldGuard


func test_ac812_is_in_front() -> void:
	var facing: Vector3 = Vector3.FORWARD
	assert_bool(ShieldGuard.is_in_front(facing, Vector3.ZERO, _at_degrees(59.0), ARC)).is_true()
	assert_bool(ShieldGuard.is_in_front(facing, Vector3.ZERO, _at_degrees(61.0), ARC)).is_false()
	assert_bool(ShieldGuard.is_in_front(facing, Vector3.ZERO, Vector3(0.0, 0.0, 3.0), ARC)).is_false()
	assert_bool(ShieldGuard.is_in_front(facing, Vector3.ZERO, Vector3.ZERO, ARC)).is_true()


func test_ac813_the_raised_guard_blocks_frontal_hits() -> void:
	var front: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	var back: Enemy = _spawn(Vector3(0.0, 0.0, 2.0))
	var blocked: Array = []
	_guard().blocked.connect(func(amount: float, attacker: Enemy) -> void: blocked.append([amount, attacker]))
	var damaged: Array[float] = []
	_player.health.damaged.connect(func(amount: float) -> void: damaged.append(amount))
	_guard().raise(1.0, ARC)
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal(0.0)
	assert_int(damaged.size()).is_equal(0)
	assert_int(blocked.size()).is_equal(1)
	assert_float(blocked[0][0]).is_equal_approx(HIT, TOLERANCE)
	assert_object(blocked[0][1]).is_same(front)
	assert_float(_player.health.receive_hit_from(HIT, back)).is_equal_approx(HIT, TOLERANCE)
	assert_int(blocked.size()).is_equal(1)
	_guard().raise(0.5, ARC)
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal_approx(HIT * 0.5, TOLERANCE)
	_guard().lower()
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal_approx(HIT, TOLERANCE)


func test_ac814_iframes_skip_the_guard() -> void:
	var front: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	var blocked: Array[float] = []
	_guard().blocked.connect(func(amount: float, _a: Enemy) -> void: blocked.append(amount))
	_guard().raise(1.0, ARC)
	_player.health.is_invulnerable = true
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal(0.0)
	assert_int(blocked.size()).is_equal(0)


func test_ac815_enemy_hits_carry_their_attacker_and_grabs_are_not_blocked() -> void:
	for file: String in DirAccess.get_files_at(BEHAVIOR_DIR):
		if not file.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string(BEHAVIOR_DIR + file)
		assert_bool(text.contains("target.health.receive_hit(")).override_failure_message(file).is_false()
	var calls: int = 0
	for file: String in DirAccess.get_files_at(BEHAVIOR_DIR):
		if file.ends_with(".gd"):
			calls += FileAccess.get_file_as_string(BEHAVIOR_DIR + file).count("target.health.receive_hit_from(")
	assert_int(calls).is_equal(9)
	_guard().raise(1.0, ARC)
	_player.begin_hold(1.0)
	assert_bool(_player.is_held()).is_true()
