extends GdUnitTestSuite

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
## boss-titan: the Titán is the single boss of reference (the Coloso is gone; AC498).
const TITAN: BossChallengeData = preload("res://data/enemies/boss_challenges/titan.tres")
const COLMENA: BossChallengeData = preload("res://data/enemies/boss_challenges/colmena.tres")
const SHIELD: DebuffData = preload("res://data/debuffs/shield.tres")
const BAR_CONFIG: HealthBarConfig = preload("res://data/ui/enemy_health_bar_config.tres")
const BOSS_BAR_CONFIG: BossBarConfig = preload("res://data/ui/boss_bar_config.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const LETHAL_HIT: float = 100000.0
## A quarter of an oscillation: the shake offset is at its peak there.
const PEAK_DELTA_FACTOR: float = 0.25

var _arena: Node3D
var _registry: EnemyRegistry
var _run_state: RunState
var _picker: UpgradePicker
var _wave_manager: WaveManager
var _stack: BossBarStack


func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_wave_manager = _arena.get_node("WaveManager") as WaveManager
	_stack = _arena.get_node("UI/Hud").get_node("%BossBars") as BossBarStack
	get_tree().paused = true
	await get_tree().process_frame
	var ability_picker: AbilityPicker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	ability_picker.choose(SHIELD_CHARGE)


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		# boss-colmena: a shielded boss (the Colmena) must die too.
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


## Clears wave 1, jumps to wave 4 (level 2) and forces `challenge`.
func _start_boss(challenge: BossChallengeData) -> void:
	_kill_all_active()
	for i: int in 3:
		_run_state.next_wave()
	_wave_manager.start_boss_wave(challenge)


func _boss(index: int) -> Enemy:
	return _registry.get_active()[index]


func test_ac158_boss_floating_bar_never_shows() -> void:
	_start_boss(TITAN)
	var boss: Enemy = _boss(0)
	boss.health.receive_hit(50.0)
	boss.notify_hit(46.0, true)
	assert_bool(boss.health_bar.is_suppressed()).is_true()
	assert_bool(boss.health_bar.visible).is_false()
	assert_bool(boss.health_bar.is_shaking()).is_false()


func test_ac159_titan_gets_one_bar_with_title_and_health() -> void:
	_start_boss(TITAN)
	assert_int(_stack.visible_bar_count()).is_equal(1)
	var bar: BossHealthBar = _stack.get_bar(0)
	assert_object(bar.get_tracked()).is_same(_boss(0))
	assert_str(bar.get_title_text()).is_equal("Titán  lv. 2")
	assert_str(bar.get_health_text()).is_equal("1008 / 1008")


## boss-colmena (AC544): no challenge has two bosses any more, so two enemies
## of the wave stand in for them; the stack still holds several bars.
## Inside a boss wave (a normal wave clears the boss bars on every kill): the
## Titán plus a grunt from the regular pool, free during a boss wave.
func _show_two_bosses() -> Array[Enemy]:
	_start_boss(TITAN)
	var extra: Enemy = (_arena.get_node("EnemyPool") as EnemyPool).acquire()
	extra.activate(Vector3(0.0, 0.0, -9.0), _arena.get_node("Player") as Player)
	var pair: Array[Enemy] = [extra, _boss(0)]
	_stack.show_bosses(pair)
	return pair


func test_ac159_ac544_two_bosses_get_two_stacked_bars() -> void:
	var pair: Array[Enemy] = _show_two_bosses()
	assert_int(_stack.visible_bar_count()).is_equal(2)
	assert_object(_stack.get_bar(1).get_tracked()).is_same(pair[1])


func test_ac160_fill_drops_and_trail_drains_after_the_hold() -> void:
	_start_boss(TITAN)
	var bar: BossHealthBar = _stack.get_bar(0)
	# Level 2 Titán (boss-health-tuning, AC555): 1007.4 HP, 2.25 defense, 70 % armour
	# → 338.05 raw removes 100.74 (10 %).
	_boss(0).health.receive_hit(338.05)
	assert_float(bar.get_fill_ratio()).is_equal_approx(0.9, 0.0001)
	assert_float(bar.get_trail_ratio()).is_equal_approx(1.0, 0.0001)
	assert_str(bar.get_health_text()).is_equal("907 / 1008")
	bar.advance(BAR_CONFIG.trail_hold_time - 0.05)
	assert_float(bar.get_trail_ratio()).is_equal_approx(1.0, 0.0001)
	for i: int in 60:
		bar.advance(1.0 / 60.0)
	assert_float(bar.get_trail_ratio()).is_equal_approx(0.9, 0.0001)


func test_ac161_crit_shakes_the_hud_bar_then_it_settles() -> void:
	_start_boss(TITAN)
	var bar: BossHealthBar = _stack.get_bar(0)
	_boss(0).notify_hit(1.0, true)
	assert_bool(bar.is_shaking()).is_true()
	bar.advance(PEAK_DELTA_FACTOR / BAR_CONFIG.shake_frequency)
	assert_float(absf(bar.get_bar_offset())).is_greater(0.5)
	bar.advance(BAR_CONFIG.shake_duration)
	assert_bool(bar.is_shaking()).is_false()
	assert_float(bar.get_bar_offset()).is_equal_approx(0.0, 0.0001)


func test_ac161_small_normal_hit_does_not_shake() -> void:
	_start_boss(TITAN)
	_boss(0).notify_hit(10.0, false)
	assert_bool(_stack.get_bar(0).is_shaking()).is_false()


func test_ac162_bleed_shows_an_icon_with_its_color() -> void:
	_start_boss(TITAN)
	var bar: BossHealthBar = _stack.get_bar(0)
	assert_int(bar.get_visible_debuff_count()).is_equal(0)
	_boss(0).debuffs.apply(BLEED, 0.01)
	assert_int(bar.get_visible_debuff_count()).is_equal(1)
	# status-icons.md (AC907): the flat color became the shared 28 px icon with its glyph.
	var icon: StatusIconView = bar.get_debuff_icon(0)
	assert_object(icon.get_glyph_texture()).is_same(BLEED.icon)
	assert_that(icon.get_glyph_color()).is_equal(BLEED.icon_color.lightened(icon.config.glyph_lighten))
	assert_float(icon.get_side()).is_equal(28.0)
	assert_str(icon.get_stack_text()).is_empty()
	_boss(0).debuffs.clear()
	assert_int(bar.get_visible_debuff_count()).is_equal(0)


func test_ac163_ac544_a_dead_boss_loses_its_bar_and_the_other_stays() -> void:
	var pair: Array[Enemy] = _show_two_bosses()
	var first: Enemy = pair[0]
	var second: Enemy = pair[1]
	first.health.receive_hit(LETHAL_HIT)
	assert_int(_stack.visible_bar_count()).is_equal(1)
	assert_object(_stack.get_bar(1).get_tracked()).is_same(second)
	second.health.receive_hit(LETHAL_HIT)
	assert_int(_stack.visible_bar_count()).is_equal(0)


func test_ac163_next_normal_wave_has_no_boss_bars() -> void:
	_start_boss(TITAN)
	_kill_all_active()
	_picker.choose(DAMAGE_UPGRADE)
	assert_bool(_run_state.is_boss_wave()).is_false()
	assert_int(_stack.visible_bar_count()).is_equal(0)


func test_ac164_normal_wave_shows_no_boss_bar() -> void:
	assert_int(_run_state.wave).is_equal(1)
	assert_int(_stack.visible_bar_count()).is_equal(0)
	assert_int(_stack.get_child_count()).is_equal(BOSS_BAR_CONFIG.max_bars)


func test_ac541_the_colmena_bar_shows_the_shield_icon() -> void:
	_start_boss(COLMENA)
	var bar: BossHealthBar = _stack.get_bar(0)
	assert_bool(_boss(0).debuffs.has_debuff(SHIELD.id)).is_true()
	assert_int(bar.get_visible_debuff_count()).is_equal(1)
	assert_object(bar.get_debuff_icon(0).get_glyph_texture()).is_same(SHIELD.icon)
