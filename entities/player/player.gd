class_name Player
extends CharacterBody3D
## Player entity. Only orchestrates: reads InputMap actions and delegates to components.

signal died
## A basic attack or the start of an ability cast: enemies may read it as an
## opening (docs/specs/enemy-types.md).
signal attack_performed

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_FORWARD: StringName = &"move_forward"
const ACTION_BACK: StringName = &"move_back"
const ACTION_ATTACK: StringName = &"attack"
const ACTION_DASH: StringName = &"dash"
const ACTION_JUMP: StringName = &"jump"
const ACTION_ABILITY_BASIC: StringName = &"ability_basic"
const ACTION_ABILITY_ULTIMATE: StringName = &"ability_ultimate"
## Blade markers every weapon scene provides for the weapon trail.
const WEAPON_TRAIL_BASE: NodePath = ^"TrailBase"
const WEAPON_TRAIL_TIP: NodePath = ^"TrailTip"
## Optional hilt marker of a weapon: the right hand grips it when a clip asks
## (docs/specs/sheath-socket-hand-grip.md).
const WEAPON_HILT: NodePath = ^"Hilt"
## Optional second-hand marker on a two-handed weapon's handle: the left hand
## grips it when a clip asks (docs/specs/class-combat-identity.md §3.2).
const WEAPON_OFF_HAND: NodePath = ^"OffHand"

## Assigned by the level; handed to the attack auto-aim and the abilities.
@export var enemy_registry: EnemyRegistry
## Class used when none was chosen in the main menu (arena loaded directly).
@export var default_class: CharacterClassData

@onready var health: HealthComponent = $HealthComponent
@onready var stats: StatsComponent = $StatsComponent
@onready var dash: DashComponent = $DashComponent
@onready var attack: AttackComponent = $AttackComponent
@onready var basic_ability: AbilityComponent = $BasicAbility
@onready var ultimate_ability: AbilityComponent = $UltimateAbility
@onready var sword_swing: SwordSwing = $SwordSwing
@onready var buffs: BuffComponent = $BuffComponent
@onready var air_slash: AirSlashComponent = $AirSlash
@onready var _weapon_pivot: Node3D = $Visual/SwordPivot
@onready var _movement: MovementComponent = $MovementComponent
@onready var _camera: ThirdPersonCamera = $CameraRig
@onready var _weapon_trail: WeaponTrail = $WeaponTrail
@onready var _visual: Node3D = $Visual
@onready var _weapon_mount: WeaponMount = $WeaponMount
@onready var _humanoid: LowPolyHumanoid = $Visual/Humanoid
@onready var _hitstop: HitstopComponent = $Hitstop

## Scabbard of the class weapon, or null when the weapon has none.
var _sheath: Node3D = null
## Socket on the torso the scabbard hangs from, or null without a scabbard.
var _sheath_socket: Node3D = null
## Ignores the buttons still held from a closed menu (e.g. B closing the pause).
var _input_guard: HeldInputGuard = HeldInputGuard.new([ACTION_ATTACK, ACTION_DASH, ACTION_JUMP, ACTION_ABILITY_BASIC, ACTION_ABILITY_ULTIMATE])
## Seconds left of a hold (a boss grab): no movement, attacks, jumps, dashes or abilities.
var _hold_left: float = 0.0


func _ready() -> void:
	attack.registry = enemy_registry
	basic_ability.registry = enemy_registry
	ultimate_ability.registry = enemy_registry
	air_slash.registry = enemy_registry
	_apply_character_class()
	_setup_health()
	stats.stats_changed.connect(_on_stats_changed)
	health.died.connect(_on_health_died)
	attack.step_started.connect(_on_attack_step_started)
	air_slash.struck.connect(_on_attacked)
	basic_ability.cast_started.connect(attack_performed.emit)
	ultimate_ability.cast_started.connect(attack_performed.emit)
	basic_ability.cast_started.connect(attack.cancel)
	ultimate_ability.cast_started.connect(attack.cancel)
	basic_ability.charge_started.connect(attack.cancel)
	ultimate_ability.charge_started.connect(attack.cancel)


func _physics_process(delta: float) -> void:
	_input_guard.update(Engine.get_physics_frames())
	if _hold_left > 0.0:
		_hold_left = maxf(_hold_left - delta, 0.0)
		_movement.hold(delta)
		return
	_handle_abilities()
	_handle_jump()
	_handle_dash()
	_handle_air_slash()
	_handle_movement(delta)
	_handle_attack()


## Held by an enemy (docs/specs/boss-verdugo.md): for `duration` seconds every
## action is ignored and the player stands still; a running dash or cast stops.
func begin_hold(duration: float) -> void:
	_hold_left = duration
	dash.cancel()
	attack.cancel()
	basic_ability.cancel_charge()
	ultimate_ability.cancel_charge()
	basic_ability.cancel_cast()
	ultimate_ability.cancel_cast()
	air_slash.cancel()


func end_hold() -> void:
	_hold_left = 0.0


func is_held() -> bool:
	return _hold_left > 0.0


## Class chosen in the main menu, or default_class when there is none.
func get_character_class() -> CharacterClassData:
	if Session.character_class != null:
		return Session.character_class
	return default_class


## Flat direction the player faces (−Z of Visual).
func get_facing() -> Vector3:
	var forward: Vector3 = -_visual.global_basis.z
	return Vector3(forward.x, 0.0, forward.z).normalized()


## Scabbard of the class weapon, or null when the weapon has none.
## Orbit camera of the player (the touch controls turn it with a drag).
func get_camera() -> ThirdPersonCamera:
	return _camera


func get_sheath() -> Node3D:
	return _sheath


func get_sheath_socket() -> Node3D:
	return _sheath_socket


## True while any ability is being charged or cast, or the air slash runs: the
## player can do nothing else (charging still allows the dash).
func is_casting() -> bool:
	return is_charging() or basic_ability.is_casting() or ultimate_ability.is_casting() or air_slash.is_active()


## Humanoid clip an ability asks the body to play while it charges or casts;
## &"" = the default (docs/specs/sheath-socket-hand-grip.md §2.7).
func get_body_clip() -> StringName:
	var clip: StringName = basic_ability.get_body_clip()
	return clip if clip != &"" else ultimate_ability.get_body_clip()


## True while an ability is held down to charge it.
func is_charging() -> bool:
	return basic_ability.is_charging() or ultimate_ability.is_charging()


## Routes an upgrade card to the player stats or to the ability that owns it.
## A card already at its cap is ignored.
func apply_upgrade(card: UpgradeCard) -> void:
	if is_maxed(card):
		return
	if card is UpgradeData:
		stats.add_upgrade(card as UpgradeData)
	elif basic_ability.owns_upgrade(card):
		basic_ability.apply_card(card)
	elif ultimate_ability.owns_upgrade(card):
		ultimate_ability.apply_card(card)


## Undoes one upgrade card (sandbox).
func remove_upgrade(card: UpgradeCard) -> void:
	if card is UpgradeData:
		stats.remove_upgrade(card as UpgradeData)
	elif basic_ability.owns_upgrade(card):
		basic_ability.remove_card(card)
	elif ultimate_ability.owns_upgrade(card):
		ultimate_ability.remove_card(card)


## Copies taken of an upgrade card (the level, for unique upgrades).
func count_upgrade(card: UpgradeCard) -> int:
	if card is UpgradeData:
		return stats.count_upgrade(card as UpgradeData)
	if basic_ability.owns_upgrade(card):
		return basic_ability.count_card(card)
	return ultimate_ability.count_card(card)


## Highest count a card can reach: max_stacks for stat cards, max_level for
## unique upgrades.
func max_count(card: UpgradeCard) -> int:
	if card is UpgradeData:
		return (card as UpgradeData).max_stacks
	if card is AbilityUpgradeData:
		return (card as AbilityUpgradeData).max_stacks
	return (card as AbilityUniqueUpgradeData).max_level


func is_maxed(card: UpgradeCard) -> bool:
	return count_upgrade(card) >= max_count(card)


## Ability slot that owns an ability card (basic or ultimate).
func ability_for(card: UpgradeCard) -> AbilityComponent:
	return basic_ability if basic_ability.owns_upgrade(card) else ultimate_ability


## Removes every upgrade from the player and its abilities (sandbox).
func reset_upgrades() -> void:
	stats.clear_upgrades()
	basic_ability.clear_upgrades()
	ultimate_ability.clear_upgrades()
	buffs.clear()


## Level a unique upgrade card would grant if chosen now (1 when not taken yet).
func next_unique_level(card: AbilityUniqueUpgradeData) -> int:
	return ability_for(card).get_unique_level(card.id) + 1


## Abilities cannot start mid-dash, unless they interrupt the dash (data). A
## charged ability is released once its key is up; if that happens mid-dash, it
## is released when the dash ends.
func _handle_abilities() -> void:
	if air_slash.is_active():
		return
	if dash.is_dashing():
		_interrupt_dash_if_pressed(basic_ability, ACTION_ABILITY_BASIC)
		_interrupt_dash_if_pressed(ultimate_ability, ACTION_ABILITY_ULTIMATE)
		return
	_release_charge_if_key_up(basic_ability, ACTION_ABILITY_BASIC)
	_release_charge_if_key_up(ultimate_ability, ACTION_ABILITY_ULTIMATE)
	if _input_guard.is_just_pressed(ACTION_ABILITY_BASIC):
		basic_ability.try_cast()
	elif _input_guard.is_just_pressed(ACTION_ABILITY_ULTIMATE):
		ultimate_ability.try_cast()


## An ability that interrupts the dash (e.g. Envainar) cuts it short and starts
## at once when its key is pressed and it can be cast; the iframes are kept.
func _interrupt_dash_if_pressed(ability: AbilityComponent, action: StringName) -> void:
	if not dash.is_dashing() or not _input_guard.is_just_pressed(action):
		return
	if not ability.interrupts_dash() or not ability.can_cast():
		return
	dash.cancel()
	ability.try_cast()


func _release_charge_if_key_up(ability: AbilityComponent, action: StringName) -> void:
	if ability.is_charging() and not Input.is_action_pressed(action):
		ability.release_charge()


## The jump cuts any strike of the combo, like the dash
## (docs/specs/jump-cancels-strike.md); in the air there is nothing to cut.
func _handle_jump() -> void:
	if not _input_guard.is_just_pressed(ACTION_JUMP) or is_casting() or not is_on_floor():
		return
	attack.cancel()
	_movement.jump()


## Dashes towards the movement input, or forward when there is none. Charging
## an ability allows the dash (the charge and the pose are kept), and so does a
## cast the dash may cut short (e.g. Envainar's recovery), which ends first so
## the abilities hear about the dash already out of it.
func _handle_dash() -> void:
	if _input_guard.is_just_pressed(ACTION_DASH) and _can_dash():
		if dash.try_dash(_camera.to_world_direction(_read_move_input())):
			attack.cancel()
			basic_ability.cut_cast_by_dash()
			ultimate_ability.cut_cast_by_dash()
			basic_ability.notify_dash()
			ultimate_ability.notify_dash()


func _can_dash() -> bool:
	if air_slash.is_active():
		return false
	return _dash_allowed_by(basic_ability) and _dash_allowed_by(ultimate_ability)


func _dash_allowed_by(ability: AbilityComponent) -> bool:
	return not ability.is_casting() or ability.dash_cancels_cast()


## While dashing, the dash owns the body's motion. While casting, the ability
## moves the player if it controls motion; otherwise the player stands still.
## A committed strike moves the body with its lunge; in its recovery, moving
## strafes or cuts it (docs/specs/bdo-combat-feel.md).
func _handle_movement(delta: float) -> void:
	if dash.is_dashing():
		dash.move_body(delta)
		return
	if is_casting():
		_move_while_casting(delta)
		return
	var move_input: Vector2 = _read_move_input()
	var wish_direction: Vector3 = _camera.to_world_direction(move_input)
	if attack.is_committed():
		attack.move_body(delta, wish_direction)
		return
	if attack.is_attacking():
		_move_in_recovery(move_input, wish_direction, delta)
		return
	_movement.move(wish_direction, delta)


## STRAFE: slides slowly without turning (the facing is locked) and the strike
## goes on. CANCEL: enough input cuts the strike and moves normally.
func _move_in_recovery(move_input: Vector2, wish_direction: Vector3, delta: float) -> void:
	if attack.combo.recovery_move == AttackComboConfig.RecoveryMove.STRAFE:
		_movement.move(wish_direction, delta, attack.combo.recovery_strafe_factor)
		return
	if not _cancels_recovery(move_input):
		_movement.move(Vector3.ZERO, delta)
		return
	attack.cancel()
	_movement.move(wish_direction, delta)


## CANCEL: enough movement input cuts a strike's recovery, unless an attack tap (this
## frame or buffered) chains the next strike.
func _cancels_recovery(move_input: Vector2) -> bool:
	if move_input.length() <= attack.combo.move_cancel_threshold:
		return false
	return not attack.has_buffered_attack() and not _input_guard.is_just_pressed(ACTION_ATTACK)


## Air slash (docs/specs/berserker-air-slash.md): in the air, the attack button
## starts it instead of a swing; letting go while suspended releases it.
func _handle_air_slash() -> void:
	if air_slash.get_phase() == AirSlashComponent.Phase.HOVER:
		if not _input_guard.is_pressed(ACTION_ATTACK):
			air_slash.release()
		return
	if air_slash.is_active() or is_on_floor() or is_casting() or dash.is_dashing():
		return
	if _input_guard.is_pressed(ACTION_ATTACK) and air_slash.try_start():
		attack.cancel()


## Each tap is one strike of the combo (docs/specs/humanoid-player-model.md):
## holding the button does not repeat it.
func _handle_attack() -> void:
	if _input_guard.is_just_pressed(ACTION_ATTACK) and not is_casting():
		attack.request_attack()


func _move_while_casting(delta: float) -> void:
	var wish_direction: Vector3 = _camera.to_world_direction(_read_move_input())
	if air_slash.controls_motion():
		air_slash.move_body(delta, wish_direction)
	elif basic_ability.controls_motion():
		basic_ability.move_body(delta, wish_direction)
	elif ultimate_ability.controls_motion():
		ultimate_ability.move_body(delta, wish_direction)
	else:
		_movement.hold(delta)


func _read_move_input() -> Vector2:
	return Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK)


func _apply_character_class() -> void:
	var character_class: CharacterClassData = get_character_class()
	stats.set_base_stats(character_class.base_stats)
	_equip_weapon(character_class.weapon)
	air_slash.setup(character_class.air_slash)
	_apply_combat_style(character_class)


## How the class fights (docs/specs/class-combat-identity.md): its animation
## profile on the humanoid, its combo and how the enemies it hits shake.
func _apply_combat_style(character_class: CharacterClassData) -> void:
	_humanoid.set_profile(character_class.animation_profile)
	attack.combo = character_class.combo
	_hitstop.config = character_class.hitstop


## The class weapon is fixed: placed once on the pivot, held in the humanoid's
## hand (WeaponMount) and at its rest pose after abilities, with
## the weapon trail following its blade markers.
func _equip_weapon(weapon: WeaponData) -> void:
	var model: Node3D = weapon.model.instantiate() as Node3D
	_weapon_pivot.add_child(model)
	sword_swing.setup(weapon)
	_weapon_trail.attach(model.get_node(WEAPON_TRAIL_BASE) as Node3D, model.get_node(WEAPON_TRAIL_TIP) as Node3D)
	_grip_with_right_hand(model)
	_grip_with_left_hand(model)
	_equip_sheath(weapon)
	_weapon_mount.setup(weapon, _sheath_socket)


## The weapon's scabbard, if any, hangs from a socket on the weapon's
## `sheath_joint` (docs/specs/sheath-in-left-hand.md): the katana's is held in
## the left hand, so each clip's left arm sets its angle.
func _equip_sheath(weapon: WeaponData) -> void:
	if weapon.sheath == null:
		return
	_sheath_socket = Node3D.new()
	_sheath_socket.name = "SheathSocket"
	_humanoid.attach_to_joint(String(weapon.sheath_joint), _sheath_socket, weapon.sheath_position, weapon.sheath_rotation)
	_sheath = weapon.sheath.instantiate() as Node3D
	_sheath_socket.add_child(_sheath)


## The left hand grips a two-handed weapon's second-hand marker, if it has one,
## when a clip asks (e.g. the Berserker's greatsword).
func _grip_with_left_hand(model: Node3D) -> void:
	if model.has_node(WEAPON_OFF_HAND):
		_humanoid.set_hand_target(LowPolyHumanoid.Hand.LEFT, model.get_node(WEAPON_OFF_HAND) as Node3D)


## The right hand grips the weapon's hilt marker, if it has one, when a clip asks.
func _grip_with_right_hand(model: Node3D) -> void:
	if model.has_node(WEAPON_HILT):
		_humanoid.set_hand_target(LowPolyHumanoid.Hand.RIGHT, model.get_node(WEAPON_HILT) as Node3D)


func _setup_health() -> void:
	health.setup(stats.get_stat(PlayerStats.Stat.MAX_HEALTH), stats.get_stat(PlayerStats.Stat.DEFENSE))


func _on_stats_changed() -> void:
	health.defense = stats.get_stat(PlayerStats.Stat.DEFENSE)
	health.set_max_health(stats.get_stat(PlayerStats.Stat.MAX_HEALTH))


func _on_health_died() -> void:
	end_hold()
	died.emit()


func _on_attacked(_hit_count: int, _total_damage: float, _was_crit: bool) -> void:
	attack_performed.emit()


func _on_attack_step_started(_step_index: int) -> void:
	attack_performed.emit()
