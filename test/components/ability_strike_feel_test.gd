extends GdUnitTestSuite
## docs/specs/warrior-abilities-rework.md §4.4 and §4.6: hit lag of the ability
## strikes (AC843–AC845) and global buffs (AC839).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const CHARGE_CONFIG: ShieldChargeConfig = preload("res://data/abilities/shield_charge/shield_charge_config.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const PARRY_CONFIG: ParryConfig = preload("res://data/abilities/parry/parry_config.tres")
const RIPOSTE: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/riposte.tres")
const TRIUMPH: BuffData = preload("res://data/buffs/triumph.tres")
const CONCUSSION: BuffData = preload("res://data/buffs/concussion.tres")
const TOLERANCE: float = 0.0001
const HIT: float = 20.0

var _registry: EnemyRegistry
var _player: Player
var _hitstop: HitstopComponent
var _anim: AnimationPlayer
var _slot: AbilityComponent


func before_test() -> void:
	Session.character_class = WARRIOR
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_hitstop = _player.get_node("Hitstop") as HitstopComponent
	_hitstop.set_physics_process(false)
	_anim = (_player.get_node("Visual/Humanoid") as LowPolyHumanoid).anim
	_slot = _player.basic_ability
	_slot.set_physics_process(false)


func after_test() -> void:
	Session.character_class = null


func _spawn(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	enemy.set_physics_process(false)
	return enemy


func test_ac843_an_ability_strike_pauses_the_clip_and_restores_its_speed() -> void:
	_slot.equip(SHIELD_CHARGE)
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -1.2))
	_anim.speed_scale = 1.25
	var camera: ThirdPersonCamera = _player.get_node("CameraRig") as ThirdPersonCamera
	assert_bool(_slot.try_cast()).is_true()
	_slot.advance(CHARGE_CONFIG.travel_time)
	assert_bool(_hitstop.is_active()).is_true()
	assert_float(_anim.speed_scale).is_equal(0.0)
	assert_bool(enemy.is_in_hitlag()).is_true()
	assert_float(camera.get_shake_strength()).is_equal_approx(CHARGE_CONFIG.bash_feel.shake_strength, TOLERANCE)
	assert_float(Engine.time_scale).is_equal(1.0)
	_hitstop.advance(CHARGE_CONFIG.bash_feel.hitlag + 0.01)
	assert_bool(_hitstop.is_active()).is_false()
	assert_float(_anim.speed_scale).is_equal_approx(1.25, TOLERANCE)


func test_ac844_the_end_of_the_cast_resumes_the_clip() -> void:
	_slot.equip(PARRY)
	_player.apply_upgrade(RIPOSTE)
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	assert_bool(_slot.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	_slot.advance(PARRY_CONFIG.riposte_hit_time)
	assert_bool(_hitstop.is_active()).is_true()
	_slot.cut_cast_by_dash()
	assert_bool(_hitstop.is_active()).is_false()
	assert_float(_anim.speed_scale).is_not_equal(0.0)


func test_ac845_the_warrior_strikes_show_the_hit_impact() -> void:
	assert_bool(SHIELD_CHARGE.shows_hit_impact).is_true()
	assert_bool(PARRY.shows_hit_impact).is_true()
	_slot.equip(SHIELD_CHARGE)
	_spawn(Vector3(0.0, 0.0, -1.2))
	var host: HitImpactVfxHost = _player.get_node("HitImpactVfx") as HitImpactVfxHost
	assert_bool(_slot.try_cast()).is_true()
	_slot.advance(CHARGE_CONFIG.travel_time)
	assert_int(host.get_active_count()).is_equal(1)


func test_ac839_a_global_buff_raises_move_speed_and_damage() -> void:
	var base_speed: float = _player.stats.get_stat(PlayerStats.Stat.MOVE_SPEED)
	var base_damage: float = _player.stats.get_stat(PlayerStats.Stat.DAMAGE)
	var buffs: BuffComponent = _player.get_node("BuffComponent") as BuffComponent
	buffs.add_stack(TRIUMPH)
	buffs.add_stack(TRIUMPH)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.MOVE_SPEED)).is_equal_approx(base_speed * 1.2, TOLERANCE)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(base_damage * 1.2, TOLERANCE)
	buffs.advance(TRIUMPH.stack_duration + 0.01)
	assert_int(buffs.get_stacks(TRIUMPH.id)).is_equal(0)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.MOVE_SPEED)).is_equal_approx(base_speed, TOLERANCE)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.DAMAGE)).is_equal_approx(base_damage, TOLERANCE)
	buffs.add_stack(CONCUSSION)
	assert_float(_player.stats.get_stat(PlayerStats.Stat.MOVE_SPEED)).is_equal_approx(base_speed, TOLERANCE)
