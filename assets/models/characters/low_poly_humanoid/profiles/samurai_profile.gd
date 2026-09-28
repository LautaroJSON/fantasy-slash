@tool
extends HumanoidProfile
## Samurái (katana con funda): calma y precisión (docs/specs/class-combat-identity.md
## §3.3 revisada, sheath-socket-hand-grip.md, samurai-rest-guard.md). En reposo,
## erguido, relajado y de frente, con la cabeza al frente; la mano
## izquierda **nunca** suelta la funda (la funda cuelga de la muñeca izquierda,
## sheath-in-left-hand.md: el brazo izquierdo de cada pose la orienta) y la
## derecha lleva la katana baja, adelante y a la derecha. Cortes a una mano con
## recorrido largo, tomados de los ocho cortes clásicos: horizontal, diagonal
## ascendente, vertical y un remate doble (diagonal ascendente y kesa; attack_4 encadena solo con attack_5).
## `sheathe_charge`: la pose de carga de Envainar (battōjutsu, la derecha sobre
## el mango).
## Los tiempos de los eventos coinciden con data/classes/samurai/samurai_combo.tres.

## Katana en la mano derecha, el brazo colgando junto a la cadera: la hoja baja
## en diagonal adelante y a la derecha, la punta cerca del piso (samurai-rest-guard.md).
const LOW_BLADE := {
	"shoulder_r": Vector3(-2, 47, 9), "elbow_r": Vector3(56, 0, 0), "wrist_r": Vector3(-143, 53, -14),
}

## La funda en la mano izquierda, en la cadera izquierda con la punta atrás y
## abajo (docs/specs/sheath-in-left-hand.md). La funda cuelga de la muñeca, así
## que el brazo la orienta: wrist_l X baja la punta (más negativo la sube), wrist_l Y la abre
## o la cierra respecto del cuerpo, y shoulder_l/elbow_l mueven la mano (la boca
## de la funda). Los brazos son invisibles: vale cualquier pose que deje bien
## la mano y la funda.
const LEFT_SHEATH_ARM := {
	"shoulder_l": Vector3(-47, -1, 19), "elbow_l": Vector3(82, 0, 0), "wrist_l": Vector3(-13, -33, -20),
}

## Brazos de la carrera por pose (samurai-run.md): la mano derecha a la
## derecha y atrás con la hoja baja arrastrándose detrás, y la funda firme en
## la cadera mientras el torso contragira. Calculados para la mano y la
## dirección de la hoja y de la funda.
const RUN_ARMS := {
	"contact_1": {
		"shoulder_r": Vector3(-31, 15, 32), "elbow_r": Vector3(8, 0, 0), "wrist_r": Vector3(-124, -7, 11),
		"shoulder_l": Vector3(-46, 0, 19), "elbow_l": Vector3(81, 0, 0), "wrist_l": Vector3(-7, -28, -19),
	},
	"pass_1": {
		"shoulder_r": Vector3(-36, 12, 35), "elbow_r": Vector3(28, 0, 0), "wrist_r": Vector3(-140, -9, 7),
		"shoulder_l": Vector3(-40, 0, 17), "elbow_l": Vector3(74, 0, 0), "wrist_l": Vector3(-7, -28, -19),
	},
	"contact_-1": {
		"shoulder_r": Vector3(-35, 12, 29), "elbow_r": Vector3(10, 0, 0), "wrist_r": Vector3(-123, -5, 25),
		"shoulder_l": Vector3(-44, 0, 19), "elbow_l": Vector3(82, 0, 0), "wrist_l": Vector3(-9, -32, -19),
	},
	"pass_-1": {
		"shoulder_r": Vector3(-37, 11, 34), "elbow_r": Vector3(30, 0, 0), "wrist_r": Vector3(-141, -7, 18),
		"shoulder_l": Vector3(-40, 0, 17), "elbow_l": Vector3(74, 0, 0), "wrist_l": Vector3(-7, -28, -19),
	},
}

## Posturas de carga más hondas de Envainar (docs/specs/sheathe-visual-rework.md
## §2.4), una por hito: la cadera baja (≈2.6, 5.2 y 8.5 cm) y el torso se
## vuelca 4°, 8° y 12° más. Piernas resueltas para que los tobillos queden
## donde están en _charge_pose() (posición y orientación, a menos de 1 mm).
const CHARGE_SINK_CLIPS: Array[StringName] = [&"sheathe_charge_1", &"sheathe_charge_2", &"sheathe_charge_full"]
const CHARGE_SINK: Array[Dictionary] = [
	{
		"hips_pos": Vector3(-0.04, -0.48, 0.12), "torso": Vector3(-9, 130, -15),
		"hip_l": Vector3(-21.5, 51.1, -25.5), "knee_l": Vector3(-70, 0, 0), "ankle_l": Vector3(7.8, 67.2, 93.3),
		"hip_r": Vector3(86.6, 35, 0), "knee_r": Vector3(-50.4, 0, 0), "ankle_r": Vector3(-36.2, 0, 0),
	},
	{
		"hips_pos": Vector3(-0.04, -0.52, 0.12), "torso": Vector3(-13, 130, -15),
		"hip_l": Vector3(-22.1, 51, -27), "knee_l": Vector3(-74.4, 0, 0), "ankle_l": Vector3(9.1, 66.7, 98.1),
		"hip_r": Vector3(91.7, 35, 0), "knee_r": Vector3(-55.6, 0, 0), "ankle_r": Vector3(-36.1, 0, 0),
	},
	{
		"hips_pos": Vector3(-0.04, -0.57, 0.12), "torso": Vector3(-17, 130, -15),
		"hip_l": Vector3(-23.4, 51.2, -28.9), "knee_l": Vector3(-79.1, 0, 0), "ankle_l": Vector3(10.6, 65.9, 104),
		"hip_r": Vector3(97.8, 35, 0), "knee_r": Vector3(-61, 0, 0), "ankle_r": Vector3(-36.8, 0, 0),
	},
]

## Succession of the body in the cuts (poc/samurai-motion): seconds each
## joint trails the hips. The right arm is driven by the cut arcs.
const OVERLAP := {
	"hips": 0.0, "torso": 0.012, "neck": 0.026,
	"shoulder_l": 0.02, "elbow_l": 0.02, "wrist_l": 0.02,
}

var _h: LowPolyHumanoid


# ---------------------------------------------------------------- MOTION

## Where the blade points (from the right shoulder) at the joints of the
## Nagare pendulum: every cut starts where the previous one ended.
const DIR_GUARD := Vector3(0.55, -0.6, -0.55)
const DIR_HIGH_RIGHT := Vector3(0.5, 0.8, 0.22)
const DIR_LOW_LEFT := Vector3(-0.6, -0.75, -0.2)
const DIR_SIDE_RIGHT := Vector3(0.92, 0.0, 0.35)
const DIR_FAR_LEFT := Vector3(-0.85, 0.05, 0.5)
const DIR_FORWARD := Vector3(0.0, -0.05, -1.0)
const DIR_OVERHEAD := Vector3(0.05, 0.8, 0.6)
const DIR_DOWN_FRONT := Vector3(0.0, -0.88, -0.45)
const DIR_FLICK := Vector3(0.72, -0.66, -0.1)


## The Nagare cuts as arcs of the grip around the right shoulder (root space:
## forward -Z, right +X, up +Y), with where the blade is at each moment.
## f = 0 start, 1 middle (the hit, for a cut), 2 end.
func build_motion() -> HumanoidMotionSetup:
	var m := HumanoidMotionSetup.new()
	m.springs = {"neck": Vector2(4.5, 0.42), "torso": Vector2(6.5, 0.55)}

	# 1. Kesa-giri: the load rises up the right side (spine first), the cut
	# falls across the front to low left.
	var load_1 := _arc(DIR_GUARD, Vector3(0.95, 0.15, 0.0), DIR_HIGH_RIGHT, 0.32, Vector3(-0.06, -0.08, 0),
		[Vector2(0.0, 0.0), Vector2(0.05, 0.6), Vector2(0.1, 1.5), Vector2(0.125, 2.0)])
	load_1.edge_flip = true
	load_1.blend_in = Vector2(0.0, 0.05)
	var cut_1 := _arc(DIR_HIGH_RIGHT, Vector3(-0.05, 0.1, -1), DIR_LOW_LEFT, 0.34, Vector3(-0.1, -0.04, 0),
		[Vector2(0.125, 0.0), Vector2(0.17, 1.0), Vector2(0.21, 1.65), Vector2(0.27, 1.97), Vector2(0.34, 2.02), Vector2(0.46, 2.0)])
	m.arcs[&"attack_1"] = [load_1, cut_1]

	# 2. Kiriage: back up the same line to high right.
	m.arcs[&"attack_2"] = [_arc(DIR_LOW_LEFT, Vector3(0.05, -0.1, -1), DIR_HIGH_RIGHT, 0.33, Vector3(-0.08, -0.05, 0),
		[Vector2(0.0, 0.0), Vector2(0.045, 0.1), Vector2(0.1, 1.0), Vector2(0.135, 1.65), Vector2(0.19, 1.97), Vector2(0.26, 2.02), Vector2(0.36, 2.0)])]

	# 3. Yokogiri: drops to the right side while the hips wind, then sweeps
	# level to far left.
	var drop_3 := _arc(DIR_HIGH_RIGHT, Vector3(0.85, 0.45, 0.3), DIR_SIDE_RIGHT, 0.33, Vector3(-0.08, -0.08, 0),
		[Vector2(0.0, 0.0), Vector2(0.05, 0.9), Vector2(0.1, 2.0)])
	var sweep_3 := _arc(DIR_SIDE_RIGHT, Vector3(0.05, 0.0, -1), DIR_FAR_LEFT, 0.36, Vector3(-0.1, -0.12, 0),
		[Vector2(0.1, 0.0), Vector2(0.13, 0.35), Vector2(0.165, 1.0), Vector2(0.2, 1.6), Vector2(0.26, 1.97), Vector2(0.34, 2.03), Vector2(0.46, 2.0)])
	m.arcs[&"attack_3"] = [drop_3, sweep_3]

	# 4. Tsuki: the blade swings back to the front while the grip pulls in to
	# the right hip, then only the radius moves: the thrust.
	var chamber_4 := _arc(DIR_FAR_LEFT, Vector3(-0.55, -0.05, -0.45), DIR_FORWARD, 0.36, Vector3(-0.04, -0.16, 0),
		[Vector2(0.0, 0.0), Vector2(0.04, 0.9), Vector2(0.075, 2.0)])
	chamber_4.radius_timing = PackedVector2Array([Vector2(0.0, 0.36), Vector2(0.075, 0.14)])
	var thrust_4 := SlashArc.fixed(DIR_FORWARD, Vector3(0, -1, 0))
	thrust_4.center_offset = Vector3(-0.04, -0.16, 0)
	thrust_4.timing = PackedVector2Array([Vector2(0.075, 0.0), Vector2(0.3, 0.0)])
	thrust_4.radius_timing = PackedVector2Array([Vector2(0.075, 0.14), Vector2(0.1, 0.3), Vector2(0.12, 0.44), Vector2(0.3, 0.42)])
	m.arcs[&"attack_4"] = [chamber_4, thrust_4]

	# 5. Karatake-wari: raise over the head (spine first), split straight down,
	# hold the zanshin, flick the blood off to the right (chiburi) and settle
	# into the low guard.
	var raise_5 := _arc(DIR_FORWARD, Vector3(0.0, 0.7, -0.7), DIR_OVERHEAD, 0.33, Vector3(-0.12, 0.0, 0),
		[Vector2(0.0, 0.0), Vector2(0.05, 0.9), Vector2(0.1, 2.0)])
	raise_5.edge_flip = true
	var split_5 := _arc(DIR_OVERHEAD, Vector3(0.0, 0.05, -1), DIR_DOWN_FRONT, 0.35, Vector3(-0.14, 0.02, 0),
		[Vector2(0.1, 0.0), Vector2(0.125, 0.4), Vector2(0.145, 1.0), Vector2(0.17, 1.6), Vector2(0.2, 1.97), Vector2(0.26, 2.02), Vector2(0.42, 2.0)])
	var chiburi_5 := _arc(DIR_DOWN_FRONT, Vector3(0.5, -0.72, -0.48), DIR_FLICK, 0.35, Vector3(-0.1, 0.0, 0),
		[Vector2(0.44, 0.0), Vector2(0.47, 1.0), Vector2(0.51, 1.9), Vector2(0.55, 2.02), Vector2(0.6, 2.0)])
	chiburi_5.blend_out = Vector2(0.62, 0.85)
	m.arcs[&"attack_5"] = [raise_5, split_5, chiburi_5]

	# The back foot stays on the floor while the other one steps in.
	m.plants = {
		&"attack_1": [["r", 0.0, 0.26]],
		&"attack_2": [["l", 0.0, 0.2]],
		&"attack_3": [["r", 0.0, 0.28]],
		&"attack_4": [["l", 0.0, 0.2]],
		&"attack_5": [["r", 0.06, 0.45]],
	}
	return m


func _arc(start: Vector3, mid: Vector3, end: Vector3, radius: float, center_offset: Vector3, timing: Array) -> SlashArc:
	var arc := SlashArc.create(start, mid, end)
	arc.radius = radius
	arc.center_offset = center_offset
	arc.timing = PackedVector2Array(timing)
	return arc


func build(humanoid: LowPolyHumanoid) -> AnimationLibrary:
	_h = humanoid
	var lib := AnimationLibrary.new()
	_add_idle(lib)
	_add_run(lib)
	_add_sprint(lib)
	_add_dash(lib)
	_add_jump(lib)
	_add_hit(lib)
	_add_sheathe_charge(lib)
	_add_sheathe_release(lib)
	_add_attacks(lib)
	return lib


## Arma un clip con la funda en la mano izquierda (docs/specs/sheath-in-left-hand.md):
## las poses que no escriben su propio brazo izquierdo (sin "wrist_l") llevan
## LEFT_SHEATH_ARM.
func _clip(keys: Array, loop := false, smooth := false, events := [], overlap: Dictionary = {}) -> Animation:
	for i: int in keys.size():
		if not keys[i][1].has("wrist_l"):
			keys[i] = [keys[i][0], _h.with(keys[i][1], LEFT_SHEATH_ARM)]
	return _h.make_clip(keys, loop, smooth, events, overlap)


## Zancada larga con la pierna izquierda adelante (cortes que atraviesan).
func _stride(depth: float) -> Dictionary:
	return {
		"hips_pos": Vector3(0, -depth, 0),
		"hip_l": Vector3(55, 0, -6), "knee_l": Vector3(-68, 0, 0), "ankle_l": Vector3(12, 0, 0),
		"hip_r": Vector3(-36, 0, 8), "knee_r": Vector3(-12, 0, 0), "ankle_r": Vector3(48, 0, 0),
	}


# ---------------------------------------------------------------- GUARDIA

## Guardia de reposo (samurai-rest-guard.md): erguida, relajada y de frente, la
## cabeza al frente, los pies a la par y casi juntos con las puntas apenas
## abiertas; la katana baja adelante a la derecha y la funda atrás y abajo.
func _stance(over := {}) -> Dictionary:
	return _h.with(_h.pose(_h.with({
		"hips_pos": Vector3(0, -0.03, 0),
		"hips": Vector3(0, 0, 0),
		"torso": Vector3(1, 0, 0), "neck": Vector3(-1, 0, 0),
		"hip_l": Vector3(6, 12, -3), "knee_l": Vector3(-12, 0, 0), "ankle_l": Vector3(6, 0, 0),
		"hip_r": Vector3(6, -12, 3), "knee_r": Vector3(-12, 0, 0), "ankle_r": Vector3(6, 0, 0),
	}, LOW_BLADE)), over)


func _add_idle(lib: AnimationLibrary) -> void:
	# Respiración casi imperceptible (3 s): el pecho sube apenas.
	lib.add_animation("idle", _clip([
		[0.0, _stance()],
		[1.5, _stance({"hips_pos": Vector3(0, -0.04, 0), "torso": Vector3(2, 0, 0)})],
		[3.0, _stance()],
	], true, true))


# ---------------------------------------------------------------- CARRERA

## Carrera (samurai-run.md): casi erguida, los pasos casi en línea y poco
## rebote; el brazo derecho estirado al costado y hacia atrás con la katana
## baja arrastrándose detrás a la derecha, y la izquierda firme en la funda.
func _run_contact(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with({
		"hips_pos": Vector3(0, -0.06, 0),
		"hips": Vector3(0, 6 * m, 0),
		"torso": Vector3(-6, -8 * m, 0), "neck": Vector3(4, 2 * m, 0),
		"hip_" + f: Vector3(40, 0, _h.side_z(f, -4)), "knee_" + f: Vector3(-22, 0, 0), "ankle_" + f: Vector3(-6, 0, 0),
		"hip_" + b: Vector3(-28, 0, _h.side_z(b, -4)), "knee_" + b: Vector3(-50, 0, 0), "ankle_" + b: Vector3(24, 0, 0),
	}, RUN_ARMS["contact_%d" % m]))


func _run_pass(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with({
		"hips_pos": Vector3(0, -0.03, 0),
		"torso": Vector3(-5, 0, 0), "neck": Vector3(3, 0, 0),
		"hip_" + f: Vector3(6, 0, _h.side_z(f, -4)), "knee_" + f: Vector3(-24, 0, 0), "ankle_" + f: Vector3(14, 0, 0),
		"hip_" + b: Vector3(32, 0, _h.side_z(b, -4)), "knee_" + b: Vector3(-85, 0, 0), "ankle_" + b: Vector3(30, 0, 0),
	}, RUN_ARMS["pass_%d" % m]))


func _add_run(lib: AnimationLibrary) -> void:
	lib.add_animation("run", _clip([
		[0.0, _run_contact(1)], [0.14, _run_pass(1)],
		[0.28, _run_contact(-1)], [0.42, _run_pass(-1)],
		[0.56, _run_contact(1)],
	], true, true))

	# Arranque (samurai-run.md): desde la guardia, el primer paso empuja con el
	# cuerpo inclinado y la katana barre desde adelante-abajo por el costado
	# derecho hasta arrastrarse detrás; termina en el primer cuadro de run.
	lib.add_animation("run_start", _clip([
		[0.0, _stance()],
		[0.08, _h.with(_run_contact(1), {
			"hips_pos": Vector3(0, -0.08, 0), "torso": Vector3(-12, -4, 0), "neck": Vector3(9, 2, 0),
			"shoulder_r": Vector3(-34, 11, 33), "elbow_r": Vector3(58, 0, 0), "wrist_r": Vector3(-123, -6, 17)})],
		[0.2, _run_contact(1)],
	], false, true))

	# Frena corto, casi sin derrape, y vuelve enseguida a la guardia.
	lib.add_animation("run_stop", _clip([
		[0.0, _run_contact(1)],
		[0.08, _stance({"hips_pos": Vector3(0, -0.1, 0), "torso": Vector3(-6, 0, 0),
				"hip_l": Vector3(34, 12, -3), "knee_l": Vector3(-46, 0, 0), "ankle_l": Vector3(12, 0, 0)})],
		[0.3, _stance()],
	], false, true))


# ---------------------------------------------------------------- SPRINT

## Carrera a fondo (docs/specs/sprint-stamina.md): el torso bajo y volcado,
## zancadas largas casi en línea con la rodilla alta, la katana más atrás y
## más horizontal, arrastrándose detrás a la derecha, y la izquierda firme en
## la funda. Los brazos parten de los de la carrera (RUN_ARMS).
func _sprint_contact(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	var arms: Dictionary = RUN_ARMS["contact_%d" % m]
	var shoulder: Vector3 = arms["shoulder_r"]
	return _h.pose(_h.with(_h.with({
		"hips_pos": Vector3(0, -0.12, 0),
		"hips": Vector3(0, 8 * m, 0),
		"torso": Vector3(-26, -10 * m, 0), "neck": Vector3(22, 3 * m, 0),
		"hip_" + f: Vector3(60, 0, _h.side_z(f, -4)), "knee_" + f: Vector3(-30, 0, 0), "ankle_" + f: Vector3(-6, 0, 0),
		"hip_" + b: Vector3(-40, 0, _h.side_z(b, -4)), "knee_" + b: Vector3(-60, 0, 0), "ankle_" + b: Vector3(30, 0, 0),
	}, arms), {"shoulder_r": Vector3(shoulder.x - 18, shoulder.y, shoulder.z)}))


func _sprint_pass(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	var arms: Dictionary = RUN_ARMS["pass_%d" % m]
	var shoulder: Vector3 = arms["shoulder_r"]
	return _h.pose(_h.with(_h.with({
		"hips_pos": Vector3(0, -0.04, 0),
		"torso": Vector3(-24, 0, 0), "neck": Vector3(20, 0, 0),
		"hip_" + f: Vector3(4, 0, _h.side_z(f, -4)), "knee_" + f: Vector3(-26, 0, 0), "ankle_" + f: Vector3(16, 0, 0),
		"hip_" + b: Vector3(50, 0, _h.side_z(b, -4)), "knee_" + b: Vector3(-120, 0, 0), "ankle_" + b: Vector3(34, 0, 0),
	}, arms), {"shoulder_r": Vector3(shoulder.x - 18, shoulder.y, shoulder.z)}))


func _add_sprint(lib: AnimationLibrary) -> void:
	lib.add_animation("sprint", _clip([
		[0.0, _sprint_contact(1)], [0.1, _sprint_pass(1)],
		[0.2, _sprint_contact(-1)], [0.3, _sprint_pass(-1)],
		[0.4, _sprint_contact(1)],
	], true, true))

	# Arranque: se agacha de golpe y sale disparado, la katana barre por el
	# costado derecho hasta quedar atrás; termina en el primer cuadro de sprint.
	lib.add_animation("sprint_start", _clip([
		[0.0, _stance()],
		[0.08, _h.with(_sprint_contact(1), {
			"hips_pos": Vector3(0, -0.2, 0), "torso": Vector3(-36, -4, 0), "neck": Vector3(28, 2, 0),
			"hip_l": Vector3(-48, 0, 4), "knee_l": Vector3(-12, 0, 0), "ankle_l": Vector3(42, 0, 0),
			"shoulder_r": Vector3(-34, 11, 33), "elbow_r": Vector3(58, 0, 0), "wrist_r": Vector3(-123, -6, 17)})],
		[0.2, _sprint_contact(1)],
	], false, true))

	# Frenada de costado: gira la cadera, derrapa con la pierna izquierda
	# estirada y el peso atrás, y vuelve a la guardia.
	lib.add_animation("sprint_stop", _clip([
		[0.0, _sprint_contact(-1)],
		[0.12, _stance({
			"hips_pos": Vector3(0, -0.2, 0), "hips": Vector3(0, 28, 0),
			"torso": Vector3(8, -10, 0), "neck": Vector3(-4, -18, 0),
			"hip_l": Vector3(46, -28, -10), "knee_l": Vector3(-6, 0, 0), "ankle_l": Vector3(-20, 0, 0),
			"hip_r": Vector3(-10, -28, 10), "knee_r": Vector3(-72, 0, 0), "ankle_r": Vector3(50, 0, 0)})],
		[0.24, _stance({
			"hips_pos": Vector3(0, -0.12, 0), "hips": Vector3(0, 14, 0),
			"torso": Vector3(2, -6, 0), "neck": Vector3(-1, -8, 0),
			"hip_l": Vector3(26, -2, -6), "knee_l": Vector3(-20, 0, 0), "ankle_l": Vector3(-4, 0, 0),
			"hip_r": Vector3(0, -2, 6), "knee_r": Vector3(-40, 0, 0), "ankle_r": Vector3(30, 0, 0)})],
		[0.42, _stance()],
	], false, true))


# ---------------------------------------------------------------- DASH

## Dash (docs/specs/dash-feel.md): impulso, estirado y el primer cuadro de
## sprint, en las fracciones 0, 0.35 y 1 (la regla de conexión). La katana y la
## funda siguen los brazos del sprint en todo el clip. Samurái: sale disparado
## desde muy abajo y se desliza con la pierna delantera larga.
func _add_dash(lib: AnimationLibrary) -> void:
	var run_in := _sprint_contact(1)
	lib.add_animation("dash", _clip([
		[0.0, _h.with(run_in, {
			"hips_pos": Vector3(0, -0.24, 0), "hips": Vector3(0, 4, 0),
			"torso": Vector3(-42, -6, 0), "neck": Vector3(34, 2, 0),
			"hip_l": Vector3(44, 0, 4), "knee_l": Vector3(-70, 0, 0), "ankle_l": Vector3(24, 0, 0),
			"hip_r": Vector3(-50, 0, -4), "knee_r": Vector3(-12, 0, 0), "ankle_r": Vector3(44, 0, 0)})],
		[0.084, _h.with(run_in, {
			"hips_pos": Vector3(0, -0.18, 0), "hips": Vector3(0, 10, 0),
			"torso": Vector3(-36, -12, 0), "neck": Vector3(28, 4, 0),
			"hip_r": Vector3(78, 0, -4), "knee_r": Vector3(-14, 0, 0), "ankle_r": Vector3(-16, 0, 0),
			"hip_l": Vector3(-52, 0, 4), "knee_l": Vector3(-62, 0, 0), "ankle_l": Vector3(34, 0, 0)})],
		[0.24, run_in],
	], false, true))


# ---------------------------------------------------------------- SALTO

func _add_jump(lib: AnimationLibrary) -> void:
	# Salto liviano: piernas recogidas limpias, la mano sigue en la funda.
	lib.add_animation("jump_start", _clip([
		[0.0, _stance()],
		[0.07, _h.crouch(_h.with(LOW_BLADE, {"hips_pos": Vector3(0, -0.16, 0), "wrist_r": Vector3(-95, 0, 0)}))],
		[0.16, _h.pose(_h.with(LOW_BLADE, {
			"hips_pos": Vector3(0, 0.04, 0), "torso": Vector3(-6, 0, 0),
			"hip_l": Vector3(-5, 0, 0), "ankle_l": Vector3(-35, 0, 0),
			"hip_r": Vector3(12, 0, 0), "knee_r": Vector3(-30, 0, 0), "ankle_r": Vector3(-20, 0, 0)}))],
	]))

	var air := _h.with(LOW_BLADE, {
		"torso": Vector3(-8, 0, 0),
		"hip_r": Vector3(75, 0, 0), "knee_r": Vector3(-120, 0, 0), "ankle_r": Vector3(25, 0, 0),
		"hip_l": Vector3(60, 0, 0), "knee_l": Vector3(-115, 0, 0), "ankle_l": Vector3(25, 0, 0),
	})
	lib.add_animation("jump_air", _clip([
		[0.0, _h.pose(air)],
		[0.3, _h.pose(_h.with(air, {"hip_l": Vector3(66, 0, 0), "torso": Vector3(-10, 0, 0)}))],
		[0.6, _h.pose(air)],
	], true, true))

	# Aterriza sin ruido: poca flexión.
	var land := _h.crouch(_h.with(LOW_BLADE, {"hips_pos": Vector3(0, -0.14, 0), "wrist_r": Vector3(-95, 0, 0)}))
	lib.add_animation("jump_land", _clip([
		[0.0, land], [0.04, land], [0.22, _stance()],
	]))


func _add_hit(lib: AnimationLibrary) -> void:
	# Retrocede con un giro corto del torso, sin soltar la funda.
	lib.add_animation("hit", _clip([
		[0.0, _stance()],
		[0.08, _stance({
			"hips_pos": Vector3(0, -0.07, 0.06), "hips": Vector3(0, -8, 0),
			"torso": Vector3(12, -8, 0), "neck": Vector3(10, 16, 0),
			"shoulder_r": Vector3(20, 45, 20)})],
		[0.35, _stance()],
	]))


## Carga de Envainar (battōjutsu, sheath-socket-hand-grip.md §2.7, revisión 4):
## estocada baja adelante-atrás (la izquierda adelante con el muslo casi
## horizontal; la derecha estirada atrás, con la rodilla cerca del piso), la
## cadera de costado. El torso volcado ≈ 45° hacia el enemigo con el pecho
## abierto (el giro y la inclinación lateral mantienen el vuelco derecho al
## frente), así la funda, que sigue al torso, sube por detrás de la espalda con
## el mango adelante y abajo, en la cadera izquierda. La cabeza arriba, mirando
## al frente. La izquierda sostiene la funda junto a la tsuba y la derecha
## cruza hasta el mango. La cadera se corre en el plano horizontal para que el
## cuerpo quede centrado sobre el jugador.
func _charge_pose() -> Dictionary:
	return _h.pose({
		"hips_pos": Vector3(-0.04, -0.44, 0.12), "hips": Vector3(0, -35, 0),
		"torso": Vector3(-5, 130, -15), "neck": Vector3(10, -100, -8),
		"hip_l": Vector3(-21, 52, -25), "knee_l": Vector3(-65, 0, 0), "ankle_l": Vector3(7, 67, 88),
		"hip_r": Vector3(81, 35, 0), "knee_r": Vector3(-44, 0, 0), "ankle_r": Vector3(-37, 0, 0),
		"shoulder_r": Vector3(50, 45, 0), "elbow_r": Vector3(50, 0, 0),
		# La funda en la mano izquierda: wrist_l X más negativo sube la punta, Y la abre.
		"shoulder_l": Vector3(-34, 0, 14), "elbow_l": Vector3(87, 0, 0), "wrist_l": Vector3(-28, -40, -22),
		"right_grip": 1.0,
	})


## La pose de carga está en _charge_pose(), compartida con el primer cuadro del
## suelte (sheathe_release), así no hay salto al soltar.
func _add_sheathe_charge(lib: AnimationLibrary) -> void:
	var ready := _charge_pose()
	# "torso": Vector3(-46, 55, -15)})
	lib.add_animation("sheathe_charge", _clip([
		[0.0, ready],
		[1.0, _h.with(ready, {"hips_pos": Vector3(-0.04, -0.45, 0.12)})],
		[2.0, ready],
	], true, true))
	for level: int in CHARGE_SINK.size():
		var sunk := _h.with(ready, CHARGE_SINK[level])
		var breath: Vector3 = sunk["hips_pos"]
		lib.add_animation(CHARGE_SINK_CLIPS[level], _clip([
			[0.0, sunk],
			[1.0, _h.with(sunk, {"hips_pos": breath + Vector3(0, -0.01, 0)})],
			[2.0, sunk],
		], true, true))


## Suelte de Envainar (docs/specs/sheathe-release-animation.md): desde la pose
## de carga, desenvaina hacia la derecha y arriba (nukitsuke), sigue con la hoja
## por encima y detrás de la cabeza con el cuerpo volcado (zanshin), se
## incorpora y sacude la hoja hacia abajo a la derecha (chiburi), y vuelve a la
## guardia. La katana va en la mano derecha (el recorrido lo da el brazo) y la
## funda en la izquierda, que la tira hacia atrás al desenvainar (saya-biki).
## Curva cúbica (fluida). Los primeros 0.5 s son el casteo que compromete
## (sheathe.tres: cast_duration); la vuelta, el chiburi y la guardia son una
## recuperación libre que se corta al moverse o actuar (§10 de la spec).
func _add_sheathe_release(lib: AnimationLibrary) -> void:
	var draw := _h.pose({  # 0.1: el brazo estirado arriba a la derecha
		"hips_pos": Vector3(0, -0.36, 0.08), "hips": Vector3(0, -35, 0),
		"torso": Vector3(-35, 5, 0), "neck": Vector3(30, 10, 0),
		"hip_l": Vector3(-21, 52, -25), "knee_l": Vector3(-65, 0, 0), "ankle_l": Vector3(7, 67, 88),
		"hip_r": Vector3(81, 35, 0), "knee_r": Vector3(-44, 0, 0), "ankle_r": Vector3(-37, 0, 0),
		"shoulder_r": Vector3(165, 57, 8), "elbow_r": Vector3(22, 0, 0), "wrist_r": Vector3(-82, -23, -12),
		"shoulder_l": Vector3(-50, 11, 15), "elbow_l": Vector3(59, 0, 0), "wrist_l": Vector3(-2, -8, -22),
	})
	var follow := _h.pose({  # 0.2: la hoja detrás de la cabeza, el cuerpo volcado
		"hips_pos": Vector3(0, -0.40, 0.1), "hips": Vector3(0, -35, 0),
		"torso": Vector3(-55, -10, 0), "neck": Vector3(35, 20, 0),
		"hip_l": Vector3(-21, 52, -25), "knee_l": Vector3(-65, 0, 0), "ankle_l": Vector3(7, 67, 88),
		"hip_r": Vector3(81, 35, 0), "knee_r": Vector3(-44, 0, 0), "ankle_r": Vector3(-37, 0, 0),
		"shoulder_r": Vector3(254, 34, -52), "elbow_r": Vector3(17, 0, 0), "wrist_r": Vector3(-43, -66, -8),
		"shoulder_l": Vector3(-31, 19, 8), "elbow_l": Vector3(10, 0, 0), "wrist_l": Vector3(33, 1, -6),
	})
	var rise := _stance({  # 0.58: incorporado, la hoja alzada al costado derecho
		"hips_pos": Vector3(0, -0.08, 0), "hips": Vector3(0, -10, 0), "torso": Vector3(-8, 15, 0), "neck": Vector3(6, 0, 0),
		"shoulder_r": Vector3(60, -27, 50), "elbow_r": Vector3(128, 0, 0), "wrist_r": Vector3(-131, 25, 12),
	})
	var chiburi := _stance({  # 0.66: la sacudida, la hoja abajo y adelante a la derecha
		"hips_pos": Vector3(0, -0.1, 0), "hips": Vector3(0, -10, 0), "torso": Vector3(-12, 20, 0), "neck": Vector3(8, -5, 0),
		"shoulder_r": Vector3(25, -3, 44), "elbow_r": Vector3(75, 0, 0), "wrist_r": Vector3(-131, -14, 10),
	})
	lib.add_animation("sheathe_release", _clip([
		[0.0, _charge_pose()],
		[0.03, _h.with(_charge_pose(), {  # tira del mango a lo largo de la funda
			"right_grip": 0.0, "hips_pos": Vector3(-0.02, -0.4, 0.1), "torso": Vector3(-15, 70, -8),
			"shoulder_r": Vector3(59, 92, -2), "elbow_r": Vector3(3, 0, 0), "wrist_r": Vector3(27, 119, -2)})],
		[0.06, _h.with(draw, {  # la mano cruza por delante del pecho, no por la cabeza
			"shoulder_r": Vector3(130, 113, 46), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-20, -7, 0)})],
		[0.1, draw],
		[0.2, follow],
		[0.26, follow],  # sostén: la curva cúbica no se pasa del seguimiento
		[0.4, _h.with(follow, {"torso": Vector3(-56, -10, 0)})],
		[0.5, _h.with(rise, {  # vuelve por el costado derecho, no por encima de la cabeza
			"hips_pos": Vector3(0, -0.2, 0.05), "torso": Vector3(-30, 0, 0),
			"shoulder_r": Vector3(122, -64, 57), "elbow_r": Vector3(69, 0, 0), "wrist_r": Vector3(-122, 32, -2)})],
		[0.58, rise],
		[0.66, chiburi],
		[0.72, chiburi],  # sostén: la hoja no baja más allá del chiburi
		[0.9, _stance()],
	], false, true))


# ---------------------------------------------------------------- COMBO

## With the motion layer the combo is "Nagare" (end of this file); without it,
## the previous five cuts (kept to compare before and after).
func _add_attacks(lib: AnimationLibrary) -> void:
	if _h.motion_enabled:
		_add_nagare(lib)
		return
	_add_horizontal(lib)
	_add_rising_right_to_left(lib)
	_add_vertical(lib)
	_add_rising_left_to_right(lib)
	_add_kesa(lib)


## 1. Tajo horizontal de derecha a izquierda (corte 4): se enrosca con la hoja
## atrás, detrás de la cadera derecha, y la suelta en un arco largo que termina
## con el brazo cruzado bien a la izquierda; la cadera y el torso giran 120°.
func _add_horizontal(lib: AnimationLibrary) -> void:
	var impact := _stance(_h.with(_stride(0.14), {  # la hoja cruza al frente
		"hips": Vector3(0, 0, 0),
		"torso": Vector3(-14, 0, -8), "neck": Vector3(10, 0, 6),
		"shoulder_r": Vector3(92, 4, 0), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-92, 0, 35),
	}))
	var follow := _horizontal_end()
	lib.add_animation("attack_1", _clip([
		[0.0, _stance()],
		[0.06, _stance(_h.with(LEFT_SHEATH_ARM, {  # se enrosca: hoja atrás a la derecha, torso de espaldas al corte
			"hips_pos": Vector3(0, -0.07, 0), "hips": Vector3(0, -36, 0),
			"torso": Vector3(-6, -54, 8), "neck": Vector3(4, 80, -6),
			"shoulder_r": Vector3(78, -84, 22), "elbow_r": Vector3(22, 0, 0), "wrist_r": Vector3(-98, 0, -25),
			"wrist_l": Vector3(-18, 5, 30)}))],  # saya-biki: la funda sigue atrás aunque el torso gire
		[0.14, impact],
		[0.18, follow],
		[0.4, _stance()],
	], false, false, _h.strike_events(0.14, 0.18, 0.22, 0.4), OVERLAP))


## Fin del tajo horizontal: el brazo cruzado bien a la izquierda, en zancada
## (también es el comienzo del golpe 2).
func _horizontal_end() -> Dictionary:
	return _stance(_h.with(_stride(0.14), {
		"hips": Vector3(0, 26, 0),
		"torso": Vector3(-18, 58, -14), "neck": Vector3(12, -76, 10),
		"shoulder_r": Vector3(88, 88, 0), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-88, 0, 45),
	}))


## Fin de la diagonal ascendente: arriba a la izquierda, el cuerpo estirado
## (también es el comienzo del golpe 3).
func _rising_end() -> Dictionary:
	return _stance({
		"hips_pos": Vector3(0, -0.06, 0), "hips": Vector3(0, 12, 0),
		"torso": Vector3(4, 30, 16), "neck": Vector3(-4, -42, -12),
		"hip_l": Vector3(12, -12, -6), "knee_l": Vector3(-16, 0, 0),
		"hip_r": Vector3(-20, -12, 8), "knee_r": Vector3(-10, 0, 0), "ankle_r": Vector3(35, 0, 0),
		"shoulder_r": Vector3(120, 55, 0), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-62, 0, -45),
		# La funda más levantada: el cuerpo estirado la acercaba al piso.
		"shoulder_l": Vector3(-34, 0, 14), "elbow_l": Vector3(87, 0, 0), "wrist_l": Vector3(-43, -41, 22),
	})


## Fin del vertical: la punta en el piso, el cuerpo volcado (también es el
## comienzo del remate).
func _vertical_end() -> Dictionary:
	return _stance(_h.with(_stride(0.2), {
		"hips": Vector3(0, -8, 0),
		"torso": Vector3(-44, -6, 0), "neck": Vector3(34, 14, 0),
		"shoulder_r": Vector3(50, -4, 6), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-62, 0, 0),
	}))


## 2. Diagonal ascendente de abajo a la derecha hasta arriba a la izquierda
## (corte 7): agachado y girado, la hoja sale desde atrás y abajo, y el cuerpo
## se estira hacia arriba con el brazo en alto.
func _add_rising_right_to_left(lib: AnimationLibrary) -> void:
	var impact := _stance({  # la hoja sube cruzando el frente
		"hips_pos": Vector3(0, -0.09, 0), "hips": Vector3(0, -2, 0),
		"torso": Vector3(-8, 0, 10), "neck": Vector3(6, 2, -8),
		"shoulder_r": Vector3(96, 0, 16), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-76, 0, -45),
	})
	var follow := _rising_end()
	lib.add_animation("attack_2", _clip([
		[0.0, _horizontal_end()],
		[0.05, _stance({  # carga: agachado y girado, la hoja baja y atrás a la derecha
			"hips_pos": Vector3(0, -0.12, 0), "hips": Vector3(0, -24, 0),
			"torso": Vector3(-14, -36, -10), "neck": Vector3(10, 60, 8),
			"hip_l": Vector3(34, 30, -6), "knee_l": Vector3(-48, 0, 0),
			"shoulder_r": Vector3(-14, -50, 40), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-98, 0, 40)})],
		[0.08, impact],
		[0.12, follow],
		[0.17, _h.with(follow, {"torso": Vector3(5, 31, 17), "shoulder_r": Vector3(123, 57, 0)})],
		[0.34, _stance()],
	], false, false, _h.strike_events(0.08, 0.12, 0.17, 0.34), OVERLAP))


## 3. Vertical descendente (corte 1): se arquea con la hoja alzada atrás del
## hombro derecho y cae en un arco largo hasta el piso, con el torso volcado.
func _add_vertical(lib: AnimationLibrary) -> void:
	var impact := _stance(_h.with(_stride(0.15), {  # la hoja cae al frente
		"hips": Vector3(0, -8, 0),
		"torso": Vector3(-26, -6, 0), "neck": Vector3(20, 14, 0),
		"shoulder_r": Vector3(100, -4, 4), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-72, 0, 0),
	}))
	var follow := _vertical_end()
	lib.add_animation("attack_3", _clip([
		[0.0, _rising_end()],
		[0.06, _stance({  # carga: arqueado, la hoja alzada atrás del hombro derecho
			"hips_pos": Vector3(0, 0.0, 0), "hips": Vector3(0, -14, 0),
			"torso": Vector3(14, -24, -10), "neck": Vector3(-12, 38, 8),
			"shoulder_r": Vector3(166, -14, 28), "elbow_r": Vector3(18, 0, 0), "wrist_r": Vector3(-34, 0, 0)})],
		[0.1, impact],
		[0.14, follow],
		[0.2, _h.with(follow, {"torso": Vector3(-46, -6, 0), "shoulder_r": Vector3(46, -4, 6)})],
		[0.38, _stance()],
	], false, false, _h.strike_events(0.1, 0.14, 0.2, 0.38), OVERLAP))


## Arriba a la derecha: fin de la subida del remate y comienzo de la kesa.
func _double_top() -> Dictionary:
	# Saya-biki: la muñeca izquierda mantiene la funda atrás con el torso girado.
	return _stance(_h.with(LEFT_SHEATH_ARM, {
		"hips_pos": Vector3(0, -0.01, 0), "hips": Vector3(0, -22, 0),
		"torso": Vector3(10, -40, -16), "neck": Vector3(-8, 60, 12),
		"hip_l": Vector3(14, 22, -6), "knee_l": Vector3(-16, 0, 0),
		"hip_r": Vector3(-14, 22, 8), "knee_r": Vector3(-10, 0, 0),
		"shoulder_r": Vector3(160, -36, 30), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-72, 0, 40),
		"wrist_l": Vector3(-39, -14, 18),
	}))


## 4a. Remate, 1.er impacto: diagonal ascendente de abajo a la izquierda hasta
## arriba a la derecha (corte 6); encadena solo con attack_5 (auto_chain).
func _add_rising_left_to_right(lib: AnimationLibrary) -> void:
	var impact := _stance({  # la hoja sube cruzando el frente
		"hips_pos": Vector3(0, -0.08, 0), "hips": Vector3(0, -2, 0),
		"torso": Vector3(-6, 0, -8), "neck": Vector3(4, 2, 6),
		"shoulder_r": Vector3(100, 0, 12), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-66, 0, 45),
	})
	lib.add_animation("attack_4", _clip([
		[0.0, _vertical_end()],
		[0.05, _stance({  # carga: agachado, el brazo cruzado abajo a la izquierda
			"hips_pos": Vector3(0, -0.14, 0), "hips": Vector3(0, 22, 0),
			"torso": Vector3(-24, 46, 10), "neck": Vector3(16, -68, -8),
			"hip_l": Vector3(34, -22, -6), "knee_l": Vector3(-48, 0, 0), "hip_r": Vector3(-14, -22, 8),
			"shoulder_r": Vector3(22, 70, 0), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-104, 0, -30)})],
		[0.1, impact],
		[0.13, _double_top()],
		[0.24, _double_top()],
	], false, false, _h.strike_events(0.1, 0.13, 0.16, 0.24), OVERLAP))


## 4b. Remate, 2.º impacto: kesa, de arriba a la derecha hasta abajo a la
## izquierda (corte 3), con zancada; queda en zanshin, bajo y volcado.
func _add_kesa(lib: AnimationLibrary) -> void:
	var impact := _stance(_h.with(_stride(0.16), {  # la hoja cae cruzando el frente
		"hips": Vector3(0, 0, 0),
		"torso": Vector3(-24, 6, 10), "neck": Vector3(18, -4, -8),
		"shoulder_r": Vector3(96, 10, 6), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-82, 0, 40),
	}))
	var zanshin := _h.with(impact, {  # abajo a la izquierda, bajo y volcado
		"hips_pos": Vector3(0, -0.2, 0), "hips": Vector3(0, 24, 0),
		"torso": Vector3(-34, 40, 14), "neck": Vector3(24, -60, -10),
		"hip_l": Vector3(55, -24, -6), "hip_r": Vector3(-36, -24, 8),
		"shoulder_r": Vector3(58, 58, 0), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-100, 0, 30),
	})
	lib.add_animation("attack_5", _clip([
		[0.0, _double_top()],
		[0.04, _h.with(_double_top(), {"shoulder_r": Vector3(168, -42, 32), "torso": Vector3(14, -46, -18)})],
		[0.08, impact],
		[0.12, zanshin],
		[0.34, _h.with(zanshin, {"torso": Vector3(-33, 42, 14)})],
		[0.6, _stance()],
	], false, false, _h.strike_events(0.08, 0.12, 0.34, 0.6), OVERLAP))


# ---------------------------------------------------------------- NAGARE

## "Nagare" (poc/samurai-motion): a pendulum of cuts. Each one starts where
## the last one ended and goes back along it: kesa-giri, kiriage, yokogiri,
## tsuki and karatake-wari with chiburi. The feet step in turn (left, right,
## left, long right lunge, stomp) and every cut holds its finish instead of
## going back to the guard. The grip follows the arcs of build_motion(); the
## right arm keys here only matter while an arc blends in or out.

## Right arm with the blade high over the right shoulder.
const ARM_HIGH := {"shoulder_r": Vector3(160, -36, 30), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-72, 0, 40)}
## Right arm with the blade crossing the front.
const ARM_FRONT := {"shoulder_r": Vector3(96, 10, 6), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-82, 0, 40)}
## Right arm crossed low to the left.
const ARM_LOW_LEFT := {"shoulder_r": Vector3(58, 58, 0), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-100, 0, 30)}
## Right arm wound to the right, the blade level behind the hip.
const ARM_WOUND := {"shoulder_r": Vector3(78, -84, 22), "elbow_r": Vector3(22, 0, 0), "wrist_r": Vector3(-98, 0, -25)}
## Right arm swept far to the left.
const ARM_FAR_LEFT := {"shoulder_r": Vector3(88, 88, 0), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-88, 0, 45)}
## Right arm straight to the front (thrust).
const ARM_THRUST := {"shoulder_r": Vector3(92, 4, 0), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-92, 0, 0)}
## Right arm raised over the head.
const ARM_OVERHEAD := {"shoulder_r": Vector3(166, -14, 28), "elbow_r": Vector3(18, 0, 0), "wrist_r": Vector3(-34, 0, 0)}
## Right arm down in front (the tip near the floor).
const ARM_DOWN := {"shoulder_r": Vector3(50, -4, 6), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-62, 0, 0)}


## Long stride with the right leg forward (mirror of _stride).
func _stride_r(depth: float) -> Dictionary:
	return {
		"hips_pos": Vector3(0, -depth, 0),
		"hip_r": Vector3(55, 0, 6), "knee_r": Vector3(-68, 0, 0), "ankle_r": Vector3(12, 0, 0),
		"hip_l": Vector3(-36, 0, -8), "knee_l": Vector3(-12, 0, 0), "ankle_l": Vector3(48, 0, 0),
	}


## A pose of the flow: legs, hips yaw, torso, neck and right arm.
func _flow(legs: Dictionary, yaw: float, torso: Vector3, neck: Vector3, arm: Dictionary) -> Dictionary:
	return _stance(_h.with(_h.with(legs, arm), {"hips": Vector3(0, yaw, 0), "torso": torso, "neck": neck}))


func _nagare_end_1() -> Dictionary:
	return _flow(_stride(0.18), 24, Vector3(-24, 38, -10), Vector3(16, -58, 8), ARM_LOW_LEFT)


func _nagare_end_2() -> Dictionary:
	return _flow(_stride_r(0.06), -22, Vector3(6, -36, -12), Vector3(-6, 52, 10), ARM_HIGH)


func _nagare_end_3() -> Dictionary:
	return _flow(_stride(0.17), 34, Vector3(-16, 62, -12), Vector3(12, -86, 10), ARM_FAR_LEFT)


func _nagare_end_4() -> Dictionary:
	return _flow(_stride_r(0.24), -18, Vector3(-14, -26, 0), Vector3(10, 40, 0), ARM_THRUST)


func _add_nagare(lib: AnimationLibrary) -> void:
	# 1. Kesa-giri: from the low guard the blade rises up the right side, over
	# the shoulder, and falls to low left; the left foot steps in.
	lib.add_animation("attack_1", _clip([
		[0.0, _stance()],
		[0.1, _flow({"hips_pos": Vector3(0, -0.06, 0), "hip_l": Vector3(16, 12, -3), "knee_l": Vector3(-24, 0, 0)},
			-28, Vector3(-2, -34, 8), Vector3(2, 56, -6), ARM_HIGH)],
		[0.17, _flow(_stride(0.14), -2, Vector3(-18, -4, -6), Vector3(12, 6, 4), ARM_FRONT)],
		[0.24, _flow(_stride(0.18), 24, Vector3(-26, 40, -12), Vector3(16, -60, 8), ARM_LOW_LEFT)],
		[0.46, _nagare_end_1()],
	], false, false, _h.strike_events(0.16, 0.21, 0.25, 0.46), OVERLAP))

	# 2. Kiriage: back up the same line, low left to high right; the right foot
	# steps through.
	lib.add_animation("attack_2", _clip([
		[0.0, _nagare_end_1()],
		[0.05, _flow(_stride(0.22), 30, Vector3(-30, 46, -8), Vector3(18, -66, 6), ARM_LOW_LEFT)],
		[0.1, _flow(_stride_r(0.12), -4, Vector3(-8, -6, 10), Vector3(6, 8, -8), ARM_FRONT)],
		[0.16, _flow(_stride_r(0.06), -22, Vector3(8, -38, -14), Vector3(-6, 54, 10), ARM_HIGH)],
		[0.36, _nagare_end_2()],
	], false, false, _h.strike_events(0.09, 0.13, 0.17, 0.36), OVERLAP))

	# 3. Yokogiri: the blade drops from high right to the right side while the
	# hips wind, then sweeps level to far left with the whole body; left foot.
	lib.add_animation("attack_3", _clip([
		[0.0, _nagare_end_2()],
		[0.1, _flow(_stride_r(0.1), -38, Vector3(-6, -60, 6), Vector3(4, 86, -4), ARM_WOUND)],
		[0.165, _flow(_stride(0.15), 0, Vector3(-14, 0, -8), Vector3(10, 0, 6), ARM_FRONT)],
		[0.24, _flow(_stride(0.17), 34, Vector3(-18, 66, -14), Vector3(12, -88, 10), ARM_FAR_LEFT)],
		[0.46, _nagare_end_3()],
	], false, false, _h.strike_events(0.15, 0.2, 0.24, 0.46), OVERLAP))

	# 4. Tsuki: the blade comes back to the right hip and shoots straight out,
	# with a long lunge of the right leg; chains into the finisher.
	lib.add_animation("attack_4", _clip([
		[0.0, _nagare_end_3()],
		[0.075, _flow(_stride(0.12), 8, Vector3(-8, 16, 2), Vector3(6, -22, 0), ARM_THRUST)],
		[0.12, _flow(_stride_r(0.24), -18, Vector3(-14, -26, 0), Vector3(10, 40, 0), ARM_THRUST)],
		[0.3, _nagare_end_4()],
	], false, false, _h.strike_events(0.1, 0.14, 0.16, 0.3), OVERLAP))

	# 5. Karatake-wari: from the thrust the blade rises over the head and splits
	# straight down with a stomp; zanshin, a chiburi flick to the right and
	# back to the low guard.
	lib.add_animation("attack_5", _clip([
		[0.0, _nagare_end_4()],
		[0.1, _flow(_stride_r(0.1), -6, Vector3(14, -10, 0), Vector3(-12, 12, 0), ARM_OVERHEAD)],
		[0.145, _flow(_stride(0.2), 0, Vector3(-30, 0, 0), Vector3(22, 0, 0), ARM_FRONT)],
		[0.2, _flow(_stride(0.25), 0, Vector3(-40, 2, 0), Vector3(30, -2, 0), ARM_DOWN)],
		[0.42, _flow(_stride(0.23), 0, Vector3(-36, 4, 0), Vector3(26, -4, 0), ARM_DOWN)],
		[0.5, _flow(_stride(0.2), -10, Vector3(-22, -14, 0), Vector3(14, 18, 0), LOW_BLADE)],
		[0.9, _stance()],
	], false, false, _h.strike_events(0.14, 0.18, 0.5, 0.9), OVERLAP))
