extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const RIPOSTE: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/riposte.tres")
const DUEL: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/duel.tres")
const CHALLENGED: DebuffData = preload("res://data/debuffs/challenged.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const ENEMY_HEALTH: float = 40.0
const StatusOverlayProbe := preload("res://test/helpers/status_overlay_probe.gd")

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	await _physics_frames(20)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Idle enemy (no target) whose health is lowered to `health_left` first.
func _spawn_idle_enemy(at: Vector3, health_left: float = ENEMY_HEALTH) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	if health_left < ENEMY_HEALTH:
		enemy.health.receive_hit(ENEMY_HEALTH - health_left)
	return enemy


func test_ac100_different_debuffs_coexist_and_clear_on_recycle() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	var poison := DebuffData.new()
	poison.id = &"test_poison"
	poison.duration = 3.0
	poison.tick_interval = 1.0
	poison.icon = BLEED.icon
	poison.icon_color = BLEED.icon_color
	enemy.debuffs.apply(BLEED, 0.01)
	enemy.debuffs.apply(poison, 0.01)
	enemy.debuffs.apply(BLEED, 0.01)
	assert_int(enemy.debuffs.get_active().size()).is_equal(2)
	enemy.deactivate()
	assert_int(enemy.debuffs.get_active().size()).is_equal(0)


## status-icons.md: the icon lives in the HUD overlay row of the enemy.
func test_ac101_icon_shows_while_the_debuff_lasts() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	var probe: StatusOverlayProbe = auto_free(StatusOverlayProbe.new())
	add_child(probe)
	probe.watch(enemy)
	assert_int(probe.visible_icon_count()).is_equal(0)
	enemy.debuffs.apply(BLEED, 0.01)
	assert_int(probe.visible_icon_count()).is_equal(1)
	assert_object(probe.row().icon(0).get_glyph_texture()).is_same(BLEED.icon)
	for i: int in 5:
		enemy.debuffs.advance(BLEED.tick_interval)
	assert_int(probe.visible_icon_count()).is_equal(0)


func test_ac102_every_bleed_tick_is_reported_for_a_damage_number() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, -2.0))
	var ticks: Array[float] = []
	_registry.enemy_debuff_ticked.connect(func(_e: Enemy, amount: float, _d: DebuffData) -> void: ticks.append(amount))
	enemy.debuffs.apply(BLEED, 0.01)
	for i: int in 5:
		enemy.debuffs.advance(BLEED.tick_interval)
	assert_int(ticks.size()).is_equal(5)
	assert_float(ticks[0]).is_equal_approx(0.4, 0.0001)


## Swift Strike ("Reset", "Asesinato") and the Thrust ("Lacerante") were
## removed with their unique upgrades (warrior-abilities-rework.md §10); the
## Parry's are checked in parry_test.gd.
func test_ac105_levels_are_declared_in_data() -> void:
	assert_int(RIPOSTE.max_level).is_equal(1)
	assert_int(DUEL.max_level).is_equal(1)
	assert_object(DUEL.debuff).is_same(CHALLENGED)
