@tool
class_name LowPolyHumanoid
extends Node3D
## Personaje low-poly estilo Rayman: torso, cabeza, manos y pies flotantes,
## construido 100% con nodos de Godot 4: sin Blender, sin esqueleto.
## Cada articulación es un Node3D; las animaciones se generan por código
## a partir de poses clave (ángulos en grados).
##
## Perfiles de animación (docs/specs/class-combat-identity.md): cada perfil
## (profiles/*.gd) arma una librería completa con su guardia, su locomoción y
## su combo. Todas las librerías se construyen una sola vez, en _ready;
## set_profile() solo elige cuál es la librería por defecto del AnimationPlayer,
## así que los nombres de clip no cambian entre perfiles.
##
## Uso:
##   $Humanoid.set_profile(&"samurai")
##   $Humanoid.play("run")
##   $Humanoid.play("attack_1")
##   $Humanoid.hit_window.connect(func(active): ...)   # la espada daña / deja de dañar
##
## Clips de cada perfil: idle, run, run_stop, jump_start, jump_air, jump_land,
##                       hit, attack_1 … attack_N

signal hit_window(active: bool)   ## La espada empieza / deja de hacer daño
signal combo_window_opened        ## Desde acá se puede encadenar el siguiente golpe
signal attack_finished            ## El ataque terminó (volver a idle/locomoción)

## Mano con objetivo (set_hand_target).
enum Hand { LEFT, RIGHT }

## Perfiles disponibles: id -> script (extends HumanoidProfile).
const PROFILES: Dictionary[StringName, Script] = {
	&"warrior": preload("res://assets/models/characters/low_poly_humanoid/profiles/warrior_profile.gd"),
	&"samurai": preload("res://assets/models/characters/low_poly_humanoid/profiles/samurai_profile.gd"),
	&"berserker": preload("res://assets/models/characters/low_poly_humanoid/profiles/berserker_profile.gd"),
}
## Clips que todo perfil tiene, además de su combo (attack_1 … attack_N).
const LOCOMOTION_CLIPS: Array[StringName] = [&"idle", &"run", &"run_stop", &"jump_start", &"jump_air", &"jump_land", &"hit"]

@export var body_color := Color(0.95, 0.95, 0.95)
@export var accent_color := Color(0.12, 0.12, 0.15)
@export var weapon_color := Color(0.72, 0.76, 0.82)
@export var has_sword := true
## Shared materials (Principle II). When set they replace the per-instance
## materials built from the colors above.
@export var body_material: Material
@export var accent_material: Material
@export var weapon_material: Material
## Creates the sword Area3D (hitbox). Games that compute hits otherwise turn it off.
@export var use_hitbox := true
## Perfil activo al cargar (una clave de PROFILES).
@export var profile: StringName = &"warrior"
## Cuánto sigue cada mano a su objetivo (set_hand_target), de 0 a 1: 0 = su
## animación, 1 = pegada al objetivo. Lo anima cada clip (pistas de make_clip).
@export_range(0.0, 1.0) var left_hand_grip_weight: float = 0.0
@export_range(0.0, 1.0) var right_hand_grip_weight: float = 0.0
## Teclas para probar: 1-6 locomoción, 7 hit, 8 siguiente golpe del combo,
## 9 vuelve al primer golpe, 0 siguiente perfil.
@export var demo_controls := false
## Reconstruir en el editor (tildalo si cambiás colores)
@export var rebuild := false:
	set(v):
		if v and is_inside_tree():
			_build(true)

const HIPS_REST := Vector3(0, 0.55, 0)
const LEG_SCALE := 0.49  ## las poses se escribieron para piernas más largas

var anim: AnimationPlayer
var hitbox: Area3D
var _j := {}  # nombre de articulación -> Node3D
## Librería de cada perfil, construida una sola vez por ejecución y compartida
## por todas las instancias (la estructura de articulaciones es siempre la misma).
static var _libraries: Dictionary[StringName, AnimationLibrary] = {}
## Cuántas veces se construyó la librería de cada perfil.
static var _build_counts: Dictionary[StringName, int] = {}
## Libraries built without the motion layer (motion_enabled = false), so an
## old and a new humanoid can live side by side (poc/samurai-motion).
static var _classic_libraries: Dictionary[StringName, AnimationLibrary] = {}
## Motion layer setup of each profile (null entry: the profile has none).
static var _motion_setups: Dictionary[StringName, HumanoidMotionSetup] = {}
## Procedural motion (arcs, springs, planted feet) on top of the clips, for
## the profiles that provide a HumanoidMotionSetup (poc/samurai-motion).
@export var motion_enabled: bool = true
var _motion: HumanoidMotion = null
var _foot_meshes: Array[MeshInstance3D] = []
## Malla visible de cada mano (Hand), su transform local de reposo y su objetivo.
var _hand_meshes: Array[MeshInstance3D] = [null, null]
## Visible body meshes (torso, head, hands, feet), for VFX copies (dash-feel.md).
var _body_meshes: Array[MeshInstance3D] = []
var _hand_rest: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _hand_targets: Array[Node3D] = [null, null]
var _demo_attack: int = 0


func _ready() -> void:
	_build()
	if not Engine.is_editor_hint():
		play("idle", 0.0)
		if demo_controls:
			anim.animation_finished.connect(func(_n: StringName) -> void: play("idle"))


## Reproduce una animación con mezcla suave. No reinicia un loop que ya está sonando.
func play(anim_name: StringName, blend := 0.12) -> void:
	if anim.current_animation == anim_name and anim.get_animation(anim_name).loop_mode != Animation.LOOP_NONE:
		return
	anim.play(anim_name, blend)
	if not String(anim_name).begins_with("attack"):
		_set_hitbox(false)


## Right wrist joint: holds the built-in sword, or an external weapon.
func get_right_hand() -> Node3D:
	return _j["wrist_r"]


## Articulación por nombre (p. ej. "torso", "neck", "wrist_l"), o null.
func get_joint(key: String) -> Node3D:
	return _j.get(key) as Node3D


## Objetivo de una mano (docs/specs/sheath-socket-hand-grip.md): la malla de
## esa mano se lleva hacia `target` según su peso de agarre, cada vez que el
## AnimationPlayer aplica la animación. Solo se mueve la malla visual: la
## muñeca (y lo que cuelga de ella) conserva su animación.
func set_hand_target(hand: Hand, target: Node3D) -> void:
	_hand_targets[hand] = target
	_apply_hand_targets()


func clear_hand_target(hand: Hand) -> void:
	_hand_targets[hand] = null
	_apply_hand_targets()


## Vuelve a llevar cada mano a su objetivo: llamalo si el objetivo se movió
## después de que el AnimationPlayer aplicó el cuadro (p. ej. el arma).
func refresh_hand_targets() -> void:
	_apply_hand_targets()


## Visible body meshes (torso, head, hands, feet), built once.
func get_body_meshes() -> Array[MeshInstance3D]:
	return _body_meshes


func get_hand_mesh(hand: Hand) -> MeshInstance3D:
	return _hand_meshes[hand]


## Cuelga `node` de la articulación `key` en `local_position` (metros) y
## `local_rotation` (radianes) relativos a ella, compensando la escala del
## humanoide: lo que cuelga mide lo mismo que fuera de él.
func attach_to_joint(key: String, node: Node3D, local_position: Vector3, local_rotation: Vector3) -> void:
	var joint: Node3D = _j[key]
	joint.add_child(node)
	var size: float = global_basis.get_scale().x
	node.transform = Transform3D(Basis.from_euler(local_rotation).scaled(Vector3.ONE / size), local_position / size)


## Elige la librería de un perfil ya construido y vuelve a idle. No crea animaciones.
func set_profile(id: StringName) -> void:
	if not _libs().has(id):
		push_error("LowPolyHumanoid: unknown animation profile '%s'" % id)
		return
	if anim.has_animation_library(&"") and anim.get_animation_library(&"") == _libs()[id]:
		profile = id
		return
	anim.stop()
	anim.remove_animation_library(&"")
	anim.add_animation_library(&"", _libs()[id])
	profile = id
	if _motion != null:
		_motion.setup = _motion_setups.get(id) as HumanoidMotionSetup
	if not Engine.is_editor_hint():
		play("idle", 0.0)


func get_profile() -> StringName:
	return profile


func has_profile(id: StringName) -> bool:
	return _libs().has(id)


func get_profile_library(id: StringName) -> AnimationLibrary:
	return _libs().get(id) as AnimationLibrary


## Veces que se construyó la librería del perfil `id` (1 salvo reconstrucciones en el editor).
func get_library_build_count(id: StringName) -> int:
	return _build_counts.get(id, 0)


## Cantidad de golpes del combo del perfil activo (attack_1 … attack_N).
func get_attack_count() -> int:
	var count: int = 0
	while anim.has_animation(StringName("attack_%d" % (count + 1))):
		count += 1
	return count


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not demo_controls:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_demo_key(event.keycode)


func _demo_key(keycode: Key) -> void:
	var i: int = keycode - KEY_1 if keycode != KEY_0 else 9
	if i >= 0 and i < LOCOMOTION_CLIPS.size():
		anim.play(LOCOMOTION_CLIPS[i], 0.1)  # reinicia aunque ya esté sonando
	elif i == 7:
		_demo_attack = _demo_attack % get_attack_count() + 1
		anim.play(StringName("attack_%d" % _demo_attack), 0.1)
	elif i == 8:
		_demo_attack = 1
		anim.play(&"attack_1", 0.1)
	elif i == 9:
		var ids: Array[StringName] = []
		for id: StringName in PROFILES:
			ids.append(id)
		set_profile(ids[(ids.find(profile) + 1) % ids.size()])
		_demo_attack = 0
		print("profile: ", profile)


# ---------------------------------------------------------------- CUERPO

## `rebuild_libraries`: vuelve a construir las librerías (botón del editor).
func _build(rebuild_libraries := false) -> void:
	for c in get_children():
		if c.name == &"Rig" or c.name == &"Anim":
			remove_child(c)
			c.free()
	_j.clear()
	_body_meshes.clear()
	_foot_meshes.clear()

	var body: Material = body_material if body_material else _mat(body_color)
	var dark: Material = accent_material if accent_material else _mat(accent_color)
	var metal: Material = weapon_material if weapon_material else _mat(weapon_color, 0.5)

	var rig := Node3D.new()
	rig.name = "Rig"
	add_child(rig)

	# Las articulaciones de brazos y piernas existen pero son INVISIBLES:
	# solo se ven torso, cabeza, manos y pies (estilo Rayman).
	var hips := _joint(rig, "hips", HIPS_REST)

	var torso := _joint(hips, "torso", Vector3(0, 0.05, 0))
	_body_meshes.append(_mesh(torso, _torso(), Vector3.ZERO, body))

	var neck := _joint(torso, "neck", Vector3(0, 0.4, 0))
	_body_meshes.append(_mesh(neck, _gem(0.2), Vector3(0, 0.21, 0), body))  # cabeza

	for side: int in [-1, 1]:
		var s := "r" if side == 1 else "l"
		var sh := _joint(torso, "shoulder_" + s, Vector3(0.2 * side, 0.28, 0))
		var el := _joint(sh, "elbow_" + s, Vector3(0, -0.17, 0))
		var wr := _joint(el, "wrist_" + s, Vector3(0, -0.15, 0))
		var hand_mesh := _mesh(wr, _gem(0.08), Vector3(0, -0.04, 0), body)  # mano flotante
		var hand_index: int = Hand.RIGHT if side == 1 else Hand.LEFT
		_hand_meshes[hand_index] = hand_mesh
		_body_meshes.append(hand_mesh)
		_hand_rest[hand_index] = hand_mesh.transform

		var hp := _joint(hips, "hip_" + s, Vector3(0.09 * side, -0.02, 0))
		var kn := _joint(hp, "knee_" + s, Vector3(0, -0.22, 0))
		var an := _joint(kn, "ankle_" + s, Vector3(0, -0.2, 0))
		var foot_mesh := _mesh(an, _foot(), Vector3.ZERO, body)  # pie flotante
		_body_meshes.append(foot_mesh)
		_foot_meshes.append(foot_mesh)

	# Espada en la mano derecha (la hoja apunta hacia -Z = adelante con el brazo colgando)
	var hand: Node3D = _j["wrist_r"]
	if has_sword:
		_box(hand, Vector3(0.025, 0.055, 0.6), Vector3(0, -0.04, -0.4), metal)  # hoja
		_box(hand, Vector3(0.05, 0.17, 0.035), Vector3(0, -0.04, -0.09), dark)  # guarda
		_box(hand, Vector3(0.045, 0.045, 0.045), Vector3(0, -0.04, 0.09), dark) # pomo

	hitbox = null
	if use_hitbox:
		hitbox = Area3D.new()
		hitbox.name = "SwordHitbox"
		hitbox.monitoring = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.1, 0.12, 0.7)
		shape.shape = box
		shape.position = Vector3(0, -0.04, -0.4)
		hitbox.add_child(shape)
		hand.add_child(hitbox)

	anim = AnimationPlayer.new()
	anim.name = "Anim"
	add_child(anim)
	anim.mixer_applied.connect(_on_mixer_applied)
	_build_libraries(rebuild_libraries)
	if not _libs().has(profile):
		profile = &"warrior"
	anim.add_animation_library(&"", _libs()[profile])
	if motion_enabled and not Engine.is_editor_hint():
		_motion = HumanoidMotion.new(self, _foot_meshes)
		_motion.setup = _motion_setups.get(profile) as HumanoidMotionSetup


## Construye la librería de cada perfil que todavía no existe (o todas, con `force`).
func _build_libraries(force: bool) -> void:
	for id: StringName in PROFILES:
		if _libs().has(id) and not force:
			continue
		var builder: HumanoidProfile = PROFILES[id].new() as HumanoidProfile
		_libs()[id] = builder.build(self)
		_build_counts[id] = _build_counts.get(id, 0) + 1
		if motion_enabled:
			_motion_setups[id] = builder.build_motion()


func _libs() -> Dictionary[StringName, AnimationLibrary]:
	return _libraries if motion_enabled else _classic_libraries


func _on_mixer_applied() -> void:
	if _motion != null:
		_motion.apply(get_process_delta_time())
	_apply_hand_targets()


## Blade and edge directions and grip offset of the held weapon, in the right
## wrist's frame (WeaponMount.setup): the grip arcs orient the blade with it.
func set_weapon_frame(blade: Vector3, edge: Vector3, grip_origin: Vector3) -> void:
	if _motion != null:
		_motion.set_weapon_frame(blade, edge, grip_origin)


func _joint(parent: Node3D, key: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = key.to_pascal_case()
	n.position = pos
	parent.add_child(n)
	_j[key] = n
	return n


func _box(parent: Node3D, size: Vector3, offset: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	m.mesh = mesh
	m.position = offset
	parent.add_child(m)
	return m


func _mesh(parent: Node3D, mesh: Mesh, offset: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = offset
	parent.add_child(m)
	return m


# ---------------------------------------------------------------- MALLAS LOW-POLY
# Todas con normales planas (caras facetadas), generadas por código.

## Cabeza / manos: un cubo subdividido una vez (24 caras), igual que en Blender
## "cubo + Subdivision Surface nivel 1". De frente se ve un octógono con una cruz
## al centro y un anillo de caras alrededor. r = radio (un poco más alta que ancha).
func _gem(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k := [1.0, 0.78, 0.6]  # centro de cara / arista / esquina (más "cuadrado" que una esfera)
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for ai in 3:
		var ea: Vector3 = axes[ai]
		var eu: Vector3 = axes[(ai + 1) % 3]
		var ev: Vector3 = axes[(ai + 2) % 3]
		for sgn: float in [-1.0, 1.0]:
			var grid := {}
			for i: int in [-1, 0, 1]:
				for j: int in [-1, 0, 1]:
					grid[Vector2i(i, j)] = (ea * sgn + eu * i + ev * j) * k[abs(i) + abs(j)] * r * Vector3(1, 1.08, 1)
			for i: int in [-1, 0]:
				for j: int in [-1, 0]:
					_quad(st, grid[Vector2i(i, j)], grid[Vector2i(i + 1, j)],
							grid[Vector2i(i + 1, j + 1)], grid[Vector2i(i, j + 1)], Vector3.ZERO, true)
	return st.commit()


## Torso como la referencia: arriba redondeado, se ensancha un poco hacia la cadera
## y abajo se cierra en "V" (donde antes nacían las piernas). Sección de 12 lados.
func _torso() -> ArrayMesh:
	var w := 0.11   # medio ancho en los hombros
	var dz := 0.08  # media profundidad
	var y0 := -0.16
	var h := 0.52
	var sec := [  # media sección (x, z) de adelante (-z) hacia atrás, normalizada
		Vector2(0, -1), Vector2(0.42, -0.92), Vector2(0.92, -0.5), Vector2(1, 0),
		Vector2(0.92, 0.5), Vector2(0.42, 0.92), Vector2(0, 1),
	]
	var full := sec.duplicate()
	for i in range(sec.size() - 2, 0, -1):
		full.append(Vector2(-sec[i].x, sec[i].y))
	var rings := [  # [altura 0..1, escala x, escala z]
		[0.0, 0.29, 0.55],
		[0.16, 1.19, 0.95],
		[0.31, 1.15, 1.0],
		[0.775, 1.0, 0.95],
		[0.92, 0.9, 0.86],
		[1.0, 0.68, 0.66],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for r: Array in rings:
		var ring := []
		for q: Vector2 in full:
			ring.append(Vector3(q.x * w * r[1], y0 + r[0] * h, q.y * dz * r[2]))
		pts.append(ring)
	var n := full.size()
	for k in rings.size() - 1:
		var inside := Vector3(0, y0 + (rings[k][0] + rings[k + 1][0]) * 0.5 * h, 0)
		for i in n:
			var j := (i + 1) % n
			_quad(st, pts[k][i], pts[k][j], pts[k + 1][j], pts[k + 1][i], inside, true)
	var bot := Vector3(0, y0, 0)
	var top := Vector3(0, y0 + h + 0.012, 0)  # tapa apenas abombada
	for i in n:
		var j := (i + 1) % n
		_tri(st, bot, pts[0][i], pts[0][j], bot + Vector3.UP)
		_tri(st, top, pts[-1][i], pts[-1][j], top + Vector3.DOWN)
	return st.commit()


## Une anillos octogonales [y, medio_ancho, media_profundidad] y tapa los extremos.
func _loft(rings: Array, sides := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for r: Array in rings:
		var ring := []
		for i in sides:
			var a := -PI / 2 + TAU * i / sides  # un vértice mira al frente: línea central visible
			ring.append(Vector3(cos(a) * r[1], r[0], sin(a) * r[2]))
		pts.append(ring)
	for k in rings.size() - 1:
		var inside := Vector3(0, (rings[k][0] + rings[k + 1][0]) * 0.5, 0)
		for i in sides:
			var j := (i + 1) % sides
			_quad(st, pts[k][i], pts[k][j], pts[k + 1][j], pts[k + 1][i], inside)
	var bot := Vector3(0, rings[0][0], 0)
	var top := Vector3(0, rings[-1][0], 0)
	for i in sides:
		var j := (i + 1) % sides
		_tri(st, bot, pts[0][i], pts[0][j], bot + Vector3.UP)
		_tri(st, top, pts[-1][i], pts[-1][j], top + Vector3.DOWN)
	return st.commit()


## Pie: perfil lateral de bota (talón recto, empeine inclinado) extruido a lo ancho.
func _foot() -> ArrayMesh:
	var prof := [  # (z, y) relativo al tobillo; -Z = punta
		Vector2(0.06, -0.12), Vector2(-0.13, -0.12), Vector2(-0.14, -0.07),
		Vector2(-0.07, -0.02), Vector2(-0.02, 0.0), Vector2(0.06, 0.0),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var l := []
	var r := []
	for p: Vector2 in prof:
		var w: float = lerp(0.065, 0.05, (p.y + 0.12) / 0.12)  # más angosto arriba
		l.append(Vector3(-w, p.y, p.x))
		r.append(Vector3(w, p.y, p.x))
	var c := Vector3(0, -0.07, -0.03)
	for i in prof.size():
		var j := (i + 1) % prof.size()
		_quad(st, l[i], l[j], r[j], r[i], c)
	for i in range(1, prof.size() - 1):
		_tri(st, l[0], l[i], l[i + 1], c)
		_tri(st, r[0], r[i], r[i + 1], c)
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, one_face := false) -> void:
	var n := Vector3.ZERO
	if one_face:  # misma normal para los dos triángulos: se ve como una sola cara
		n = (c - a).cross(d - b)
	_tri(st, a, b, c, inside, n)
	_tri(st, a, c, d, inside, n)


## Triángulo con normal plana hacia afuera (se orienta solo usando un punto interior).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, normal := Vector3.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var out := (a + b + c) / 3.0 - inside
	if n.dot(out) < 0:  # que el orden quede antihorario visto desde afuera
		var t := b
		b = c
		c = t
		n = -n
	if normal != Vector3.ZERO:
		n = normal if normal.dot(out) > 0 else -normal
	n = n.normalized()
	# Godot considera "frente" al orden horario visto desde afuera
	for v: Vector3 in [a, c, b]:
		st.set_normal(n)
		st.add_vertex(v)


func _mat(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	m.metallic = metallic
	return m



# ---------------------------------------------------------------- KIT DE POSES
# Lo usan los perfiles (profiles/*.gd) para escribir sus poses clave.
# Convención de ángulos (grados):
#   hombro/cadera  X+ = hacia adelante     codo X+ = dobla hacia adelante
#   rodilla        X- = dobla hacia atrás  torso X- = se inclina hacia adelante
#   torso/hombro   Y+ = gira a su izquierda
#   hombro         Z+ = abre el brazo derecho hacia afuera (Z- para el izquierdo)
#   muñeca         X  = inclina el arma: con hombro + codo + muñeca en X = 0 la
#                       hoja apunta adelante, +90 arriba y -90 abajo
#   "hips_pos"     desplazamiento de la cadera en metros
#   "left_grip" / "right_grip"  peso de agarre de cada mano (0 a 1, ver
#                  set_hand_target); si falta, sigue el de la pose anterior

## Pose base: de pie, relajado, con `over` encima.
func pose(over := {}) -> Dictionary:
	var p := {
		"shoulder_l": Vector3(0, 0, -8), "shoulder_r": Vector3(0, 0, 8),
		"elbow_l": Vector3(10, 0, 0), "elbow_r": Vector3(10, 0, 0),
	}
	p.merge(over, true)
	return p


## Copia de `base` con `over` encima (para variar una pose de guardia).
func with(base: Dictionary, over := {}) -> Dictionary:
	var p := base.duplicate()
	p.merge(over, true)
	return p


## Agachado, con los brazos hacia atrás (antes de saltar y al aterrizar).
func crouch(over := {}) -> Dictionary:
	return pose(with({
		"hips_pos": Vector3(0, -0.2, 0),
		"torso": Vector3(-25, 0, 0), "neck": Vector3(20, 0, 0),
		"hip_l": Vector3(45, 0, -5), "knee_l": Vector3(-80, 0, 0), "ankle_l": Vector3(35, 0, 0),
		"hip_r": Vector3(45, 0, 5), "knee_r": Vector3(-80, 0, 0), "ankle_r": Vector3(35, 0, 0),
		"shoulder_l": Vector3(-45, 0, -10), "elbow_l": Vector3(20, 0, 0),
		"shoulder_r": Vector3(-45, 0, 10), "elbow_r": Vector3(20, 0, 0),
	}, over))


## Z de un hombro o cadera: `deg` hacia afuera para ese lado.
func side_z(s: String, deg: float) -> float:
	return deg if s == "r" else -deg


## Arma un clip desde poses clave.
## keys: [[tiempo, pose], ...]   events: [[tiempo, "hit_on"|"hit_off"|"combo"|"end"], ...]
## El último tiempo de `keys` es el largo del clip.
## `overlap` (poc/samurai-motion, only with motion_enabled): joint -> seconds
## of delay. When given, every joint is baked at BAKE_FPS with a monotone cubic
## through its keys (smooth, no overshoot, no linear kinks) and sampled that
## many seconds late, so the chain breaks in succession (hips first).
## `arcs` (poc/samurai-motion, needs `overlap`): SlashArcs of the grip; the
## right arm is then baked by two-bone IK so the clip itself carries the cut
## (any blend of the engine, like a dash cancel, starts from the true arm).
func make_clip(keys: Array, loop := false, smooth := false, events := [], overlap: Dictionary = {}, arcs: Array = []) -> Animation:
	var a := Animation.new()
	a.length = keys[-1][0]
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var interp := Animation.INTERPOLATION_CUBIC if smooth else Animation.INTERPOLATION_LINEAR
	var bake: bool = motion_enabled and not overlap.is_empty()
	var joint_tracks: Dictionary[String, int] = {}

	for joint: String in _j.keys():
		var t := a.add_track(Animation.TYPE_VALUE)
		joint_tracks[joint] = t
		a.track_set_path(t, NodePath(String(get_path_to(_j[joint])) + ":rotation"))
		a.track_set_interpolation_type(t, interp)
		if bake:
			_bake_track(a, t, keys, joint, Vector3.ZERO, PI / 180.0, Vector3.ZERO, overlap.get(joint, 0.0))
			continue
		for k: Array in keys:
			var deg: Vector3 = k[1].get(joint, Vector3.ZERO)
			a.track_insert_key(t, k[0], deg * (PI / 180.0))

	var tp := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tp, NodePath(String(get_path_to(_j["hips"])) + ":position"))
	a.track_set_interpolation_type(tp, interp)
	if bake:
		_bake_track(a, tp, keys, "hips_pos", Vector3.ZERO, LEG_SCALE, HIPS_REST, overlap.get("hips", 0.0))
		if not arcs.is_empty():
			_bake_arm(a, joint_tracks, tp, arcs)
	else:
		for k: Array in keys:
			a.track_insert_key(tp, k[0], HIPS_REST + k[1].get("hips_pos", Vector3.ZERO) * LEG_SCALE)

	for side: String in ["left", "right"]:
		var tw := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tw, NodePath(".:%s_hand_grip_weight" % side))
		a.track_set_interpolation_type(tw, interp)
		var weight: float = 0.0
		for k: Array in keys:
			weight = k[1].get(side + "_grip", weight)
			a.track_insert_key(tw, k[0], weight)

	if not events.is_empty():
		var tm := a.add_track(Animation.TYPE_METHOD)
		a.track_set_path(tm, NodePath("."))
		for e: Array in events:
			a.track_insert_key(tm, e[0], {"method": "_anim_event", "args": [e[1]]})
	return a


const BAKE_FPS: float = 60.0


## Dense keys for `key` of every pose: value = base + pose[key] * factor,
## each component through a monotone cubic, sampled `delay` seconds late.
func _bake_track(a: Animation, track: int, keys: Array, key: String, fallback: Vector3, factor: float, base: Vector3, delay: float) -> void:
	var curves: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	for k: Array in keys:
		var v: Vector3 = k[1].get(key, fallback)
		for c: int in 3:
			curves[c].append(Vector2(k[0], v[c]))
	var frames: int = maxi(ceili(a.length * BAKE_FPS), 1)
	for f: int in frames + 1:
		var time: float = minf(f / BAKE_FPS, a.length)
		var sample_time: float = clampf(time - delay, 0.0, a.length)
		var v := Vector3(
			SlashArc.monotone_cubic(curves[0], sample_time),
			SlashArc.monotone_cubic(curves[1], sample_time),
			SlashArc.monotone_cubic(curves[2], sample_time))
		a.track_insert_key(track, time, base + v * factor)


## Where the right elbow points while the arm is solved (right, down, back).
const ARM_POLE := Vector3(0.7, -0.35, 0.6)
## Seconds one arc hands its orientation over to the next inside a clip.
const ARC_BLEND: float = 0.05
## Seconds back in time to measure the blade's angular speed (tip whip).
const LAG_PROBE: float = 0.008
## Blade and edge directions and grip offset of the weapon in the right
## wrist's frame, for baking arcs (set by the profile before building).
var bake_blade: Vector3 = Vector3.FORWARD
var bake_edge: Vector3 = Vector3.RIGHT
var bake_grip: Vector3 = Vector3.ZERO


## Rewrites the right arm keys of an already baked clip so the grip rides
## `arcs`: per key, the body's torso and right shoulder (from the clip's own
## keys), the grip pose on the arc (blended with the authored arm by the arc
## weight), then a two-bone IK solve with the elbow toward ARM_POLE.
func _bake_arm(a: Animation, tracks: Dictionary[String, int], hips_track: int, arcs: Array) -> void:
	var size: float = scale.x if scale.x > 0.0 else 1.0
	var weapon: Basis = HumanoidMotion._frame(bake_blade, bake_edge)
	var arm: Array[String] = ["shoulder_r", "elbow_r", "wrist_r"]
	var previous: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for k: int in a.track_get_key_count(tracks["shoulder_r"]):
		var t: float = a.track_get_key_time(tracks["shoulder_r"], k)
		var hips := Transform3D(Basis.from_euler(a.track_get_key_value(tracks["hips"], k)), a.track_get_key_value(hips_track, k))
		var torso: Transform3D = hips * Transform3D(Basis.from_euler(a.track_get_key_value(tracks["torso"], k)), _j["torso"].position)
		var shoulder_pos: Vector3 = torso * (_j["shoulder_r"] as Node3D).position
		var authored: Transform3D = torso
		for key: String in arm:
			authored = authored * Transform3D(Basis.from_euler(a.track_get_key_value(tracks[key], k)), (_j[key] as Node3D).position)
		var target: Transform3D = _arc_target(arcs, t, shoulder_pos, size, weapon, authored)
		var solved: Array[Basis] = _solve_arm(torso.basis, shoulder_pos, target)
		for i: int in 3:
			var euler: Vector3 = solved[i].get_euler()
			if k > 0:
				euler = _unwrap_euler(euler, previous[i])
			previous[i] = euler
			a.track_set_key_value(tracks[arm[i]], k, euler)


func _arc_target(arcs: Array, t: float, shoulder_pos: Vector3, size: float, weapon: Basis, authored: Transform3D) -> Transform3D:
	var index: int = HumanoidMotion._active_arc(arcs, t)
	var arc: SlashArc = arcs[index]
	var pose: Transform3D = _arc_pose_at(arc, t, shoulder_pos, size, weapon)
	if index > 0 and t - arc.start_time() < ARC_BLEND:
		var before: Transform3D = _arc_pose_at(arcs[index - 1], t, shoulder_pos, size, weapon)
		pose = before.interpolate_with(pose, smoothstep(0.0, 1.0, (t - arc.start_time()) / ARC_BLEND))
	return authored.interpolate_with(pose, arc.weight_at(t))


## Wrist pose (humanoid space) that puts the grip on `arc` at `t`. Arc
## offsets and radii are in metres; the humanoid's space is `size` times smaller.
func _arc_pose_at(arc: SlashArc, t: float, shoulder_pos: Vector3, size: float, weapon: Basis) -> Transform3D:
	var center: Vector3 = shoulder_pos + arc.center_offset / size
	var f: float = arc.progress_at(t)
	var dir: Vector3 = arc.direction_at(f)
	var rate: float = (f - arc.progress_at(t - LAG_PROBE)) / LAG_PROBE * arc.angle_rate_at(f)
	var lag: float = clampf(rate * arc.tip_lag, -arc.max_lag, arc.max_lag)
	var blade: Vector3 = dir.rotated(arc.axis, -lag)
	var edge: Vector3 = arc.axis.cross(blade) * (-1.0 if arc.edge_flip else 1.0)
	var basis: Basis = HumanoidMotion._frame(blade, edge) * weapon.inverse()
	var grip: Vector3 = center + dir * arc.radius_at(t) / size
	return Transform3D(basis, grip - basis * bake_grip)


## Local rotations of shoulder, elbow and wrist that bring the wrist to
## `target` (clamped to the arm's reach) with its orientation.
func _solve_arm(torso_basis: Basis, shoulder_pos: Vector3, target: Transform3D) -> Array[Basis]:
	var upper_len: float = (_j["elbow_r"] as Node3D).position.length()
	var fore_len: float = (_j["wrist_r"] as Node3D).position.length()
	var to: Vector3 = target.origin - shoulder_pos
	var reach: float = clampf(to.length(), absf(upper_len - fore_len) + 0.001, upper_len + fore_len - 0.001)
	var dir: Vector3 = to.normalized()
	var pole: Vector3 = (ARM_POLE - dir * dir.dot(ARM_POLE)).normalized()
	var cos_a: float = (upper_len * upper_len + reach * reach - fore_len * fore_len) / (2.0 * upper_len * reach)
	var elbow: Vector3 = shoulder_pos + upper_len * (dir * cos_a + pole * sqrt(maxf(0.0, 1.0 - cos_a * cos_a)))
	var wrist: Vector3 = shoulder_pos + dir * reach
	var upper: Basis = _bone_basis(elbow - shoulder_pos, pole)
	var fore: Basis = _bone_basis(wrist - elbow, pole)
	return [torso_basis.orthonormalized().inverse() * upper, upper.inverse() * fore, fore.inverse() * target.basis.orthonormalized()]


## A bone basis whose -Y runs along `along` (the rest direction of the arm).
static func _bone_basis(along: Vector3, pole: Vector3) -> Basis:
	var y: Vector3 = -along.normalized()
	var z: Vector3 = (pole - y * y.dot(pole)).normalized()
	return Basis(y.cross(z), y, z)


## The YXZ Euler angles of the same rotation closest to `previous` (the two
## equivalent triples, each wrapped by whole turns), so baked keys never spin.
static func _unwrap_euler(euler: Vector3, previous: Vector3) -> Vector3:
	var near := _nearest_turns(euler, previous)
	var other := _nearest_turns(Vector3(PI - euler.x, euler.y + PI, euler.z + PI), previous)
	return near if near.distance_to(previous) <= other.distance_to(previous) else other


static func _nearest_turns(v: Vector3, reference: Vector3) -> Vector3:
	return Vector3(
		v.x + TAU * roundf((reference.x - v.x) / TAU),
		v.y + TAU * roundf((reference.y - v.y) / TAU),
		v.z + TAU * roundf((reference.z - v.z) / TAU))


## Eventos de un golpe: el daño empieza y termina, se abre el combo y termina.
func strike_events(hit_on: float, hit_off: float, combo: float, end: float) -> Array:
	return [[hit_on, "hit_on"], [hit_off, "hit_off"], [combo, "combo"], [end, "end"]]


func _anim_event(ev: String) -> void:
	match ev:
		"hit_on":
			_set_hitbox(true)
			hit_window.emit(true)
		"hit_off":
			_set_hitbox(false)
			hit_window.emit(false)
		"combo":
			combo_window_opened.emit()
		"end":
			attack_finished.emit()


## Lleva la malla de cada mano hacia su objetivo según su peso (se llama con
## AnimationMixer.mixer_applied: después de aplicar las pistas del cuadro).
func _apply_hand_targets() -> void:
	_apply_hand(Hand.LEFT, left_hand_grip_weight)
	_apply_hand(Hand.RIGHT, right_hand_grip_weight)


func _apply_hand(hand: Hand, weight: float) -> void:
	var mesh: MeshInstance3D = _hand_meshes[hand]
	if mesh == null:
		return
	mesh.transform = _hand_rest[hand]
	var target: Node3D = _hand_targets[hand]
	if target == null or weight <= 0.0 or not target.is_inside_tree() or not mesh.is_inside_tree():
		return
	var animated: Transform3D = mesh.global_transform
	var goal := Transform3D(target.global_basis.orthonormalized().scaled(animated.basis.get_scale()), target.global_position)
	mesh.global_transform = animated.interpolate_with(goal, minf(weight, 1.0))


func _set_hitbox(on: bool) -> void:
	if hitbox:
		hitbox.set_deferred("monitoring", on)
