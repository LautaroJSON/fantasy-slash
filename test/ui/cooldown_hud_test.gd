extends GdUnitTestSuite
## docs/specs/cooldown-timers.md: remaining seconds of the buffs and the boss
## debuffs in the arena HUD. The dash (AC321) moved to test/ui/dash_button_test.gd
## (AC771, docs/specs/dash-button.md).

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
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


## status-icons.md (AC906) replaced the seconds in the centre with the clock
## alone: what this checks (stacks, stack loss, hiding and processing) is kept.
func test_ac322_ac906_buff_shows_stacks_and_clock_without_time() -> void:
	var bar: BuffBar = _hud.get_node("%BuffBar") as BuffBar
	assert_bool(bar.is_processing()).is_false()
	_player.buffs.add_stack(CONCUSSION)
	_player.buffs.add_stack(CONCUSSION)
	assert_bool(bar.is_processing()).is_true()
	var icon: StatusIconView = bar.get_icon(0)
	assert_float(icon.get_side()).is_equal(36.0)
	assert_object(icon.get_glyph_texture()).is_same(CONCUSSION.icon)
	assert_str(bar.get_stack_text(0)).is_equal("2")
	assert_float(icon.get_clock_fraction()).is_equal_approx(1.0, TOLERANCE)
	var labels: int = 0
	for child: Node in icon.get_children():
		if child is Label:
			labels += 1
	assert_int(labels).is_equal(1)
	_player.buffs.advance(1.0)
	bar.update_times()
	assert_float(icon.get_clock_fraction()).is_equal_approx(0.6, TOLERANCE)
	_player.buffs.advance(1.5)
	assert_float(icon.get_clock_fraction()).is_equal_approx(1.0, TOLERANCE)
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


## status-icons.md (AC907): the seconds on the icon are gone; the clock tells
## the time left and the icons measure 28 px. What this checks is kept.
func test_ac325_boss_bar_shows_debuff_time_on_the_icon() -> void:
	_start_titan()
	var registry: EnemyRegistry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	var boss: Enemy = registry.get_active()[0]
	var bar: BossHealthBar = (_hud.get_node("%BossBars") as BossBarStack).get_bar(0)
	boss.debuffs.apply(WEAKEN, 0.05)
	assert_int(bar.get_visible_debuff_count()).is_equal(1)
	assert_float(bar.get_debuff_icon(0).get_clock_fraction()).is_equal_approx(1.0, TOLERANCE)
	boss.debuffs.advance(1.5)
	bar.advance(0.0)
	assert_float(bar.get_debuff_icon(0).get_clock_fraction()).is_equal_approx(0.625, TOLERANCE)
	assert_float(BOSS_BAR_CONFIG.debuff_icon_size_px).is_equal(28.0)
	assert_float(bar.get_debuff_icon(0).get_side()).is_equal(28.0)


func test_ac349_buff_clock_covers_the_current_stack_time() -> void:
	var bar: BuffBar = _hud.get_node("%BuffBar") as BuffBar
	_player.buffs.add_stack(CONCUSSION)
	_player.buffs.add_stack(CONCUSSION)
	var clock: CooldownClock = bar.get_clock(0)
	assert_int(clock.shape).is_equal(CooldownClock.Shape.SQUARE)
	# status-icons.md: the clock is the third child of the shared icon (over the glyph).
	assert_object(bar.get_icon(0).get_child(2)).is_same(clock)
	assert_float(clock.get_fraction()).is_equal_approx(1.0, TOLERANCE)
	_player.buffs.advance(1.0)
	bar.update_times()
	assert_float(clock.get_fraction()).is_equal_approx(0.6, TOLERANCE)
	_player.buffs.advance(1.5)
	assert_float(clock.get_fraction()).is_equal_approx(1.0, TOLERANCE)


## status-icons.md: the 3D enemy icons are gone (the enemy overlay, AC909,
## replaces them), so only the boss clock part of AC350 remains.
func test_ac350_boss_debuff_clock() -> void:
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
