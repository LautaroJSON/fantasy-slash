class_name Portal
extends Node3D
## Exit of a stage (docs/specs/stages.md §4). Hidden until opened; once its
## opening ends, the player within PortalData.enter_radius enters it (a
## distance check, no physics body). Its look is a PortalStyle scene.

signal entered

@export var player: Player

var _data: PortalData
var _style: PortalStyle
var _style_scene: PackedScene
## Seconds left of the opening (< 0 = not opening).
var _open_left: float = -1.0
var _enterable: bool = false


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	advance(delta)


## Shows the portal at `at` with the style of `data` and starts its opening.
func open(data: PortalData, at: Transform3D) -> void:
	_data = data
	global_transform = at
	_use_style(data.style_scene)
	visible = true
	_enterable = false
	_open_left = data.open_duration
	_style.play_open(data.open_duration)


func close() -> void:
	visible = false
	_enterable = false
	_open_left = -1.0


## Whether the player can enter it now (opened and not entered yet).
func is_enterable() -> bool:
	return _enterable


func get_style() -> PortalStyle:
	return _style


## Steps the opening and checks the player (public so tests can step it).
func advance(delta: float) -> void:
	if not visible:
		return
	_style.advance(delta)
	_advance_opening(delta)
	_check_player()


func _advance_opening(delta: float) -> void:
	if _open_left < 0.0:
		return
	_open_left -= delta
	if _open_left <= 0.0:
		_open_left = -1.0
		_enterable = true
		_style.play_idle()


func _check_player() -> void:
	if not _enterable or player == null:
		return
	var offset := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	if offset.length() <= _data.enter_radius:
		_enterable = false
		entered.emit()


func _use_style(scene: PackedScene) -> void:
	if _style != null and _style_scene == scene:
		return
	if _style != null:
		remove_child(_style)
		_style.queue_free()
	_style_scene = scene
	_style = scene.instantiate() as PortalStyle
	add_child(_style)
