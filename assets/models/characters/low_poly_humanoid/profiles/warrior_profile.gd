@tool
extends HumanoidProfile
## Guerrero (espada hoplita): guardia firme de hoplita, estocadas y tajos
## alternados, sin perder la base (docs/specs/class-combat-identity.md §3.1).
## Combo: estocada, tajo diagonal descendente, revés ascendente y estocada
## profunda, con arcos amplios, zancadas bajas y el torso volcado sobre el
## corte (referencia: Kaeya de Genshin Impact). Cada golpe gira la
## cadera y el torso, abre el hombro y rota la muñeca; el brazo izquierdo hace
## de contrapeso (apunta en la anticipación y se recoge en el impacto).
## Los tiempos de los eventos coinciden con data/classes/warrior/warrior_combo.tres.

## Brazo del arma en guardia: la espada a la altura de la cadera, punta adelante.
const GUARD_ARM := {
	"shoulder_r": Vector3(22, 0, 14), "elbow_r": Vector3(35, 0, 0), "wrist_r": Vector3(-45, 0, 0),
}
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
	_add_jump(lib)
	_add_hit(lib)
	_add_attacks(lib)
	return lib


# ---------------------------------------------------------------- GUARDIA

## Guardia de hoplita: pierna izquierda adelante, peso centrado, brazo
## izquierdo adelantado como si llevara el escudo.
func _stance(over := {}) -> Dictionary:
	return _h.with(_h.pose(_h.with({
		"hips_pos": Vector3(0, -0.05, 0),
		"hips": Vector3(0, -8, 0),
		"torso": Vector3(-5, -12, 0), "neck": Vector3(3, 18, 0),
		"hip_l": Vector3(22, 8, -6), "knee_l": Vector3(-32, 0, 0), "ankle_l": Vector3(10, 0, 0),
		"hip_r": Vector3(-8, 8, 6), "knee_r": Vector3(-22, 0, 0), "ankle_r": Vector3(28, 0, 0),
		"shoulder_l": Vector3(55, 10, -12), "elbow_l": Vector3(45, 0, 0), "wrist_l": Vector3(0, 0, 20),
	}, GUARD_ARM)), over)


func _add_idle(lib: AnimationLibrary) -> void:
	# Respiración lenta y pareja (2 s): la cadera baja, los hombros suben y
	# el escudo y la punta de la espada acompañan.
	lib.add_animation("idle", _h.make_clip([
		[0.0, _stance()],
		[1.0, _stance({"hips_pos": Vector3(0, -0.07, 0), "torso": Vector3(-8, -16, 0), "neck": Vector3(5, 21, 0),
				"shoulder_l": Vector3(50, 14, -16), "elbow_l": Vector3(50, 0, 0),
				"shoulder_r": Vector3(18, 4, 17), "wrist_r": Vector3(-38, 0, 6)})],
		[2.0, _stance()],
	], true, true))


# ---------------------------------------------------------------- CARRERA

## Apoyo: m = 1 pie derecho adelante. Hombros y torso contrarrotan con las
## piernas; la espada va firme, con un leve vaivén de la muñeca.
func _run_contact(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose({
		"hips_pos": Vector3(0, -0.05, 0),
		"hips": Vector3(0, 10 * m, 0),
		"torso": Vector3(-11, -24 * m, 0), "neck": Vector3(8, 14 * m, 0),
		"hip_" + f: Vector3(38, 0, 0), "knee_" + f: Vector3(-15, 0, 0), "ankle_" + f: Vector3(-10, 0, 0),
		"hip_" + b: Vector3(-32, 0, 0), "knee_" + b: Vector3(-50, 0, 0), "ankle_" + b: Vector3(25, 0, 0),
		"shoulder_l": Vector3(55 if m == 1 else -35, 0, -14), "elbow_l": Vector3(75 if m == 1 else 40, 0, 0),
		"shoulder_r": Vector3(28 if m == 1 else 14, 8 * m, 16), "elbow_r": Vector3(35, 0, 0),
		"wrist_r": Vector3(-50 if m == 1 else -40, 0, 0),
	})


func _run_pass(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with({
		"hips_pos": Vector3(0, 0.02, 0),
		"torso": Vector3(-10, 0, 0), "neck": Vector3(6, 0, 0),
		"hip_" + f: Vector3(5, 0, 0), "knee_" + f: Vector3(-20, 0, 0), "ankle_" + f: Vector3(15, 0, 0),
		"hip_" + b: Vector3(28, 0, 0), "knee_" + b: Vector3(-95, 0, 0), "ankle_" + b: Vector3(30, 0, 0),
		"shoulder_l": Vector3(10, 0, -14), "elbow_l": Vector3(60, 0, 0),
	}, GUARD_ARM))


func _add_run(lib: AnimationLibrary) -> void:
	lib.add_animation("run", _h.make_clip([
		[0.0, _run_contact(1)], [0.15, _run_pass(1)],
		[0.3, _run_contact(-1)], [0.45, _run_pass(-1)],
		[0.6, _run_contact(1)],
	], true, true))

	# Frenada controlada: planta el pie adelantado, el torso gira a la guardia
	# y el escudo sube, en un solo tiempo.
	lib.add_animation("run_stop", _h.make_clip([
		[0.0, _run_contact(-1)],
		[0.1, _stance({
			"hips_pos": Vector3(0, -0.1, 0), "hips": Vector3(0, -14, 0),
			"torso": Vector3(4, -24, 0), "neck": Vector3(-2, 28, 0),
			"hip_l": Vector3(38, 8, -6), "knee_l": Vector3(-15, 0, 0), "ankle_l": Vector3(-20, 0, 0),
			"hip_r": Vector3(-15, 8, 6), "knee_r": Vector3(-50, 0, 0), "ankle_r": Vector3(45, 0, 0),
			"shoulder_l": Vector3(70, 20, -18), "elbow_l": Vector3(35, 0, 0),
			"shoulder_r": Vector3(14, -6, 22), "wrist_r": Vector3(-30, 0, 0)})],
		[0.35, _stance()],
	], false, true))


# ---------------------------------------------------------------- SALTO

func _add_jump(lib: AnimationLibrary) -> void:
	# Salto compacto: la espada sigue adelante.
	lib.add_animation("jump_start", _h.make_clip([
		[0.0, _stance()],
		[0.08, _h.crouch(_h.with(GUARD_ARM, {"shoulder_l": Vector3(-30, 0, -12), "wrist_r": Vector3(-20, 0, 0)}))],
		[0.18, _h.pose(_h.with(GUARD_ARM, {
			"hips_pos": Vector3(0, 0.05, 0), "torso": Vector3(-5, 0, 0),
			"hip_l": Vector3(-5, 0, 0), "ankle_l": Vector3(-35, 0, 0),
			"hip_r": Vector3(10, 0, 0), "knee_r": Vector3(-30, 0, 0), "ankle_r": Vector3(-20, 0, 0),
			"shoulder_l": Vector3(120, 0, -15), "elbow_l": Vector3(20, 0, 0)}))],
	]))

	var air := _h.with(GUARD_ARM, {
		"torso": Vector3(-6, 0, 0),
		"hip_r": Vector3(65, 0, 0), "knee_r": Vector3(-100, 0, 0), "ankle_r": Vector3(20, 0, 0),
		"hip_l": Vector3(45, 0, 0), "knee_l": Vector3(-85, 0, 0), "ankle_l": Vector3(20, 0, 0),
		"shoulder_l": Vector3(40, 0, -40), "elbow_l": Vector3(35, 0, 0),
	})
	lib.add_animation("jump_air", _h.make_clip([
		[0.0, _h.pose(air)],
		[0.3, _h.pose(_h.with(air, {"shoulder_l": Vector3(45, 0, -48), "hip_l": Vector3(50, 0, 0),
				"torso": Vector3(-6, -6, 0)}))],
		[0.6, _h.pose(air)],
	], true, true))

	# Amortigua y vuelve directo a la guardia.
	var land := _h.crouch(_h.with(GUARD_ARM, {"hips_pos": Vector3(0, -0.2, 0), "wrist_r": Vector3(-20, 0, 0),
			"shoulder_l": Vector3(40, 0, -30), "elbow_l": Vector3(40, 0, 0)}))
	lib.add_animation("jump_land", _h.make_clip([
		[0.0, land], [0.06, land], [0.28, _stance()],
	]))


func _add_hit(lib: AnimationLibrary) -> void:
	# Retrocede medio paso girando el hombro golpeado, sin perder la guardia.
	lib.add_animation("hit", _h.make_clip([
		[0.0, _stance()],
		[0.08, _stance({
			"hips_pos": Vector3(0, -0.06, 0.07), "hips": Vector3(0, 6, 0),
			"torso": Vector3(14, 12, 0), "neck": Vector3(15, -6, 0),
			"shoulder_l": Vector3(75, 25, -20), "elbow_l": Vector3(60, 0, 0),
			"shoulder_r": Vector3(18, 10, 25), "wrist_r": Vector3(-60, 0, 0)})],
		[0.35, _stance()],
	]))


# ---------------------------------------------------------------- COMBO

func _add_attacks(lib: AnimationLibrary) -> void:
	_add_jab(lib)
	_add_slash(lib)
	_add_backhand(lib)
	_add_deep_thrust(lib)


## 1. Estocada rápida: se enrosca con la espada junto a la cadera y el brazo
## izquierdo apuntando; al soltar se tira a fondo, el hombro derecho sale
## adelante y la mano izquierda vuelve a la cadera (como un golpe de puño).
func _add_jab(lib: AnimationLibrary) -> void:
	var extended := _stance(_h.with(DEEP_STRIDE, {
		"hips_pos": Vector3(0, -0.16, 0), "hips": Vector3(0, 16, 0),
		"torso": Vector3(-24, 30, -6), "neck": Vector3(18, -38, 4),
		"shoulder_r": Vector3(96, -34, 6), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-76, 0, 0),
		"shoulder_l": Vector3(-40, 0, -28), "elbow_l": Vector3(100, 0, 0), "wrist_l": Vector3(0, 0, 0),
	}))
	lib.add_animation("attack_1", _h.make_clip([
		[0.0, _stance()],
		[0.06, _stance({  # se enrosca: espada a la cadera, izquierda apunta
			"hips_pos": Vector3(0, -0.09, 0.02), "hips": Vector3(0, -22, 0),
			"torso": Vector3(-4, -42, 4), "neck": Vector3(2, 50, -4),
			"shoulder_r": Vector3(-24, 26, 28), "elbow_r": Vector3(96, 0, 0), "wrist_r": Vector3(-72, 0, 12),
			"shoulder_l": Vector3(86, 30, -6), "elbow_l": Vector3(4, 0, 0), "wrist_l": Vector3(0, 0, 30)})],
		[0.1, extended],  # impacto
		[0.16, _h.with(extended, {"torso": Vector3(-26, 34, -7), "shoulder_r": Vector3(98, -36, 6)})],  # sostiene
		[0.4, _stance()],
	], false, false, _h.strike_events(0.1, 0.16, 0.22, 0.4)))


## 2. Tajo diagonal descendente amplio: la espada sube detrás del hombro
## derecho con el cuerpo erguido y cae en un arco grande hasta abajo a la
## izquierda, con zancada, el torso volcado sobre el corte y el brazo
## izquierdo tirado atrás.
func _add_slash(lib: AnimationLibrary) -> void:
	var impact := _stance(_h.with(DEEP_STRIDE, {  # la hoja cruza al frente, en diagonal
		"hips_pos": Vector3(0, -0.15, 0), "hips": Vector3(0, 4, 0),
		"torso": Vector3(-22, 8, -8), "neck": Vector3(16, -4, 6),
		"shoulder_r": Vector3(100, 10, 10), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-90, 0, 45),
		"shoulder_l": Vector3(-10, 0, -60), "elbow_l": Vector3(20, 0, 0),
	}))
	var follow := _h.with(impact, {  # termina baja a la izquierda, todo el cuerpo detrás
		"hips_pos": Vector3(0, -0.18, 0), "hips": Vector3(0, 22, 0),
		"torso": Vector3(-34, 58, -14), "neck": Vector3(24, -52, 10),
		"shoulder_r": Vector3(52, 64, 10), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-70, 0, 50),
		"shoulder_l": Vector3(-75, 0, -35), "elbow_l": Vector3(10, 0, 0), "wrist_l": Vector3(0, 0, -20),
	})
	lib.add_animation("attack_2", _h.make_clip([
		[0.0, _stance({"hips_pos": Vector3(0, -0.1, 0), "torso": Vector3(-14, 20, 0), "neck": Vector3(10, -14, 0),
				"shoulder_r": Vector3(80, -24, 6), "elbow_r": Vector3(6, 0, 0), "wrist_r": Vector3(-76, 0, 0)})],
		[0.08, _stance({  # anticipación: se yergue, gira atrás y alza la espada sobre el hombro derecho
			"hips_pos": Vector3(0, -0.03, 0), "hips": Vector3(0, -22, 0),
			"torso": Vector3(6, -62, 10), "neck": Vector3(-4, 62, -8),
			"hip_l": Vector3(22, 22, -6), "hip_r": Vector3(-8, 22, 6),
			"shoulder_r": Vector3(150, -40, 30), "elbow_r": Vector3(30, 0, 0), "wrist_r": Vector3(-20, 0, 40),
			"shoulder_l": Vector3(70, 30, -30), "elbow_l": Vector3(10, 0, 0), "wrist_l": Vector3(0, 0, 30)})],
		[0.12, impact],
		[0.16, follow],  # seguimiento
		[0.2, _h.with(follow, {"torso": Vector3(-36, 62, -15), "shoulder_r": Vector3(48, 68, 10)})],  # sostiene
		[0.44, _stance()],
	], false, false, _h.strike_events(0.12, 0.2, 0.26, 0.44)))


## 3. Revés diagonal ascendente amplio: desde abajo a la izquierda (donde
## terminó el tajo) sube en un arco grande hasta arriba a la derecha, y el
## cuerpo se estira hacia arriba al terminar.
func _add_backhand(lib: AnimationLibrary) -> void:
	var impact := _stance({  # la hoja cruza al frente, subiendo
		"hips_pos": Vector3(0, -0.1, 0), "hips": Vector3(0, -2, 0),
		"torso": Vector3(-14, -6, 6), "neck": Vector3(10, 8, -4),
		"hip_r": Vector3(30, 0, 6), "knee_r": Vector3(-40, 0, 0), "ankle_r": Vector3(8, 0, 0),
		"shoulder_r": Vector3(92, -10, 10), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-80, 0, -40),
		"shoulder_l": Vector3(40, 0, -55), "elbow_l": Vector3(25, 0, 0),
	})
	var follow := _h.with(impact, {  # termina arriba a la derecha, el cuerpo estirado
		"hips_pos": Vector3(0, -0.02, 0), "hips": Vector3(0, -24, 0),
		"torso": Vector3(6, -56, 12), "neck": Vector3(-4, 60, -10),
		"hip_l": Vector3(20, 24, -6), "hip_r": Vector3(20, 24, 6),
		"shoulder_r": Vector3(155, -50, 20), "elbow_r": Vector3(10, 0, 0), "wrist_r": Vector3(-30, 0, -40),
		"shoulder_l": Vector3(-30, 0, -70), "elbow_l": Vector3(15, 0, 0),
	})
	lib.add_animation("attack_3", _h.make_clip([
		[0.0, _stance({"hips_pos": Vector3(0, -0.16, 0), "hips": Vector3(0, 20, 0),
				"torso": Vector3(-32, 55, -12), "neck": Vector3(22, -50, 8),
				"shoulder_r": Vector3(52, 64, 10), "elbow_r": Vector3(4, 0, 0), "wrist_r": Vector3(-70, 0, 50),
				"shoulder_l": Vector3(-70, 0, -35)})],
		[0.08, _stance(_h.with(DEEP_STRIDE, {  # carga: agachado, la espada baja y atrás a la izquierda
			"hips_pos": Vector3(0, -0.17, 0), "hips": Vector3(0, 24, 0),
			"torso": Vector3(-30, 66, -10), "neck": Vector3(20, -60, 8),
			"shoulder_r": Vector3(30, 80, 0), "elbow_r": Vector3(30, 0, 0), "wrist_r": Vector3(-90, 0, 30),
			"shoulder_l": Vector3(-50, 0, -40), "elbow_l": Vector3(30, 0, 0)}))],
		[0.12, impact],
		[0.16, follow],  # seguimiento
		[0.2, _h.with(follow, {"torso": Vector3(8, -60, 13), "shoulder_r": Vector3(158, -54, 20)})],  # sostiene
		[0.44, _stance()],
	], false, false, _h.strike_events(0.12, 0.2, 0.26, 0.44)))


## 4. Remate: se enrosca con la espada recogida y el brazo izquierdo apuntando,
## y descarga una estocada a fondo, muy baja: la cadera y el hombro derecho
## salen adelante, el torso se vuelca y el brazo izquierdo se tira atrás.
func _add_deep_thrust(lib: AnimationLibrary) -> void:
	var lunge := _stance({
		"hips_pos": Vector3(0, -0.22, 0), "hips": Vector3(0, 18, 0),
		"torso": Vector3(-30, 36, -8), "neck": Vector3(24, -48, 6),
		"hip_l": Vector3(72, -18, -6), "knee_l": Vector3(-88, 0, 0), "ankle_l": Vector3(16, 0, 0),
		"hip_r": Vector3(-45, -18, 8), "knee_r": Vector3(-10, 0, 0), "ankle_r": Vector3(55, 0, 0),
		"shoulder_r": Vector3(100, -40, 0), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-72, 0, 0),
		"shoulder_l": Vector3(-78, 0, -30), "elbow_l": Vector3(8, 0, 0), "wrist_l": Vector3(0, 0, -20),
	})
	lib.add_animation("attack_4", _h.make_clip([
		[0.0, _stance()],
		[0.16, _stance({  # se enrosca: espada junto al pecho, izquierda apunta al rival
			"hips_pos": Vector3(0, -0.1, 0.04), "hips": Vector3(0, -24, 0),
			"torso": Vector3(0, -60, 6), "neck": Vector3(0, 70, -6),
			"hip_l": Vector3(26, 24, -6), "hip_r": Vector3(-14, 24, 6), "knee_r": Vector3(-36, 0, 0), "ankle_r": Vector3(38, 0, 0),
			"shoulder_r": Vector3(12, 50, 26), "elbow_r": Vector3(112, 0, 0), "wrist_r": Vector3(-120, 0, 15),
			"shoulder_l": Vector3(88, 42, -5), "elbow_l": Vector3(2, 0, 0), "wrist_l": Vector3(0, 0, 30)})],
		[0.24, lunge],  # impacto
		[0.32, _h.with(lunge, {"torso": Vector3(-32, 40, -9), "shoulder_r": Vector3(102, -42, 0)})],  # sostiene
		[0.46, _h.with(lunge, {"hips_pos": Vector3(0, -0.16, 0), "hips": Vector3(0, 8, 0),
				"torso": Vector3(-18, 18, -4), "shoulder_l": Vector3(-30, 0, -30)})],
		[0.7, _stance()],
	], false, false, _h.strike_events(0.24, 0.32, 0.46, 0.7)))
