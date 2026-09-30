extends GdUnitTestSuite
## A run across stages: waves per stage, the portal and the transition
## (docs/specs/stages.md, AC1289–AC1305, AC1307, AC1319).

const ARENA_SCENE: PackedScene = preload("res://levels/arena/arena.tscn")
const ARENA_STAGE: StageData = preload("res://data/stages/arena/arena_stage.tres")
const TWO_ARENAS: StageSequence = preload("res://test/data/two_arena_sequence.tres")
const WAVE_CONFIG: WaveConfig = preload("res://data/waves/wave_config.tres")
const TRANSITION: StageTransitionConfig = preload("res://data/stages/stage_transition_config.tres")
const GRUNT_SPAWN: EnemySpawnEntry = preload("res://data/enemies/spawn/grunt_spawn.tres")
const TITAN: BossChallengeData = preload("res://data/enemies/boss_challenges/titan.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const DAMAGE_UPGRADE: UpgradeData = preload("res://data/upgrades/damage.tres")
const LETHAL_HIT: float = 100000.0
const STEP: float = 0.05

var _arena: Node3D
var _director: StageDirector
var _waves: WaveManager
var _registry: EnemyRegistry
var _player: Player
var _run_state: RunState
var _picker: UpgradePicker
var _portal: Portal
var _transition: StageTransition
var _stage_changes: int = 0
var _cleared: int = 0


## Builds the arena with `sequence` and chooses the ability (wave 1 running).
func _start(sequence: StageSequence) -> void:
	_stage_changes = 0
	_cleared = 0
	_arena = auto_free(ARENA_SCENE.instantiate())
	_director = _arena.get_node("StageDirector") as StageDirector
	_director.sequence = sequence
	add_child(_arena)
	preload("res://test/helpers/test_world.gd").without_horde(_arena)
	_waves = _arena.get_node("WaveManager") as WaveManager
	_registry = _arena.get_node("EnemyRegistry") as EnemyRegistry
	_player = _arena.get_node("Player") as Player
	_run_state = _arena.get_node("RunState") as RunState
	_picker = _arena.get_node("UI/UpgradePicker") as UpgradePicker
	_portal = _arena.get_node("Portal") as Portal
	_transition = _arena.get_node("UI/StageTransition") as StageTransition
	_director.stage_started.connect(func(_data: StageData, _index: int) -> void: _stage_changes += 1)
	_waves.stage_cleared.connect(func() -> void: _cleared += 1)
	get_tree().paused = true
	await get_tree().process_frame
	(_arena.get_node("UI/AbilityPicker") as AbilityPicker).choose(SHIELD_CHARGE)


func after_test() -> void:
	get_tree().paused = false
	Session.mode = GameSession.Mode.NORMAL
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _kill_all_active() -> void:
	var active: Array[Enemy] = []
	active.assign(_registry.get_active())
	for enemy: Enemy in active:
		enemy.health.is_invulnerable = false
		enemy.health.receive_hit(LETHAL_HIT)


func _choose_all() -> void:
	while _picker.is_open():
		_picker.choose(DAMAGE_UPGRADE)


## Jumps to the last regular wave of the stage and clears it: the boss wave runs.
func _reach_boss_wave() -> void:
	while _run_state.stage_wave < ARENA_STAGE.regular_waves:
		_run_state.next_wave()
	_kill_all_active()
	_choose_all()
	assert_bool(_run_state.is_boss_wave()).is_true()


## Clears the boss and picks its card: the stage is cleared.
func _clear_stage() -> void:
	_reach_boss_wave()
	_kill_all_active()
	_choose_all()


func _open_portal() -> void:
	_director.advance(ARENA_STAGE.portal.open_delay + STEP)
	_portal.advance(ARENA_STAGE.portal.open_duration + STEP)


func _enter_portal() -> void:
	_player.global_position = _portal.global_position
	_portal.advance(STEP)


func _step_transition(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_transition.advance(STEP)
		left -= STEP


func _single_type_sequence() -> StageSequence:
	var solo: StageData = ARENA_STAGE.duplicate() as StageData
	var types: Array[EnemySpawnEntry] = [GRUNT_SPAWN]
	solo.enemy_types = types
	var sequence := StageSequence.new()
	var stages: Array[StageData] = [solo]
	sequence.stages = stages
	return sequence


# --- run and waves ---------------------------------------------------------

func test_ac1289_the_first_stage_is_loaded_with_the_player_on_its_start() -> void:
	await _start(TWO_ARENAS)
	var root: Node3D = _arena.get_node("StageRoot") as Node3D
	assert_int(root.get_child_count()).is_equal(1)
	assert_object(root.get_child(0)).is_same(_director.get_stage())
	assert_object(_director.get_stage().get_data()).is_same(TWO_ARENAS.get_stage(0))
	assert_int(_director.get_stage_index()).is_equal(0)
	assert_vector(_player.global_position).is_equal_approx(_director.get_stage().get_player_start().origin, Vector3.ONE * 0.2)


func test_ac1290_the_boss_is_the_eleventh_wave_and_one_of_the_stage() -> void:
	await _start(TWO_ARENAS)
	for i: int in ARENA_STAGE.regular_waves - 1:
		_kill_all_active()
		_choose_all()
		assert_bool(_run_state.is_boss_wave()).is_false()
	assert_int(_run_state.stage_wave).is_equal(ARENA_STAGE.regular_waves)
	_kill_all_active()
	_choose_all()
	assert_int(_run_state.stage_wave).is_equal(ARENA_STAGE.regular_waves + 1)
	assert_bool(_run_state.is_boss_wave()).is_true()
	var boss: Enemy = _registry.get_active()[0]
	var from_stage: bool = false
	for challenge: BossChallengeData in ARENA_STAGE.boss_challenges:
		from_stage = from_stage or challenge.stats == boss.stats
	assert_bool(from_stage).is_true()


func test_ac1291_regular_waves_only_use_the_stage_types() -> void:
	await _start(_single_type_sequence())
	for i: int in 7:
		for enemy: Enemy in _registry.get_active():
			assert_object(enemy.stats).is_same(GRUNT_SPAWN.stats)
		_kill_all_active()
		_choose_all()


func test_ac1292_the_wave_number_keeps_counting_in_the_next_stage() -> void:
	await _start(TWO_ARENAS)
	_clear_stage()
	_open_portal()
	_enter_portal()
	_step_transition(_transition.get_cover_duration() + STEP)
	assert_int(_run_state.wave).is_equal(ARENA_STAGE.regular_waves + 2)
	assert_int(_run_state.stage_wave).is_equal(1)
	var level: int = WAVE_CONFIG.enemy_level_for(_run_state.wave)
	for enemy: Enemy in _registry.get_active():
		assert_int(enemy.level).is_equal(level)


func test_ac1293_clearing_the_boss_of_a_stage_that_is_not_the_last_waits_for_the_portal() -> void:
	await _start(TWO_ARENAS)
	_clear_stage()
	assert_int(_cleared).is_equal(1)
	assert_int(_registry.alive_count()).is_equal(0)
	assert_int(_run_state.stage_wave).is_equal(ARENA_STAGE.regular_waves + 1)


func test_ac1294_the_last_stage_keeps_going_after_its_boss() -> void:
	await _start(preload("res://test/data/arena_only_sequence.tres"))
	_clear_stage()
	assert_int(_cleared).is_equal(0)
	assert_int(_run_state.wave).is_equal(ARENA_STAGE.regular_waves + 2)
	assert_int(_run_state.stage_wave).is_equal(1)
	assert_bool(_run_state.is_boss_wave()).is_false()
	assert_int(_registry.alive_count()).is_greater(0)
	assert_bool(_run_state.is_stage_boss_wave(ARENA_STAGE.regular_waves)).is_false()


## Without cards left (Rage) the boss also leads to the portal. The sandbox no
## longer runs waves (docs/specs/sandbox-arena-control.md), so it has no portal.
func test_ac1295_without_cards_the_boss_also_leads_to_the_portal() -> void:
	await _start(TWO_ARENAS)
	_waves.get_card_pool().clear()
	while _run_state.stage_wave < ARENA_STAGE.regular_waves:
		_run_state.next_wave()
	_kill_all_active()
	await get_tree().process_frame
	assert_bool(_run_state.is_boss_wave()).is_true()
	_kill_all_active()
	await get_tree().process_frame
	assert_int(_cleared).is_equal(1)
	assert_int(_registry.alive_count()).is_equal(0)


# --- portal and transition ---------------------------------------------------

func test_ac1296_the_portal_opens_at_the_portal_point_after_the_delay() -> void:
	await _start(TWO_ARENAS)
	_clear_stage()
	_director.advance(ARENA_STAGE.portal.open_delay - STEP)
	assert_bool(_portal.visible).is_false()
	_director.advance(STEP * 2.0)
	assert_bool(_portal.visible).is_true()
	assert_vector(_portal.global_position).is_equal_approx(_director.get_stage().get_portal_transform().origin, Vector3.ONE * 0.001)
	assert_object(_portal.get_style()).is_instanceof(RuneRingPortal)


func test_ac1297_a_closed_portal_cannot_be_entered() -> void:
	await _start(TWO_ARENAS)
	var entered: Array[int] = [0]
	_portal.entered.connect(func() -> void: entered[0] += 1)
	assert_bool(_portal.visible).is_false()
	_player.global_position = _director.get_stage().get_portal_transform().origin
	_portal.advance(STEP)
	assert_bool(_portal.is_enterable()).is_false()
	assert_int(entered[0]).is_equal(0)
	# Opening but not open yet: still closed.
	_clear_stage()
	_director.advance(ARENA_STAGE.portal.open_delay + STEP)
	_portal.advance(STEP)
	assert_bool(_portal.is_enterable()).is_false()
	assert_int(entered[0]).is_equal(0)


func test_ac1298_the_player_in_range_enters_once() -> void:
	await _start(TWO_ARENAS)
	var entered: Array[int] = [0]
	_portal.entered.connect(func() -> void: entered[0] += 1)
	_clear_stage()
	_open_portal()
	_player.global_position = _portal.global_position + Vector3(ARENA_STAGE.portal.enter_radius + 1.0, 0.0, 0.0)
	_portal.advance(STEP)
	assert_int(entered[0]).is_equal(0)
	_enter_portal()
	_portal.advance(STEP)
	_portal.advance(STEP)
	assert_int(entered[0]).is_equal(1)
	assert_bool(_transition.is_playing()).is_true()


func test_ac1299_behind_the_fade_the_next_stage_replaces_the_old_one() -> void:
	await _start(TWO_ARENAS)
	var old_stage: StageMap = _director.get_stage()
	_clear_stage()
	_open_portal()
	_enter_portal()
	_step_transition(TRANSITION.fade_out + STEP)
	var root: Node3D = _arena.get_node("StageRoot") as Node3D
	assert_int(root.get_child_count()).is_equal(1)
	assert_object(root.get_child(0)).is_not_same(old_stage)
	assert_int(_director.get_stage_index()).is_equal(1)
	assert_int(_run_state.get_stage_index()).is_equal(1)
	assert_vector(_player.global_position).is_equal_approx(_director.get_stage().get_player_start().origin, Vector3.ONE * 0.001)
	assert_vector(_player.velocity).is_equal(Vector3.ZERO)
	assert_bool(_portal.visible).is_false()


func test_ac1300_the_player_keeps_everything_across_the_portal() -> void:
	await _start(TWO_ARENAS)
	_clear_stage()
	var damage_stacks: int = _player.count_upgrade(DAMAGE_UPGRADE)
	var health: float = _player.health.current_health
	var banned: int = _run_state.ban_count()
	_open_portal()
	_enter_portal()
	_step_transition(_transition.get_cover_duration() + STEP)
	assert_int(_player.count_upgrade(DAMAGE_UPGRADE)).is_equal(damage_stacks)
	assert_float(_player.health.current_health).is_equal(health)
	assert_int(_run_state.ban_count()).is_equal(banned)
	assert_object(_player.basic_ability.get_data()).is_same(SHIELD_CHARGE)


func test_ac1301_the_next_wave_starts_once_the_fade_is_over() -> void:
	await _start(TWO_ARENAS)
	_clear_stage()
	_open_portal()
	_enter_portal()
	_step_transition(TRANSITION.fade_out + STEP)
	assert_int(_registry.alive_count()).is_equal(0)
	_step_transition(TRANSITION.hold + TRANSITION.fade_in + STEP)
	assert_bool(_transition.is_playing()).is_false()
	assert_int(_registry.alive_count()).is_equal(WAVE_CONFIG.enemies_for_wave(_run_state.wave))
	for enemy: Enemy in _registry.get_active():
		var known: bool = false
		for entry: EnemySpawnEntry in TWO_ARENAS.get_stage(1).enemy_types:
			known = known or entry.stats == enemy.stats
		assert_bool(known).is_true()


func test_ac1302_the_banner_names_the_stage() -> void:
	await _start(TWO_ARENAS)
	await get_tree().process_frame
	assert_bool(_transition.is_banner_visible()).is_true()
	assert_str(_transition.get_title_text()).is_equal(TRANSITION.banner_title_format % 1)
	assert_str(_transition.get_name_text()).is_equal(ARENA_STAGE.display_name)
	assert_str(_transition.get_subtitle_text()).is_equal(ARENA_STAGE.subtitle)
	_clear_stage()
	_open_portal()
	_enter_portal()
	_step_transition(TRANSITION.fade_out + TRANSITION.hold + STEP)
	assert_bool(_transition.is_banner_visible()).is_true()
	assert_str(_transition.get_title_text()).is_equal(TRANSITION.banner_title_format % 2)
	_step_transition(TRANSITION.fade_in + TRANSITION.banner_duration + STEP)
	assert_bool(_transition.is_banner_visible()).is_false()


func test_ac1303_the_player_is_held_during_the_transition() -> void:
	await _start(TWO_ARENAS)
	_clear_stage()
	_open_portal()
	_enter_portal()
	assert_bool(_player.is_held()).is_true()
	# The hold lasts the whole cover: fade out, hold and fade in.
	assert_float(_transition.get_cover_duration()).is_equal_approx(TRANSITION.fade_out + TRANSITION.hold + TRANSITION.fade_in, 0.0001)


func test_ac1304_another_style_scene_changes_the_portal_look() -> void:
	await _start(TWO_ARENAS)
	var plain := PortalStyle.new()
	var scene := PackedScene.new()
	scene.pack(plain)
	plain.free()
	var data: PortalData = ARENA_STAGE.portal.duplicate() as PortalData
	data.style_scene = scene
	_portal.open(data, Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, -4.0)))
	assert_object(_portal.get_style()).is_not_null()
	assert_bool(_portal.get_style() is RuneRingPortal).is_false()
	assert_vector(_portal.global_position).is_equal(Vector3(3.0, 0.0, -4.0))


# --- spawns in the arena -----------------------------------------------------

func test_ac1305_arena_spawn_points_match_the_old_square() -> void:
	await _start(TWO_ARENAS)
	var stage: StageMap = _director.get_stage()
	var rng_new := RandomNumberGenerator.new()
	var rng_old := RandomNumberGenerator.new()
	rng_new.seed = 1305
	rng_old.seed = 1305
	for i: int in 40:
		var expected := Vector3(rng_old.randf_range(-12.0, 12.0), 0.0, rng_old.randf_range(-12.0, 12.0))
		assert_vector(stage.random_spawn_point(rng_new)).is_equal_approx(expected, Vector3.ONE * 0.0001)


func test_ac1307_horde_and_summons_stay_inside_the_arena_square() -> void:
	await _start(TWO_ARENAS)
	var stage: StageMap = _director.get_stage()
	for point: Vector3 in [Vector3(14.0, 0.0, 2.0), Vector3(-13.0, 0.0, -15.0), Vector3(5.0, 0.0, 11.0)]:
		var inside: Vector3 = stage.clamp_inside(point)
		assert_vector(inside).is_equal_approx(Vector3(clampf(point.x, -12.0, 12.0), 0.0, clampf(point.z, -12.0, 12.0)), Vector3.ONE * 0.0001)


func test_ac1319_the_arena_stage_keeps_its_floor_walls_and_spawn_square() -> void:
	await _start(TWO_ARENAS)
	var stage: StageMap = _director.get_stage()
	var floor_shape: BoxShape3D = (stage.get_node("Floor/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	assert_vector(floor_shape.size).is_equal(Vector3(30.0, 1.0, 30.0))
	for wall: String in ["WallNorth", "WallSouth", "WallEast", "WallWest"]:
		assert_object(stage.get_node_or_null(wall)).override_failure_message(wall).is_not_null()
	assert_object(stage.get_node_or_null("WorldEnvironment")).is_not_null()
	assert_object(_arena.get_node_or_null("Floor")).is_null()
	var bounds: Rect2 = ARENA_STAGE.layout.bounds()
	assert_vector(bounds.position).is_equal(Vector2(-12.0, -12.0))
	assert_vector(bounds.end).is_equal(Vector2(12.0, 12.0))
	assert_float(stage.height_at(3.0, -4.0)).is_equal(0.0)
