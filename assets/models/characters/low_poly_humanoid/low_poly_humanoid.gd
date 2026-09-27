@tool
class_name LowPolyHumanoid
extends Node3D
## Personaje low-poly estilo Rayman: torso, cabeza, manos y pies flotantes,
## construido 100% con nodos de Godot 4: sin Blender, sin esqueleto.
## Cada articulación es un Node3D; las animaciones se generan por código
## a partir de poses clave (ángulos en grados).
##
## Uso:
##   $Humanoid.play("run")
##   $Humanoid.play("attack_1")
##   $Humanoid.hit_window.connect(func(active): ...)   # la espada daña / deja de dañar
##
## Animaciones: idle, run, run_stop, jump_start, jump_air, jump_land,
##              attack_1, attack_2, attack_3, hit

signal hit_window(active: bool)   ## La espada empieza / deja de hacer daño
signal combo_window_opened        ## Desde acá se puede encadenar el siguiente golpe
signal attack_finished            ## El ataque terminó (volver a idle/locomoción)

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
## Teclas 1-0 reproducen cada animación (para probar)
@export var demo_controls := false
## Reconstruir en el editor (tildalo si cambiás colores)
@export var rebuild := false:
	set(v):
		if v and is_inside_tree():
			_build()

const HIPS_REST := Vector3(0, 0.55, 0)
const LEG_SCALE := 0.49  ## las poses se escribieron para piernas más largas
const ANIM_LIST := ["idle", "run", "run_stop", "jump_start", "jump_air",
		"jump_land", "attack_1", "attack_2", "attack_3", "hit"]

var anim: AnimationPlayer
var hitbox: Area3D
var _j := {}  # nombre de articulación -> Node3D


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


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not demo_controls:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var i: int = event.keycode - KEY_1 if event.keycode != KEY_0 else 9
		if i >= 0 and i < ANIM_LIST.size():
			anim.play(ANIM_LIST[i], 0.1)  # reinicia aunque ya esté sonando


# ---------------------------------------------------------------- CUERPO

func _build() -> void:
	for c in get_children():
		if c.name == &"Rig" or c.name == &"Anim":
			remove_child(c)
			c.free()
	_j.clear()

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
	_mesh(torso, _torso(), Vector3.ZERO, body)

	var neck := _joint(torso, "neck", Vector3(0, 0.4, 0))
	_mesh(neck, _gem(0.2), Vector3(0, 0.21, 0), body)  # cabeza

	for side: int in [-1, 1]:
		var s := "r" if side == 1 else "l"
		var sh := _joint(torso, "shoulder_" + s, Vector3(0.2 * side, 0.28, 0))
		var el := _joint(sh, "elbow_" + s, Vector3(0, -0.17, 0))
		var wr := _joint(el, "wrist_" + s, Vector3(0, -0.15, 0))
		_mesh(wr, _gem(0.08), Vector3(0, -0.04, 0), body)  # mano flotante

		var hp := _joint(hips, "hip_" + s, Vector3(0.09 * side, -0.02, 0))
		var kn := _joint(hp, "knee_" + s, Vector3(0, -0.22, 0))
		var an := _joint(kn, "ankle_" + s, Vector3(0, -0.2, 0))
		_mesh(an, _foot(), Vector3.ZERO, body)  # pie flotante

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
	var lib := AnimationLibrary.new()
	_build_animations(lib)
	anim.add_animation_library("", lib)


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


# ---------------------------------------------------------------- POSES
# Convención de ángulos (grados):
#   hombro/cadera  X+ = hacia adelante     codo X+ = dobla hacia adelante
#   rodilla        X- = dobla hacia atrás  torso X- = se inclina hacia adelante
#   torso/hombro   Y+ = gira a su izquierda
#   hombro         Z+ = abre el brazo derecho hacia afuera (Z- para el izquierdo)
#   "hips_pos"     desplazamiento de la cadera en metros

func _p(over := {}) -> Dictionary:  # de pie, relajado
	var p := {
		"shoulder_l": Vector3(0, 0, -8), "shoulder_r": Vector3(0, 0, 8),
		"elbow_l": Vector3(10, 0, 0), "elbow_r": Vector3(10, 0, 0),
	}
	p.merge(over, true)
	return p


func _stance(over := {}) -> Dictionary:  # guardia de combate
	var p := _p({
		"hips_pos": Vector3(0, -0.04, 0),
		"torso": Vector3(-6, -10, 0), "neck": Vector3(4, 10, 0),
		"hip_l": Vector3(20, 0, -4), "knee_l": Vector3(-30, 0, 0), "ankle_l": Vector3(10, 0, 0),
		"hip_r": Vector3(-5, 0, 4), "knee_r": Vector3(-20, 0, 0), "ankle_r": Vector3(25, 0, 0),
		"shoulder_r": Vector3(25, 0, 12), "elbow_r": Vector3(55, 0, 0),
		"shoulder_l": Vector3(15, 0, -15), "elbow_l": Vector3(40, 0, 0),
	})
	p.merge(over, true)
	return p


func _side_z(s: String, deg: float) -> float:
	return deg if s == "r" else -deg


func _run_contact(m: int) -> Dictionary:  # m = 1: pie derecho adelante
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _p({
		"hips_pos": Vector3(0, -0.05, 0),
		"torso": Vector3(-14, -8 * m, 0), "neck": Vector3(10, 8 * m, 0),
		"hip_" + f: Vector3(40, 0, 0), "knee_" + f: Vector3(-15, 0, 0), "ankle_" + f: Vector3(-10, 0, 0),
		"hip_" + b: Vector3(-35, 0, 0), "knee_" + b: Vector3(-50, 0, 0), "ankle_" + b: Vector3(25, 0, 0),
		"shoulder_" + b: Vector3(45, 0, _side_z(b, 10)), "elbow_" + b: Vector3(70, 0, 0),
		"shoulder_" + f: Vector3(-35, 0, _side_z(f, 10)), "elbow_" + f: Vector3(45, 0, 0),
	})


func _run_pass(m: int) -> Dictionary:  # la pierna "m" apoya, la otra pasa recogida
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _p({
		"hips_pos": Vector3(0, 0.03, 0),
		"torso": Vector3(-12, 0, 0), "neck": Vector3(8, 0, 0),
		"hip_" + f: Vector3(5, 0, 0), "knee_" + f: Vector3(-20, 0, 0), "ankle_" + f: Vector3(15, 0, 0),
		"hip_" + b: Vector3(30, 0, 0), "knee_" + b: Vector3(-100, 0, 0), "ankle_" + b: Vector3(30, 0, 0),
		"shoulder_l": Vector3(5, 0, -10), "elbow_l": Vector3(70, 0, 0),
		"shoulder_r": Vector3(5, 0, 10), "elbow_r": Vector3(70, 0, 0),
	})


func _crouch() -> Dictionary:
	return _p({
		"hips_pos": Vector3(0, -0.2, 0),
		"torso": Vector3(-25, 0, 0), "neck": Vector3(20, 0, 0),
		"hip_l": Vector3(45, 0, -5), "knee_l": Vector3(-80, 0, 0), "ankle_l": Vector3(35, 0, 0),
		"hip_r": Vector3(45, 0, 5), "knee_r": Vector3(-80, 0, 0), "ankle_r": Vector3(35, 0, 0),
		"shoulder_l": Vector3(-45, 0, -10), "elbow_l": Vector3(20, 0, 0),
		"shoulder_r": Vector3(-45, 0, 10), "elbow_r": Vector3(20, 0, 0),
	})


# ---------------------------------------------------------------- ANIMACIONES

func _build_animations(lib: AnimationLibrary) -> void:
	lib.add_animation("idle", _make([
		[0.0, _stance()],
		[1.0, _stance({"hips_pos": Vector3(0, -0.055, 0), "torso": Vector3(-9, -10, 0),
				"shoulder_l": Vector3(12, 0, -18), "shoulder_r": Vector3(22, 0, 14)})],
		[2.0, _stance()],
	], true, true))

	lib.add_animation("run", _make([
		[0.0, _run_contact(1)], [0.15, _run_pass(1)],
		[0.3, _run_contact(-1)], [0.45, _run_pass(-1)],
		[0.6, _run_contact(1)],
	], true, true))

	lib.add_animation("run_stop", _make([
		[0.0, _run_contact(1)],
		[0.12, _p({  # derrape: se echa hacia atrás y frena con la pierna adelante
			"hips_pos": Vector3(0, -0.12, 0), "torso": Vector3(8, 0, 0), "neck": Vector3(-5, 0, 0),
			"hip_r": Vector3(45, 0, 0), "knee_r": Vector3(-10, 0, 0), "ankle_r": Vector3(-30, 0, 0),
			"hip_l": Vector3(-15, 0, 0), "knee_l": Vector3(-70, 0, 0), "ankle_l": Vector3(60, 0, 0),
			"shoulder_l": Vector3(40, 0, -30), "elbow_l": Vector3(30, 0, 0),
			"shoulder_r": Vector3(40, 0, 30), "elbow_r": Vector3(30, 0, 0)})],
		[0.4, _stance()],
	], false, true))

	lib.add_animation("jump_start", _make([
		[0.0, _stance()],
		[0.08, _crouch()],
		[0.18, _p({  # despegue: todo estirado, brazos arriba
			"hips_pos": Vector3(0, 0.05, 0), "torso": Vector3(-5, 0, 0),
			"hip_l": Vector3(-5, 0, 0), "ankle_l": Vector3(-35, 0, 0),
			"hip_r": Vector3(10, 0, 0), "knee_r": Vector3(-30, 0, 0), "ankle_r": Vector3(-20, 0, 0),
			"shoulder_l": Vector3(150, 0, -15), "elbow_l": Vector3(20, 0, 0),
			"shoulder_r": Vector3(150, 0, 15), "elbow_r": Vector3(20, 0, 0)})],
	]))

	var air := {
		"torso": Vector3(-5, 0, 0),
		"hip_r": Vector3(70, 0, 0), "knee_r": Vector3(-100, 0, 0), "ankle_r": Vector3(20, 0, 0),
		"hip_l": Vector3(15, 0, 0), "knee_l": Vector3(-50, 0, 0), "ankle_l": Vector3(20, 0, 0),
		"shoulder_l": Vector3(20, 0, -60), "elbow_l": Vector3(30, 0, 0),
		"shoulder_r": Vector3(20, 0, 60), "elbow_r": Vector3(30, 0, 0),
	}
	var air2 := air.duplicate()
	air2["shoulder_l"] = Vector3(25, 0, -70)
	air2["shoulder_r"] = Vector3(25, 0, 70)
	air2["hip_l"] = Vector3(22, 0, 0)
	lib.add_animation("jump_air", _make([
		[0.0, _p(air)], [0.3, _p(air2)], [0.6, _p(air)],
	], true, true))

	var land := _crouch()
	land["hips_pos"] = Vector3(0, -0.22, 0)
	land["shoulder_l"] = Vector3(30, 0, -40)
	land["shoulder_r"] = Vector3(30, 0, 40)
	lib.add_animation("jump_land", _make([
		[0.0, land], [0.08, land], [0.3, _stance()],
	]))

	# --- ATAQUE 1: tajo horizontal rápido de derecha a izquierda
	lib.add_animation("attack_1", _make([
		[0.0, _stance()],
		[0.1, _stance({  # anticipación: gira el torso y lleva la espada atrás
			"hips_pos": Vector3(0, -0.06, 0),
			"torso": Vector3(-5, -45, 0), "neck": Vector3(0, 40, 0),
			"shoulder_r": Vector3(70, -65, 0), "elbow_r": Vector3(20, 0, 0), "wrist_r": Vector3(-70, 0, 0),
			"shoulder_l": Vector3(30, 0, -30)})],
		[0.2, _stance({  # impacto: barrido completo, pequeña estocada con la pierna
			"hips_pos": Vector3(0, -0.08, 0),
			"torso": Vector3(-12, 40, 0), "neck": Vector3(0, -35, 0),
			"hip_l": Vector3(30, 0, -4), "knee_l": Vector3(-35, 0, 0), "ankle_l": Vector3(5, 0, 0),
			"shoulder_r": Vector3(80, 50, 0), "elbow_r": Vector3(5, 0, 0), "wrist_r": Vector3(-80, 0, 0),
			"shoulder_l": Vector3(-20, 0, -30)})],
		[0.26, _stance({  # se sostiene un instante: se "siente" el golpe
			"hips_pos": Vector3(0, -0.08, 0),
			"torso": Vector3(-12, 45, 0), "neck": Vector3(0, -38, 0),
			"hip_l": Vector3(30, 0, -4), "knee_l": Vector3(-35, 0, 0), "ankle_l": Vector3(5, 0, 0),
			"shoulder_r": Vector3(78, 58, 0), "elbow_r": Vector3(8, 0, 0), "wrist_r": Vector3(-80, 0, 0),
			"shoulder_l": Vector3(-20, 0, -30)})],
		[0.45, _stance()],
	], false, false, [
		[0.12, "hit_on"], [0.22, "hit_off"], [0.24, "combo"], [0.45, "end"],
	]))

	# --- ATAQUE 2: revés de izquierda a derecha
	lib.add_animation("attack_2", _make([
		[0.0, _stance({"torso": Vector3(-12, 40, 0), "neck": Vector3(0, -35, 0),
				"shoulder_r": Vector3(78, 58, 0), "elbow_r": Vector3(8, 0, 0), "wrist_r": Vector3(-80, 0, 0)})],
		[0.12, _stance({  # carga: brazo cruzado sobre el pecho
			"hips_pos": Vector3(0, -0.06, 0),
			"torso": Vector3(-8, 50, 0), "neck": Vector3(0, -45, 0),
			"shoulder_r": Vector3(75, 70, 0), "elbow_r": Vector3(60, 0, 0), "wrist_r": Vector3(-60, 0, 0),
			"shoulder_l": Vector3(-10, 0, -40)})],
		[0.22, _stance({  # impacto
			"hips_pos": Vector3(0, -0.08, 0),
			"torso": Vector3(-10, -40, 0), "neck": Vector3(0, 36, 0),
			"hip_r": Vector3(25, 0, 4), "knee_r": Vector3(-30, 0, 0), "ankle_r": Vector3(5, 0, 0),
			"shoulder_r": Vector3(80, -50, 0), "elbow_r": Vector3(5, 0, 0), "wrist_r": Vector3(-80, 0, 0),
			"shoulder_l": Vector3(30, 0, -20)})],
		[0.28, _stance({
			"hips_pos": Vector3(0, -0.08, 0),
			"torso": Vector3(-10, -45, 0), "neck": Vector3(0, 40, 0),
			"hip_r": Vector3(25, 0, 4), "knee_r": Vector3(-30, 0, 0), "ankle_r": Vector3(5, 0, 0),
			"shoulder_r": Vector3(80, -56, 0), "elbow_r": Vector3(8, 0, 0), "wrist_r": Vector3(-80, 0, 0),
			"shoulder_l": Vector3(30, 0, -20)})],
		[0.5, _stance()],
	], false, false, [
		[0.14, "hit_on"], [0.24, "hit_off"], [0.26, "combo"], [0.5, "end"],
	]))

	# --- ATAQUE 3: golpe pesado desde arriba (final del combo)
	var slam := _stance({
		"hips_pos": Vector3(0, -0.16, 0),
		"torso": Vector3(-35, 0, 0), "neck": Vector3(25, 0, 0),
		"hip_l": Vector3(50, 0, -4), "knee_l": Vector3(-70, 0, 0), "ankle_l": Vector3(20, 0, 0),
		"hip_r": Vector3(-30, 0, 4), "knee_r": Vector3(-20, 0, 0), "ankle_r": Vector3(50, 0, 0),
		"shoulder_r": Vector3(100, 0, 5), "elbow_r": Vector3(10, 0, 0), "wrist_r": Vector3(-100, 0, 0),
		"shoulder_l": Vector3(90, 0, -10), "elbow_l": Vector3(20, 0, 0),
	})
	lib.add_animation("attack_3", _make([
		[0.0, _stance()],
		[0.28, _p({  # anticipación larga: se estira y levanta la espada
			"hips_pos": Vector3(0, 0.0, 0),
			"torso": Vector3(12, 0, 0), "neck": Vector3(-10, 0, 0),
			"hip_l": Vector3(10, 0, -4), "knee_l": Vector3(-10, 0, 0),
			"hip_r": Vector3(-10, 0, 4), "knee_r": Vector3(-5, 0, 0), "ankle_r": Vector3(15, 0, 0),
			"shoulder_r": Vector3(165, 0, 10), "elbow_r": Vector3(30, 0, 0), "wrist_r": Vector3(-30, 0, 0),
			"shoulder_l": Vector3(150, 0, -20), "elbow_l": Vector3(40, 0, 0)})],
		[0.38, slam],   # cae rápido
		[0.55, slam],   # se queda clavado: peso
		[0.85, _stance()],
	], false, false, [
		[0.32, "hit_on"], [0.44, "hit_off"], [0.6, "combo"], [0.85, "end"],
	]))

	lib.add_animation("hit", _make([
		[0.0, _stance()],
		[0.08, _stance({
			"hips_pos": Vector3(0, -0.05, 0.06),
			"torso": Vector3(20, 0, 0), "neck": Vector3(25, 0, 0),
			"shoulder_l": Vector3(10, 0, -35), "shoulder_r": Vector3(10, 0, 35)})],
		[0.35, _stance()],
	]))


## keys: [[tiempo, pose], ...]   events: [[tiempo, "hit_on"|"hit_off"|"combo"|"end"], ...]
func _make(keys: Array, loop := false, smooth := false, events := []) -> Animation:
	var a := Animation.new()
	a.length = keys[-1][0]
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var interp := Animation.INTERPOLATION_CUBIC if smooth else Animation.INTERPOLATION_LINEAR

	for joint: String in _j.keys():
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath(String(get_path_to(_j[joint])) + ":rotation"))
		a.track_set_interpolation_type(t, interp)
		for k: Array in keys:
			var deg: Vector3 = k[1].get(joint, Vector3.ZERO)
			a.track_insert_key(t, k[0], deg * (PI / 180.0))

	var tp := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tp, NodePath(String(get_path_to(_j["hips"])) + ":position"))
	a.track_set_interpolation_type(tp, interp)
	for k: Array in keys:
		a.track_insert_key(tp, k[0], HIPS_REST + k[1].get("hips_pos", Vector3.ZERO) * LEG_SCALE)

	if not events.is_empty():
		var tm := a.add_track(Animation.TYPE_METHOD)
		a.track_set_path(tm, NodePath("."))
		for e: Array in events:
			a.track_insert_key(tm, e[0], {"method": "_anim_event", "args": [e[1]]})
	return a


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


func _set_hitbox(on: bool) -> void:
	if hitbox:
		hitbox.set_deferred("monitoring", on)
