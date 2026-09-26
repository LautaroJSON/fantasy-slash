class_name SpinAbility
extends AbilityBehavior
## Spin with the weapon held out for CAST_DURATION, one full turn every
## TICK_INTERVAL. Each completed turn hits every enemy within HIT_RANGE once:
## BASE_DAMAGE + ATTACK_SCALING x player DAMAGE, no bonus or lifesteal, with a
## light push outwards. A turn left unfinished when the spin ends does not hit.
## The player can walk while spinning, slowed by SpinConfig. The player's
## WeaponTrail follows the blade while the spin is cast.
## A dash cuts the spin short and turns into a horizontal slash: every enemy
## the dash crosses takes one spin hit x dash_slash_damage_factor and is pushed
## sideways (docs/specs/spin-dash-slash.md).
## Unique upgrades (spin turns and dash slash alike): "Rompecorazas" makes
## every hit apply Weaken (armor reduction); "Vigorizante" grants a Concussion
## stack per kill, and while spinning each stack speeds up walking and turning
## and adds crit chance; "Tornado" takes seconds off the remaining cooldown per kill.

## Float tolerance when counting completed turns (the cast steps add up to
## CAST_DURATION only approximately). Structural, not a design value.
const TIME_EPSILON: float = 0.0001
const ARMOR_BREAK: StringName = &"armor_break"
const INVIGORATING: StringName = &"invigorating"
const TORNADO: StringName = &"tornado"

@export var config: SpinConfig

## Rolls the crit of every hit; public so tests can seed it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _start_yaw: float = 0.0
## Turns spun so far this cast, fractional. Accumulated per step so a change
## of turn speed mid-spin never makes the blade jump.
var _turn_progress: float = 0.0
var _turns_done: int = 0
## Reused every turn: enemies may leave the registry while damage is applied.
var _hit_buffer: Array[Enemy] = []
## Slot of the running dash slash (null when none).
var _slash_ability: AbilityComponent = null
var _slash_direction: Vector3 = Vector3.ZERO
## Player's feet at the end of the last sliced step.
var _slash_from: Vector3 = Vector3.ZERO
## Enemies already slashed by the running dash; cleared on every slash.
var _slashed: Array[Enemy] = []

@onready var _dash_slash: DashSlashVfx = $DashSlash


func _ready() -> void:
	set_physics_process(false)


## Runs after Player moved the body this frame (child of the player).
func _physics_process(_delta: float) -> void:
	advance_dash_slash()


func begin(ability: AbilityComponent) -> void:
	_start_yaw = ability.visual.rotation.y
	_turn_progress = 0.0
	_turns_done = 0
	ability.sword_swing.hold_pose(config.blade_position, config.blade_rotation)


func channel(ability: AbilityComponent, step: float) -> void:
	_turn_progress += step / get_turn_time(ability)
	ability.visual.rotation.y = wrapf(_start_yaw + TAU * _turn_progress, -PI, PI)
	_hit_completed_turns(ability)


func controls_motion() -> bool:
	return true


func move_body(ability: AbilityComponent, delta: float, wish_direction: Vector3) -> void:
	ability.movement.move(wish_direction, delta, get_move_speed_factor(ability))


func release(ability: AbilityComponent) -> void:
	ability.sword_swing.recover()


## Cut short without a dash (e.g. a boss grab): the weapon goes back to rest.
func cancel_cast(ability: AbilityComponent) -> void:
	ability.sword_swing.recover()


## The dash that cut the spin short becomes a horizontal slash: the player
## faces the dash, the weapon sweeps and the blade of light starts.
func cast_cut_by_dash(ability: AbilityComponent) -> void:
	_slash_ability = ability
	_slash_direction = ability.dash.get_direction()
	_slash_from = ability.body.global_position
	_slashed.clear()
	var yaw: float = atan2(-_slash_direction.x, -_slash_direction.z)
	ability.visual.rotation.y = yaw
	ability.sword_swing.play(config.dash_slash_arc_degrees, config.dash_slash_sweep_duration, 1.0)
	_dash_slash.begin(_slash_from, yaw, config.dash_slash_width)
	set_physics_process(true)


## Slices the stretch the dash covered since the last step; ends with the dash.
func advance_dash_slash() -> void:
	if _slash_ability == null:
		return
	var to: Vector3 = _slash_ability.body.global_position
	_slice_along(_slash_ability, _slash_from, to)
	_dash_slash.extend_to(to)
	_slash_from = to
	if not _slash_ability.dash.is_dashing():
		_end_dash_slash()


func is_dash_slashing() -> bool:
	return _slash_ability != null


func get_dash_slash() -> DashSlashVfx:
	return _dash_slash


func get_turns_done() -> int:
	return _turns_done


## Seconds per turn: TICK_INTERVAL, shortened by the Concussion turn speed.
func get_turn_time(ability: AbilityComponent) -> float:
	var speed_bonus: float = _concussion_modifier(ability, BuffModifier.Stat.ABILITY_SPEED)
	return ability.get_stat(AbilityData.Stat.TICK_INTERVAL) / (1.0 + speed_bonus)


## Fraction of MOVE_SPEED kept while spinning, raised by Concussion.
func get_move_speed_factor(ability: AbilityComponent) -> float:
	var speed_bonus: float = _concussion_modifier(ability, BuffModifier.Stat.MOVE_SPEED)
	return config.move_speed_factor * (1.0 + speed_bonus)


## Crit chance of each hit: only Concussion's (the spin has no crit of its own).
func get_crit_chance(ability: AbilityComponent) -> float:
	return _concussion_modifier(ability, BuffModifier.Stat.CRIT_CHANCE)


## Damage of one dash slash hit, before crit and defense.
func get_dash_slash_damage(ability: AbilityComponent) -> float:
	return hit_damage(ability) * config.dash_slash_damage_factor


func _hit_completed_turns(ability: AbilityComponent) -> void:
	var completed: int = floori(_turn_progress + TIME_EPSILON)
	while _turns_done < completed:
		_turns_done += 1
		_strike(ability)


func _strike(ability: AbilityComponent) -> void:
	_collect_hits(ability)
	var damage: float = hit_damage(ability)
	var origin: Vector3 = ability.visual.global_position
	for enemy: Enemy in _hit_buffer:
		_hit_enemy(ability, enemy, damage, enemy.global_position - origin, config.knockback_speed)


func _collect_hits(ability: AbilityComponent) -> void:
	_hit_buffer.clear()
	var origin: Vector3 = ability.visual.global_position
	var radius: float = ability.get_stat(AbilityData.Stat.HIT_RANGE)
	for enemy: Enemy in ability.registry.get_active():
		if HitboxMath.in_radius(origin, enemy.global_position, radius + enemy.get_hit_padding()):
			_hit_buffer.append(enemy)


## Hits every enemy not slashed yet inside the band covered from `from` to `to`.
func _slice_along(ability: AbilityComponent, from: Vector3, to: Vector3) -> void:
	var flat_direction := Vector2(_slash_direction.x, _slash_direction.z)
	var travelled: float = maxf(Vector2(to.x - from.x, to.z - from.z).dot(flat_direction), 0.0)
	var half_width: float = config.dash_slash_width / 2.0
	_hit_buffer.clear()
	for enemy: Enemy in ability.registry.get_active():
		if _slashed.has(enemy):
			continue
		var padding: float = enemy.get_hit_padding()
		if HitboxMath.in_rectangle(from, flat_direction, enemy.global_position, travelled + padding, half_width + padding):
			_hit_buffer.append(enemy)
	if _hit_buffer.is_empty():
		return
	var damage: float = get_dash_slash_damage(ability)
	for enemy: Enemy in _hit_buffer:
		_slashed.append(enemy)
		_hit_enemy(ability, enemy, damage, _sideways_from_path(enemy.global_position - from), config.dash_slash_knockback_speed)


func _end_dash_slash() -> void:
	_slash_ability = null
	_dash_slash.finish()
	set_physics_process(false)


## Perpendicular to the dash, towards the side the enemy is on.
func _sideways_from_path(offset: Vector3) -> Vector3:
	var side := Vector3(-_slash_direction.z, 0.0, _slash_direction.x)
	if offset.dot(side) < 0.0:
		return -side
	return side


## One hit of the spin (turn or dash slash): crit from Concussion, damage,
## push, and the unique upgrades.
func _hit_enemy(ability: AbilityComponent, enemy: Enemy, damage: float, push: Vector3, push_speed: float) -> void:
	var is_crit: bool = DamageMath.roll_crit(get_crit_chance(ability), rng.randf())
	var crit_bonus: float = ability.player_stats.get_stat(PlayerStats.Stat.CRIT_DAMAGE)
	var was_alive: bool = not enemy.health.is_dead()
	var applied: float = enemy.health.receive_hit(DamageMath.apply_crit(damage, is_crit, crit_bonus))
	ability.report_hit(enemy, applied, is_crit)
	enemy.apply_knockback(push, push_speed)
	_apply_weaken(ability, enemy)
	if was_alive and enemy.health.is_dead():
		_gain_concussion(ability)
		_shorten_cooldown(ability)


## "Rompecorazas": the hit adds a Weaken stack to a survivor.
func _apply_weaken(ability: AbilityComponent, enemy: Enemy) -> void:
	if not ability.has_unique(ARMOR_BREAK) or enemy.health.is_dead():
		return
	enemy.debuffs.apply(ability.get_unique_upgrade(ARMOR_BREAK).debuff, ability.get_unique_value(ARMOR_BREAK))


## "Vigorizante": a kill by the spin adds a Concussion stack to the player.
func _gain_concussion(ability: AbilityComponent) -> void:
	if not ability.has_unique(INVIGORATING):
		return
	ability.buffs.add_stack(ability.get_unique_upgrade(INVIGORATING).buff)


## "Tornado": a kill by the spin takes seconds off the remaining cooldown.
func _shorten_cooldown(ability: AbilityComponent) -> void:
	if not ability.has_unique(TORNADO):
		return
	ability.reduce_cooldown(ability.get_unique_value(TORNADO))


## Concussion only acts while the player has "Vigorizante".
func _concussion_modifier(ability: AbilityComponent, stat: BuffModifier.Stat) -> float:
	if not ability.has_unique(INVIGORATING):
		return 0.0
	return ability.buffs.get_modifier(ability.get_unique_upgrade(INVIGORATING).buff.id, stat)
