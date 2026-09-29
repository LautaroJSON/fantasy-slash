extends GdUnitTestSuite
## Multi-kill hit lag tables (docs/specs/kill-feedback.md, AC1159, AC1162).

const CONFIG: MultiKillFeelConfig = preload("res://data/player/multi_kill_feel_config.tres")
const IMPACT: HitImpactVfxConfig = preload("res://data/player/hit_impact_vfx_config.tres")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const TOLERANCE: float = 0.0001


func test_ac1159_bonuses_start_at_two_kills_and_repeat_the_last_value() -> void:
	assert_float(CONFIG.hitlag_bonus_for(0)).is_equal(0.0)
	assert_float(CONFIG.hitlag_bonus_for(1)).is_equal(0.0)
	assert_float(CONFIG.shake_bonus_for(1)).is_equal(0.0)
	assert_float(CONFIG.hitlag_bonus_for(2)).is_equal_approx(0.02, TOLERANCE)
	assert_float(CONFIG.shake_bonus_for(2)).is_equal_approx(0.05, TOLERANCE)
	assert_float(CONFIG.hitlag_bonus_for(3)).is_equal_approx(0.035, TOLERANCE)
	assert_float(CONFIG.shake_bonus_for(3)).is_equal_approx(0.1, TOLERANCE)
	assert_float(CONFIG.hitlag_bonus_for(4)).is_equal_approx(0.05, TOLERANCE)
	assert_float(CONFIG.hitlag_bonus_for(9)).is_equal_approx(0.05, TOLERANCE)
	assert_float(CONFIG.shake_bonus_for(4)).is_equal_approx(0.15, TOLERANCE)
	assert_float(CONFIG.shake_bonus_for(9)).is_equal_approx(0.15, TOLERANCE)


func test_ac1162_the_data_exists_and_the_player_uses_it() -> void:
	assert_int(CONFIG.min_kills).is_equal(2)
	assert_int(CONFIG.hitlag_bonus.size()).is_equal(3)
	assert_int(CONFIG.shake_bonus.size()).is_equal(3)
	assert_float(IMPACT.kill_scale).is_greater(1.0)
	assert_float(IMPACT.max_kill_crit_scale).is_greater_equal(IMPACT.kill_scale)
	var player: Player = auto_free(PLAYER_SCENE.instantiate())
	add_child(player)
	var hitstop: HitstopComponent = player.get_node("Hitstop") as HitstopComponent
	assert_object(hitstop.multi_kill).is_same(CONFIG)
