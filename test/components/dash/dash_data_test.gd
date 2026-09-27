extends GdUnitTestSuite
## Class dash data and behavior hooks (docs/specs/dash-feel.md): AC778-AC781.

const TestWorld := preload("res://test/helpers/test_world.gd")
const RecordingDashBehavior := preload("res://test/helpers/recording_dash_behavior.gd")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const CATALOG: ClassCatalog = preload("res://data/classes/class_catalog.tres")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
const VFX_SET: DashVfxSet = preload("res://data/player/dash/dash_vfx_set.tres")

var _player: Player


func before_test() -> void:
	Input.action_release(&"dash")
	var floor_body: StaticBody3D = auto_free(TestWorld.make_floor(60.0))
	add_child(floor_body)
	var registry: EnemyRegistry = auto_free(EnemyRegistry.new())
	add_child(registry)
	Session.character_class = SAMURAI
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = registry
	add_child(_player)
	await _physics_frames(5)


func after_test() -> void:
	Session.character_class = null


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## A DashData whose behavior is a fresh RecordingDashBehavior.
func _recording_data() -> DashData:
	var node: DashBehavior = RecordingDashBehavior.new()
	var scene := PackedScene.new()
	scene.pack(node)
	node.free()
	var data := DashData.new()
	data.clip = &"dash"
	data.behavior = scene
	data.vfx_set = VFX_SET
	return data


func _recorder() -> RecordingDashBehavior:
	return _player.dash.get_behavior() as RecordingDashBehavior


func _run_dash() -> void:
	while _player.dash.is_dashing():
		await get_tree().physics_frame


func test_ac778_every_class_has_its_dash_data() -> void:
	for character_class: CharacterClassData in CATALOG.classes:
		var data: DashData = character_class.dash
		assert_object(data).override_failure_message(character_class.title).is_not_null()
		assert_str(String(data.clip)).is_equal("dash")
		assert_object(data.behavior).is_null()
		assert_object(data.vfx_set).is_same(VFX_SET)
	assert_object(_player.dash.get_data()).is_same(SAMURAI.dash)
	assert_object(_player.dash.get_behavior()).is_null()


func test_ac779_equip_instantiates_and_replaces_the_behavior() -> void:
	_player.dash.equip(_recording_data())
	var first: DashBehavior = _player.dash.get_behavior()
	assert_object(first).is_not_null()
	assert_object(first.get_parent()).is_same(_player.dash)
	_player.dash.equip(_recording_data())
	assert_object(_player.dash.get_behavior()).is_not_same(first)
	assert_bool(first.is_queued_for_deletion()).is_true()
	_player.dash.equip(SAMURAI.dash)
	assert_object(_player.dash.get_behavior()).is_null()


func test_ac780_hooks_run_in_order_and_can_refuse() -> void:
	_player.dash.equip(_recording_data())
	_recorder().allow = false
	assert_bool(_player.dash.try_dash(Vector3.FORWARD)).is_false()
	assert_float(_player.dash.get_cooldown_remaining()).is_equal(0.0)
	assert_bool(_player.health.is_invulnerable).is_false()
	_recorder().allow = true
	_recorder().calls.clear()
	assert_bool(_player.dash.try_dash(Vector3.FORWARD)).is_true()
	await _run_dash()
	assert_array(_recorder().calls).is_equal(["can_start", "started", "ended"])
	var steps: int = ceili(_player.dash.get_duration() * Engine.physics_ticks_per_second)
	assert_int(_recorder().step_count).is_between(steps - 1, steps + 1)
	assert_bool(_recorder().ended_cancelled).is_false()


func test_ac780_a_cut_dash_ends_cancelled() -> void:
	_player.dash.equip(_recording_data())
	_player.dash.try_dash(Vector3.FORWARD)
	await _physics_frames(2)
	_player.dash.cancel()
	assert_bool(_recorder().ended_cancelled).is_true()


func test_ac781_the_behavior_picks_the_clip() -> void:
	_player.dash.equip(_recording_data())
	assert_str(String(_player.dash.get_clip())).is_equal("dash")
	_recorder().clip_override = &"idle"
	assert_str(String(_player.dash.get_clip())).is_equal("idle")
	_player.dash.try_dash(Vector3.FORWARD)
	await _physics_frames(2)
	var humanoid: LowPolyHumanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	assert_str(String(humanoid.anim.current_animation)).is_equal("idle")
