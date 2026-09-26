extends GdUnitTestSuite
## docs/specs/cooldown-timers.md: remaining seconds of the dash, the buffs and
## the boss debuffs in the arena HUD.

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const HUD_CONFIG: HudConfig = preload("res://data/ui/hud_config.tres")
const BOSS_BAR_CONFIG: BossBarConfig = preload("res://data/ui/boss_bar_config.tres")
## boss-titan: the Titán is the single boss of reference (the Coloso is gone).
const TITAN: BossChallengeData = preload("res://data/enemies/boss_challenges/titan.tres")
const CONCUSSION: BuffData = preload("res://data/buffs/concussion.tres")
const WEAKEN: DebuffData = preload("res://data/debuffs/weaken.tres")
const THRUST: AbilityData = preload("res://data/abilities/thrust/thrust.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const LETHAL_HIT: float = 100000.0
const TOLERANCE: float = 0.0001

var _arena: Node3D
var _player: Player
var _hud: Hud


## The ability picker stays open (tree paused), so nothing advances on its own.
func before_test() -> void:
	_arena = auto_free(ARENA_SCENE.instantiate())
	add_child(_arena)
	_player = _arena.get_node("Player") as Player
	_hud = _arena.get_node("UI/Hud") as Hud
	get_tree().paused = true
	await get_tree().process_frame


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_ac321_dash_label_shows_the_remaining_cooldown() -> void:
	var label: Label = _hud.get_node("%DashLabel") as Label
	_hud._process(0.0)
	assert_str(label.text).is_equal(HUD_CONFIG.dash_ready_text)
	assert_str(HUD_CONFIG.dash_ready_text).is_equal("DASH")
	assert_bool(_player.dash.try_dash(Vector3.FORWARD)).is_true()
	_hud._process(0.0)
	assert_str(label.text).is_equal("1.5")
	_player.dash.advance_timers(0.7)
	_hud._process(0.0)
	assert_str(label.text).is_equal("0.8")
	_player.dash.advance_timers(1.0)
	_hud._process(0.0)
	assert_str(label.text).is_equal("DASH")


func test_ac322_buff_shows_time_in_the_centre_and_stacks_in_the_corner() -> void:
	var bar: BuffBar = _hud.get_node("%BuffBar") as BuffBar
	assert_bool(bar.is_processing()).is_false()
	_player.buffs.add_stack(CONCUSSION)
	_player.buffs.add_stack(CONCUSSION)
	assert_bool(bar.is_processing()).is_true()
	assert_str(bar.get_time_text(0)).is_equal("2.5")
	assert_str(bar.get_stack_text(0)).is_equal("2")
	_player.buffs.advance(1.0)
	bar.update_times()
	assert_str(bar.get_time_text(0)).is_equal("1.5")
	_player.buffs.advance(1.5)
	assert_str(bar.get_time_text(0)).is_equal("2.5")
	assert_str(bar.get_stack_text(0)).is_equal("1")
	_player.buffs.advance(CONCUSSION.stack_duration)
	assert_int(bar.get_visible_icon_count()).is_equal(0)
	assert_bool(bar.is_processing()).is_false()


## Picks an ability (starts the run), clears wave 1 and forces the Titán at wave 4 (AC499).
func _start_titan() -> void:
	var ability_picker: AbilityPicker = _arena.get_node("UI/AbilityPicker") as AbilityPicker
	ability_picker.choose(THRUST)
	var registry: EnemyRegistry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	var run_state: RunState = _arena.get_node("RunState") as RunState
	var wave_manager: WaveManager = _arena.get_node("WaveManager") as WaveManager
	var active: Array[Enemy] = []
	active.assign(registry.get_active())
	for enemy: Enemy in active:
		enemy.health.receive_hit(LETHAL_HIT)
	for i: int in 3:
		run_state.next_wave()
	wave_manager.start_boss_wave(TITAN)


func test_ac325_boss_bar_shows_debuff_seconds_on_the_icon() -> void:
	_start_titan()
	var registry: EnemyRegistry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	var boss: Enemy = registry.get_active()[0]
	var bar: BossHealthBar = (_hud.get_node("%BossBars") as BossBarStack).get_bar(0)
	boss.debuffs.apply(WEAKEN, 0.05)
	assert_int(bar.get_visible_debuff_count()).is_equal(1)
	assert_str(bar.get_debuff_time_text(0)).is_equal("4.0")
	boss.debuffs.advance(1.5)
	bar.advance(0.0)
	assert_str(bar.get_debuff_time_text(0)).is_equal("2.5")
	assert_float(BOSS_BAR_CONFIG.debuff_icon_size_px).is_equal(24.0)


func test_ac349_buff_clock_covers_the_current_stack_time() -> void:
	var bar: BuffBar = _hud.get_node("%BuffBar") as BuffBar
	_player.buffs.add_stack(CONCUSSION)
	_player.buffs.add_stack(CONCUSSION)
	var clock: CooldownClock = bar.get_clock(0)
	assert_int(clock.shape).is_equal(CooldownClock.Shape.SQUARE)
	assert_object(bar.get_icon(0).get_child(0)).is_same(clock)
	assert_float(clock.get_fraction()).is_equal_approx(1.0, TOLERANCE)
	_player.buffs.advance(1.0)
	bar.update_times()
	assert_float(clock.get_fraction()).is_equal_approx(0.6, TOLERANCE)
	_player.buffs.advance(1.5)
	assert_float(clock.get_fraction()).is_equal_approx(1.0, TOLERANCE)


func test_ac350_boss_debuff_clock_and_no_clock_on_3d_icons() -> void:
	_start_titan()
	var registry: EnemyRegistry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	var boss: Enemy = registry.get_active()[0]
	var bar: BossHealthBar = (_hud.get_node("%BossBars") as BossBarStack).get_bar(0)
	boss.debuffs.apply(WEAKEN, 0.05)
	boss.debuffs.apply(BLEED, 0.001)
	assert_float(bar.get_debuff_clock(0).get_fraction()).is_equal_approx(1.0, TOLERANCE)
	assert_float(bar.get_debuff_clock(1).get_fraction()).is_equal_approx(1.0, TOLERANCE)
	boss.debuffs.advance(1.5)
	bar.advance(0.0)
	assert_float(bar.get_debuff_clock(0).get_fraction()).is_equal_approx(0.625, TOLERANCE)
	var icons: DebuffIconRow = boss.get_node("HealthBar/DebuffIcons") as DebuffIconRow
	for i: int in icons.get_child_count():
		var icon: Node = icons.get_child(i)
		for child: Node in icon.get_children():
			assert_bool(child is CooldownClock).is_false()


func test_ac384_boss_debuff_icon_shows_stacks() -> void:
	_start_titan()
	var registry: EnemyRegistry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	var boss: Enemy = registry.get_active()[0]
	var bar: BossHealthBar = (_hud.get_node("%BossBars") as BossBarStack).get_bar(0)
	boss.debuffs.apply(WEAKEN, 0.05)
	boss.debuffs.apply(WEAKEN, 0.05)
	boss.debuffs.apply(BLEED, 0.001)
	assert_str(bar.get_debuff_stack_text(0)).is_equal("2")
	assert_str(bar.get_debuff_stack_text(1)).is_equal("")
