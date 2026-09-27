extends GdUnitTestSuite

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const RAGE: DebuffData = preload("res://data/debuffs/rage.tres")
const BLEED: DebuffData = preload("res://data/debuffs/bleed.tres")
const StatusOverlayProbe := preload("res://test/helpers/status_overlay_probe.gd")


func _spawn_idle_enemy() -> Enemy:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	add_child(enemy)
	enemy.activate(Vector3.ZERO, null)
	return enemy


func test_ac339_a_permanent_status_never_expires_and_clears_on_reset() -> void:
	var enemy: Enemy = _spawn_idle_enemy()
	enemy.debuffs.apply(RAGE, 1.0)
	enemy.debuffs.advance(1000.0)
	assert_bool(enemy.debuffs.has_debuff(RAGE.id)).is_true()
	assert_float(enemy.debuffs.get_defense_reduction()).is_equal(0.0)
	assert_float(enemy.debuffs.get_remaining_seconds(RAGE.id)).is_equal(0.0)
	enemy.debuffs.clear()
	assert_bool(enemy.debuffs.has_debuff(RAGE.id)).is_false()


## status-icons.md: the 3D row became the HUD overlay row; "no time" is now
## "no clock" (permanent) next to a timed debuff with its clock.
func test_ac340_rage_icon_has_no_time_and_sits_next_to_a_debuff() -> void:
	var enemy: Enemy = _spawn_idle_enemy()
	var probe: StatusOverlayProbe = auto_free(StatusOverlayProbe.new())
	add_child(probe)
	probe.watch(enemy)
	enemy.debuffs.apply(RAGE, 1.0)
	enemy.debuffs.apply(BLEED, 0.01)
	var row: StatusIconRow = probe.row()
	assert_int(row.get_visible_icon_count()).is_equal(2)
	assert_object(row.icon(0).get_glyph_texture()).is_same(RAGE.icon)
	assert_bool(row.icon(0).get_clock().visible).is_false()
	assert_bool(row.icon(1).get_clock().visible).is_true()
