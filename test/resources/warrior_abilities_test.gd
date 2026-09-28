extends GdUnitTestSuite
## docs/specs/warrior-abilities-rework.md: the Warrior's catalog, the removed
## abilities and the body clips of the new ones (AC801–AC803, AC847).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const WARRIOR: CharacterClassData = preload("res://data/classes/warrior/warrior.tres")
const SHIELD_CHARGE: AbilityData = preload("res://data/abilities/shield_charge/shield_charge.tres")
const PARRY: AbilityData = preload("res://data/abilities/parry/parry.tres")
const CHARGE_CONFIG: ShieldChargeConfig = preload("res://data/abilities/shield_charge/shield_charge_config.tres")
const PARRY_CONFIG: ParryConfig = preload("res://data/abilities/parry/parry_config.tres")
const RIPOSTE: AbilityUniqueUpgradeData = preload("res://data/abilities/parry/unique/riposte.tres")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const TOLERANCE: float = 0.0001
const HIT: float = 20.0
const SCAN_DIRS: Array[String] = ["res://components/", "res://entities/", "res://data/", "res://levels/", "res://resources/", "res://systems/", "res://ui/"]

var _player: Player
var _slot: AbilityComponent
var _anim: AnimationPlayer


func before_test() -> void:
	Session.character_class = WARRIOR
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = auto_free(EnemyRegistry.new())
	add_child(_player)
	_slot = _player.basic_ability
	_slot.set_physics_process(false)
	_anim = (_player.get_node("Visual/Humanoid") as LowPolyHumanoid).anim


func after_test() -> void:
	Session.character_class = null


func test_ac801_the_warrior_offers_the_shield_charge_and_the_parry() -> void:
	assert_array(WARRIOR.abilities.abilities).contains_exactly([SHIELD_CHARGE, PARRY])
	assert_int(SHIELD_CHARGE.slot).is_equal(AbilityData.Slot.BASIC)
	assert_int(PARRY.slot).is_equal(AbilityData.Slot.BASIC)


func test_ac802_the_thrust_and_swift_strike_are_gone() -> void:
	for path: String in ["res://data/abilities/thrust", "res://data/abilities/swift_strike"]:
		assert_bool(DirAccess.dir_exists_absolute(path)).override_failure_message(path).is_false()
	for path: String in ["res://components/abilities/thrust_ability.gd", "res://components/abilities/swift_strike_ability.gd"]:
		assert_bool(FileAccess.file_exists(path)).override_failure_message(path).is_false()
	var library: AnimationLibrary = (_player.get_node("SwingPlayer") as AnimationPlayer).get_animation_library(&"")
	for clip: StringName in [&"thrust", &"thrust_recover", &"swift_strike", &"swift_strike_recover"]:
		assert_bool(library.has_animation(clip)).override_failure_message(String(clip)).is_false()
	for dir: String in SCAN_DIRS:
		_assert_no_reference(dir)
	assert_bool(FileAccess.file_exists("res://data/debuffs/bleed.tres")).is_true()


func test_ac803_every_phase_plays_a_warrior_clip() -> void:
	_slot.equip(SHIELD_CHARGE)
	assert_bool(_slot.try_cast()).is_true()
	_assert_warrior_clip()
	_slot.advance(CHARGE_CONFIG.travel_time)
	_assert_warrior_clip()
	_slot.advance(1.0)
	_slot.reset_cooldown()
	_slot.equip(PARRY)
	_player.apply_upgrade(RIPOSTE)
	assert_bool(_slot.try_cast()).is_true()
	_assert_warrior_clip()
	_slot.advance(PARRY.cast_duration)
	_assert_warrior_clip()
	# equip() frees the previous behavior with queue_free: let it go (no orphans).
	await get_tree().process_frame


func test_ac847_the_clip_events_match_the_configs() -> void:
	assert_float(_event_time(&"shield_bash", "bash")).is_equal_approx(CHARGE_CONFIG.bash_hit_time, TOLERANCE)
	assert_float(_event_time(&"shield_parry", "raise")).is_equal_approx(PARRY_CONFIG.raise_time, TOLERANCE)
	assert_float(_event_time(&"shield_riposte", "riposte")).is_equal_approx(PARRY_CONFIG.riposte_hit_time, TOLERANCE)
	assert_float(_event_time(&"shield_riposte", "trail_on")).is_equal_approx(PARRY_CONFIG.riposte_trail_start, TOLERANCE)
	assert_float(_event_time(&"shield_riposte", "trail_off")).is_equal_approx(PARRY_CONFIG.riposte_trail_end, TOLERANCE)
	assert_float(_event_time(&"shield_riposte_empowered", "empowered")).is_equal_approx(PARRY_CONFIG.empowered_hit_time, TOLERANCE)
	assert_float(_event_time(&"shield_riposte_empowered", "trail_on")).is_equal_approx(PARRY_CONFIG.empowered_trail_start, TOLERANCE)
	assert_float(_event_time(&"shield_riposte_empowered", "trail_off")).is_equal_approx(PARRY_CONFIG.empowered_trail_end, TOLERANCE)
	for clip: StringName in [CHARGE_CONFIG.charge_body_clip, CHARGE_CONFIG.bash_body_clip, PARRY_CONFIG.parry_body_clip,
			PARRY_CONFIG.whiff_body_clip, PARRY_CONFIG.riposte_body_clip, PARRY_CONFIG.empowered_body_clip]:
		assert_bool(_anim.has_animation(clip)).override_failure_message(String(clip)).is_true()


func test_ac847_the_weapon_stays_in_the_hand_during_both_abilities() -> void:
	var mount: WeaponMount = _player.get_node("WeaponMount") as WeaponMount
	_slot.equip(SHIELD_CHARGE)
	assert_bool(_slot.try_cast()).is_true()
	assert_bool(_slot.holds_weapon_in_hand()).is_true()
	assert_bool(mount.is_hand_free()).is_true()
	_slot.advance(1.0)
	_slot.reset_cooldown()
	_slot.equip(PARRY)
	assert_bool(_slot.try_cast()).is_true()
	assert_bool(_slot.holds_weapon_in_hand()).is_true()
	assert_bool(mount.is_hand_free()).is_true()
	await get_tree().process_frame


func _assert_warrior_clip() -> void:
	var clip: StringName = _slot.get_body_clip()
	assert_str(String(clip)).is_not_empty()
	assert_bool(_anim.has_animation(clip)).override_failure_message(String(clip)).is_true()


func _event_time(clip: StringName, event: String) -> float:
	var animation: Animation = _anim.get_animation(clip)
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key: int in animation.track_get_key_count(track):
			var args: Array = animation.method_track_get_params(track, key)
			if not args.is_empty() and String(args[0]) == event:
				return animation.track_get_key_time(track, key)
	return -1.0


func _assert_no_reference(dir: String) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if not (file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres")):
			continue
		var text: String = FileAccess.get_file_as_string(dir + file)
		for needle: String in ["abilities/thrust/", "abilities/swift_strike/", "thrust_ability", "swift_strike_ability"]:
			assert_bool(text.contains(needle)).override_failure_message(dir + file + ": " + needle).is_false()
	for sub: String in DirAccess.get_directories_at(dir):
		_assert_no_reference(dir + sub + "/")
