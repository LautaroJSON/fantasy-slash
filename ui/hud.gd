class_name Hud
extends Control
## In-game HUD: player health, dash cooldown, current wave, ability slots, the
## boss health bars (top centre), the active buffs (above the health bar). The game mode is shown in the pause menu.
## The ability slots show the key or the gamepad button, after the last device used.

@export var player: Player
@export var run_state: RunState
## Source of boss waves; their bosses get a bar at the top centre.
@export var wave_manager: WaveManager
## Green, rounded look of the player health bar (bottom centre).
@export var health_bar_style: PlayerHealthBarStyle
## Dash label text and the format of the remaining seconds.
@export var config: HudConfig
## Key and button names of the ability slots.
@export var prompts: InputPromptConfig

## Step of the dash label on the last write (0 = ready text).
var _dash_step: int = -1

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _dash_bar: ProgressBar = %DashBar
@onready var _dash_label: Label = %DashLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _basic_slot: AbilitySlotView = %BasicSlot
@onready var _ultimate_slot: AbilitySlotView = %UltimateSlot
@onready var _boss_bars: BossBarStack = %BossBars
@onready var _buff_bar: BuffBar = %BuffBar
@onready var _device_monitor: InputDeviceMonitor = %InputDeviceMonitor


func _ready() -> void:
	_apply_health_bar_style()
	_basic_slot.setup(player.basic_ability)
	_ultimate_slot.setup(player.ultimate_ability)
	_buff_bar.setup(player.buffs)
	_device_monitor.device_changed.connect(_show_prompts)
	_show_prompts(_device_monitor.get_device())
	player.health.health_changed.connect(_on_health_changed)
	run_state.changed.connect(_on_run_changed)
	if wave_manager != null:
		wave_manager.boss_wave_started.connect(_boss_bars.show_bosses)
	_on_health_changed(player.health.current_health, player.health.max_health)
	_on_run_changed()


## Writes a float per frame and the dash text only when it changes (no allocations).
func _process(_delta: float) -> void:
	_update_dash_bar()


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [ceili(current), ceili(maximum)]


func _on_run_changed() -> void:
	if run_state.is_boss_wave():
		_wave_label.text = "Oleada %d · %s" % [run_state.wave, run_state.challenge_title]
	else:
		_wave_label.text = "Oleada %d" % run_state.wave
		_boss_bars.clear()


## Full bar = dash ready. During the cooldown the label shows the remaining
## seconds; it is written only when the shown step changes.
func _update_dash_bar() -> void:
	_dash_bar.value = 1.0 - player.dash.get_cooldown_ratio()
	var step: int = CooldownText.to_step(player.dash.get_cooldown_remaining(), config.cooldown_text)
	if step == _dash_step:
		return
	_dash_step = step
	_dash_label.text = config.dash_ready_text if step == 0 else CooldownText.text_for_step(step, config.cooldown_text)


func _show_prompts(device: InputDeviceMonitor.Device) -> void:
	for slot: AbilitySlotView in [_basic_slot, _ultimate_slot]:
		slot.set_prompt(prompts.get_prompt(slot.prompt_action, device))


## Builds the fill and background styles once (same approach as CardStyle).
func _apply_health_bar_style() -> void:
	_health_bar.add_theme_stylebox_override(&"fill", _rounded_box(health_bar_style.fill_color))
	_health_bar.add_theme_stylebox_override(&"background", _rounded_box(health_bar_style.background_color))


func _rounded_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(health_bar_style.corner_radius)
	return box
