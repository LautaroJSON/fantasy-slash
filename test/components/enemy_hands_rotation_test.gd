extends GdUnitTestSuite
## Rotation of the enemy hands and the two-handed grip (docs/specs/boss-king-rework.md,
## AC1267-AC1270).

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const VERDUGO: EnemyStats = preload("res://data/enemies/verdugo_stats.tres")
const TITAN: EnemyStats = preload("res://data/enemies/titan_stats.tres")
const KING: EnemyStats = preload("res://data/enemies/king_stats.tres")
const KING_SLASH: EnemyAttackData = preload("res://data/enemies/attacks/king_slash_1.tres")
const VERDUGO_SLASH: EnemyAttackData = preload("res://data/enemies/attacks/verdugo_slash_1.tres")


func _hands(stats: EnemyStats) -> EnemyHands:
	var enemy: Enemy = auto_free(ENEMY_SCENE.instantiate())
	enemy.stats = stats
	add_child(enemy)
	enemy.activate(Vector3(0.0, 0.0, 30.0), null)
	return enemy.get_hands()


func _hand(hands: EnemyHands, left: bool) -> MeshInstance3D:
	return hands.get_node("LeftHand" if left else "RightHand") as MeshInstance3D


func _expected(base: Vector3, offset: Vector3) -> Quaternion:
	var turned: Basis = Basis.from_euler(offset * (PI / 180.0)) * Basis.from_euler(base * (PI / 180.0))
	return turned.get_rotation_quaternion()


func _same_rotation(a: Quaternion, b: Quaternion) -> bool:
	return absf(a.dot(b)) > 0.9999


func test_ac1267_without_rotation_data_the_hands_keep_their_rotation() -> void:
	for stats: EnemyStats in [VERDUGO, TITAN]:
		var hands: EnemyHands = _hands(stats)
		var base: Vector3 = hands.config.hand_rotation
		var mirrored := Vector3(base.x, -base.y, -base.z)
		hands.play_windup(VERDUGO_SLASH, 0.2)
		for step: int in 8:
			hands.advance(0.05)
			assert_vector(_hand(hands, false).rotation_degrees).is_equal_approx(base, Vector3(0.001, 0.001, 0.001))
			assert_vector(_hand(hands, true).rotation_degrees).is_equal_approx(mirrored, Vector3(0.001, 0.001, 0.001))
		hands.play_strike(VERDUGO_SLASH, 0.1)
		hands.advance(0.1)
		hands.return_to_rest()
		hands.advance(0.5)
		assert_vector(_hand(hands, false).rotation_degrees).is_equal_approx(base, Vector3(0.001, 0.001, 0.001))
		assert_vector(_hand(hands, true).rotation_degrees).is_equal_approx(mirrored, Vector3(0.001, 0.001, 0.001))


func test_ac1268_the_windup_and_the_strike_turn_the_hand_with_the_move() -> void:
	var hands: EnemyHands = _hands(KING)
	var base: Vector3 = hands.config.hand_rotation
	hands.play_windup(KING_SLASH, 0.4)
	hands.advance(0.2)
	var right: MeshInstance3D = _hand(hands, false)
	assert_bool(_same_rotation(right.quaternion, _expected(base, KING_SLASH.hand_windup_rotation * 0.5))).is_true()
	hands.advance(0.2)
	assert_bool(_same_rotation(right.quaternion, _expected(base, KING_SLASH.hand_windup_rotation))).is_true()
	hands.play_strike(KING_SLASH, 0.1)
	hands.advance(0.1)
	assert_bool(_same_rotation(right.quaternion, _expected(base, KING_SLASH.hand_strike_rotation))).is_true()
	hands.return_to_rest()
	hands.advance(hands.config.return_time)
	assert_vector(right.rotation_degrees).is_equal_approx(base, Vector3(0.001, 0.001, 0.001))


func test_ac1268_the_left_hand_mirrors_the_rotation() -> void:
	var hands: EnemyHands = _hands(VERDUGO)
	var attack := EnemyAttackData.new()
	attack.hands = EnemyAttackData.Hands.BOTH
	attack.hand_windup_rotation = Vector3(20.0, 30.0, 40.0)
	hands.play_windup(attack, 0.0)
	var base: Vector3 = hands.config.hand_rotation
	assert_bool(_same_rotation(_hand(hands, false).quaternion, _expected(base, Vector3(20.0, 30.0, 40.0)))).is_true()
	assert_bool(_same_rotation(_hand(hands, true).quaternion,
		_expected(Vector3(base.x, -base.y, -base.z), Vector3(20.0, -30.0, -40.0)))).is_true()


func test_ac1269_the_left_hand_holds_the_pommel_of_a_two_handed_weapon() -> void:
	var hands: EnemyHands = _hands(KING)
	var grip: Vector3 = hands.config.off_hand_grip
	var right: MeshInstance3D = _hand(hands, false)
	var left: MeshInstance3D = _hand(hands, true)
	hands.play_windup(KING_SLASH, 0.3)
	for step: int in 8:
		hands.advance(0.05)
		assert_vector(left.position).is_equal_approx(right.position + right.quaternion * grip, Vector3(0.001, 0.001, 0.001))
		assert_bool(_same_rotation(left.quaternion, right.quaternion)).is_true()
	hands.shake_hand(false, 0.2, 0.1)
	hands.advance(0.05)
	assert_vector(left.position).is_equal_approx(right.position + right.quaternion * grip, Vector3(0.001, 0.001, 0.001))
	# A hand pair without the option still mirrors.
	var fists: EnemyHands = _hands(VERDUGO)
	assert_float(_hand(fists, true).position.x).is_equal_approx(-_hand(fists, false).position.x, 0.001)


func test_ac1270_a_pose_can_turn_the_hands_and_a_null_material_keeps_the_mesh_materials() -> void:
	var hands: EnemyHands = _hands(KING)
	hands.play_pose(Vector3.ZERO, 0.0, &"pose", Vector3(90.0, 0.0, 0.0))
	assert_bool(_same_rotation(_hand(hands, false).quaternion, _expected(hands.config.hand_rotation, Vector3(90.0, 0.0, 0.0)))).is_true()
	var sword: MeshInstance3D = _hand(hands, false)
	assert_object(sword.material_override).is_null()
	assert_int(sword.mesh.get_surface_count()).is_greater_equal(3)
	for surface: int in sword.mesh.get_surface_count():
		assert_object(sword.mesh.surface_get_material(surface)).is_not_null()
