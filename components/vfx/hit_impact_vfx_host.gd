class_name HitImpactVfxHost
extends Node
## Shows a HitImpactVfx where the blade crosses every enemy hit by the basic
## combo or by an ability whose data asks for it (docs/specs/hit-impact-vfx.md).
## Hits are decided by a logical sector, so the contact point is computed: the
## point of the blade (TrailBase→TrailTip) closest to the enemy's axis, carried
## to the enemy's surface. The cut direction is the tip's movement since the
## last physics step. Effects come from a pool built once (Principle V).

## Runs after the gameplay nodes, so the stored tip is last step's when a hit
## lands this step. Structural.
const TIP_SAMPLE_PRIORITY: int = 1000
## Horizontal length below which a direction is treated as unknown. Structural.
const DIRECTION_EPSILON: float = 0.00001

@export var attack: AttackComponent
@export var abilities: Array[AbilityComponent]
## The player's visual: fallback side of the impact and height reference.
@export var visual: Node3D
@export var config: HitImpactVfxConfig
## White, unshaded, additive.
@export var glow_material: StandardMaterial3D
## Amber, unshaded, additive: critical hits.
@export var crit_material: StandardMaterial3D

var _pool: Array[HitImpactVfx] = []
var _base: Node3D = null
var _tip: Node3D = null
var _last_tip: Vector3 = Vector3.ZERO


func _ready() -> void:
	process_physics_priority = TIP_SAMPLE_PRIORITY
	_create_pool()
	_connect_sources()


func _physics_process(_delta: float) -> void:
	_sample_tip()


## Blade markers of the equipped weapon, the same the weapon trail follows.
func attach(base: Node3D, tip: Node3D) -> void:
	_base = base
	_tip = tip
	_sample_tip()


## Plays the next free effect (or the oldest) where the blade crosses `enemy`.
func show_impact(enemy: Enemy, is_crit: bool) -> void:
	var blade_a: Vector3 = _blade_start()
	var blade_b: Vector3 = _blade_end()
	var player_pos: Vector3 = visual.global_position
	var enemy_pos: Vector3 = enemy.global_position
	var normal: Vector3 = impact_normal(enemy_pos, blade_a, blade_b, player_pos)
	var point: Vector3 = impact_point(enemy_pos, enemy.get_hit_padding(), blade_a, blade_b, player_pos, config.min_height, config.max_height)
	var slash_dir: Vector3 = cut_direction(blade_b - _last_tip, normal, config.min_tip_speed)
	_next_effect().play(point, normal, slash_dir, is_crit)


func get_active_count() -> int:
	var count: int = 0
	for effect: HitImpactVfx in _pool:
		if effect.is_playing():
			count += 1
	return count


func get_pool() -> Array[HitImpactVfx]:
	return _pool


## Contact point on the enemy's surface (a vertical cylinder of `radius` around
## `enemy_pos`), on the blade's side and at the blade's height clamped to
## [min_height, max_height] above the enemy's feet.
static func impact_point(enemy_pos: Vector3, radius: float, blade_a: Vector3, blade_b: Vector3,
		player_pos: Vector3, min_height: float, max_height: float) -> Vector3:
	var blade_point: Vector3 = closest_blade_point(enemy_pos, blade_a, blade_b)
	var normal: Vector3 = impact_normal(enemy_pos, blade_a, blade_b, player_pos)
	var height: float = clampf(blade_point.y - enemy_pos.y, min_height, max_height)
	return Vector3(enemy_pos.x, enemy_pos.y + height, enemy_pos.z) + normal * radius


## Horizontal unit direction from the enemy's axis to the blade; towards the
## player when the blade is on the axis.
static func impact_normal(enemy_pos: Vector3, blade_a: Vector3, blade_b: Vector3, player_pos: Vector3) -> Vector3:
	var to_blade: Vector3 = _flat(closest_blade_point(enemy_pos, blade_a, blade_b) - enemy_pos)
	if to_blade.length() > DIRECTION_EPSILON:
		return to_blade.normalized()
	var to_player: Vector3 = _flat(player_pos - enemy_pos)
	if to_player.length() > DIRECTION_EPSILON:
		return to_player.normalized()
	return Vector3.BACK


## Point of the segment blade_a→blade_b closest (horizontally) to the vertical
## axis through `enemy_pos`; the middle of a vertical blade.
static func closest_blade_point(enemy_pos: Vector3, blade_a: Vector3, blade_b: Vector3) -> Vector3:
	var along: Vector3 = _flat(blade_b - blade_a)
	var length_squared: float = along.length_squared()
	if length_squared < DIRECTION_EPSILON:
		return blade_a.lerp(blade_b, 0.5)
	var t: float = clampf(_flat(enemy_pos - blade_a).dot(along) / length_squared, 0.0, 1.0)
	return blade_a.lerp(blade_b, t)


## Tip movement projected on the surface (perpendicular to `normal`); when it is
## shorter than `min_speed`, the horizontal direction across the normal.
static func cut_direction(tip_motion: Vector3, normal: Vector3, min_speed: float) -> Vector3:
	var tangent: Vector3 = tip_motion - normal * tip_motion.dot(normal)
	if tangent.length() >= min_speed and tangent.length() > DIRECTION_EPSILON:
		return tangent.normalized()
	return Vector3.UP.cross(normal).normalized()


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _create_pool() -> void:
	for index: int in config.pool_size:
		var effect := HitImpactVfx.new()
		effect.name = "Impact%d" % index
		effect.setup(config, glow_material, crit_material)
		add_child(effect)
		_pool.append(effect)


func _connect_sources() -> void:
	if attack != null:
		attack.enemy_hit.connect(_on_attack_hit)
	for ability: AbilityComponent in abilities:
		ability.enemy_hit.connect(_on_ability_hit.bind(ability))


## First effect not playing; the one that has played the longest otherwise.
func _next_effect() -> HitImpactVfx:
	var oldest: HitImpactVfx = _pool[0]
	for effect: HitImpactVfx in _pool:
		if not effect.is_playing():
			return effect
		if effect.get_elapsed() > oldest.get_elapsed():
			oldest = effect
	return oldest


func _sample_tip() -> void:
	_last_tip = _blade_end()


## Without blade markers the blade collapses to a point in front of the player's chest.
func _blade_start() -> Vector3:
	if _base == null:
		return _blade_fallback()
	return _base.global_position


func _blade_end() -> Vector3:
	if _tip == null:
		return _blade_fallback()
	return _tip.global_position


func _blade_fallback() -> Vector3:
	return visual.global_position + Vector3.UP * lerpf(config.min_height, config.max_height, 0.5)


func _on_attack_hit(enemy: Enemy, _applied: float, is_crit: bool) -> void:
	show_impact(enemy, is_crit)


func _on_ability_hit(enemy: Enemy, _applied: float, is_crit: bool, ability: AbilityComponent) -> void:
	var data: AbilityData = ability.get_data()
	if data != null and data.shows_hit_impact:
		show_impact(enemy, is_crit)
