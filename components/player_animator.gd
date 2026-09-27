class_name PlayerAnimator
extends Node
## Maps the player's state to the humanoid's clips
## (docs/specs/humanoid-player-model.md). The locomotion state is decided by a
## pure function (next_locomotion); this node only turns states into clips and
## is the only one that plays clips on the humanoid.
## Priority each frame: a combo strike (its clip is requested by the
## AttackComponent through play_attack), then `hit`, then the dash (`run`),
## then casts, charges, the air slash and holds (`idle`), then locomotion.

enum Locomotion {
	IDLE,
	RUN,
	RUN_STOP,
	JUMP_START,
	AIR,
	LAND,
}

## Clip of each Locomotion state, indexed by the enum.
const LOCOMOTION_CLIPS: Array[StringName] = [&"idle", &"run", &"run_stop", &"jump_start", &"jump_air", &"jump_land"]
const CLIP_HIT: StringName = &"hit"
const CLIP_DASH: StringName = &"run"
const CLIP_BUSY: StringName = &"idle"

@export var player: Player
@export var humanoid: LowPolyHumanoid
@export var attack: AttackComponent
@export var dash: DashComponent
@export var health: HealthComponent
@export var config: PlayerAnimationConfig

var _locomotion: Locomotion = Locomotion.IDLE
## True for one update after the current locomotion clip finished.
var _locomotion_clip_finished: bool = false
var _hit_playing: bool = false
## Last clip requested on the humanoid; a clip is only requested on change.
var _requested: StringName = &""


func _ready() -> void:
	humanoid.anim.animation_finished.connect(_on_clip_finished)
	health.damaged.connect(_on_damaged)


func _physics_process(_delta: float) -> void:
	update()


## Pure: the next locomotion state. `rising` = moving up (a jump take-off);
## `clip_finished` = the clip of `current` has just finished.
static func next_locomotion(current: Locomotion, on_floor: bool, horizontal_speed: float, rising: bool, clip_finished: bool, animation_config: PlayerAnimationConfig) -> Locomotion:
	if not on_floor:
		return _next_in_air(current, rising, clip_finished)
	if current == Locomotion.JUMP_START or current == Locomotion.AIR:
		return Locomotion.LAND
	if horizontal_speed > animation_config.run_speed_threshold:
		return Locomotion.RUN
	return _next_on_floor_still(current, clip_finished)


## Locomotion state an action leaves behind: no stop, take-off or landing clip.
static func settled_locomotion(on_floor: bool, horizontal_speed: float, animation_config: PlayerAnimationConfig) -> Locomotion:
	if not on_floor:
		return Locomotion.AIR
	if horizontal_speed > animation_config.run_speed_threshold:
		return Locomotion.RUN
	return Locomotion.IDLE


static func _next_in_air(current: Locomotion, rising: bool, clip_finished: bool) -> Locomotion:
	if current == Locomotion.JUMP_START:
		return Locomotion.AIR if clip_finished else Locomotion.JUMP_START
	if current == Locomotion.AIR:
		return Locomotion.AIR
	return Locomotion.JUMP_START if rising else Locomotion.AIR


static func _next_on_floor_still(current: Locomotion, clip_finished: bool) -> Locomotion:
	match current:
		Locomotion.RUN:
			return Locomotion.RUN_STOP
		Locomotion.RUN_STOP, Locomotion.LAND:
			return Locomotion.IDLE if clip_finished else current
	return Locomotion.IDLE


func update() -> void:
	if _is_action_owning_body():
		_locomotion = settled_locomotion(player.is_on_floor(), _horizontal_speed(), config)
		_locomotion_clip_finished = false
		_play_action_clip()
		return
	_advance_locomotion()
	_request(LOCOMOTION_CLIPS[_locomotion])


## Plays a combo strike clip at `speed` (the AttackComponent decides when).
func play_attack(clip: StringName, speed: float) -> void:
	_hit_playing = false
	humanoid.anim.speed_scale = speed
	humanoid.play(clip)
	_requested = clip


func get_locomotion() -> Locomotion:
	return _locomotion


func is_hit_playing() -> bool:
	return _hit_playing


func _is_action_owning_body() -> bool:
	return attack.is_attacking() or _hit_playing or dash.is_dashing() or _is_busy()


## Casting, charging, the air slash or a hold: the weapon has its own poses.
func _is_busy() -> bool:
	return player.is_casting() or player.is_held()


func _play_action_clip() -> void:
	if attack.is_attacking() or _hit_playing:
		return
	_request(CLIP_DASH if dash.is_dashing() else CLIP_BUSY)


func _advance_locomotion() -> void:
	var on_floor: bool = player.is_on_floor()
	var rising: bool = player.velocity.y > 0.0
	_locomotion = next_locomotion(_locomotion, on_floor, _horizontal_speed(), rising, _locomotion_clip_finished, config)
	_locomotion_clip_finished = false


func _horizontal_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _request(clip: StringName) -> void:
	if clip == _requested:
		return
	humanoid.anim.speed_scale = 1.0
	humanoid.play(clip)
	_requested = clip


## Chains the next clip at once, so a finished one-shot clip never freezes a frame.
func _on_clip_finished(clip: StringName) -> void:
	if clip == CLIP_HIT:
		_hit_playing = false
		_requested = &""
	elif clip == LOCOMOTION_CLIPS[_locomotion]:
		_locomotion_clip_finished = true
	update()


## `hit` only while no strike or cast is running: purely visual, it stuns nothing.
func _on_damaged(_amount: float) -> void:
	if attack.is_attacking() or _is_busy():
		return
	_hit_playing = true
	humanoid.anim.speed_scale = 1.0
	humanoid.play(CLIP_HIT)
	_requested = CLIP_HIT
