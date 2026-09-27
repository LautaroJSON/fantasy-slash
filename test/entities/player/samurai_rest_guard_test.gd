extends GdUnitTestSuite
## The Samurai rests facing forward with the katana low to the right and the
## sheath back and down (docs/specs/samurai-rest-guard.md, AC731–AC734).
## Measured on `idle` at t = 0, in the Visual's space (-Z to the enemy, +X to
## the character's right).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SAMURAI: CharacterClassData = preload("res://data/classes/samurai/samurai.tres")
## AC731: widest turn of the chest and the head from the front, and widest lean.
const FACING: float = 10.0
const LEAN: float = 8.0
## AC732: feet side by side and almost together, in meters; flat and pointing
## ahead, in degrees.
const FEET_STAGGER: float = 0.08
const FEET_GAP_MIN: float = 0.12
const FEET_GAP_MAX: float = 0.30
const FOOT_FLAT: float = 10.0
const FOOT_HEADING: float = 25.0
## AC733: the right hand by the right hip and the blade tip ahead, right and
## low, in meters; the blade's angle under the horizontal, in degrees.
const HAND_RIGHT: float = 0.12
const HAND_LOW: float = 0.7
const HAND_HIGH: float = 1.0
const TIP_AHEAD: float = -0.3
const TIP_RIGHT: float = 0.3
const TIP_LOW: float = 0.4
const BLADE_DOWN_MIN: float = 25.0
const BLADE_DOWN_MAX: float = 60.0
## AC734: the sheath mouth by the left hip, in meters; its axis back and down.
const MOUTH_REACH: float = 0.30
const SHEATH_BACK: float = 0.5
const SHEATH_DOWN_MIN: float = 10.0
const SHEATH_DOWN_MAX: float = 45.0

var _player: Player
var _humanoid: LowPolyHumanoid
var _to_visual: Transform3D


func before_test() -> void:
	Session.character_class = SAMURAI
	_player = auto_free(PLAYER_SCENE.instantiate())
	_player.enemy_registry = auto_free(EnemyRegistry.new())
	add_child(_player)
	_humanoid = _player.get_node("Visual/Humanoid") as LowPolyHumanoid
	_humanoid.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	(_player.get_node("PlayerAnimator") as PlayerAnimator).set_physics_process(false)
	_humanoid.anim.play(&"idle", 0.0)
	_humanoid.anim.seek(0.0, true)
	(_player.get_node("WeaponMount") as WeaponMount).update(1.0)
	_to_visual = (_player.get_node("Visual") as Node3D).global_transform.affine_inverse()


func after_test() -> void:
	Session.character_class = null


func _point(node: Node3D) -> Vector3:
	return _to_visual * node.global_position


func _basis(node: Node3D) -> Basis:
	return (_to_visual.basis * node.global_basis).orthonormalized()


## Angle of a direction from -Z on the floor plane, in degrees.
func _heading_from_front(direction: Vector3) -> float:
	return rad_to_deg(Vector3(direction.x, 0.0, direction.z).angle_to(Vector3.FORWARD))


func _below_horizontal(direction: Vector3) -> float:
	return rad_to_deg(-asin(direction.normalized().y))


func test_ac731_facing_forward_and_upright() -> void:
	var torso: Basis = _basis(_humanoid.get_joint("torso"))
	assert_float(_heading_from_front(-torso.z)).is_less_equal(FACING)
	assert_float(rad_to_deg(torso.y.angle_to(Vector3.UP))).is_less_equal(LEAN)
	assert_float(_heading_from_front(-_basis(_humanoid.get_joint("neck")).z)).is_less_equal(FACING)


func test_ac732_feet_side_by_side_and_almost_together() -> void:
	var ankle_l: Vector3 = _point(_humanoid.get_joint("ankle_l"))
	var ankle_r: Vector3 = _point(_humanoid.get_joint("ankle_r"))
	assert_float(absf(ankle_l.z - ankle_r.z)).is_less_equal(FEET_STAGGER)
	assert_float(absf(ankle_l.x - ankle_r.x)).is_between(FEET_GAP_MIN, FEET_GAP_MAX)
	for ankle: String in ["ankle_l", "ankle_r"]:
		var foot: Basis = _basis(_humanoid.get_joint(ankle))
		assert_float(rad_to_deg(foot.y.angle_to(Vector3.UP))).override_failure_message(ankle).is_less_equal(FOOT_FLAT)
		assert_float(_heading_from_front(-foot.z)).override_failure_message(ankle).is_less_equal(FOOT_HEADING)


func test_ac733_the_katana_hangs_low_ahead_to_the_right() -> void:
	var pivot: Node3D = _player.get_node("Visual/SwordPivot") as Node3D
	var hand: Vector3 = _point(pivot)
	assert_float(hand.x).is_greater_equal(HAND_RIGHT)
	assert_float(hand.y).is_between(HAND_LOW, HAND_HIGH)
	var tip: Vector3 = _point(pivot.get_child(0).get_node("TrailTip") as Node3D)
	assert_float(tip.z).is_less(TIP_AHEAD)
	assert_float(tip.x).is_greater_equal(TIP_RIGHT)
	assert_float(tip.y).is_less_equal(TIP_LOW)
	assert_float(_below_horizontal(tip - hand)).is_between(BLADE_DOWN_MIN, BLADE_DOWN_MAX)


func test_ac734_the_sheath_goes_back_and_down() -> void:
	var sheath: Node3D = _player.get_sheath()
	var mouth: Vector3 = _point(sheath.get_node("Grip") as Node3D)
	var hips: Vector3 = _point(_humanoid.get_joint("hips"))
	assert_float(mouth.x).is_less(0.0)
	assert_float(mouth.distance_to(hips)).is_less_equal(MOUTH_REACH)
	var axis: Vector3 = (_to_visual.basis * -sheath.global_basis.z).normalized()
	assert_float(axis.z).is_greater_equal(SHEATH_BACK)
	assert_float(_below_horizontal(axis)).is_between(SHEATH_DOWN_MIN, SHEATH_DOWN_MAX)
