extends GdUnitTestSuite
## Esbirro behavior (docs/specs/fodder-minion.md, AC1143–AC1146, AC1155).

const TestWorld := preload("res://test/helpers/test_world.gd")
const ComboDriver := preload("res://test/helpers/combo_driver.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const FODDER: EnemyStats = preload("res://data/enemies/fodder_stats.tres")
const CONFIG: GroupAIConfig = preload("res://data/enemies/group_ai_config.tres")
const PACE: EnemyPaceConfig = preload("res://data/enemies/enemy_pace_config.tres")
const NO_CRIT_ROLL: float = 0.99
const CLASSES: Array[String] = [
	"res://data/classes/warrior/warrior.tres",
	"res://data/classes/berserker/berserker.tres",
	"res://data/classes/samurai/samurai.tres",
]

var _registry: EnemyRegistry
var _coordinator: AttackCoordinator
var _player: Player


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)


func after_test() -> void:
	Session.character_class = null


func _make_player(class_path: String) -> void:
	Session.character_class = load(class_path) as CharacterClassData
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)


func _make_coordinator() -> void:
	_coordinator = auto_free(AttackCoordinator.new())
	_coordinator.config = CONFIG
	_coordinator.registry = _registry
	_coordinator.player = _player
	add_child(_coordinator)


func _spawn(at: Vector3, with_coordinator: bool = false) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = FODDER
	enemy.registry = _registry
	if with_coordinator:
		enemy.coordinator = _coordinator
	add_child(enemy)
	enemy.activate(at, _player)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_ac1143_one_combo_hit_of_each_class_kills_a_fodder() -> void:
	for path: String in CLASSES:
		_make_player(path)
		ComboDriver.drive_by_hand(_player)
		var fodder: Enemy = _spawn(_player.global_position + Vector3(0.0, 0.0, -1.2))
		var kills: Array[int] = [0]
		fodder.killed.connect(func(_e: Enemy) -> void: kills[0] += 1)
		await _physics_frames(2)
		assert_bool(ComboDriver.strike_and_finish(_player, NO_CRIT_ROLL)).is_true()
		assert_int(kills[0]).override_failure_message("%s: the first hit did not kill" % path).is_equal(1)
		assert_bool(fodder.health.is_dead()).is_true()
		_player.queue_free()
		fodder.queue_free()
		await _physics_frames(2)


func test_ac1144_a_sweep_kills_four_fodder_at_once() -> void:
	_make_player(CLASSES[0])
	ComboDriver.drive_by_hand(_player)
	var group: Array[Enemy] = []
	for angle_degrees: float in [-9.0, -3.0, 3.0, 9.0]:
		var direction: Vector3 = Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(angle_degrees))
		group.append(_spawn(_player.global_position + direction * 1.2))
	await _physics_frames(2)
	var hit_counts: Array[int] = [0]
	_player.attack.attacked.connect(func(hit_count: int, _total: float, _crit: bool) -> void: hit_counts[0] = maxi(hit_counts[0], hit_count))
	# A tight group (a horde group is ~1.6 m wide): all inside the arc of the first strike.
	assert_bool(ComboDriver.strike(_player, NO_CRIT_ROLL)).is_true()
	assert_int(hit_counts[0]).is_equal(4)
	for fodder: Enemy in group:
		assert_bool(fodder.health.is_dead()).is_true()


func test_ac1145_windup_is_long_and_a_push_cancels_it() -> void:
	_make_player(CLASSES[0])
	var fodder: Enemy = _spawn(Vector3(0.0, 0.0, -1.4))
	fodder.apply_pace(PACE, 0)
	assert_float(fodder.windup(FODDER.attacks[0].windup_time)).is_greater_equal(1.5)
	var behavior: FodderBehavior = fodder.get_behavior() as FodderBehavior
	await _physics_frames(5)
	assert_int(behavior.get_phase()).is_equal(MeleeBehavior.Phase.WINDUP)
	fodder.apply_knockback(Vector3(0.0, 0.0, -1.0), 3.0)
	assert_int(behavior.get_phase()).is_equal(MeleeBehavior.Phase.CHASE)


func test_ac1145_a_landed_swipe_hurts_by_damage_minus_defense_with_a_floor_of_one() -> void:
	_make_player(CLASSES[2])
	var before: float = _player.health.get_health_ratio()
	var applied: float = _player.health.receive_hit_from(FODDER.damage * FODDER.attacks[0].damage_multiplier, null)
	assert_float(applied).is_greater_equal(1.0)
	assert_float(_player.health.get_health_ratio()).is_less(before)


func test_ac1146_without_a_token_it_waits_at_swarm_distance_and_takes_no_ring_place() -> void:
	_make_player(CLASSES[0])
	_player.health.is_invulnerable = true
	_make_coordinator()
	var swarm: FodderConfig = FODDER.behavior_config as FodderConfig
	# Two fodder already hold the fodder tokens, so a third one has to wait.
	for i: int in 2:
		var holder: Enemy = _spawn(Vector3(30.0 + 3.0 * i, 0.0, 30.0), true)
		holder.set_physics_process(false)
		_coordinator.advance(CONFIG.token_gap)
		assert_bool(_coordinator.request_token(holder)).is_true()
		holder.begin_attack()
	_coordinator.advance(CONFIG.token_gap)
	var fodder: Enemy = _spawn(Vector3(8.0, 0.0, 0.0), true)
	await _physics_frames(180)
	assert_int(_coordinator.get_slot(fodder)).is_equal(-1)
	var flat: Vector3 = _player.global_position - fodder.global_position
	flat.y = 0.0
	assert_float(flat.length()).is_between(swarm.swarm_distance - 0.5, swarm.swarm_distance + 0.5)


func test_ac1155_scale_hands_material_and_reuse_reset() -> void:
	_make_player(CLASSES[0])
	var fodder: Enemy = _spawn(Vector3(6.0, 0.0, 0.0))
	assert_float(fodder.get_body_scale()).is_equal(0.7)
	assert_float(FODDER.hands_config.hand_scale).is_equal(0.7)
	await _physics_frames(5)
	fodder.deactivate()
	fodder.activate(Vector3(6.0, 0.0, 0.0), _player)
	assert_bool((fodder.get_behavior() as FodderBehavior).is_attacking()).is_false()
	assert_bool(fodder.health.is_dead()).is_false()
	assert_float(fodder.health.get_health_ratio()).is_equal(1.0)
