extends GdUnitTestSuite
## The class weapon in the humanoid's hand (docs/specs/humanoid-player-model.md, AC603).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
## Seconds of the sweep that takes the pivot (AC603).
const SWEEP_SECONDS: float = 0.3
const CONFIG: PlayerAnimationConfig = preload("res://data/player/player_animation_config.tres")
const HAND_TOLERANCE: float = 0.05
## Frame slack on top of the blend time, in milliseconds.
const BLEND_SLACK_MS: int = 100

var _registry: EnemyRegistry
var _player: Player
var _mount: WeaponMount
var _pivot: Node3D


func after_test() -> void:
	Session.character_class = null


func _spawn_player(character_class: CharacterClassData) -> void:
	Session.character_class = character_class
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_mount = _player.get_node("WeaponMount") as WeaponMount
	_pivot = _player.get_node("Visual/SwordPivot") as Node3D


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _distance_to_hand() -> float:
	return _pivot.global_position.distance_to(_mount.get_hand_pose().origin)


func test_ac603_every_class_weapon_follows_the_hand() -> void:
	for character_class: CharacterClassData in [WARRIOR, BERSERKER, SAMURAI]:
		_spawn_player(character_class)
		await _frames(20)
		assert_bool(_mount.is_mounted()).is_true()
		assert_float(_distance_to_hand()).is_less_equal(HAND_TOLERANCE)


func test_ac603_the_weapon_stays_in_the_hand_during_a_strike() -> void:
	_spawn_player(WARRIOR)
	await _frames(20)
	_player.attack.request_attack()
	for i: int in 20:
		await get_tree().process_frame
		assert_float(_distance_to_hand()).is_less_equal(HAND_TOLERANCE)


## The Warrior abilities keep the weapon in the hand (warrior-abilities-rework.md,
## AC847): the sweep of the SwordSwing is what still takes the pivot.
func test_ac603_a_sweep_owns_the_pivot_and_hands_it_back() -> void:
	_spawn_player(WARRIOR)
	await _frames(20)
	_player.sword_swing.play(_player.stats.get_stat(PlayerStats.Stat.ATTACK_ARC), SWEEP_SECONDS, 1.0)
	await _frames(2)
	assert_bool(_mount.is_hand_free()).is_false()
	assert_bool(_mount.is_mounted()).is_false()
	while not _mount.is_hand_free():
		await get_tree().process_frame
	await _frames(1)
	assert_bool(_mount.is_mounted()).is_true()
	var start_ms: int = Time.get_ticks_msec()
	while _distance_to_hand() > HAND_TOLERANCE and Time.get_ticks_msec() - start_ms < 1000:
		await get_tree().process_frame
	assert_float(_distance_to_hand()).is_less_equal(HAND_TOLERANCE)
	assert_int(Time.get_ticks_msec() - start_ms).is_less_equal(int(CONFIG.weapon_mount_blend * 1000.0) + BLEND_SLACK_MS)
