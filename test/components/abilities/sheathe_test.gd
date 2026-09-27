extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const SHEATHE: AbilityData = preload("res://data/abilities/sheathe/sheathe.tres")
const SHEATHE_CONFIG: SheatheConfig = preload("res://data/abilities/sheathe/sheathe_config.tres")
const DAMAGE_UPGRADE: AbilityUpgradeData = preload("res://data/abilities/sheathe/upgrades/damage.tres")
const CHARGE_UPGRADE: AbilityUpgradeData = preload("res://data/abilities/sheathe/upgrades/charge_speed.tres")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const ENEMY_HEALTH: float = 40.0
const STEP: float = 0.05
const TOLERANCE: float = 0.0001
const DAMAGE_TOLERANCE: float = 0.01

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _hits: Array[Enemy] = []
var _crits: Array[bool] = []


func before_test() -> void:
	Session.character_class = SAMURAI
	_add_static(TestWorld.make_floor(60.0))
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_hits.clear()
	_crits.clear()
	_ability.enemy_hit.connect(_on_enemy_hit)
	await _physics_frames(20)


func after_test() -> void:
	Session.character_class = null
	Input.action_release(&"ability_basic")
	Input.action_release(&"attack")
	Input.action_release(&"dash")
	Input.action_release(&"jump")
	Input.action_release(&"move_forward")


func _on_enemy_hit(enemy: Enemy, _applied: float, is_crit: bool) -> void:
	_hits.append(enemy)
	_crits.append(is_crit)


func _add_static(body: StaticBody3D) -> void:
	auto_free(body)
	add_child(body)


func _spawn_idle_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(at, null)
	return enemy


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Drives the slot by hand (its own physics step is off) for determinism.
func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > TOLERANCE:
		var step: float = minf(STEP, left)
		_ability.advance(step)
		left -= step


func _equip_by_hand() -> void:
	_ability.set_physics_process(false)
	_ability.equip(SHEATHE)


## Presses, holds for `seconds`, releases and lets the cast land.
func _charge_and_slash(seconds: float) -> void:
	assert_bool(_ability.try_cast()).is_true()
	_advance(seconds)
	assert_bool(_ability.release_charge()).is_true()
	_advance(SHEATHE.cast_duration + STEP)


## The player faces -Z at spawn: enemies straight ahead are at negative z.
func _ahead(distance: float) -> Vector3:
	return _player.global_position + Vector3(0.0, 0.0, -distance)


func _full_damage() -> float:
	return SHEATHE.base_damage + SHEATHE.attack_scaling * SAMURAI.base_stats.damage


func _set_crit_chance(chance: float) -> void:
	var stats: PlayerStats = SAMURAI.base_stats.duplicate() as PlayerStats
	stats.crit_chance = chance
	_player.stats.set_base_stats(stats)


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func test_ac239_the_press_starts_charging_without_cooldown_and_the_charge_holds_at_full() -> void:
	_equip_by_hand()
	assert_bool(_ability.try_cast()).is_true()
	assert_bool(_ability.is_charging()).is_true()
	assert_bool(_ability.is_casting()).is_false()
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	_advance(1.5)
	assert_float(_ability.get_charge_ratio()).is_equal_approx(0.5, TOLERANCE)
	_advance(3.5)
	assert_bool(_ability.is_charging()).is_true()
	assert_float(_ability.get_charge_ratio()).is_equal(1.0)
	assert_bool(_ability.try_cast()).is_false()


## Replaces AC240 (sheathe-dash-cancel.md): the hit lands on the release.
func test_ac361_the_release_lands_the_hit_at_once_and_starts_the_cooldown() -> void:
	var enemy: Enemy = _spawn_idle_enemy(_ahead(2.0))
	_equip_by_hand()
	_ability.try_cast()
	_advance(1.0)
	assert_bool(_ability.release_charge()).is_true()
	assert_bool(_ability.is_charging()).is_false()
	assert_bool(_ability.is_casting()).is_true()
	assert_float(_ability.get_cooldown_ratio()).is_equal(1.0)
	assert_float(_ability.get_cast_remaining()).is_equal_approx(SHEATHE.cast_duration, TOLERANCE)
	assert_array(_hits).is_equal([enemy])
	_advance(SHEATHE.cast_duration + STEP)
	assert_bool(_ability.is_casting()).is_false()
	assert_array(_hits).is_equal([enemy])
	assert_float(SHEATHE.cooldown).is_equal(8.0)
	_advance(SHEATHE.cooldown)
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)


func test_ac241_damage_scales_linearly_from_thirty_percent_to_full() -> void:
	_set_crit_chance(0.0)
	_equip_by_hand()
	var tap: Enemy = _spawn_idle_enemy(_ahead(1.0))
	_charge_and_slash(0.0)
	assert_float(tap.health.current_health).is_equal_approx(ENEMY_HEALTH - 0.3 * _full_damage(), DAMAGE_TOLERANCE)
	tap.health.receive_true_damage(ENEMY_HEALTH)
	_ability.reset_cooldown()
	var half: Enemy = _spawn_idle_enemy(_ahead(1.0))
	_charge_and_slash(1.5)
	assert_float(half.health.current_health).is_equal_approx(ENEMY_HEALTH - 0.65 * _full_damage(), DAMAGE_TOLERANCE)
	half.health.receive_true_damage(ENEMY_HEALTH)
	_ability.reset_cooldown()
	var full: Enemy = _spawn_idle_enemy(_ahead(1.0))
	_charge_and_slash(5.0)
	assert_float(full.health.current_health).is_equal_approx(ENEMY_HEALTH - _full_damage(), DAMAGE_TOLERANCE)
	assert_float(_full_damage()).is_equal_approx(30.0 + 0.5 * 14.0, TOLERANCE)


func test_ac242_the_slash_can_crit_with_the_player_crit_stats() -> void:
	_set_crit_chance(1.0)
	_equip_by_hand()
	var enemy: Enemy = _spawn_idle_enemy(_ahead(1.0))
	_charge_and_slash(0.0)
	var crit_bonus: float = SAMURAI.base_stats.crit_damage
	var expected: float = 0.3 * _full_damage() * (1.0 + crit_bonus)
	assert_float(enemy.health.current_health).is_equal_approx(ENEMY_HEALTH - expected, DAMAGE_TOLERANCE)
	assert_array(_crits).is_equal([true])


func test_ac242_without_crit_chance_the_slash_never_crits() -> void:
	_set_crit_chance(0.0)
	_equip_by_hand()
	_spawn_idle_enemy(_ahead(1.0))
	_charge_and_slash(0.0)
	assert_array(_crits).is_equal([false])


func test_ac243_the_reach_grows_with_the_charge() -> void:
	_set_crit_chance(0.0)
	_equip_by_hand()
	var enemy: Enemy = _spawn_idle_enemy(_ahead(3.0))
	_charge_and_slash(0.0)
	assert_bool(_hits.has(enemy)).is_false()
	assert_float(enemy.health.current_health).is_equal(ENEMY_HEALTH)
	_ability.reset_cooldown()
	_charge_and_slash(SHEATHE.charge_time)
	assert_bool(_hits.has(enemy)).is_true()


func test_ac244_hit_enemies_are_pushed_away_with_the_scaled_knockback() -> void:
	_equip_by_hand()
	var enemy: Enemy = _spawn_idle_enemy(_ahead(1.0))
	_charge_and_slash(0.0)
	var push: Vector3 = enemy.get_knockback_velocity()
	assert_float(push.length()).is_equal_approx(SHEATHE_CONFIG.knockback_speed * 0.3, TOLERANCE)
	assert_float(push.z).is_less(0.0)


func test_ac245_the_wave_pushes_nearby_enemies_without_damage() -> void:
	_equip_by_hand()
	# The nearest enemy, ahead, keeps the player facing -Z.
	_spawn_idle_enemy(_ahead(1.0))
	var behind: Enemy = _spawn_idle_enemy(_player.global_position + Vector3(0.0, 0.0, 1.5))
	var far_behind: Enemy = _spawn_idle_enemy(_player.global_position + Vector3(0.0, 0.0, 5.0))
	_charge_and_slash(SHEATHE.charge_time)
	assert_float(behind.health.current_health).is_equal(ENEMY_HEALTH)
	assert_bool(_hits.has(behind)).is_false()
	var push: Vector3 = behind.get_knockback_velocity()
	assert_float(push.length()).is_equal_approx(SHEATHE_CONFIG.knockback_speed, TOLERANCE)
	assert_float(push.z).is_greater(0.0)
	assert_bool(far_behind.is_knocked_back()).is_false()
	assert_float(far_behind.health.current_health).is_equal(ENEMY_HEALTH)


func test_ac246_charging_walks_very_slowly_and_cannot_attack_or_jump() -> void:
	_ability.equip(SHEATHE)
	var swings: Array[int] = [0]
	_player.attack.attacked.connect(func(_h: int, _t: float, _c: bool) -> void: swings[0] += 1)
	Input.action_press(&"ability_basic")
	await _physics_frames(2)
	assert_bool(_ability.is_charging()).is_true()
	Input.action_press(&"move_forward")
	Input.action_press(&"attack")
	await _physics_frames(30)
	assert_bool(_ability.is_charging()).is_true()
	var expected: float = SAMURAI.base_stats.move_speed * SHEATHE_CONFIG.charge_move_speed_factor
	assert_float(_horizontal_speed()).is_equal_approx(expected, expected * 0.05)
	Input.action_press(&"jump")
	await _physics_frames(5)
	assert_float(_player.velocity.y).is_less_equal(0.0)
	assert_int(swings[0]).is_equal(0)
	assert_float(SHEATHE_CONFIG.charge_move_speed_factor).is_equal_approx(0.2, TOLERANCE)


func test_ac247_the_dash_keeps_the_charge_and_the_facing() -> void:
	_ability.equip(SHEATHE)
	var visual: Node3D = _player.get_node("Visual") as Node3D
	Input.action_press(&"ability_basic")
	await _physics_frames(10)
	var yaw: float = visual.rotation.y
	var start: Vector3 = _player.global_position
	var charge_before: float = _ability.get_charge_ratio()
	Input.action_press(&"dash")
	await _physics_frames(2)
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	var moved: float = Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()
	assert_float(moved).is_equal_approx(SAMURAI.base_stats.dash_distance, 0.15)
	assert_bool(_ability.is_charging()).is_true()
	assert_float(_ability.get_charge_ratio()).is_greater(charge_before)
	assert_float(visual.rotation.y).is_equal_approx(yaw, 0.001)


func test_ac248_releasing_mid_dash_slashes_when_the_dash_ends() -> void:
	_ability.equip(SHEATHE)
	Input.action_press(&"ability_basic")
	await _physics_frames(10)
	Input.action_press(&"dash")
	await _physics_frames(2)
	Input.action_release(&"dash")
	Input.action_release(&"ability_basic")
	await _physics_frames(1)
	assert_bool(_player.dash.is_dashing()).is_true()
	assert_bool(_ability.is_charging()).is_true()
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await _physics_frames(1)
	assert_bool(_ability.is_charging()).is_false()
	assert_bool(_ability.is_casting()).is_true()


func test_ac249_charging_halves_the_damage_taken_without_cancelling() -> void:
	_equip_by_hand()
	var raw: float = 21.0
	var mitigated: float = raw - SAMURAI.base_stats.defense
	_ability.try_cast()
	var taken: float = _player.health.receive_hit(raw)
	assert_float(taken).is_equal_approx(mitigated * 0.5, TOLERANCE)
	assert_bool(_ability.is_charging()).is_true()
	_ability.release_charge()
	taken = _player.health.receive_hit(raw)
	assert_float(taken).is_equal_approx(mitigated, TOLERANCE)
	assert_float(SHEATHE_CONFIG.charge_damage_reduction).is_equal_approx(0.5, TOLERANCE)


func test_ac250_the_outline_grows_with_the_charge_and_fades_after_the_hit() -> void:
	_equip_by_hand()
	var indicator: AbilityRectIndicator = (_ability.get_behavior() as SheatheAbility).get_indicator()
	_ability.try_cast()
	assert_bool(indicator.is_showing()).is_true()
	# Adapted (docs/specs/spin-visual-rework.md §2.6): the area is one fill, so
	# its length replaces the far edge's position.
	assert_float(indicator.get_length()).is_equal_approx(SHEATHE.hit_range * 0.3, TOLERANCE)
	_advance(1.5)
	assert_float(indicator.get_length()).is_equal_approx(SHEATHE.hit_range * 0.65, TOLERANCE)
	assert_float(indicator.get_transparency()).is_not_equal(SHEATHE_CONFIG.full_charge_transparency)
	_advance(1.5 + STEP)
	assert_float(indicator.get_length()).is_equal_approx(SHEATHE.hit_range, TOLERANCE)
	# The full-charge milestone pulses the outline first (sheathe-feel.md).
	indicator.advance(indicator.config.pulse_duration)
	assert_float(indicator.get_transparency()).is_equal_approx(SHEATHE_CONFIG.full_charge_transparency, TOLERANCE)
	_ability.release_charge()
	_advance(SHEATHE.cast_duration + STEP)
	indicator.advance(1.0)
	assert_bool(indicator.is_showing()).is_false()


func test_ac250_the_katana_rests_in_its_sheath_while_charging_and_returns_after() -> void:
	_equip_by_hand()
	var pivot: Node3D = _player.get_node("Visual/SwordPivot") as Node3D
	_ability.try_cast()
	# Adapted (docs/specs/sheath-socket-hand-grip.md): the katana waits in the
	# sheath socket on the torso (no fixed sheathed pose in SheatheConfig).
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	assert_bool(mount.is_holding_in_sheath()).is_true()
	var sheathed: Transform3D = mount.get_sheath_pose()
	assert_vector(pivot.global_position).is_equal_approx(sheathed.origin, Vector3.ONE * 0.001)
	assert_float(pivot.global_basis.get_rotation_quaternion().angle_to(sheathed.basis.get_rotation_quaternion())).is_less(0.01)
	_ability.release_charge()
	assert_bool(mount.is_holding_in_sheath()).is_false()
	# Adapted (docs/specs/sheathe-release-animation.md): no sheathe_slash on the
	# SwingPlayer; the katana returns to the hand, which draws the cut.
	var animator: AnimationPlayer = _player.get_node("SwingPlayer") as AnimationPlayer
	assert_bool(animator.is_playing()).is_false()
	mount.update(1.0)
	var in_hand: Transform3D = mount.get_hand_pose()
	assert_vector(pivot.global_position).is_equal_approx(in_hand.origin, Vector3.ONE * 0.001)
	assert_float(pivot.global_basis.get_rotation_quaternion().angle_to(in_hand.basis.get_rotation_quaternion())).is_less(0.01)


func test_ac252_damage_and_charge_speed_upgrades() -> void:
	_equip_by_hand()
	_ability.add_upgrade(DAMAGE_UPGRADE)
	assert_float(_ability.get_stat(AbilityData.Stat.BASE_DAMAGE)).is_equal_approx(36.0, TOLERANCE)
	assert_int(DAMAGE_UPGRADE.max_stacks).is_equal(6)
	_ability.add_upgrade(CHARGE_UPGRADE)
	assert_float(_ability.get_stat(AbilityData.Stat.CHARGE_TIME)).is_equal_approx(2.7, TOLERANCE)
	_ability.try_cast()
	_advance(1.35)
	assert_float(_ability.get_charge_ratio()).is_equal_approx(0.5, TOLERANCE)
	_ability.cancel_charge()
	for i: int in 10:
		_ability.add_upgrade(CHARGE_UPGRADE)
	assert_float(_ability.get_stat(AbilityData.Stat.CHARGE_TIME)).is_equal(SHEATHE.min_charge_time)
	assert_float(SHEATHE.min_charge_time).is_equal_approx(1.5, TOLERANCE)
	assert_int(CHARGE_UPGRADE.max_stacks).is_equal(5)


func test_ac253_press_cast_abilities_still_cast_on_the_press() -> void:
	_ability.set_physics_process(false)
	_ability.equip(THRUST)
	assert_bool(_ability.try_cast()).is_true()
	assert_bool(_ability.is_charging()).is_false()
	assert_bool(_ability.is_casting()).is_true()
	assert_float(_ability.get_cooldown_ratio()).is_equal(1.0)
	assert_bool(_ability.release_charge()).is_false()


func test_ac253_the_spin_still_casts_on_the_press() -> void:
	_ability.set_physics_process(false)
	_ability.equip(SPIN)
	assert_bool(_ability.try_cast()).is_true()
	assert_bool(_ability.is_charging()).is_false()
	assert_bool(_ability.is_casting()).is_true()
	assert_float(_ability.get_cooldown_ratio()).is_equal(1.0)


func test_ac254_equipping_mid_charge_cancels_it_and_the_damage_reduction() -> void:
	_equip_by_hand()
	_ability.try_cast()
	assert_float(_player.health.damage_reduction).is_greater(0.0)
	_ability.equip(SHEATHE)
	assert_bool(_ability.is_charging()).is_false()
	assert_float(_player.health.damage_reduction).is_equal(0.0)
	assert_float(_ability.get_cooldown_ratio()).is_equal(0.0)
	await get_tree().process_frame
