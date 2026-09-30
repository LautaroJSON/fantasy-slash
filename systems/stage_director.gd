class_name StageDirector
extends Node
## Loads the stages of the run in order, opens the exit portal after the boss
## of every stage but the last, and swaps the stage behind the fade when the
## player crosses it (docs/specs/stages.md §2.5).

signal stage_started(data: StageData, index: int)
signal portal_opened

@export var sequence: StageSequence
## Holds the stage in play as its only child.
@export var stage_root: Node3D
@export var player: Player
@export var wave_manager: WaveManager
@export var run_state: RunState
@export var portal: Portal
@export var transition: StageTransition

var _index: int = -1
var _stage: StageMap
## Seconds until the portal starts opening (< 0 = none scheduled).
var _portal_delay_left: float = -1.0


func _ready() -> void:
	wave_manager.stage_cleared.connect(_on_stage_cleared)
	portal.entered.connect(_on_portal_entered)
	transition.covered.connect(_on_transition_covered)
	transition.finished.connect(_on_transition_finished)
	load_stage(0)
	# Deferred: the transition UI is readied after this node.
	_show_first_banner.call_deferred()


func _process(delta: float) -> void:
	advance(delta)


## Frees the stage in play, instances stage `index`, puts the player on its
## start and hands it to the WaveManager.
func load_stage(index: int) -> void:
	var data: StageData = sequence.get_stage(index)
	if data == null:
		push_error("StageDirector: no stage %d in the sequence." % index)
		return
	_free_current_stage()
	_index = index
	_stage = data.scene.instantiate() as StageMap
	_stage.setup(data)
	stage_root.add_child(_stage)
	_place_player()
	wave_manager.set_stage(_stage, sequence.is_last(index))
	stage_started.emit(data, index)


func get_stage() -> StageMap:
	return _stage


func get_stage_index() -> int:
	return _index


## Opens the portal of the stage in play at its PortalPoint.
func open_portal() -> void:
	_portal_delay_left = -1.0
	portal.open(_stage.get_data().portal, _stage.get_portal_transform())
	portal_opened.emit()


## Counts down the portal's opening delay (public so tests can step it).
func advance(delta: float) -> void:
	if _portal_delay_left < 0.0:
		return
	_portal_delay_left -= delta
	if _portal_delay_left <= 0.0:
		open_portal()


func _free_current_stage() -> void:
	if _stage == null:
		return
	stage_root.remove_child(_stage)
	_stage.queue_free()
	_stage = null


func _place_player() -> void:
	var start: Transform3D = _stage.get_player_start()
	player.global_position = start.origin
	player.velocity = Vector3.ZERO
	var camera: ThirdPersonCamera = player.get_camera()
	if camera != null:
		camera.rotate_camera(start.basis.get_euler().y - camera.get_yaw(), 0.0)


func _show_first_banner() -> void:
	var data: StageData = sequence.get_stage(0)
	transition.show_banner(_banner_title(0), data.display_name, data.subtitle)


func _banner_title(index: int) -> String:
	return transition.config.banner_title_format % (index + 1)


func _on_stage_cleared() -> void:
	_portal_delay_left = _stage.get_data().portal.open_delay


func _on_portal_entered() -> void:
	var next: StageData = sequence.get_stage(_index + 1)
	player.begin_hold(transition.get_cover_duration())
	transition.play(_banner_title(_index + 1), next.display_name, next.subtitle)


## Behind the fade: the next stage replaces this one and its waves count from 1.
func _on_transition_covered() -> void:
	portal.close()
	run_state.next_wave()
	run_state.set_stage(_index + 1)
	load_stage(_index + 1)


func _on_transition_finished() -> void:
	wave_manager.start_wave()
