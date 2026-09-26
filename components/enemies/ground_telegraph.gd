class_name GroundTelegraph
extends Node3D
## Warning of an enemy attack on the floor (docs/specs/enemy-ground-telegraph.md):
## the whole hitbox zone, faint, with a stronger fill that grows from the
## origin of the blow to its edge over `duration`; it flashes when the blow
## lands (optionally with dust) and then fades out. Shapes: a circular sector
## (an ArrayMesh built once per arc by prepare_arcs), a line (unit BoxMesh) or
## a circle (unit CylinderMesh). Everything is created in _ready and only
## moved, scaled and shown afterwards (Principle V). Must be top_level.

enum Shape { NONE, SECTOR, LINE, CIRCLE }

@export var config: TelegraphConfig
@export var material: StandardMaterial3D
@export var dust_material: StandardMaterial3D

## Sector meshes by arc (whole degrees).
var _sectors: Dictionary = {}
var _circle_mesh: CylinderMesh = null
var _line_mesh: BoxMesh = null
var _base: MeshInstance3D = null
var _fill: MeshInstance3D = null
var _dust: CPUParticles3D = null
var _shape: Shape = Shape.NONE
var _origin: Vector3 = Vector3.ZERO
var _direction: Vector3 = Vector3.FORWARD
## Sector/circle: radius. Line: length.
var _size: float = 0.0
## Sector: arc in degrees.
var _arc: float = 0.0
## Line: width.
var _width: float = 0.0
var _elapsed: float = 0.0
var _duration: float = 0.0
var _flashing: bool = false
var _flash_elapsed: float = 0.0


func _ready() -> void:
	top_level = true
	_circle_mesh = CylinderMesh.new()
	_circle_mesh.top_radius = 1.0
	_circle_mesh.bottom_radius = 1.0
	_circle_mesh.height = config.thickness
	_circle_mesh.radial_segments = config.sector_segments
	_circle_mesh.rings = 1
	_line_mesh = BoxMesh.new()
	_line_mesh.size = Vector3(1.0, config.thickness, 1.0)
	_base = _make_instance(&"Base")
	_fill = _make_instance(&"Fill")
	_dust = _make_dust()
	clear()


func _physics_process(delta: float) -> void:
	advance(delta)


## Builds the sector meshes of these arcs (degrees) once; repeated arcs are skipped.
func prepare_arcs(arcs: Array[float]) -> void:
	for arc: float in arcs:
		var key: int = roundi(arc)
		if not _sectors.has(key):
			_sectors[key] = _build_sector(float(key))


func get_sector_count() -> int:
	return _sectors.size()


func show_sector(origin: Vector3, facing: Vector3, radius: float, arc_degrees: float, duration: float) -> void:
	var key: int = roundi(arc_degrees)
	if not _sectors.has(key):
		push_error("GroundTelegraph: arc %d was not prepared." % key)
		return
	var mesh: ArrayMesh = _sectors[key]
	_base.mesh = mesh
	_fill.mesh = mesh
	_arc = arc_degrees
	_begin(Shape.SECTOR, origin, facing, radius, 0.0, duration)


func show_line(origin: Vector3, direction: Vector3, length: float, width: float, duration: float) -> void:
	_base.mesh = _line_mesh
	_fill.mesh = _line_mesh
	_begin(Shape.LINE, origin, direction, length, width, duration)


func show_circle(center: Vector3, radius: float, duration: float) -> void:
	_base.mesh = _circle_mesh
	_fill.mesh = _circle_mesh
	_begin(Shape.CIRCLE, center, Vector3.FORWARD, radius, 0.0, duration)


## Moves and turns a sector or a line that is not locked yet.
func follow(origin: Vector3, direction: Vector3) -> void:
	_origin = origin
	if not Vector3(direction.x, 0.0, direction.z).is_zero_approx():
		_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_layout()


## Moves a circle that is not locked yet.
func move_center(center: Vector3) -> void:
	_origin = center
	_layout()


## The blow lands: full fill, bright, then a fade and it hides.
func flash(with_dust: bool) -> void:
	if _shape == Shape.NONE:
		return
	_flashing = true
	_flash_elapsed = 0.0
	_elapsed = _duration
	_layout()
	_fill.transparency = config.flash_transparency
	if with_dust:
		_dust.global_position = _dust_center()
		_dust.emission_sphere_radius = maxf(_size * config.dust_spread, 0.01)
		_dust.restart()


func clear() -> void:
	_shape = Shape.NONE
	_flashing = false
	_base.visible = false
	_fill.visible = false


func is_showing() -> bool:
	return _shape != Shape.NONE


func is_flashing() -> bool:
	return _flashing


func get_shape() -> Shape:
	return _shape


## Seconds the fill takes to reach the edge.
func get_duration() -> float:
	return _duration


func get_fill_ratio() -> float:
	if _duration <= 0.0:
		return 1.0
	return clampf(_elapsed / _duration, 0.0, 1.0)


## Sector/circle: radius. Line: length.
func get_size() -> float:
	return _size


## Line: width.
func get_width() -> float:
	return _width


## Sector/line: where the blow starts. Circle: its centre.
func get_origin() -> Vector3:
	return _origin


func get_arc() -> float:
	return _arc


func get_direction() -> Vector3:
	return _direction


func get_base() -> MeshInstance3D:
	return _base


func get_fill() -> MeshInstance3D:
	return _fill


func get_dust() -> CPUParticles3D:
	return _dust


func advance(delta: float) -> void:
	if _shape == Shape.NONE:
		return
	if not _flashing:
		_elapsed = minf(_elapsed + delta, _duration)
		_layout()
		return
	_flash_elapsed += delta
	var fade: float = clampf((_flash_elapsed - config.flash_time) / config.fade_time, 0.0, 1.0)
	_fill.transparency = lerpf(config.flash_transparency, 1.0, fade)
	_base.transparency = lerpf(config.base_transparency, 1.0, fade)
	if fade >= 1.0:
		clear()


func _begin(shape: Shape, origin: Vector3, direction: Vector3, size: float, width: float, duration: float) -> void:
	_shape = shape
	_size = size
	_width = width
	_duration = duration
	_elapsed = 0.0
	_flashing = false
	_base.transparency = config.base_transparency
	_fill.transparency = config.fill_transparency
	_base.visible = true
	_fill.visible = true
	follow(origin, direction)


## Places both meshes: the zone at full size, the fill at get_fill_ratio().
func _layout() -> void:
	if _shape == Shape.NONE:
		return
	var ratio: float = get_fill_ratio()
	var yaw := Basis(Vector3.UP, atan2(-_direction.x, -_direction.z))
	var ground: Vector3 = Vector3(_origin.x, _origin.y + config.ground_offset, _origin.z)
	var lift := Vector3.UP * config.fill_lift
	match _shape:
		Shape.SECTOR, Shape.CIRCLE:
			_base.global_transform = Transform3D(yaw * Basis.from_scale(Vector3(_size, 1.0, _size)), ground)
			var grown: float = maxf(_size * ratio, 0.001)
			_fill.global_transform = Transform3D(yaw * Basis.from_scale(Vector3(grown, 1.0, grown)), ground + lift)
		Shape.LINE:
			_base.global_transform = Transform3D(yaw * Basis.from_scale(Vector3(_width, 1.0, _size)), ground + _direction * _size * 0.5)
			var reach: float = maxf(_size * ratio, 0.001)
			_fill.global_transform = Transform3D(yaw * Basis.from_scale(Vector3(_width, 1.0, reach)), ground + lift + _direction * reach * 0.5)


func _dust_center() -> Vector3:
	if _shape == Shape.LINE:
		return _origin + _direction * _size * 0.5
	return _origin


func _make_instance(node_name: StringName) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _make_dust() -> CPUParticles3D:
	var puff := SphereMesh.new()
	puff.radius = config.dust_size * 0.5
	puff.height = config.dust_size
	puff.material = dust_material
	var particles := CPUParticles3D.new()
	particles.name = &"Dust"
	particles.mesh = puff
	particles.amount = config.dust_amount
	particles.lifetime = config.dust_lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.direction = Vector3.UP
	particles.spread = config.dust_cone_degrees
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = config.dust_rise_speed_min
	particles.initial_velocity_max = config.dust_rise_speed_max
	particles.local_coords = false
	add_child(particles)
	return particles


## Flat triangle fan: unit radius, `arc` degrees centred on −Z, in the XZ plane.
func _build_sector(arc: float) -> ArrayMesh:
	var segments: int = maxi(ceili(float(config.sector_segments) * arc / 360.0), 2)
	var half: float = deg_to_rad(arc) * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i: int in segments:
		var a0: float = -half + deg_to_rad(arc) * float(i) / float(segments)
		var a1: float = -half + deg_to_rad(arc) * float(i + 1) / float(segments)
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(sin(a1), 0.0, -cos(a1)))
		vertices.append(Vector3(sin(a0), 0.0, -cos(a0)))
		for n: int in 3:
			normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
