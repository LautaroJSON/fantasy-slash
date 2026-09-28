extends GdUnitTestSuite
## docs/specs/warrior-abilities-rework.md §3.2 and §5.2, revised by
## docs/specs/parry-riposte-rework.md: the Parry and its golden upgrades
## (AC829–AC838, AC846 in part; the adapted cases are listed in the new spec §11).

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const CONFIG: ParryConfig = preload("res://data/abilities/parry/parry_config.tres")
const COOLDOWN_CARD: AbilityUpgradeData = preload("res://data/abilities/parry/upgrades/cooldown.tres")
const WINDOW_CARD: AbilityUpgradeData = preload("res://data/abilities/parry/upgrades/window.tres")
const RIPOSTE: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/riposte.tres")
const DUEL: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/duel.tres")
const CHALLENGED: DebuffData = preload("res://data/debuffs/challenged.tres")
const TRIUMPH: BuffData = preload("res://data/buffs/triumph.tres")
const GRUNT: EnemyStats = preload("res://data/enemies/grunt_stats.tres")
const TOLERANCE: float = 0.001
const HIT: float = 20.0
const LETHAL: float = 100000.0

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent


func before_test() -> void:
	Session.character_class = WARRIOR
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_player.health.setup(1000.0, 0.0)
	_ability = _player.basic_ability
	_ability.equip(PARRY)
	# The test drives the cast step by step.
	_ability.set_physics_process(false)
	await _frames(10)


func after_test() -> void:
	Session.character_class = null


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## An idle enemy (no target, no defense): the applied damage is the raw one.
func _spawn(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = GRUNT
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	enemy.health.setup(1000.0, 0.0)
	return enemy


func _behavior() -> ParryAbility:
	return _ability.get_behavior() as ParryAbility


func _guard() -> ShieldGuard:
	return _player.get_node("ShieldGuard") as ShieldGuard


func _riposte_damage() -> float:
	return PARRY.base_damage + PARRY.attack_scaling * _player.stats.get_stat(PlayerStats.Stat.DAMAGE)


func test_ac829_a_tap_raises_the_shield_for_the_window() -> void:
	var front: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	# Adapted (parry-riposte-rework.md §11): the arc is read from the data (it
	# went from 120° to 180°); the side enemy stands 10° outside it.
	var outside: float = deg_to_rad(CONFIG.guard_arc_degrees * 0.5 + 10.0)
	var side: Enemy = _spawn(Vector3(sin(outside), 0.0, -cos(outside)) * 3.0)
	assert_bool(_ability.try_cast()).is_true()
	assert_bool(_ability.is_charging()).is_false()
	assert_bool(_guard().is_raised()).is_true()
	assert_float(_ability.get_cooldown_remaining()).is_equal_approx(PARRY.cooldown, TOLERANCE)
	assert_float(_ability.get_stat(AbilityData.Stat.CAST_DURATION)).is_equal_approx(0.35, TOLERANCE)
	# Outside the arc.
	assert_float(_player.health.receive_hit_from(HIT, side)).is_equal_approx(HIT, TOLERANCE)
	# Adapted (AC1022): the blocked hit starts the invulnerable thrust, so it goes last.
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal(0.0)
	# The player stands still during the window (no ability motion).
	assert_bool(_ability.controls_motion()).is_false()


func test_ac830_a_parry_that_blocks_nothing_leaves_the_player_exposed() -> void:
	assert_bool(_ability.try_cast()).is_true()
	assert_float(_ability.get_cast_remaining()).is_equal_approx(0.35 + CONFIG.whiff_recovery, TOLERANCE)
	_ability.advance(0.35)
	assert_bool(_guard().is_raised()).is_false()
	assert_int(_behavior().get_state()).is_equal(ParryAbility.State.WHIFF)
	assert_str(String(_ability.get_body_clip())).is_equal(String(CONFIG.whiff_body_clip))
	assert_float(_ability.get_cast_remaining()).is_equal_approx(CONFIG.whiff_recovery, TOLERANCE)
	assert_float(_ability.get_cooldown_remaining()).is_equal_approx(PARRY.cooldown - 0.35, TOLERANCE)
	_ability.advance(CONFIG.whiff_recovery)
	assert_bool(_ability.is_casting()).is_false()


func test_ac831_a_frontal_hit_is_cancelled_and_shortens_the_cooldown() -> void:
	var front: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	var damaged: Array[float] = []
	_player.health.damaged.connect(func(amount: float) -> void: damaged.append(amount))
	assert_bool(_ability.try_cast()).is_true()
	_ability.advance(0.2)
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal(0.0)
	assert_int(damaged.size()).is_equal(0)
	assert_float(_ability.get_cooldown_remaining()).is_equal_approx(CONFIG.success_cooldown, TOLERANCE)
	# Adapted (parry-riposte-rework.md, AC1022): the block is answered with the
	# thrust instead of the shield push; the player is invulnerable meanwhile.
	assert_int(_behavior().get_state()).is_equal(ParryAbility.State.RIPOSTE)
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal(0.0)
	assert_str(String(_ability.get_body_clip())).is_equal(String(CONFIG.riposte_body_clip))
	assert_float(_ability.get_cast_remaining()).is_equal_approx(CONFIG.riposte_duration, TOLERANCE)
	_ability.advance(CONFIG.riposte_duration)
	assert_bool(_ability.is_casting()).is_false()


func test_ac832_hits_from_behind_or_after_the_window_land() -> void:
	var front: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	var back: Enemy = _spawn(Vector3(0.0, 0.0, 2.0))
	assert_bool(_ability.try_cast()).is_true()
	_ability.advance(0.1)
	assert_float(_player.health.receive_hit_from(HIT, back)).is_equal_approx(HIT, TOLERANCE)
	_ability.advance(0.25)
	assert_int(_behavior().get_state()).is_equal(ParryAbility.State.WHIFF)
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal_approx(HIT, TOLERANCE)


func test_ac833_a_dash_cuts_the_parry_and_a_grab_is_not_blocked() -> void:
	assert_bool(_ability.try_cast()).is_true()
	_ability.advance(0.1)
	_ability.cut_cast_by_dash()
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_guard().is_raised()).is_false()
	assert_bool(_ability.is_on_cooldown()).is_true()
	_ability.reset_cooldown()
	assert_bool(_ability.try_cast()).is_true()
	_player.begin_hold(1.0)
	assert_bool(_player.is_held()).is_true()
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_guard().is_raised()).is_false()


func test_ac834_cooldown_and_window_cards() -> void:
	for i: int in COOLDOWN_CARD.max_stacks:
		_ability.add_upgrade(COOLDOWN_CARD)
	assert_float(_ability.get_stat(AbilityData.Stat.COOLDOWN)).is_equal_approx(PARRY.min_cooldown, TOLERANCE)
	assert_float(PARRY.min_cooldown).is_equal_approx(3.0, TOLERANCE)
	assert_int(WINDOW_CARD.max_stacks).is_equal(2)
	for i: int in WINDOW_CARD.max_stacks:
		_ability.add_upgrade(WINDOW_CARD)
	assert_float(_ability.get_stat(AbilityData.Stat.CAST_DURATION)).is_equal_approx(0.45, TOLERANCE)
	var front: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	assert_bool(_ability.try_cast()).is_true()
	_ability.advance(0.42)
	assert_float(_player.health.receive_hit_from(HIT, front)).is_equal(0.0)


## Adapted (AC1022): without Contragolpe every block thrusts; the cooldown drops
## to success_cooldown instead of being renewed.
func test_ac836_a_block_thrusts_at_the_attacker() -> void:
	var attacker: Enemy = _spawn(Vector3(-2.0, 0.0, -1.0))
	var hits: Array[float] = []
	_ability.enemy_hit.connect(func(_e: Enemy, applied: float, _c: bool) -> void: hits.append(applied))
	assert_bool(_ability.try_cast()).is_true()
	_ability.advance(0.1)
	_player.health.receive_hit_from(HIT, attacker)
	assert_float(_ability.get_cooldown_remaining()).is_equal_approx(CONFIG.success_cooldown, TOLERANCE)
	assert_int(_behavior().get_state()).is_equal(ParryAbility.State.RIPOSTE)
	assert_str(String(_ability.get_body_clip())).is_equal(String(CONFIG.riposte_body_clip))
	assert_float(_ability.get_cast_remaining()).is_equal_approx(CONFIG.riposte_duration, TOLERANCE)
	var facing: Vector3 = -(_player.get_node("Visual") as Node3D).global_basis.z
	var to_attacker: Vector3 = (attacker.global_position - _player.global_position)
	to_attacker.y = 0.0
	assert_float(rad_to_deg(facing.angle_to(to_attacker.normalized()))).is_less(1.0)
	_ability.advance(CONFIG.riposte_hit_time)
	assert_int(hits.size()).is_equal(1)
	var crit: float = _riposte_damage() * (1.0 + _player.stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	assert_bool(is_equal_approx(hits[0], _riposte_damage()) or is_equal_approx(hits[0], crit)).is_true()
	assert_bool(attacker.is_knocked_back()).is_true()
	# A second block no longer happens (the shield is down) and starts no other riposte.
	_player.health.receive_hit_from(HIT, attacker)
	assert_int(hits.size()).is_equal(1)
	assert_float(_ability.get_cast_remaining()).is_equal_approx(CONFIG.riposte_duration - CONFIG.riposte_hit_time, TOLERANCE)


func test_ac837_the_riposte_is_invulnerable() -> void:
	var attacker: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	assert_bool(_player.health.is_invulnerable).is_true()
	_ability.advance(CONFIG.riposte_duration)
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_player.health.is_invulnerable).is_false()
	_ability.reset_cooldown()
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)
	assert_bool(_player.health.is_invulnerable).is_true()
	_ability.cut_cast_by_dash()
	# The dash sets its own iframes; the riposte's end with the cut.
	assert_bool(_behavior().get_state() == ParryAbility.State.IDLE).is_true()


## Adapted (AC1022, AC1031): the first block of a cast lowers the shield for
## the thrust, so each parry marks one attacker; Triumph stacks up to 5.
func test_ac838_duel_marks_the_attacker_and_its_death_grants_triumph() -> void:
	_player.apply_upgrade(DUEL)
	var first: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	var second: Enemy = _spawn(Vector3(0.5, 0.0, -2.0))
	var unmarked: Enemy = _spawn(Vector3(-0.5, 0.0, -2.5))
	_parry_hit_by(first)
	assert_float(first.debuffs.get_remaining_seconds(CHALLENGED.id)).is_equal_approx(CHALLENGED.duration, TOLERANCE)
	_parry_hit_by(second)
	unmarked.health.receive_hit(LETHAL)
	assert_int(_ability.buffs.get_stacks(TRIUMPH.id)).is_equal(0)
	first.health.receive_hit(LETHAL)
	assert_int(_ability.buffs.get_stacks(TRIUMPH.id)).is_equal(1)
	_ability.buffs.advance(3.0)
	second.health.receive_hit(LETHAL)
	assert_int(_ability.buffs.get_stacks(TRIUMPH.id)).is_equal(2)
	assert_float(_ability.buffs.get_time_left(TRIUMPH.id)).is_equal_approx(TRIUMPH.stack_duration, TOLERANCE)
	for i: int in TRIUMPH.max_stacks + 1 - 2:
		var extra: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
		_parry_hit_by(extra)
		extra.health.receive_hit(LETHAL)
	assert_int(_ability.buffs.get_stacks(TRIUMPH.id)).is_equal(TRIUMPH.max_stacks)
	_ability.buffs.advance(TRIUMPH.stack_duration + 0.1)
	assert_int(_ability.buffs.get_stacks(TRIUMPH.id)).is_equal(0)


## A fresh parry blocked by `attacker` (the previous cast is let finish).
func _parry_hit_by(attacker: Enemy) -> void:
	_ability.advance(CONFIG.riposte_duration + CONFIG.whiff_recovery + 1.0)
	_ability.reset_cooldown()
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, attacker)


func test_ac838_a_mark_that_ran_out_grants_nothing() -> void:
	_player.apply_upgrade(DUEL)
	var enemy: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, enemy)
	enemy.debuffs.advance(CHALLENGED.duration + 0.1)
	assert_bool(enemy.debuffs.has_debuff(CHALLENGED.id)).is_false()
	enemy.health.receive_hit(LETHAL)
	assert_int(_ability.buffs.get_stacks(TRIUMPH.id)).is_equal(0)


## Adapted (AC1022): a cast blocks once (then the thrust lowers the shield).
func test_ac846_every_block_sparks_on_the_shield() -> void:
	var front: Enemy = _spawn(Vector3(0.0, 0.0, -2.0))
	var sparks: BlockSparkVfx = _behavior().get_block_vfx()
	assert_int(sparks.get_pool_size()).is_equal(sparks.config.pool_size)
	assert_int(sparks.count_emitting()).is_equal(0)
	assert_bool(_ability.try_cast()).is_true()
	_player.health.receive_hit_from(HIT, front)
	_player.health.receive_hit_from(HIT, front)
	assert_int(sparks.count_emitting()).is_equal(1)
