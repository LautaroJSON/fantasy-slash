class_name Hud
extends Control
## In-game HUD: player health, stamina (bottom left), current wave, the action
## buttons (dash, basic and ultimate ability; docs/specs/dash-button.md), the
## boss health bars (top centre), the active buffs (above the health bar), the
## common enemies' statuses over their health bars. The game mode is shown in the pause menu.
## The action buttons show the key or the gamepad button, after the last device used.

@export var player: Player
@export var run_state: RunState
## Source of boss waves; their bosses get a bar at the top centre.
@export var wave_manager: WaveManager
## Green, rounded look of the player health bar (bottom centre).
@export var health_bar_style: PlayerHealthBarStyle
## Yellow, thinner look of the stamina bar, bottom left (docs/specs/sprint-stamina.md).
@export var stamina_bar_style: PlayerHealthBarStyle
## Key and button names of the action buttons.
@export var prompts: InputPromptConfig
## Enemies whose statuses the overlay draws over their health bars
## (docs/specs/status-icons.md).
@export var enemy_registry: EnemyRegistry

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _wave_label: Label = %WaveLabel
@onready var _dash_slot: AbilitySlotView = %DashSlot
@onready var _basic_slot: AbilitySlotView = %BasicSlot
@onready var _ultimate_slot: AbilitySlotView = %UltimateSlot
@onready var _boss_bars: BossBarStack = %BossBars
@onready var _buff_bar: BuffBar = %BuffBar
@onready var _device_monitor: InputDeviceMonitor = %InputDeviceMonitor
@onready var _enemy_status_overlay: EnemyStatusOverlay = %EnemyStatusOverlay


func _ready() -> void:
	_apply_bar_style(_health_bar, health_bar_style)
	_apply_bar_style(_stamina_bar, stamina_bar_style)
	_dash_slot.setup_dash(player.dash)
	_basic_slot.setup(player.basic_ability)
	_ultimate_slot.setup(player.ultimate_ability)
	_buff_bar.setup(player.buffs)
	_enemy_status_overlay.registry = enemy_registry
	_device_monitor.device_changed.connect(_show_prompts)
	_show_prompts(_device_monitor.get_device())
	player.health.health_changed.connect(_on_health_changed)
	player.stamina.stamina_changed.connect(_on_stamina_changed)
	run_state.changed.connect(_on_run_changed)
	if wave_manager != null:
		wave_manager.boss_wave_started.connect(_boss_bars.show_bosses)
	_on_health_changed(player.health.current_health, player.health.max_health)
	_on_stamina_changed(player.stamina.get_current(), player.stamina.get_max())
	_on_run_changed()


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [ceili(current), ceili(maximum)]


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current


func _on_run_changed() -> void:
	if run_state.is_boss_wave():
		_wave_label.text = "Oleada %d · %s" % [run_state.wave, run_state.challenge_title]
	else:
		_wave_label.text = "Oleada %d" % run_state.wave
		_boss_bars.clear()


func _show_prompts(device: InputDeviceMonitor.Device) -> void:
	for slot: AbilitySlotView in [_dash_slot, _basic_slot, _ultimate_slot]:
		slot.set_prompt(prompts.get_prompt(slot.prompt_action, device))


## Builds the fill and background styles once (same approach as CardStyle).
func _apply_bar_style(bar: ProgressBar, style: PlayerHealthBarStyle) -> void:
	bar.add_theme_stylebox_override(&"fill", _rounded_box(style.fill_color, style.corner_radius))
	bar.add_theme_stylebox_override(&"background", _rounded_box(style.background_color, style.corner_radius))


func _rounded_box(color: Color, corner_radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(corner_radius)
	return box
