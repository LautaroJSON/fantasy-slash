class_name BossHealthBar
extends VBoxContainer
## One boss health bar fixed in the HUD: title with name and level, health
## numbers, the same lost-health trail and shake as the floating 3D bars, and
## the boss's debuff icons. Pooled by BossBarStack: track() binds it to a boss,
## release() frees it (also when the boss dies).

var _config: BossBarConfig
var _enemy: Enemy = null
var _trail_state: HealthTrail = HealthTrail.new()
var _shake: ShakeState = ShakeState.new()
var _icons: Array[ColorRect] = []
var _time_labels: Array[Label] = []
var _clocks: Array[CooldownClock] = []
var _stack_labels: Array[Label] = []
## Step shown by each debuff time label (-1 = rewrite on the next update).
var _shown_steps: PackedInt32Array = PackedInt32Array()

@onready var _title: Label = $TitleLabel
@onready var _frame: Control = $BarFrame
## Moved sideways while shaking; not laid out by the container (child of the frame).
@onready var _bar: Control = $BarFrame/Bar
@onready var _background: ColorRect = $BarFrame/Bar/Background
@onready var _trail: ColorRect = $BarFrame/Bar/Trail
@onready var _fill: ColorRect = $BarFrame/Bar/Fill
@onready var _health_label: Label = $BarFrame/Bar/HealthLabel
@onready var _debuff_icons: HBoxContainer = $DebuffIcons


func _process(delta: float) -> void:
	advance(delta)


## Called once by the stack: sizes, colors and debuff icon slots.
func setup(config: BossBarConfig) -> void:
	_config = config
	_frame.custom_minimum_size = config.bar_size
	_bar.size = config.bar_size
	_background.size = config.bar_size
	_background.color = config.background_color
	_trail.color = config.trail_color
	_fill.color = config.fill_color
	_health_label.size = config.bar_size
	_debuff_icons.add_theme_constant_override(&"separation", config.debuff_spacing_px)
	_create_icons()
	release()


func track(enemy: Enemy) -> void:
	release()
	_enemy = enemy
	_enemy.health.health_changed.connect(_on_health_changed)
	_enemy.health.died.connect(release)
	_enemy.debuffs.changed.connect(_refresh_debuffs)
	_enemy.hit_notified.connect(_on_hit_notified)
	_title.text = _config.title_format % [enemy.stats.display_name, enemy.level]
	_trail_state.reset()
	_apply_ratios()
	_update_health_text(enemy.health.current_health, enemy.health.max_health)
	_refresh_debuffs()
	show()
	set_process(true)


func release() -> void:
	if _enemy != null:
		_enemy.health.health_changed.disconnect(_on_health_changed)
		_enemy.health.died.disconnect(release)
		_enemy.debuffs.changed.disconnect(_refresh_debuffs)
		_enemy.hit_notified.disconnect(_on_hit_notified)
		_enemy = null
	_shake.stop()
	_bar.position.x = 0.0
	hide()
	set_process(false)


## Trail, shake and debuff times; called by _process and by tests.
func advance(delta: float) -> void:
	if _trail_state.advance(delta, _config.health_bar_config):
		_apply_ratios()
	_update_debuff_times()
	if _shake.is_active():
		var bar_config: HealthBarConfig = _config.health_bar_config
		_bar.position.x = _config.shake_amplitude_px * _shake.advance(delta, bar_config.shake_frequency)


func get_tracked() -> Enemy:
	return _enemy


func get_fill_ratio() -> float:
	return _trail_state.fill_ratio


func get_trail_ratio() -> float:
	return _trail_state.trail_ratio


func is_shaking() -> bool:
	return _shake.is_active()


func get_bar_offset() -> float:
	return _bar.position.x


func get_title_text() -> String:
	return _title.text


func get_health_text() -> String:
	return _health_label.text


func get_visible_debuff_count() -> int:
	var count: int = 0
	for icon: ColorRect in _icons:
		if icon.visible:
			count += 1
	return count


func get_debuff_color(index: int) -> Color:
	return _icons[index].color


func get_debuff_time_text(index: int) -> String:
	return _time_labels[index].text


func get_debuff_stack_text(index: int) -> String:
	return _stack_labels[index].text


func get_debuff_clock(index: int) -> CooldownClock:
	return _clocks[index]


func _on_health_changed(current: float, maximum: float) -> void:
	_update_health_text(current, maximum)
	if _trail_state.on_health(current, maximum, _config.health_bar_config):
		_apply_ratios()


## Same rule as the floating bar (crit or ≥ heavy_hit_fraction of max health).
func _on_hit_notified(applied: float, is_crit: bool) -> void:
	var bar_config: HealthBarConfig = _config.health_bar_config
	if EnemyHealthBar.should_shake(applied, _enemy.health.max_health, is_crit, bar_config):
		_shake.start(bar_config.shake_duration)


func _update_health_text(current: float, maximum: float) -> void:
	_health_label.text = _config.health_format % [ceili(current), ceili(maximum)]


func _apply_ratios() -> void:
	_set_segment(_trail, _trail_state.trail_ratio)
	_set_segment(_fill, _trail_state.fill_ratio)


## Left-anchored segment covering `ratio` of the bar width.
func _set_segment(segment: ColorRect, ratio: float) -> void:
	segment.visible = ratio > 0.0
	segment.size = Vector2(_config.bar_size.x * ratio, _config.bar_size.y)


func _create_icons() -> void:
	_shown_steps.resize(_config.max_debuff_icons)
	for i: int in _config.max_debuff_icons:
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2.ONE * _config.debuff_icon_size_px
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		var label := Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		CooldownText.style_label(label, _config.debuff_time_font_size, _config.cooldown_text)
		var stack_label := Label.new()
		stack_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		CooldownText.style_label(stack_label, _config.debuff_stack_font_size, _config.cooldown_text)
		var clock: CooldownClock = CooldownClock.create(_config.clock, CooldownClock.Shape.SQUARE)
		icon.add_child(clock)
		icon.add_child(label)
		icon.add_child(stack_label)
		_debuff_icons.add_child(icon)
		_icons.append(icon)
		_time_labels.append(label)
		_clocks.append(clock)
		_stack_labels.append(stack_label)


## Icons take the color of each debuff's 3D icon material (Principle II).
func _refresh_debuffs() -> void:
	var active: Array[DebuffComponent.ActiveDebuff] = _enemy.debuffs.get_active()
	for i: int in _icons.size():
		var icon: ColorRect = _icons[i]
		icon.visible = i < active.size()
		_shown_steps[i] = -1
		if icon.visible:
			icon.color = active[i].data.icon_material.albedo_color
			_stack_labels[i].text = str(active[i].stacks) if active[i].data.get_stack_cap() > 1 else ""
	_update_debuff_times()


## Clock and time of each shown debuff; a text is written only when its step
## changes (strings come from a table).
func _update_debuff_times() -> void:
	if _enemy == null:
		return
	var active: Array[DebuffComponent.ActiveDebuff] = _enemy.debuffs.get_active()
	var shown: int = mini(active.size(), _icons.size())
	for i: int in shown:
		_clocks[i].set_fraction(DebuffComponent.get_remaining_ratio(active[i]))
		var step: int = CooldownText.to_step(DebuffComponent.get_remaining(active[i]), _config.cooldown_text)
		if step != _shown_steps[i]:
			_shown_steps[i] = step
			_time_labels[i].text = CooldownText.text_for_step(step, _config.cooldown_text)
