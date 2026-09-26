extends GdUnitTestSuite

const TestWorld := preload("res://test/helpers/test_world.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const BERSERKER: CharacterClassData = preload("res://data/classes/berserker/berserker.tres")
const SPIN: AbilityData = preload("res://data/abilities/spin/spin.tres")
const SPIN_CONFIG: SpinConfig = preload("res://data/abilities/spin/spin_config.tres")
const VFX_CONFIG: DashSlashVfxConfig = preload("res://data/abilities/spin/dash_slash_vfx_config.tres")
const GLOW_MATERIAL: StandardMaterial3D = preload("res://materials/vfx/wind_cut_additive_material.tres")
const ARMOR_BREAK: AbilityUniqueUpgradeData = preload("res://data/abilities/spin/unique/armor_break.tres")
const INVIGORATING: AbilityUniqueUpgradeData = preload("res://data/abilities/spin/unique/invigorating.tres")
const TORNADO: AbilityUniqueUpgradeData = preload("res://data/abilities/spin/unique/tornado.tres")
const WEAKEN: DebuffData = preload("res://data/debuffs/weaken.tres")
const CONCUSSION: BuffData = preload("res://data/buffs/concussion.tres")
## Tough enough that no slash kills it (the spin damage is tuned in data).
const ENEMY_HEALTH: float = 10000.0
const TOLERANCE: float = 0.0001
const DISTANCE_TOLERANCE: float = 0.15
## Sideways offset of the enemies in the dash path, so their bodies do not
## stop the dash; still well inside the slash band.
const IN_PATH_X: float = 0.8

var _registry: EnemyRegistry
var _player: Player
var _ability: AbilityComponent
var _spin: SpinAbility
var _crits: Array[bool] = []


func before_test() -> void:
	# Another suite may leave these held: a held action never reads as just pressed.
	Input.action_release(&"dash")
	Input.action_release(&"move_right")
	Session.character_class = BERSERKER
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	_registry = auto_free(EnemyRegistry.new())
	add_child(_registry)
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = _registry
	add_child(_player)
	_ability = _player.basic_ability
	_ability.equip(SPIN)
	_spin = _ability.get_behavior() as SpinAbility
	_crits.clear()
	_ability.enemy_hit.connect(func(_e: Enemy, _a: float, is_crit: bool) -> void: _crits.append(is_crit))
	await _physics_frames(20)


func after_test() -> void:
	Session.character_class = null
	Input.action_release(&"dash")
	Input.action_release(&"move_right")


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Idle enemy (no target) at `offset` from the player, lowered to `health_left` first.
func _spawn_idle_enemy(offset: Vector3, health_left: float = ENEMY_HEALTH) -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.registry = _registry
	add_child(enemy)
	enemy.activate(_player.global_position + offset, null)
	enemy.health.setup(ENEMY_HEALTH, 0.0)
	if health_left < ENEMY_HEALTH:
		enemy.health.receive_true_damage(ENEMY_HEALTH - health_left)
	return enemy


## The slot is frozen so the spin neither turns the player nor ticks its
## cooldown: without move input the dash goes forward (-Z).
func _spin_by_hand() -> void:
	_ability.set_physics_process(false)
	_player.buffs.set_physics_process(false)
	assert_bool(_ability.try_cast()).is_true()


func _start_dash() -> void:
	Input.action_press(&"dash")
	# The press is read on the next physics step after it.
	await _physics_frames(2)
	Input.action_release(&"dash")
	assert_bool(_player.dash.is_dashing()).is_true()


func _wait_dash_end() -> void:
	while _player.dash.is_dashing():
		await get_tree().physics_frame
	await get_tree().physics_frame


func _cooldown_left() -> float:
	return _ability.get_cooldown_ratio() * _ability.get_stat(AbilityData.Stat.COOLDOWN)


func _slash_damage() -> float:
	var hit: float = _ability.get_stat(AbilityData.Stat.BASE_DAMAGE) \
		+ _ability.get_stat(AbilityData.Stat.ATTACK_SCALING) * _player.stats.get_stat(PlayerStats.Stat.DAMAGE)
	return hit * SPIN_CONFIG.dash_slash_damage_factor


func _flat_distance(from: Vector3) -> float:
	return Vector2(_player.global_position.x - from.x, _player.global_position.z - from.z).length()


func test_ac567_dash_slash_data() -> void:
	assert_bool(SPIN.dash_cancels_cast).is_true()
	assert_float(SPIN_CONFIG.dash_slash_damage_factor).is_equal(2.0)
	assert_float(SPIN_CONFIG.dash_slash_width).is_equal(2.5)
	assert_float(SPIN_CONFIG.dash_slash_knockback_speed).is_equal(4.0)
	assert_float(SPIN_CONFIG.dash_slash_arc_degrees).is_equal(220.0)
	assert_float(SPIN_CONFIG.dash_slash_sweep_duration).is_equal_approx(0.2, TOLERANCE)
	assert_float(VFX_CONFIG.blade_height).is_equal_approx(1.1, TOLERANCE)
	assert_float(VFX_CONFIG.flash_start_transparency).is_equal_approx(0.5, TOLERANCE)
	assert_float(VFX_CONFIG.flash_duration).is_equal_approx(0.15, TOLERANCE)
	assert_int(VFX_CONFIG.spark_amount).is_equal(24)
	assert_object(_spin.get_dash_slash().glow_material).is_same(GLOW_MATERIAL)


func test_ac568_dashing_ends_the_spin_with_a_normal_dash() -> void:
	_spin_by_hand()
	var start: Vector3 = _player.global_position
	var cooldown_before: float = _cooldown_left()
	await _start_dash()
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_player.health.is_invulnerable).is_true()
	await _wait_dash_end()
	assert_bool(_player.health.is_invulnerable).is_false()
	assert_float(_flat_distance(start)).is_equal_approx(BERSERKER.base_stats.dash_distance, DISTANCE_TOLERANCE)
	assert_float(_cooldown_left()).is_equal_approx(cooldown_before, TOLERANCE)
	assert_bool(_ability.is_on_cooldown()).is_true()


func test_ac569_enemies_crossed_take_one_double_hit_the_rest_nothing() -> void:
	var crossed: Enemy = _spawn_idle_enemy(Vector3(IN_PATH_X, 0.0, -1.5))
	var probe: Enemy = _spawn_idle_enemy(Vector3(0.0, 0.0, 20.0))
	var outside_x: float = SPIN_CONFIG.dash_slash_width / 2.0 + probe.get_hit_padding() + 0.5
	var outside: Enemy = _spawn_idle_enemy(Vector3(outside_x, 0.0, -1.5))
	_spin_by_hand()
	await _start_dash()
	await _wait_dash_end()
	assert_float(crossed.health.current_health).is_equal_approx(ENEMY_HEALTH - minf(_slash_damage(), ENEMY_HEALTH), 0.01)
	assert_float(outside.health.current_health).is_equal(ENEMY_HEALTH)
	assert_float(probe.health.current_health).is_equal(ENEMY_HEALTH)
	assert_int(_crits.size()).is_equal(1)


func test_ac570_slashed_enemies_are_pushed_sideways() -> void:
	var right: Enemy = _spawn_idle_enemy(Vector3(IN_PATH_X, 0.0, -1.5))
	var left: Enemy = _spawn_idle_enemy(Vector3(-IN_PATH_X, 0.0, -1.5))
	var pushes: Dictionary[Enemy, Vector3] = {}
	_spin_by_hand()
	await _start_dash()
	while _player.dash.is_dashing():
		for enemy: Enemy in [right, left]:
			if not pushes.has(enemy) and enemy.is_knocked_back():
				pushes[enemy] = enemy.get_knockback_velocity()
		await get_tree().physics_frame
	assert_int(pushes.size()).is_equal(2)
	# At most one physics step of friction may have passed since the push.
	var decay: float = right.get_scaled_stats().knockback_friction / Engine.physics_ticks_per_second
	var speed: float = SPIN_CONFIG.dash_slash_knockback_speed
	assert_float(pushes[right].x).is_greater(0.0)
	assert_float(pushes[left].x).is_less(0.0)
	assert_float(pushes[right].length()).is_between(speed - decay - 0.01, speed + 0.01)
	assert_float(absf(pushes[right].z)).is_less(0.01)


func test_ac571_the_golden_upgrades_apply_to_the_slash() -> void:
	_player.apply_upgrade(ARMOR_BREAK)
	_player.apply_upgrade(INVIGORATING)
	_player.apply_upgrade(TORNADO)
	var survivor: Enemy = _spawn_idle_enemy(Vector3(IN_PATH_X, 0.0, -1.0), ENEMY_HEALTH)
	_spawn_idle_enemy(Vector3(-IN_PATH_X, 0.0, -2.0), 1.0)
	_spin_by_hand()
	var cooldown_before: float = _cooldown_left()
	await _start_dash()
	await _wait_dash_end()
	assert_bool(survivor.health.is_dead()).is_false()
	assert_int(survivor.debuffs.get_stacks(WEAKEN.id)).is_equal(1)
	assert_int(_player.buffs.get_stacks(CONCUSSION.id)).is_equal(1)
	assert_float(_cooldown_left()).is_equal_approx(cooldown_before - TORNADO.get_value(1), TOLERANCE)


func test_ac572_the_slash_can_crit_with_concussion() -> void:
	var sure_crit := BuffData.new()
	sure_crit.id = CONCUSSION.id
	sure_crit.max_stacks = 1
	sure_crit.stack_duration = 10.0
	var modifier := BuffModifier.new()
	modifier.stat = BuffModifier.Stat.CRIT_CHANCE
	modifier.per_stack = 1.0
	sure_crit.modifiers.append(modifier)
	_player.apply_upgrade(INVIGORATING)
	_player.buffs.add_stack(sure_crit)
	var enemy: Enemy = _spawn_idle_enemy(Vector3(IN_PATH_X, 0.0, -1.5))
	_spin_by_hand()
	await _start_dash()
	await _wait_dash_end()
	assert_int(_crits.size()).is_equal(1)
	assert_bool(_crits[0]).is_true()
	var crit_bonus: float = _player.stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE)
	var expected: float = minf(_slash_damage() * (1.0 + crit_bonus), ENEMY_HEALTH)
	assert_float(enemy.health.current_health).is_equal_approx(ENEMY_HEALTH - expected, 0.01)


func test_ac572_without_stacks_the_slash_does_not_crit() -> void:
	_player.apply_upgrade(INVIGORATING)
	_spawn_idle_enemy(Vector3(IN_PATH_X, 0.0, -1.5))
	_spawn_idle_enemy(Vector3(-IN_PATH_X, 0.0, -2.0))
	_spin_by_hand()
	await _start_dash()
	await _wait_dash_end()
	assert_int(_crits.size()).is_equal(2)
	assert_bool(_crits.has(true)).is_false()


func test_ac573_faces_the_dash_sweeps_and_trails() -> void:
	var trail: WeaponTrail = _player.get_node("WeaponTrail") as WeaponTrail
	_spin_by_hand()
	Input.action_press(&"move_right")
	await _start_dash()
	var dash_direction: Vector3 = _player.dash.get_direction()
	assert_float(_player.get_facing().dot(dash_direction)).is_equal_approx(1.0, 0.001)
	assert_bool(_player.sword_swing.is_swinging()).is_true()
	assert_float(_player.sword_swing.get_swing_duration()).is_equal_approx(SPIN_CONFIG.dash_slash_sweep_duration, TOLERANCE)
	assert_bool(trail.is_emitting()).is_true()


## No blade of light behind the player (user request): only the weapon sweep,
## its trail, the sparks along the path and the flash at the tip.
func test_ac574_sparks_and_flash_at_the_end_of_the_dash() -> void:
	var vfx: DashSlashVfx = _spin.get_dash_slash()
	var nodes: int = vfx.get_child_count()
	assert_bool(vfx.is_playing()).is_false()
	_spin_by_hand()
	var start: Vector3 = _player.global_position
	await _start_dash()
	assert_bool(vfx.is_playing()).is_true()
	assert_bool(vfx.get_flash().visible).is_false()
	for child: Node in vfx.get_children():
		if child is MeshInstance3D:
			assert_object(child).is_same(vfx.get_flash())
	await _wait_dash_end()
	assert_float(vfx.get_path_length()).is_equal_approx(_flat_distance(start), 0.1)
	assert_bool(vfx.get_sparks().emitting).is_true()
	assert_bool(vfx.get_flash().visible).is_true()
	assert_object(vfx.get_flash().mesh.surface_get_material(0)).is_same(GLOW_MATERIAL)
	assert_float(vfx.get_flash().global_position.y - start.y).is_equal_approx(VFX_CONFIG.blade_height, 0.05)
	await _physics_frames(ceili(VFX_CONFIG.flash_duration * Engine.physics_ticks_per_second) + 5)
	assert_bool(vfx.is_playing()).is_false()
	assert_bool(vfx.get_flash().visible).is_false()
	# Second slash: same nodes, reused.
	_ability.reset_cooldown()
	_player.dash.reset_cooldown()
	assert_bool(_ability.try_cast()).is_true()
	await _start_dash()
	assert_bool(vfx.is_playing()).is_true()
	assert_int(vfx.get_child_count()).is_equal(nodes)

func test_ac575_a_dash_without_spin_does_not_slash() -> void:
	var enemy: Enemy = _spawn_idle_enemy(Vector3(IN_PATH_X, 0.0, -1.5))
	await _start_dash()
	await _wait_dash_end()
	assert_bool(_spin.is_dash_slashing()).is_false()
	assert_bool(_spin.get_dash_slash().is_playing()).is_false()
	assert_float(enemy.health.current_health).is_equal(ENEMY_HEALTH)


func test_ac575_a_boss_grab_ends_the_spin_without_a_slash() -> void:
	_spin_by_hand()
	_player.begin_hold(0.5)
	assert_bool(_ability.is_casting()).is_false()
	assert_bool(_spin.is_dash_slashing()).is_false()
	assert_bool(_spin.get_dash_slash().is_playing()).is_false()
