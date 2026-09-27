class_name SheatheAbility
extends AbilityBehavior
## "Envainar": held down to charge (see AbilityComponent). While charging, the
## katana rests in its sheath, the player keeps facing the nearest enemy (or
## its last facing when there is none) while walking slowly (the dash is still
## allowed), and takes reduced damage. Every charge milestone pulses the ground
## outline. With the unique upgrade "Paso del Viento" (wind_step), each dash
## while charging adds charge at once; with "Zanshin" (zanshin), a slash that
## kills makes the dash ready; with "Nuki" (nuki), a dash while on cooldown makes
## the ability ready; with "Tsubame Gaeshi" (tsubame_gaeshi), a manual full charge
## that connects stores an empowered Sheathe (glowing katana), cast at once at
## full charge on the next press. On the release the player draws with a
## rising diagonal cut (gyaku kesa-giri); the slash lands on the release (the
## cast that follows is a recovery a dash may cut short):
## - every enemy in a rectangle in front (HIT_RANGE x factor long) takes
##   (BASE_DAMAGE + ATTACK_SCALING x DAMAGE) x factor, which can crit with the
##   player's CRIT_CHANCE / CRIT_DAMAGE (no damage bonus or lifesteal), and is
##   pushed away;
## - every other enemy within wave_radius is pushed away without damage;
## - a wind cut rises along the slash, opening upwards in a V (wind-cut-v.md).
## factor = SheatheConfig.charge_factor(charge ratio) also scales the push.

const SLASH_ANIMATION: StringName = &"sheathe_slash"
## Unique upgrade "Paso del Viento": each dash while charging adds charge.
const WIND_STEP: StringName = &"wind_step"
## Unique upgrade "Zanshin": a kill with the slash makes the dash ready.
const ZANSHIN: StringName = &"zanshin"
## Unique upgrade "Nuki": every dash resets the cooldown.
const NUKI: StringName = &"nuki"
## Unique upgrade "Tsubame Gaeshi": a full manual charge that connects stores an
## empowered Sheathe, cast at once at full charge.
const TSUBAME_GAESHI: StringName = &"tsubame_gaeshi"
## Blade mesh inside the weapon adapter scene (glow overlay).
const WEAPON_MODEL: NodePath = ^"Model"

@export var config: SheatheConfig

var _charging: bool = false
## Facing kept while charging when no enemy is alive.
var _held_yaw: float = 0.0
## Reused every cast: enemies may leave the registry while damage is applied.
var _hit_buffer: Array[Enemy] = []
var _wave_buffer: Array[Enemy] = []
## An empowered Sheathe is stored (Tsubame Gaeshi).
var _empowered: bool = false
## The running cast spent the empowered Sheathe: it cannot store another.
var _cast_is_empowered: bool = false
## Katana blade, found once on the first glow.
var _blade: MeshInstance3D = null
## Created once: swaps the gain flash for the steady glow.
var _flash_timer: Timer = null

@onready var _indicator: AbilityRectIndicator = $Indicator
@onready var _wind_cut: WindCutVfx = $WindCut


func _ready() -> void:
	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	add_child(_flash_timer)
	_flash_timer.timeout.connect(_on_flash_timeout)


## A replaced ability leaves no glow on the katana.
func _exit_tree() -> void:
	if is_instance_valid(_blade):
		_blade.material_overlay = null


## An empowered Sheathe skips the charge: it is cast at once at full charge.
func skips_charge() -> bool:
	return _empowered


func is_empowered() -> bool:
	return _empowered


## While charging the body crouches in the iai pose (sheath-socket-hand-grip.md §2.7).
func get_body_clip(_ability: AbilityComponent) -> StringName:
	return config.charge_body_clip if _charging else &""


func is_charged() -> bool:
	return true


func begin_charge(ability: AbilityComponent) -> void:
	_charging = true
	_held_yaw = ability.visual.rotation.y
	_face_target(ability)
	ability.weapon_mount.hold_in_sheath(true)
	ability.health.damage_reduction = config.charge_damage_reduction
	_indicator.show_rect(
		ability.visual.global_position,
		ability.visual.global_rotation.y,
		_slash_length(ability, config.charge_factor(ability.get_charge_ratio())),
		ability.get_stat(AbilityData.Stat.HIT_WIDTH))


func charge(ability: AbilityComponent, _step: float) -> void:
	_face_target(ability)
	_update_reach(ability, ability.get_charge_ratio())


## "Nuki": every dash while on cooldown makes the ability ready.
func dash_started(ability: AbilityComponent) -> void:
	if not ability.has_unique(NUKI):
		return
	if not ability.is_on_cooldown() or ability.is_casting() or ability.is_charging():
		return
	ability.reset_cooldown()


## "Paso del Viento": the dash adds its level value, in seconds, to the charge.
func dash_during_charge(ability: AbilityComponent) -> void:
	if ability.has_unique(WIND_STEP):
		ability.add_charge(ability.get_unique_value(WIND_STEP))


func charge_milestone(_ability: AbilityComponent, _index: int, is_full: bool) -> void:
	if is_full:
		_indicator.set_transparency(config.full_charge_transparency)
	_indicator.pulse()


func cancel_charge(ability: AbilityComponent) -> void:
	_end_charge(ability)
	_indicator.start_fade()
	ability.sword_swing.recover()


## The key was released: the slash lands at once, then the cut is drawn over
## CAST_DURATION as a recovery that a dash may cut short.
func begin(ability: AbilityComponent) -> void:
	_cast_is_empowered = _empowered
	if _empowered:
		_spend_empowered(ability)
	_end_charge(ability)
	face_nearest_enemy(ability)
	_update_reach(ability, ability.get_released_charge_ratio())
	play_cast_animation(ability, SLASH_ANIMATION)
	_slash(ability)


## The recovery ran to its end: nothing left to do (the hit already landed).
func release(_ability: AbilityComponent) -> void:
	pass


## A dash cut the recovery short: the katana goes back to rest at once.
func cancel_cast(ability: AbilityComponent) -> void:
	ability.swing_player.stop()
	ability.sword_swing.recover()


func _slash(ability: AbilityComponent) -> void:
	var factor: float = config.charge_factor(ability.get_released_charge_ratio())
	_collect_hits(ability, factor)
	var is_crit: bool = DamageMath.roll_crit(ability.player_stats.get_stat(PlayerStats.Stat.CRIT_CHANCE), randf())
	var damage: float = DamageMath.apply_crit(hit_damage(ability) * factor, is_crit, ability.player_stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE))
	var push: float = config.knockback_speed * factor
	var killed: bool = false
	for enemy: Enemy in _hit_buffer:
		killed = _hit_enemy(ability, enemy, damage, is_crit, push) or killed
	for enemy: Enemy in _wave_buffer:
		_push_away(ability, enemy, push)
	_indicator.start_fade()
	_wind_cut.play(ability.visual.global_position, ability.visual.global_rotation.y, _slash_length(ability, factor), factor)
	if killed and ability.has_unique(ZANSHIN):
		ability.dash.reset_cooldown()
	if _connects_full_manual_charge(ability):
		_grant_empowered(ability)


func controls_motion() -> bool:
	return _charging


## Walks slowly without turning towards the walk: the facing stays on the target.
func move_body(ability: AbilityComponent, delta: float, wish_direction: Vector3) -> void:
	ability.movement.move(wish_direction, delta, config.charge_move_speed_factor)
	_face_target(ability)


func get_indicator() -> AbilityRectIndicator:
	return _indicator


func get_wind_cut() -> WindCutVfx:
	return _wind_cut


func get_flash_timer() -> Timer:
	return _flash_timer


## Tsubame Gaeshi: a manual charge released at 100 % whose slash hit someone.
func _connects_full_manual_charge(ability: AbilityComponent) -> bool:
	if _cast_is_empowered or not ability.has_unique(TSUBAME_GAESHI):
		return false
	return ability.get_released_charge_ratio() >= 1.0 and not _hit_buffer.is_empty()


## Stores the empowered Sheathe: the katana flashes, then keeps a steady glow.
func _grant_empowered(ability: AbilityComponent) -> void:
	_empowered = true
	_find_blade(ability).material_overlay = config.empowered_flash_overlay
	_flash_timer.start(config.empowered_flash_duration)
	ability.notify_empowered(true)


func _spend_empowered(ability: AbilityComponent) -> void:
	_empowered = false
	_flash_timer.stop()
	_find_blade(ability).material_overlay = null
	ability.notify_empowered(false)


func _on_flash_timeout() -> void:
	if _empowered and is_instance_valid(_blade):
		_blade.material_overlay = config.empowered_overlay


func _find_blade(ability: AbilityComponent) -> MeshInstance3D:
	if _blade == null:
		_blade = ability.sword_swing.pivot.get_child(0).get_node(WEAPON_MODEL) as MeshInstance3D
	return _blade


func _end_charge(ability: AbilityComponent) -> void:
	_charging = false
	ability.weapon_mount.hold_in_sheath(false)
	ability.health.damage_reduction = 0.0


## Faces the nearest enemy; with none alive, keeps the last facing.
func _face_target(ability: AbilityComponent) -> void:
	if ability.registry.find_nearest(ability.visual.global_position) == null:
		ability.visual.rotation.y = _held_yaw
		return
	face_nearest_enemy(ability)
	_held_yaw = ability.visual.rotation.y


## Moves and resizes the slash outline for this charge ratio, from the player's feet.
func _update_reach(ability: AbilityComponent, ratio: float) -> void:
	_indicator.resize(
		ability.visual.global_position,
		ability.visual.global_rotation.y,
		_slash_length(ability, config.charge_factor(ratio)),
		ability.get_stat(AbilityData.Stat.HIT_WIDTH))


func _slash_length(ability: AbilityComponent, factor: float) -> float:
	return ability.get_stat(AbilityData.Stat.HIT_RANGE) * factor


## Fills the slash targets (rectangle in front) and the wave targets (the rest
## within wave_radius).
func _collect_hits(ability: AbilityComponent, factor: float) -> void:
	_hit_buffer.clear()
	_wave_buffer.clear()
	var origin: Vector3 = ability.visual.global_position
	var forward: Vector3 = -ability.visual.global_basis.z
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	var length: float = _slash_length(ability, factor)
	var half_width: float = ability.get_stat(AbilityData.Stat.HIT_WIDTH) / 2.0
	for enemy: Enemy in ability.registry.get_active():
		var padding: float = enemy.get_hit_padding()
		if HitboxMath.in_rectangle(origin, flat_forward, enemy.global_position, length + padding, half_width + padding):
			_hit_buffer.append(enemy)
		elif HitboxMath.in_radius(origin, enemy.global_position, config.wave_radius + padding):
			_wave_buffer.append(enemy)


## Returns true when the hit killed the enemy.
func _hit_enemy(ability: AbilityComponent, enemy: Enemy, damage: float, is_crit: bool, push: float) -> bool:
	var applied: float = enemy.health.receive_hit(damage)
	ability.report_hit(enemy, applied, is_crit)
	_push_away(ability, enemy, push)
	return enemy.health.is_dead()


func _push_away(ability: AbilityComponent, enemy: Enemy, push: float) -> void:
	enemy.apply_knockback(enemy.global_position - ability.visual.global_position, push)
