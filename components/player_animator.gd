class_name PlayerAnimator
extends Node
## Maps the player's state to the humanoid's clips
## (docs/specs/humanoid-player-model.md). The locomotion state is decided by a
## pure function (next_locomotion); this node only turns states into clips and
## is the only one that plays clips on the humanoid.
## Priority each frame: a combo strike (its clip is requested by the
## AttackComponent through play_attack), then `hit`, then the dash (the class
## `dash` clip stretched to the dash, or `run`; docs/specs/dash-feel.md),
## then casts, charges, the air slash and holds (`idle`, or the clip the
## ability asks for, e.g. Sheathe's charge crouch), then locomotion. A one-shot
## clip an ability asked for (Sheathe's release) finishes after the cast while
## the body stays idle.

enum Locomotion {
	IDLE,
	RUN,
	RUN_STOP,
	JUMP_START,
	AIR,
	LAND,
	## The first step out of the guard (a profile without its clip goes straight
	## to RUN; docs/specs/samurai-run.md).
	RUN_START,
	## The sprint (docs/specs/sprint-stamina.md): its start, loop and stop. A
	## profile without these clips falls back to the walk ones.
	SPRINT_START,
	SPRINT,
	SPRINT_STOP,
}

## Clip of each Locomotion state, indexed by the enum.
const LOCOMOTION_CLIPS: Array[StringName] = [&"idle", &"run", &"run_stop", &"jump_start", &"jump_air", &"jump_land", &"run_start", &"sprint_start", &"sprint", &"sprint_stop"]
## Sprint states: leaving them depends on the movement input, not the speed.
const SPRINT_STATES: Array[Locomotion] = [Locomotion.SPRINT_START, Locomotion.SPRINT, Locomotion.SPRINT_STOP]
## State each optional state falls back to when the profile lacks its clip.
const CLIP_FALLBACKS: Dictionary[Locomotion, Locomotion] = {
	Locomotion.SPRINT_START: Locomotion.SPRINT,
	Locomotion.SPRINT: Locomotion.RUN,
	Locomotion.SPRINT_STOP: Locomotion.RUN_STOP,
	Locomotion.RUN_START: Locomotion.RUN,
}
const CLIP_HIT: StringName = &"hit"
## Dash clip of a profile without its own (the class clip comes from the DashComponent).
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
## True while the body still holds a strike's last pose (it blends out slowly).
var _in_strike_pose: bool = false
## One-shot clip an ability asked for (e.g. Sheathe's release): it keeps
## playing after the cast, as a free recovery, while the body stays idle
## (docs/specs/sheathe-release-animation.md §10). &"" = none.
var _tail_clip: StringName = &""
## True while the dash clip plays: the first locomotion after it picks the exit.
var _dash_playing: bool = false


func _ready() -> void:
	humanoid.anim.animation_finished.connect(_on_clip_finished)
	health.damaged.connect(_on_damaged)


func _physics_process(_delta: float) -> void:
	update()


## Pure: the next locomotion state. `rising` = moving up (a jump take-off);
## `clip_finished` = the clip of `current` has just finished; `sprinting` = the
## player sprints and `move_input` = there is movement input
## (docs/specs/sprint-stamina.md): out of a sprint, the input and not the
## speed says whether the body walks on or skids to a stop.
static func next_locomotion(current: Locomotion, on_floor: bool, horizontal_speed: float, rising: bool, clip_finished: bool, animation_config: PlayerAnimationConfig, sprinting: bool = false, move_input: bool = false) -> Locomotion:
	if not on_floor:
		return _next_in_air(current, rising, clip_finished)
	if current == Locomotion.JUMP_START or current == Locomotion.AIR:
		return Locomotion.SPRINT if sprinting else Locomotion.LAND
	if sprinting:
		return _next_sprinting(current, clip_finished)
	if current in SPRINT_STATES:
		return _next_out_of_sprint(current, clip_finished, move_input)
	if horizontal_speed > animation_config.run_speed_threshold:
		if current == Locomotion.IDLE:
			return Locomotion.RUN_START
		if current == Locomotion.RUN_START and not clip_finished:
			return Locomotion.RUN_START
		return Locomotion.RUN
	return _next_on_floor_still(current, clip_finished)


## Locomotion state an action leaves behind: no stop, take-off or landing clip.
## Sprinting after it (e.g. out of a dash) goes straight to the sprint loop.
static func settled_locomotion(on_floor: bool, horizontal_speed: float, animation_config: PlayerAnimationConfig, sprinting: bool = false) -> Locomotion:
	if not on_floor:
		return Locomotion.AIR
	if sprinting:
		return Locomotion.SPRINT
	if horizontal_speed > animation_config.run_speed_threshold:
		return Locomotion.RUN
	return Locomotion.IDLE


static func _next_in_air(current: Locomotion, rising: bool, clip_finished: bool) -> Locomotion:
	if current == Locomotion.JUMP_START:
		return Locomotion.AIR if clip_finished else Locomotion.JUMP_START
	if current == Locomotion.AIR:
		return Locomotion.AIR
	return Locomotion.JUMP_START if rising else Locomotion.AIR


static func _next_sprinting(current: Locomotion, clip_finished: bool) -> Locomotion:
	match current:
		Locomotion.SPRINT:
			return Locomotion.SPRINT
		Locomotion.SPRINT_START:
			return Locomotion.SPRINT if clip_finished else Locomotion.SPRINT_START
	return Locomotion.SPRINT_START


## Out of the sprint: walks on while there is input; otherwise skids to a stop
## (the body still slides, decelerating) and then idles.
static func _next_out_of_sprint(current: Locomotion, clip_finished: bool, move_input: bool) -> Locomotion:
	if move_input:
		return Locomotion.RUN
	if current == Locomotion.SPRINT_STOP:
		return Locomotion.IDLE if clip_finished else Locomotion.SPRINT_STOP
	return Locomotion.SPRINT_STOP


static func _next_on_floor_still(current: Locomotion, clip_finished: bool) -> Locomotion:
	match current:
		Locomotion.RUN_START:
			return Locomotion.IDLE
		Locomotion.RUN:
			return Locomotion.RUN_STOP
		Locomotion.RUN_STOP, Locomotion.LAND:
			return Locomotion.IDLE if clip_finished else current
	return Locomotion.IDLE


func update() -> void:
	if _is_action_owning_body():
		if not _is_busy():
			_tail_clip = &""  # a strike, a hit or the dash takes the body
		_locomotion = _with_available_clip(settled_locomotion(player.is_on_floor(), _horizontal_speed(), config, player.is_running()))
		_locomotion_clip_finished = false
		_dash_playing = dash.is_dashing()
		_play_action_clip()
		return
	if _dash_playing:
		_leave_dash()
		return
	var previous: Locomotion = _locomotion
	_advance_locomotion()
	if _is_playing_tail():
		return
	if _walks_out_of_sprint(previous):
		_request_blended(LOCOMOTION_CLIPS[_locomotion], config.sprint_exit_blend)
		return
	_request_locomotion(LOCOMOTION_CLIPS[_locomotion])


## Plays a combo strike clip at `speed` (the AttackComponent decides when).
func play_attack(clip: StringName, speed: float) -> void:
	_hit_playing = false
	humanoid.anim.speed_scale = speed
	humanoid.play(clip)
	_requested = clip
	_in_strike_pose = true


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
	if dash.is_dashing():
		_play_dash()
		return
	var clip: StringName = _busy_clip()
	_request(clip)
	if clip != CLIP_BUSY and humanoid.anim.get_animation(clip).loop_mode == Animation.LOOP_NONE:
		_tail_clip = clip
		_in_strike_pose = true  # cut by locomotion, it blends out slowly


## The ability's one-shot clip keeps playing after its cast while the body is
## idle; moving, jumping or any action cuts it.
func _is_playing_tail() -> bool:
	if _tail_clip == &"":
		return false
	if _requested != _tail_clip or _locomotion != Locomotion.IDLE:
		_tail_clip = &""
		return false
	return true


func _advance_locomotion() -> void:
	var on_floor: bool = player.is_on_floor()
	var rising: bool = player.velocity.y > 0.0
	var next: Locomotion = next_locomotion(_locomotion, on_floor, _horizontal_speed(), rising, _locomotion_clip_finished, config, player.is_running(), player.has_move_input())
	_locomotion = _with_available_clip(next)
	_locomotion_clip_finished = false


## An optional state (the walk start, the sprint's) whose clip the profile
## lacks falls back to the next one (e.g. a profile without sprint clips walks
## instead of sprinting).
func _with_available_clip(state: Locomotion) -> Locomotion:
	while CLIP_FALLBACKS.has(state) and not humanoid.anim.has_animation(LOCOMOTION_CLIPS[state]):
		state = CLIP_FALLBACKS[state]
	return state


## The sprint just ended while still moving: the walk blends in slower.
func _walks_out_of_sprint(previous: Locomotion) -> bool:
	if _locomotion != Locomotion.RUN:
		return false
	return previous == Locomotion.SPRINT or previous == Locomotion.SPRINT_START


func _horizontal_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


## Locomotion after a strike blends out of its last pose slowly (the strike
## ends in the pose the next one starts from, not in the guard).
func _request_locomotion(clip: StringName) -> void:
	if clip == _requested or not _in_strike_pose:
		_request(clip)
		return
	_request_blended(clip, config.attack_exit_blend)


func _request_blended(clip: StringName, blend: float) -> void:
	humanoid.anim.speed_scale = 1.0
	humanoid.play(clip, blend)
	_requested = clip
	_in_strike_pose = false


func _request(clip: StringName) -> void:
	if clip == _requested:
		return
	humanoid.anim.speed_scale = 1.0
	humanoid.play(clip)
	_requested = clip
	_in_strike_pose = false


## Chains the next clip at once, so a finished one-shot clip never freezes a frame.
func _on_clip_finished(clip: StringName) -> void:
	if clip == CLIP_HIT:
		_hit_playing = false
		_requested = &""
	elif clip == _tail_clip:
		_tail_clip = &""
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
	_in_strike_pose = false


## The clip an ability asks for while it charges or casts (e.g. Sheathe's
## crouch), if the active profile has it; idle otherwise.
func _busy_clip() -> StringName:
	var clip: StringName = player.get_body_clip()
	if clip != &"" and humanoid.anim.has_animation(clip):
		return clip
	return CLIP_BUSY


## The class dash clip, entered with dash_entry_blend and stretched to last
## exactly the dash; `run` when the profile has none.
func _play_dash() -> void:
	var clip: StringName = dash.get_clip()
	if clip == &"" or not humanoid.anim.has_animation(clip):
		_request(CLIP_DASH)
		return
	if clip == _requested:
		return
	humanoid.play(clip, config.dash_entry_blend)
	humanoid.anim.speed_scale = humanoid.anim.get_animation(clip).length / dash.get_duration()
	_requested = clip
	_in_strike_pose = false


## Out of a dash (docs/specs/dash-feel.md §2.3): the dash ends on the sprint's
## first frame, so a sprint goes on from frame 0 with no blend; with no input
## the body skids (sprint_stop); moving but winded, it walks.
func _leave_dash() -> void:
	_dash_playing = false
	_locomotion_clip_finished = false
	if not player.is_on_floor():
		_locomotion = Locomotion.AIR
	elif player.is_running():
		_locomotion = Locomotion.SPRINT
	elif player.has_move_input():
		_locomotion = Locomotion.RUN
	else:
		_locomotion = Locomotion.SPRINT_STOP
	_locomotion = _with_available_clip(_locomotion)
	var clip: StringName = LOCOMOTION_CLIPS[_locomotion]
	match _locomotion:
		Locomotion.SPRINT:
			_request_blended(clip, 0.0)
		Locomotion.RUN:
			_request_blended(clip, config.sprint_exit_blend)
		_:
			_request(clip)
