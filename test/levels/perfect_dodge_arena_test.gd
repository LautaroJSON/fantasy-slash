extends GdUnitTestSuite
## Perfect dodge in the arena with each class (docs/specs/perfect-dodge.md, AC1181).
## The hit is injected with receive_hit_from using a real enemy of the wave as
## the attacker, at the moments the spec describes: 0.05 s into the dash counts;
## a hit after the dash has ended (the dash started 0.5 s earlier) does not and
## hurts.

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const TestWorld := preload("res://test/helpers/test_world.gd")
const CLASSES: Array[String] = [
	"res://data/classes/warrior/warrior.tres",
	"res://data/classes/berserker/berserker.tres",
	"res://data/classes/samurai/samurai.tres",
]
const HIT: float = 8.0

var _arena: Node3D
var _player: Player
var _registry: EnemyRegistry


func after_test() -> void:
	Session.character_class = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _start_run(class_path: String) -> void:
	Session.character_class = load(class_path) as CharacterClassData
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	TestWorld.without_horde(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	# The ability picker opens deferred: keep the tree paused until it is chosen.
	get_tree().paused = true
	await get_tree().process_frame
	var basic: AbilityData = _player.get_character_class().abilities.get_for_slot(AbilityData.Slot.BASIC)[0]
	(_arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(basic)
	# Nothing may reach the player while the test places the hits.
	for enemy: Enemy in _registry.get_active():
		enemy.set_physics_process(false)


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _dodge_with(class_path: String) -> void:
	await _start_run(class_path)
	var attacker: Enemy = _registry.get_active()[0]
	var dodges: Array[Enemy] = []
	_player.perfect_dodge.perfect_dodged.connect(func(enemy: Enemy) -> void: dodges.append(enemy))
	# A dash and a hit 0.05 s into it.
	_player.dash.reset_cooldown()
	assert_bool(_player.dash.try_dash(Vector3.RIGHT)).is_true()
	await _physics_frames(3)
	var before: float = _player.health.current_health
	_player.health.receive_hit_from(HIT, attacker)
	assert_array(dodges).is_equal([attacker])
	assert_float(_player.health.current_health).is_equal(before)
	# Another dash whose hit only comes 0.5 s later: the dash is over.
	_player.dash.reset_cooldown()
	await _physics_frames(int(_player.perfect_dodge.config.min_interval * 60.0) + 2)
	_player.dash.reset_cooldown()
	assert_bool(_player.dash.try_dash(Vector3.LEFT)).is_true()
	await _physics_frames(30)
	assert_bool(_player.dash.is_dashing()).is_false()
	_player.health.receive_hit_from(HIT, attacker)
	assert_array(dodges).is_equal([attacker])
	assert_float(_player.health.current_health).is_less(before)


func test_ac1181_warrior_dodges_perfectly_early_in_the_dash_only() -> void:
	await _dodge_with(CLASSES[0])


func test_ac1181_berserker_dodges_perfectly_early_in_the_dash_only() -> void:
	await _dodge_with(CLASSES[1])


func test_ac1181_samurai_dodges_perfectly_early_in_the_dash_only() -> void:
	await _dodge_with(CLASSES[2])
