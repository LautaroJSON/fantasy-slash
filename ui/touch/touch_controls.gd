class_name TouchControls
extends Control
## On-screen touch controls: floating movement stick on the left half, camera
## drag on the right half and the action cluster (attack in the middle, jump,
## dash, basic ability and ultimate around it) plus a pause button.
## The only node that reads InputEventScreenTouch/Drag (Principle VI exception):
## it routes every finger by position and turns it into InputMap actions sent
## as InputEventAction, and into a camera look delta
## (docs/specs/mobile-touch-controls.md). Lays out inside its own rect, which
## the HUD keeps within the safe area.

const NO_FINGER: int = -1
const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_FORWARD: StringName = &"move_forward"
const ACTION_MOVE_BACK: StringName = &"move_back"

@export var config: TouchControlsConfig
@export var prompts: InputPromptConfig
## Turned by the camera drag; setup() takes the player's camera when unset.
@export var camera: ThirdPersonCamera
## Clock and cooldown text of the dash button (same look as the ability slots).
@export var slot_config: AbilitySlotViewConfig

var _player: Player = null
var _active: bool = false
var _was_paused: bool = false
var _look_finger: int = NO_FINGER
## Buttons from the smallest to the largest, so a small button next to a big
## one wins the touch.
var _buttons: Array[TouchActionButton] = []
## Last strength sent per movement action (only changes are sent).
var _sent_strengths: Dictionary[StringName, float] = {}

@onready var _stick: VirtualStick = %MoveStick
@onready var _attack: TouchActionButton = %AttackButton
@onready var _jump: TouchActionButton = %JumpButton
@onready var _dash: TouchActionButton = %DashButton
@onready var _basic: TouchActionButton = %BasicButton
@onready var _ultimate: TouchActionButton = %UltimateButton
@onready var _pause: TouchActionButton = %PauseButton
@onready var _basic_slot: AbilitySlotView = %BasicSlot
@onready var _ultimate_slot: AbilitySlotView = %UltimateSlot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(layout)
	layout()
	_collect_buttons()
	_apply_texts()
	set_active(false)


func _input(event: InputEvent) -> void:
	handle_event(event)


func _process(_delta: float) -> void:
	_follow_tree_pause()
	_update_dash_cooldown()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()


## Binds the dash clock and the two ability slots to the player.
func setup(player: Player) -> void:
	_player = player
	if camera == null:
		camera = player.get_camera()
	_basic_slot.setup(player.basic_ability, config.side_button_radius)
	_ultimate_slot.setup(player.ultimate_ability, config.side_button_radius)
	_dash.show_cooldown(slot_config.clock, slot_config.cooldown_text, slot_config.cooldown_font_size)


## Shown and taking touches only while the last input was touch. Turning it
## off releases every action it holds.
func set_active(active: bool) -> void:
	_active = active
	_refresh_visibility()
	if not active:
		release_all()


func is_active() -> bool:
	return _active


## Called by _input and by tests.
func handle_event(event: InputEvent) -> void:
	if not _active:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_touch_down(touch.index, touch.position)
		else:
			_on_touch_up(touch.index)
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		_on_drag(drag.index, drag.position, drag.relative)


## Releases every action this node pressed and frees every finger.
func release_all() -> void:
	for button: TouchActionButton in _buttons:
		if button.is_pressed():
			button.release()
			_send(button.action, false, 0.0)
	if _stick != null and _stick.is_held():
		_stick.end()
	_update_move()
	_look_finger = NO_FINGER


## Last vector sent as movement strengths.
func get_stick_vector() -> Vector2:
	return _stick.get_vector()


func get_look_finger() -> int:
	return _look_finger


func get_button(action: StringName) -> TouchActionButton:
	for button: TouchActionButton in _buttons:
		if button.action == action:
			return button
	return null


func get_stick() -> VirtualStick:
	return _stick


## Places the stick rest point, the cluster and the pause button from the
## corners of this control's rect.
func layout() -> void:
	if _stick == null:
		return
	_stick.set_rest_center(Vector2(0.0, size.y) + config.stick_rest_position)
	var attack_center: Vector2 = size + config.cluster_anchor
	for button: TouchActionButton in [_attack, _jump, _dash, _basic, _ultimate]:
		button.layout(attack_center + config.get_cluster_offset(button.action), config.get_cluster_radius(button.action))
	_pause.layout(Vector2(size.x, 0.0) + config.pause_anchor, config.pause_radius)


func _collect_buttons() -> void:
	_buttons.assign([_pause, _jump, _dash, _basic, _ultimate, _attack])
	_buttons.sort_custom(func(a: TouchActionButton, b: TouchActionButton) -> bool: return a.get_radius() < b.get_radius())


func _apply_texts() -> void:
	for button: TouchActionButton in _buttons:
		if not button.draws_slot:
			button.set_text(prompts.get_prompt(button.action, InputDeviceMonitor.Device.TOUCH))


## A new finger: a free button first, then the stick zone, then the camera.
## While the game is paused (menus) new fingers are ignored.
func _on_touch_down(finger: int, point: Vector2) -> void:
	if get_tree().paused:
		return
	var button: TouchActionButton = _button_at(point)
	if button != null:
		if not button.is_pressed():
			button.press(finger)
			_send(button.action, true, 1.0)
		return
	var local: Vector2 = point - get_global_rect().position
	if local.x < size.x * config.stick_zone_width_ratio:
		_begin_stick(finger, local)
	elif _look_finger == NO_FINGER:
		_look_finger = finger


## Releases always run, even while paused, so no action stays stuck.
func _on_touch_up(finger: int) -> void:
	for button: TouchActionButton in _buttons:
		if button.get_finger() == finger:
			button.release()
			_send(button.action, false, 0.0)
	if _stick.get_finger() == finger:
		_stick.end()
		_update_move()
	if _look_finger == finger:
		_look_finger = NO_FINGER


func _on_drag(finger: int, point: Vector2, relative: Vector2) -> void:
	if _stick.get_finger() == finger:
		_stick.drag(point - get_global_rect().position)
		_update_move()
	elif finger == _look_finger and camera != null:
		camera.apply_touch_look(relative)


func _begin_stick(finger: int, local: Vector2) -> void:
	if _stick.is_held():
		return
	_stick.begin(finger, local)
	_update_move()


func _button_at(point: Vector2) -> TouchActionButton:
	for button: TouchActionButton in _buttons:
		if button.contains_point(point, config.touch_slop):
			return button
	return null


func _update_move() -> void:
	var move: Vector2 = _stick.get_vector() if _stick != null else Vector2.ZERO
	_send_strength(ACTION_MOVE_RIGHT, maxf(move.x, 0.0))
	_send_strength(ACTION_MOVE_LEFT, maxf(-move.x, 0.0))
	_send_strength(ACTION_MOVE_BACK, maxf(move.y, 0.0))
	_send_strength(ACTION_MOVE_FORWARD, maxf(-move.y, 0.0))


func _send_strength(action: StringName, strength: float) -> void:
	if _sent_strengths.get(action, 0.0) == strength:
		return
	_sent_strengths[action] = strength
	_send(action, strength > 0.0, strength)


## Same path as a key: sets the action state and reaches event handlers.
func _send(action: StringName, pressed: bool, strength: float) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength
	Input.parse_input_event(event)


## Entering a pause releases everything and hides the controls behind menus.
func _follow_tree_pause() -> void:
	var paused: bool = get_tree().paused
	if paused == _was_paused:
		return
	_was_paused = paused
	if paused:
		release_all()
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = _active and not _was_paused


func _update_dash_cooldown() -> void:
	if _player == null or not visible:
		return
	_dash.set_cooldown(_player.dash.get_cooldown_ratio(), _player.dash.get_cooldown_remaining())
