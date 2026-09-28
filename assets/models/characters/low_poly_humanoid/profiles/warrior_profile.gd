@tool
extends HumanoidProfile
## Guerrero (espada de armas y escudo de caballero): reposo y marcha de
## caballero, estocadas y tajos alternados, sin perder la base
## (docs/specs/class-combat-identity.md §3.1, docs/specs/warrior-sword-and-shield.md).
## Reposo: erguido y casi de frente, la espada colgando baja a la derecha y el
## escudo al costado izquierdo (referencias del responsable). El combo arranca
## en el reposo y vuelve a él.
## Combo: estocada, tajo diagonal descendente, revés ascendente y estocada
## profunda, con arcos amplios, zancadas bajas y el torso volcado sobre el
## corte (referencia: Kaeya de Genshin Impact). Cada golpe gira la
## cadera y el torso, abre el hombro y rota la muñeca; el escudo cubre el pecho
## en la anticipación y en el impacto queda adelante, frente a la cintura (o
## recogido contra el costado cuando el torso gira a la derecha).
## Los tiempos de los eventos coinciden con data/classes/warrior/warrior_combo.tres.

## Brazo del arma en reposo: cuelga junto al muslo, la hoja baja adelante y a
## la derecha (≈ 42° bajo la horizontal, la punta cerca del piso).
const REST_BLADE := {
	"shoulder_r": Vector3(-22, -22, -12), "elbow_r": Vector3(86, 0, 0), "wrist_r": Vector3(-110, -4, -5),
}
## Brazo del escudo en reposo: la mano a la altura de la cadera, el escudo al
## costado izquierdo, vertical, la cara mirando adelante y afuera (≈ 37°).
const SHIELD_ARM := {
	"shoulder_l": Vector3(-47, -35, -10), "elbow_l": Vector3(94, 0, 0), "wrist_l": Vector3(-47, -1, 9),
}
## El escudo sube al frente del pecho, la cara al frente (relativo al torso).
const SHIELD_COVER := {
	"shoulder_l": Vector3(56, -24, -1), "elbow_l": Vector3(58, 0, 0), "wrist_l": Vector3(-37, -102, 111),
}
## El escudo recogido contra el costado izquierdo, la cara afuera (relativo al torso).
const SHIELD_TUCK := {
	"shoulder_l": Vector3(-56, -5, -33), "elbow_l": Vector3(128, 0, 0), "wrist_l": Vector3(-61, 13, 6),
}
## El escudo adelante, frente a la cintura, la cara adelante y afuera (relativo al
## torso): en los golpes que giran el torso a la izquierda, así no pasa detrás
## de la espalda.
const SHIELD_FORE := {
	"shoulder_l": Vector3(10, -79, -51), "elbow_l": Vector3(39, 0, 0), "wrist_l": Vector3(-56, 16, 35),
}
## Escudo al frente a la altura del pecho, empujando: el brazo más estirado
## que en SHIELD_COVER (Carga de escudo, docs/specs/warrior-abilities-rework.md §4.8).
const SHIELD_BASH := {
	"shoulder_l": Vector3(64, -22, -1), "elbow_l": Vector3(30, 0, 0), "wrist_l": Vector3(-37, -102, 111),
}
## Brazo de la espada al cargar: la hoja lista, adelante y a la derecha, alta,
## así la punta no toca el piso con el torso volcado.
const CHARGE_BLADE := {
	"shoulder_r": Vector3(-20, -22, -12), "elbow_r": Vector3(90, 0, 0), "wrist_r": Vector3(-30, -4, -5),
}
## Escudo alto, cubriendo el torso y la cabeza (Parada).
const SHIELD_BLOCK := {
	"shoulder_l": Vector3(74, -26, -1), "elbow_l": Vector3(62, 0, 0), "wrist_l": Vector3(-37, -102, 111),
}
## Muñeca del arma al marchar: la hoja un poco más alta que en reposo, porque el
## torso se inclina y el brazo se balancea (la punta no toca el piso).
const WALK_WRIST := Vector3(-101, -4, -5)
## Muñeca del arma levantada (al saltar y al volver del tajo bajo): la hoja más
## alta, así la punta no se clava en el piso.
const LIFTED_WRIST := Vector3(-70, -4, -5)
## Muñeca del arma al correr (sprint-stamina.md): la hoja atrás y baja, sin
## tocar el piso aunque el torso se vuelque.
const SPRINT_WRIST := Vector3(-60, -4, -5)
## Zancada baja con la pierna izquierda adelante (golpes a fondo).
const DEEP_STRIDE := {
	"hip_l": Vector3(62, -10, -6), "knee_l": Vector3(-78, 0, 0), "ankle_l": Vector3(16, 0, 0),
	"hip_r": Vector3(-38, -10, 8), "knee_r": Vector3(-22, 0, 0), "ankle_r": Vector3(52, 0, 0),
}

var _h: LowPolyHumanoid


func build(humanoid: LowPolyHumanoid) -> AnimationLibrary:
	_h = humanoid
	var lib := AnimationLibrary.new()
	_add_idle(lib)
	_add_run(lib)
	_add_sprint(lib)
	_add_dash(lib)
	_add_jump(lib)
	_add_hit(lib)
	_add_attacks(lib)
	_add_shield_charge(lib)
	_add_parry(lib)
	return lib


# ---------------------------------------------------------------- REPOSO

## Reposo de caballero: erguido, casi de frente, los pies al ancho de los
## hombros con el izquierdo apenas adelante y el peso en el derecho.
func _stance(over := {}) -> Dictionary:
	return _h.with(_h.pose(_h.with(_h.with({
		"hips_pos": Vector3(0, -0.02, 0),
		"hips": Vector3(0, -5, 0),
		"torso": Vector3(2, -5, 0), "neck": Vector3(-3, 9, 0),
		"hip_l": Vector3(10, 8, -5), "knee_l": Vector3(-14, 0, 0), "ankle_l": Vector3(4, 0, 0),
		"hip_r": Vector3(-4, 8, 5), "knee_r": Vector3(-8, 0, 0), "ankle_r": Vector3(12, 0, 0),
	}, REST_BLADE), SHIELD_ARM)), over)


func _add_idle(lib: AnimationLibrary) -> void:
	# Respiración lenta y pareja (2 s): la cadera baja, el pecho sube y el
	# escudo y la punta de la espada acompañan apenas.
	lib.add_animation("idle", _h.make_clip([
		[0.0, _stance()],
		[1.0, _stance({"hips_pos": Vector3(0, -0.04, 0), "torso": Vector3(-1, -6, 0), "neck": Vector3(0, 10, 0),
				"shoulder_l": Vector3(-44, -35, -12), "shoulder_r": Vector3(-19, -22, -14)})],
		[2.0, _stance()],
	], true, true))


# ---------------------------------------------------------------- MARCHA

## Apoyo: m = 1 pie derecho adelante. Torso erguido con un contragiro leve; la
## espada cuelga baja y se balancea con el paso, el escudo va firme al costado.
func _run_contact(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with(_h.with(_h.with({
		"hips_pos": Vector3(0, -0.04, 0),
		"hips": Vector3(0, 8 * m, 0),
		"torso": Vector3(-5, -12 * m, 0), "neck": Vector3(3, 4 * m, 0),
		"hip_" + f: Vector3(30, 0, 0), "knee_" + f: Vector3(-10, 0, 0), "ankle_" + f: Vector3(-8, 0, 0),
		"hip_" + b: Vector3(-24, 0, 0), "knee_" + b: Vector3(-36, 0, 0), "ankle_" + b: Vector3(22, 0, 0),
	}, REST_BLADE), SHIELD_ARM), {
		"shoulder_r": Vector3(-25 if m == 1 else -20, -22, -12), "wrist_r": WALK_WRIST,
		"shoulder_l": Vector3(-42 if m == 1 else -52, -35, -10),
	}))


func _run_pass(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with(_h.with(_h.with({
		"hips_pos": Vector3(0, 0.0, 0),
		"torso": Vector3(-5, 0, 0), "neck": Vector3(3, 0, 0),
		"hip_" + f: Vector3(4, 0, 0), "knee_" + f: Vector3(-14, 0, 0), "ankle_" + f: Vector3(10, 0, 0),
		"hip_" + b: Vector3(22, 0, 0), "knee_" + b: Vector3(-70, 0, 0), "ankle_" + b: Vector3(26, 0, 0),
	}, REST_BLADE), SHIELD_ARM), {"wrist_r": WALK_WRIST}))


func _add_run(lib: AnimationLibrary) -> void:
	lib.add_animation("run", _h.make_clip([
		[0.0, _run_contact(1)], [0.15, _run_pass(1)],
		[0.3, _run_contact(-1)], [0.45, _run_pass(-1)],
		[0.6, _run_contact(1)],
	], true, true))

	# Frenada: planta el pie adelantado, el escudo se recoge y vuelve al reposo.
	lib.add_animation("run_stop", _h.make_clip([
		[0.0, _run_contact(-1)],
		[0.1, _stance(_h.with(SHIELD_TUCK, {
			"hips_pos": Vector3(0, -0.08, 0), "hips": Vector3(0, -10, 0),
			"torso": Vector3(4, -10, 0), "neck": Vector3(-2, 18, 0),
			"hip_l": Vector3(30, 8, -6), "knee_l": Vector3(-12, 0, 0), "ankle_l": Vector3(-16, 0, 0),
			"hip_r": Vector3(-12, 8, 6), "knee_r": Vector3(-40, 0, 0), "ankle_r": Vector3(38, 0, 0),
			"shoulder_r": Vector3(-10, -22, -12)}))],
		[0.35, _stance()],
	], false, true))


# ---------------------------------------------------------------- SPRINT

## Carga (docs/specs/sprint-stamina.md): el torso volcado detrás del escudo,
## que sube al pecho, zancadas largas con la rodilla alta y la espada atrás y
## baja, balanceándose con el brazo. m = 1 pie derecho adelante.
func _sprint_contact(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with(_h.with({
		"hips_pos": Vector3(0, -0.1, 0),
		"hips": Vector3(0, 10 * m, 0),
		"torso": Vector3(-30, -12 * m, 0), "neck": Vector3(24, 4 * m, 0),
		"hip_" + f: Vector3(58, 0, 0), "knee_" + f: Vector3(-24, 0, 0), "ankle_" + f: Vector3(-10, 0, 0),
		"hip_" + b: Vector3(-42, 0, 0), "knee_" + b: Vector3(-58, 0, 0), "ankle_" + b: Vector3(30, 0, 0),
	}, SHIELD_COVER), {
		"shoulder_r": Vector3(4 if m == 1 else 16, -22, -12), "elbow_r": Vector3(40, 0, 0), "wrist_r": SPRINT_WRIST,
	}))


func _sprint_pass(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with(_h.with({
		"hips_pos": Vector3(0, 0.03, 0),
		"torso": Vector3(-28, 0, 0), "neck": Vector3(22, 0, 0),
		"hip_" + f: Vector3(6, 0, 0), "knee_" + f: Vector3(-20, 0, 0), "ankle_" + f: Vector3(12, 0, 0),
		"hip_" + b: Vector3(50, 0, 0), "knee_" + b: Vector3(-118, 0, 0), "ankle_" + b: Vector3(34, 0, 0),
	}, SHIELD_COVER), {
		"shoulder_r": Vector3(10, -22, -12), "elbow_r": Vector3(46, 0, 0), "wrist_r": SPRINT_WRIST,
	}))


func _add_sprint(lib: AnimationLibrary) -> void:
	lib.add_animation("sprint", _h.make_clip([
		[0.0, _sprint_contact(1)], [0.11, _sprint_pass(1)],
		[0.22, _sprint_contact(-1)], [0.33, _sprint_pass(-1)],
		[0.44, _sprint_contact(1)],
	], true, true))

	# Arranque: se agacha y empuja con la pierna de atrás estirada, el escudo
	# sube al pecho; termina en el primer cuadro de sprint.
	lib.add_animation("sprint_start", _h.make_clip([
		[0.0, _stance()],
		[0.1, _h.with(_sprint_contact(1), {
			"hips_pos": Vector3(0, -0.17, 0), "torso": Vector3(-34, -6, 0), "neck": Vector3(26, 2, 0),
			"hip_l": Vector3(-50, 0, 0), "knee_l": Vector3(-14, 0, 0), "ankle_l": Vector3(40, 0, 0)})],
		[0.24, _sprint_contact(1)],
	], false, true))

	# Frenada: derrapa con el pie adelantado estirado y el peso atrás, el
	# escudo se recoge contra el costado y vuelve al reposo.
	lib.add_animation("sprint_stop", _h.make_clip([
		[0.0, _sprint_contact(-1)],
		[0.14, _stance(_h.with(SHIELD_TUCK, {
			"hips_pos": Vector3(0, -0.2, 0), "hips": Vector3(0, -18, 0),
			"torso": Vector3(10, -14, 0), "neck": Vector3(-6, 26, 0),
			"hip_l": Vector3(52, 18, -8), "knee_l": Vector3(-6, 0, 0), "ankle_l": Vector3(-22, 0, 0),
			"hip_r": Vector3(-14, 18, 8), "knee_r": Vector3(-76, 0, 0), "ankle_r": Vector3(52, 0, 0),
			"shoulder_r": Vector3(-10, -22, -12), "wrist_r": WALK_WRIST}))],
		[0.26, _stance(_h.with(SHIELD_TUCK, {
			"hips_pos": Vector3(0, -0.12, 0), "hips": Vector3(0, -12, 0),
			"torso": Vector3(4, -10, 0), "neck": Vector3(-2, 18, 0),
			"hip_l": Vector3(34, 10, -6), "knee_l": Vector3(-14, 0, 0), "ankle_l": Vector3(-14, 0, 0),
			"hip_r": Vector3(-10, 10, 6), "knee_r": Vector3(-44, 0, 0), "ankle_r": Vector3(38, 0, 0)}))],
		[0.46, _stance()],
	], false, true))


# ---------------------------------------------------------------- DASH

## Dash (docs/specs/dash-feel.md): impulso, estirado y el primer cuadro de
## sprint, en las fracciones 0, 0.35 y 1 (la regla de conexión). Los brazos
## son los del sprint en todo el clip: el arma no cambia de agarre.
## Guerrero: embestida baja detrás del escudo.
func _add_dash(lib: AnimationLibrary) -> void:
	var run_in := _sprint_contact(1)
	lib.add_animation("dash", _h.make_clip([
		[0.0, _h.with(run_in, {
			"hips_pos": Vector3(0, -0.18, 0), "hips": Vector3(0, 6, 0),
			"torso": Vector3(-38, -8, 0), "neck": Vector3(30, 2, 0),
			"hip_l": Vector3(40, 0, 0), "knee_l": Vector3(-56, 0, 0), "ankle_l": Vector3(16, 0, 0),
			"hip_r": Vector3(-48, 0, 0), "knee_r": Vector3(-10, 0, 0), "ankle_r": Vector3(42, 0, 0)})],
		[0.084, _h.with(run_in, {
			"hips_pos": Vector3(0, -0.06, 0), "hips": Vector3(0, 12, 0),
			"torso": Vector3(-34, -14, 0), "neck": Vector3(26, 5, 0),
			"hip_r": Vector3(72, 0, 0), "knee_r": Vector3(-18, 0, 0), "ankle_r": Vector3(-14, 0, 0),
			"hip_l": Vector3(-56, 0, 0), "knee_l": Vector3(-44, 0, 0), "ankle_l": Vector3(34, 0, 0)})],
		[0.24, run_in],
	], false, true))


# ---------------------------------------------------------------- SALTO

func _add_jump(lib: AnimationLibrary) -> void:
	# Salto compacto: la espada baja y el escudo recogido contra el costado.
	var arms := _h.with(_h.with(REST_BLADE, SHIELD_TUCK), {"wrist_r": LIFTED_WRIST})
	lib.add_animation("jump_start", _h.make_clip([
		[0.0, _stance()],
		[0.08, _h.crouch(arms)],
		[0.18, _h.pose(_h.with(arms, {
			"hips_pos": Vector3(0, 0.05, 0), "torso": Vector3(-5, 0, 0),
			"hip_l": Vector3(-5, 0, 0), "ankle_l": Vector3(-35, 0, 0),
			"hip_r": Vector3(10, 0, 0), "knee_r": Vector3(-30, 0, 0), "ankle_r": Vector3(-20, 0, 0),
			"shoulder_r": Vector3(-40, -22, -12)}))],
	]))

	var air := _h.with(arms, {
		"torso": Vector3(-6, 0, 0),
		"hip_r": Vector3(65, 0, 0), "knee_r": Vector3(-100, 0, 0), "ankle_r": Vector3(20, 0, 0),
		"hip_l": Vector3(45, 0, 0), "knee_l": Vector3(-85, 0, 0), "ankle_l": Vector3(20, 0, 0),
	})
	lib.add_animation("jump_air", _h.make_clip([
		[0.0, _h.pose(air)],
		[0.3, _h.pose(_h.with(air, {"hip_l": Vector3(50, 0, 0), "torso": Vector3(-6, -6, 0),
				"shoulder_r": Vector3(-28, -22, -12)}))],
		[0.6, _h.pose(air)],
	], true, true))

	# Amortigua y vuelve directo al reposo.
	var land := _h.crouch(_h.with(arms, {"hips_pos": Vector3(0, -0.2, 0)}))
	lib.add_animation("jump_land", _h.make_clip([
		[0.0, land], [0.06, land], [0.28, _stance()],
	]))


func _add_hit(lib: AnimationLibrary) -> void:
	# Retrocede medio paso y se cubre con el escudo, sin soltar la espada.
	lib.add_animation("hit", _h.make_clip([
		[0.0, _stance()],
		[0.08, _stance(_h.with(SHIELD_COVER, {
			"hips_pos": Vector3(0, -0.06, 0.07), "hips": Vector3(0, 6, 0),
			"torso": Vector3(14, 12, 0), "neck": Vector3(15, -6, 0),
			"shoulder_r": Vector3(-34, -22, -4)}))],
		[0.35, _stance()],
	]))


# ---------------------------------------------------------------- COMBO

func _add_attacks(lib: AnimationLibrary) -> void:
	_add_jab(lib)
	_add_slash(lib)
	_add_backhand(lib)
	_add_deep_thrust(lib)


## 1. Estocada rápida: desde el reposo sube la espada a la cadera y se enrosca
## tras el escudo; al soltar se tira a fondo, el hombro derecho sale adelante y
## el escudo baja frente a la cintura.
func _add_jab(lib: AnimationLibrary) -> void:
	var extended := _stance(_h.with(_h.with(DEEP_STRIDE, SHIELD_FORE), {
		"hips_pos": Vector3(0, -0.16, 0), "hips": Vector3(0, 16, 0),
		"torso": Vector3(-24, 30, -6), "neck": Vector3(18, -38, 4),
		"shoulder_r": Vector3(96, -34, 6), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-76, 0, 0),
	}))
	lib.add_animation("attack_1", _h.make_clip([
		[0.0, _stance()],
		[0.06, _stance(_h.with(SHIELD_COVER, {  # se enrosca: espada a la cadera, escudo al frente
			"hips_pos": Vector3(0, -0.09, 0.02), "hips": Vector3(0, -22, 0),
			"torso": Vector3(-4, -42, 4), "neck": Vector3(2, 50, -4),
			"shoulder_r": Vector3(-24, 26, 28), "elbow_r": Vector3(96, 0, 0), "wrist_r": Vector3(-72, 0, 12)}))],
		[0.1, extended],  # impacto
		[0.16, _h.with(extended, {"torso": Vector3(-26, 34, -7), "shoulder_r": Vector3(98, -36, 6)})],  # sostiene
		[0.4, _stance()],
	], false, false, _h.strike_events(0.1, 0.16, 0.22, 0.4)))


## 2. Tajo diagonal descendente amplio: la espada sube detrás del hombro
## derecho con el cuerpo erguido y el escudo al frente, y cae en un arco grande
## hasta abajo a la izquierda, con zancada, el torso volcado sobre el corte y el
## escudo frente a la cintura.
func _add_slash(lib: AnimationLibrary) -> void:
	var impact := _stance(_h.with(_h.with(DEEP_STRIDE, SHIELD_FORE), {  # la hoja cruza al frente, en diagonal
		"hips_pos": Vector3(0, -0.15, 0), "hips": Vector3(0, 4, 0),
		"torso": Vector3(-22, 8, -8), "neck": Vector3(16, -4, 6),
		"shoulder_r": Vector3(100, 10, 10), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-90, 0, 45),
	}))
	var follow := _h.with(impact, {  # termina baja a la izquierda, todo el cuerpo detrás
		"hips_pos": Vector3(0, -0.18, 0), "hips": Vector3(0, 22, 0),
		"torso": Vector3(-34, 58, -14), "neck": Vector3(24, -52, 10),
		"shoulder_r": Vector3(52, 64, 10), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-70, 0, 50),
	})
	lib.add_animation("attack_2", _h.make_clip([
		[0.0, _stance(_h.with(SHIELD_FORE, {"hips_pos": Vector3(0, -0.1, 0), "torso": Vector3(-14, 20, 0), "neck": Vector3(10, -14, 0),
				"shoulder_r": Vector3(80, -24, 6), "elbow_r": Vector3(6, 0, 0), "wrist_r": Vector3(-76, 0, 0)}))],
		[0.08, _stance(_h.with(SHIELD_COVER, {  # anticipación: se yergue, gira atrás y alza la espada sobre el hombro derecho
			"hips_pos": Vector3(0, -0.03, 0), "hips": Vector3(0, -22, 0),
			"torso": Vector3(6, -62, 10), "neck": Vector3(-4, 62, -8),
			"hip_l": Vector3(22, 22, -6), "hip_r": Vector3(-8, 22, 6),
			"shoulder_r": Vector3(150, -40, 30), "elbow_r": Vector3(30, 0, 0), "wrist_r": Vector3(-20, 0, 40)}))],
		[0.12, impact],
		[0.16, follow],  # seguimiento
		[0.2, _h.with(follow, {"torso": Vector3(-36, 62, -15), "shoulder_r": Vector3(48, 68, 10)})],  # sostiene
		[0.32, _stance({"wrist_r": LIFTED_WRIST})],  # vuelve con la hoja alta, sin rozar el piso
		[0.44, _stance()],
	], false, false, _h.strike_events(0.12, 0.2, 0.26, 0.44)))


## 3. Revés diagonal ascendente amplio: desde abajo a la izquierda (donde
## terminó el tajo) sube en un arco grande hasta arriba a la derecha, y el
## cuerpo se estira hacia arriba al terminar; el escudo se recoge contra el costado.
func _add_backhand(lib: AnimationLibrary) -> void:
	var impact := _stance(_h.with(SHIELD_TUCK, {  # la hoja cruza al frente, subiendo
		"hips_pos": Vector3(0, -0.1, 0), "hips": Vector3(0, -2, 0),
		"torso": Vector3(-14, -6, 6), "neck": Vector3(10, 8, -4),
		"hip_r": Vector3(30, 0, 6), "knee_r": Vector3(-40, 0, 0), "ankle_r": Vector3(8, 0, 0),
		"shoulder_r": Vector3(92, -10, 10), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-80, 0, -40),
	}))
	var follow := _h.with(impact, {  # termina arriba a la derecha, el cuerpo estirado
		"hips_pos": Vector3(0, -0.02, 0), "hips": Vector3(0, -24, 0),
		"torso": Vector3(6, -56, 12), "neck": Vector3(-4, 60, -10),
		"hip_l": Vector3(20, 24, -6), "hip_r": Vector3(20, 24, 6),
		"shoulder_r": Vector3(155, -50, 20), "elbow_r": Vector3(10, 0, 0), "wrist_r": Vector3(-30, 0, -40),
	})
	lib.add_animation("attack_3", _h.make_clip([
		[0.0, _stance(_h.with(SHIELD_FORE, {"hips_pos": Vector3(0, -0.16, 0), "hips": Vector3(0, 20, 0),
				"torso": Vector3(-32, 55, -12), "neck": Vector3(22, -50, 8),
				"shoulder_r": Vector3(52, 64, 10), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-70, 0, 50)}))],
		[0.08, _stance(_h.with(_h.with(DEEP_STRIDE, SHIELD_FORE), {  # carga: agachado, la espada baja y atrás a la izquierda
			"hips_pos": Vector3(0, -0.17, 0), "hips": Vector3(0, 24, 0),
			"torso": Vector3(-30, 66, -10), "neck": Vector3(20, -60, 8),
			"shoulder_r": Vector3(30, 80, 0), "elbow_r": Vector3(30, 0, 0), "wrist_r": Vector3(-90, 0, 30),
			"shoulder_l": Vector3(10, -95, -51)}))],  # el escudo cruza adelante: el torso gira 90°
		[0.12, impact],
		[0.16, follow],  # seguimiento
		[0.2, _h.with(follow, {"torso": Vector3(8, -60, 13), "shoulder_r": Vector3(158, -54, 20)})],  # sostiene
		[0.44, _stance()],
	], false, false, _h.strike_events(0.12, 0.2, 0.26, 0.44)))


## 4. Remate: se enrosca con la espada recogida tras el escudo, y descarga una
## estocada a fondo, muy baja: la cadera y el hombro derecho salen adelante, el
## torso se vuelca y el escudo baja frente a la cintura.
func _add_deep_thrust(lib: AnimationLibrary) -> void:
	var lunge := _stance(_h.with(SHIELD_FORE, {
		"hips_pos": Vector3(0, -0.22, 0), "hips": Vector3(0, 18, 0),
		"torso": Vector3(-30, 36, -8), "neck": Vector3(24, -48, 6),
		"hip_l": Vector3(72, -18, -6), "knee_l": Vector3(-88, 0, 0), "ankle_l": Vector3(16, 0, 0),
		"hip_r": Vector3(-45, -18, 8), "knee_r": Vector3(-10, 0, 0), "ankle_r": Vector3(55, 0, 0),
		"shoulder_r": Vector3(100, -40, 0), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-72, 0, 0),
	}))
	lib.add_animation("attack_4", _h.make_clip([
		[0.0, _stance()],
		[0.16, _stance(_h.with(SHIELD_COVER, {  # se enrosca: espada junto al pecho, escudo al frente
			"hips_pos": Vector3(0, -0.1, 0.04), "hips": Vector3(0, -24, 0),
			"torso": Vector3(0, -60, 6), "neck": Vector3(0, 70, -6),
			"hip_l": Vector3(26, 24, -6), "hip_r": Vector3(-14, 24, 6), "knee_r": Vector3(-36, 0, 0), "ankle_r": Vector3(38, 0, 0),
			"shoulder_r": Vector3(12, 50, 26), "elbow_r": Vector3(112, 0, 0), "wrist_r": Vector3(-120, 0, 15)}))],
		[0.24, lunge],  # impacto
		[0.32, _h.with(lunge, {"torso": Vector3(-32, 40, -9), "shoulder_r": Vector3(102, -42, 0)})],  # sostiene
		[0.46, _h.with(lunge, {"hips_pos": Vector3(0, -0.16, 0), "hips": Vector3(0, 8, 0),
				"torso": Vector3(-18, 18, -4)})],
		[0.7, _stance()],
	], false, false, _h.strike_events(0.24, 0.32, 0.46, 0.7)))


# ---------------------------------------------------------------- HABILIDADES

## Carga de escudo (docs/specs/warrior-abilities-rework.md §4.8): el torso
## volcado detrás del escudo, que empuja al frente del pecho; zancadas cortas y
## la espada atrás y alta, lista. m = 1 pie derecho adelante.
func _charge_step(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with(_h.with(_h.with({
		"hips_pos": Vector3(0, -0.14, 0),
		"hips": Vector3(0, 14 * m, 0),
		"torso": Vector3(-36, -16, 0), "neck": Vector3(30, 10, 0),
		"hip_" + f: Vector3(52, 0, 0), "knee_" + f: Vector3(-34, 0, 0), "ankle_" + f: Vector3(-4, 0, 0),
		"hip_" + b: Vector3(-36, 0, 0), "knee_" + b: Vector3(-50, 0, 0), "ankle_" + b: Vector3(30, 0, 0),
	}, CHARGE_BLADE), SHIELD_BASH), {
		"shoulder_r": Vector3(-24 if m == 1 else -16, -22, -12),
	}))


func _add_shield_charge(lib: AnimationLibrary) -> void:
	lib.add_animation("shield_charge", _h.make_clip([
		[0.0, _charge_step(1)], [0.2, _charge_step(-1)], [0.4, _charge_step(1)],
	], true, true))

	# Golpe de escudo: recoge el escudo contra el pecho y lo descarga al frente
	# con todo el cuerpo (pico en bash_hit_time = 0.08 s), y vuelve al reposo.
	var push := _stance(_h.with(_h.with(DEEP_STRIDE, SHIELD_BASH), {
		"hips_pos": Vector3(0, -0.2, 0), "hips": Vector3(0, -18, 0),
		"torso": Vector3(-32, -34, 4), "neck": Vector3(26, 40, -4),
		"shoulder_l": Vector3(78, -14, -1), "elbow_l": Vector3(8, 0, 0),
		"shoulder_r": Vector3(-26, -22, -12), "elbow_r": Vector3(90, 0, 0), "wrist_r": Vector3(-30, -4, -5),
	}))
	lib.add_animation("shield_bash", _h.make_clip([
		[0.0, _stance(_h.with(SHIELD_COVER, {
			"hips_pos": Vector3(0, -0.14, 0), "hips": Vector3(0, 10, 0),
			"torso": Vector3(-28, 6, 0), "neck": Vector3(22, -4, 0),
			"hip_l": Vector3(40, 8, -5), "knee_l": Vector3(-40, 0, 0), "ankle_l": Vector3(4, 0, 0),
			"hip_r": Vector3(-24, 8, 5), "knee_r": Vector3(-30, 0, 0), "ankle_r": Vector3(30, 0, 0),
			"shoulder_r": Vector3(-20, -22, -12), "elbow_r": Vector3(90, 0, 0), "wrist_r": Vector3(-30, -4, -5)}))],
		[0.08, push],  # empujón
		[0.16, _h.with(push, {"torso": Vector3(-34, -38, 5), "shoulder_l": Vector3(80, -12, -1)})],  # sostiene
		[0.35, _stance()],
	], false, false, [[0.08, "bash"]]))


## Parada: el escudo sube de golpe y cubre el torso y la cabeza, el peso
## adelante, la espada atrás y lista (escudo arriba en raise_time = 0.06 s).
func _block_pose(over := {}) -> Dictionary:
	return _stance(_h.with(_h.with(SHIELD_BLOCK, {
		"hips_pos": Vector3(0, -0.12, 0), "hips": Vector3(0, -12, 0),
		"torso": Vector3(-14, -22, 0), "neck": Vector3(8, 26, 0),
		"hip_l": Vector3(36, 10, -6), "knee_l": Vector3(-40, 0, 0), "ankle_l": Vector3(4, 0, 0),
		"hip_r": Vector3(-20, 10, 6), "knee_r": Vector3(-34, 0, 0), "ankle_r": Vector3(34, 0, 0),
		"shoulder_r": Vector3(-6, 20, 20), "elbow_r": Vector3(100, 0, 0), "wrist_r": Vector3(-80, 0, 12),
	}), over))


func _add_parry(lib: AnimationLibrary) -> void:
	var block := _block_pose()
	# Parry (docs/specs/parry-riposte-rework.md §2.2): el escudo aparece al
	# frente de golpe (el clip arranca ya en el bloqueo y se entra sin mezcla),
	# pasado de largo con el cuerpo sobregirado, y se asienta.
	lib.add_animation("shield_parry", _h.make_clip([
		[0.0, _block_pose(_h.with(SHIELD_BASH, {"torso": Vector3(-20, -34, 2), "hips_pos": Vector3(0, -0.16, 0)}))],  # pasado de largo
		[0.06, block],  # se asienta
		[0.2, _block_pose({"hips_pos": Vector3(0, -0.13, 0), "torso": Vector3(-15, -23, 0)})],
		[0.35, _block_pose({"torso": Vector3(-16, -24, 0), "hips_pos": Vector3(0, -0.14, 0)})],
	], false, false, [[0.0, "raise"]]))

	# Parada fallida: el escudo baja pesado y el torso cae, expuesto.
	lib.add_animation("shield_parry_whiff", _h.make_clip([
		[0.0, block],
		[0.16, _stance(_h.with(SHIELD_TUCK, {
			"hips_pos": Vector3(0, -0.16, 0), "hips": Vector3(0, 6, 0),
			"torso": Vector3(-24, 10, 0), "neck": Vector3(18, -6, 0),
			"hip_l": Vector3(30, 8, -6), "knee_l": Vector3(-44, 0, 0), "ankle_l": Vector3(12, 0, 0),
			"hip_r": Vector3(-14, 8, 6), "knee_r": Vector3(-40, 0, 0), "ankle_r": Vector3(38, 0, 0),
			"shoulder_r": Vector3(-26, -22, -12), "wrist_r": LIFTED_WRIST}))],
		[0.4, _stance()],
	], false, true))

	# Contragolpe: desde el bloqueo, la estocada sale por el costado del escudo
	# (extensión en riposte_hit_time = 0.15 s; la hoja barre entre 0.08 y 0.25).
	var extended := _stance(_h.with(_h.with(DEEP_STRIDE, SHIELD_FORE), {
		"hips_pos": Vector3(0, -0.18, 0), "hips": Vector3(0, 18, 0),
		"torso": Vector3(-26, 34, -6), "neck": Vector3(20, -42, 4),
		"shoulder_r": Vector3(98, -36, 6), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-76, 0, 0),
	}))
	lib.add_animation("shield_riposte", _h.make_clip([
		[0.0, block],
		[0.08, _block_pose({"torso": Vector3(-10, -40, 4), "neck": Vector3(4, 46, -4),
				"shoulder_r": Vector3(-24, 26, 28), "elbow_r": Vector3(96, 0, 0), "wrist_r": Vector3(-72, 0, 12)})],  # recoge la espada
		[0.15, extended],  # estocada
		[0.25, _h.with(extended, {"torso": Vector3(-28, 38, -7), "shoulder_r": Vector3(100, -38, 6)})],  # sostiene
		[0.5, _stance()],
	], false, false, [[0.08, "trail_on"], [0.15, "riposte"], [0.25, "trail_off"]]))

	_add_empowered_riposte(lib)


## Estocada mejorada (docs/specs/parry-riposte-rework.md §2.4): mientras el
## mundo está congelado (0.3 s) se carga inclinado, la mirada abajo y la espada
## sobre el hombro izquierdo; después barre en horizontal por delante hasta
## detrás del hombro derecho (el daño a 0.42 s) y vuelve al reposo. Los brazos
## se calcularon con el script de brazos, encadenando cada pose con la anterior.
func _add_empowered_riposte(lib: AnimationLibrary) -> void:
	var legs := {
		"hip_l": Vector3(40, 10, -8), "knee_l": Vector3(-50, 0, 0), "ankle_l": Vector3(10, 0, 0),
		"hip_r": Vector3(-20, 10, 8), "knee_r": Vector3(-40, 0, 0), "ankle_r": Vector3(40, 0, 0),
	}
	var windup := _stance(_h.with(_h.with(legs, SHIELD_FORE), {
		"hips_pos": Vector3(0, -0.14, 0), "hips": Vector3(0, 20, 0),
		"torso": Vector3(-26, 30, 0), "neck": Vector3(0, -45, 0),
		"shoulder_r": Vector3(177, 223, 59), "elbow_r": Vector3(86, 0, 0), "wrist_r": Vector3(-103, 2, 2)}))
	var leaving := _stance(_h.with(_h.with(legs, SHIELD_FORE), {
		"hips_pos": Vector3(0, -0.15, 0), "hips": Vector3(0, 15, 0),
		"torso": Vector3(-26, 24, 0), "neck": Vector3(0, -35, 0),
		"shoulder_r": Vector3(164, 196, 48), "elbow_r": Vector3(100, 0, 0), "wrist_r": Vector3(-103, 1, 1)}))
	var cross := _stance(_h.with(_h.with(legs, SHIELD_FORE), {
		"hips_pos": Vector3(0, -0.15, 0), "hips": Vector3(0, 10, 0),
		"torso": Vector3(-26, 15, 0), "neck": Vector3(1, -22, 0),
		"shoulder_r": Vector3(180, 167, 43), "elbow_r": Vector3(74, 0, 0), "wrist_r": Vector3(-101, 0, 0)}))
	var front := _stance(_h.with(_h.with(legs, SHIELD_FORE), {
		"hips_pos": Vector3(0, -0.16, 0), "hips": Vector3(0, 0, 0),
		"torso": Vector3(-26, 0, 0), "neck": Vector3(2, 0, 0),
		"shoulder_r": Vector3(194, 100, 59), "elbow_r": Vector3(-27, 0, 0), "wrist_r": Vector3(-41, 1, 0)}))
	var right := _stance(_h.with(_h.with(legs, SHIELD_TUCK), {
		"hips_pos": Vector3(0, -0.15, 0), "hips": Vector3(0, -10, 0),
		"torso": Vector3(-25, -20, 0), "neck": Vector3(1, 28, 0),
		"shoulder_r": Vector3(208, 78, 58), "elbow_r": Vector3(-78, 0, 0), "wrist_r": Vector3(7, 2, 0)}))
	var behind := _stance(_h.with(_h.with(legs, SHIELD_TUCK), {
		"hips_pos": Vector3(0, -0.14, 0), "hips": Vector3(0, -20, 0),
		"torso": Vector3(-24, -40, 0), "neck": Vector3(0, 55, 0),
		"shoulder_r": Vector3(249, 40, 70), "elbow_r": Vector3(-130, 0, 0), "wrist_r": Vector3(33, 1, 0)}))
	lib.add_animation("shield_riposte_empowered", _h.make_clip([
		[0.0, _block_pose()],
		[0.08, windup],  # se carga: el mundo está congelado
		[0.3, _h.with(windup, {"hips_pos": Vector3(0, -0.16, 0), "torso": Vector3(-28, 32, 0)})],  # tensión
		[0.33, leaving],  # sale del hombro izquierdo, plana
		[0.36, cross],
		[0.42, front],  # daño
		[0.48, right],
		[0.55, behind],  # la espada termina detrás del hombro derecho
		[0.64, _h.with(behind, {"torso": Vector3(-25, -42, 0)})],  # sostiene
		[0.9, _stance()],
	], false, false, [[0.3, "trail_on"], [0.42, "empowered"], [0.55, "trail_off"]]))
