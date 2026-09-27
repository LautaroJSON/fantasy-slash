class_name WeaponTrail
extends MeshInstance3D
## White translucent ribbon that follows the weapon's blade (between the
## weapon's TrailBase and TrailTip markers) while it attacks: during the basic
## attack combo strikes, the weapon sweeps and while any ability is cast. Each
## sample fades out over `lifetime`. Procedural VFX mesh (Principle II, 3.1.0)
## rebuilt from a ring buffer allocated once (Principle V). Must be top_level
## with an identity transform: samples are stored in world space.

@export var sword_swing: SwordSwing
## Basic attack combo: the trail emits during each strike. Optional.
@export var attack: AttackComponent
@export var abilities: Array[AbilityComponent] = []
@export var config: WeaponTrailConfig
@export var material: StandardMaterial3D

var _immediate: ImmediateMesh = null
var _base: Node3D = null
var _tip: Node3D = null
var _emitting: bool = false
## Ring buffer: _head is the newest sample, _count how many are alive.
var _bases: PackedVector3Array = PackedVector3Array()
var _tips: PackedVector3Array = PackedVector3Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _head: int = -1
var _count: int = 0


func _ready() -> void:
	_create_buffers()
	_connect_sources()
	_hide_trail()


func _process(delta: float) -> void:
	advance(delta)


## Follows these blade markers from now on (the class weapon, once equipped).
func attach(base: Node3D, tip: Node3D) -> void:
	_base = base
	_tip = tip
	_clear_samples()


func advance(delta: float) -> void:
	_age_samples(delta)
	_drop_expired()
	if _emitting:
		_push_sample()
	_rebuild_mesh()
	if not _emitting and _count == 0:
		_hide_trail()


func is_emitting() -> bool:
	return _emitting


func get_sample_count() -> int:
	return _count


## `index` 0 is the newest sample.
func get_sample_tip(index: int) -> Vector3:
	return _tips[_ring_index(index)]


func get_sample_alpha(index: int) -> float:
	var age: float = _ages[_ring_index(index)]
	return config.head_alpha * maxf(1.0 - age / config.lifetime, 0.0)


func _create_buffers() -> void:
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bases.resize(config.max_samples)
	_tips.resize(config.max_samples)
	_ages.resize(config.max_samples)


func _connect_sources() -> void:
	sword_swing.swing_started.connect(_refresh_emitting)
	sword_swing.swing_ended.connect(_refresh_emitting)
	if attack != null:
		attack.step_started.connect(_refresh_emitting.unbind(1))
		attack.step_ended.connect(_refresh_emitting)
	for ability: AbilityComponent in abilities:
		ability.cast_started.connect(_refresh_emitting)
		ability.cast_released.connect(_refresh_emitting)


## Emits during a combo strike, while the weapon sweeps or any ability is being cast.
func _refresh_emitting() -> void:
	_emitting = _base != null and _is_weapon_attacking()
	if _emitting:
		show()
		set_process(true)


func _is_weapon_attacking() -> bool:
	if sword_swing.is_swinging() or (attack != null and attack.is_attacking()):
		return true
	for ability: AbilityComponent in abilities:
		if ability.is_casting():
			return true
	return false


func _age_samples(delta: float) -> void:
	for i: int in _count:
		_ages[_ring_index(i)] += delta


## The oldest samples are at the end of the ring: drop them while expired.
func _drop_expired() -> void:
	while _count > 0 and _ages[_ring_index(_count - 1)] >= config.lifetime:
		_count -= 1


func _push_sample() -> void:
	_head = (_head + 1) % config.max_samples
	_bases[_head] = _base.global_position
	_tips[_head] = _tip.global_position
	_ages[_head] = 0.0
	_count = mini(_count + 1, config.max_samples)


## Triangle strip from the newest sample to the oldest, fading with age.
func _rebuild_mesh() -> void:
	_immediate.clear_surfaces()
	if _count < 2:
		return
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for i: int in _count:
		var index: int = _ring_index(i)
		_immediate.surface_set_color(Color(1.0, 1.0, 1.0, get_sample_alpha(i)))
		_immediate.surface_add_vertex(_bases[index])
		_immediate.surface_add_vertex(_tips[index])
	_immediate.surface_end()


func _ring_index(index: int) -> int:
	return posmod(_head - index, config.max_samples)


func _clear_samples() -> void:
	_head = -1
	_count = 0
	if _immediate != null:
		_immediate.clear_surfaces()


func _hide_trail() -> void:
	_clear_samples()
	hide()
	set_process(false)
