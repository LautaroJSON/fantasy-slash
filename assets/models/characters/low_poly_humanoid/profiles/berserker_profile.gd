@tool
extends HumanoidProfile
## Berserker (mandoble de caballero): furia y peso (docs/specs/class-combat-identity.md
## §3.2, revisión 2026-09-27). Guardia erguida y confiada con el mandoble
## apoyado en el hombro derecho, sostenido solo con la mano derecha (referencias:
## Siegfried de Soul Calibur y bocetos del responsable); camina y corre con el
## arma al hombro y el puño izquierdo balanceando. Combo: barrido horizontal
## enroscado desde atrás, barrido de vuelta que termina a una mano con la
## izquierda extendida, y tajo de leñador con el mandoble alzado sobre la cabeza,
## pisotón y hoja clavada en el piso. Cada golpe arrastra el cuerpo entero.
## En los golpes, la mano izquierda toma el OffHand del arma (peso de agarre 1).
## Las poses del brazo derecho salen de la posición de la mano y la dirección de
## la hoja buscadas en cada pose clave (el brazo es invisible: se ven la mano y
## el arma). Los tiempos de los eventos coinciden con
## data/classes/berserker/berserker_combo.tres.

## Mandoble al hombro: la mano delante del hombro derecho y la hoja apoyada,
## apuntando atrás y arriba por detrás de la cabeza.
const SHOULDER_REST := {
	"shoulder_r": Vector3(121, -29, 42), "elbow_r": Vector3(23, 0, 0), "wrist_r": Vector3(32, -10, 90),
}
## Mandoble vertical delante del hombro derecho (vuelve a apoyarlo al terminar un golpe).
const RAISED_UPRIGHT := {
	"shoulder_r": Vector3(113, 52, 42), "elbow_r": Vector3(6, 0, 0), "wrist_r": Vector3(-5, 12, 0),
}
## Brazo izquierdo suelto, con el puño cerrado al costado.
const LEFT_RELAXED := {"shoulder_l": Vector3(-4, 0, -12), "elbow_l": Vector3(18, 0, 0)}
## Brazo izquierdo hacia el mango (lo que se ve lo corrige el agarre al OffHand).
const LEFT_TO_HILT := {"shoulder_l": Vector3(62, -24, 24), "elbow_l": Vector3(58, 0, 0)}
## Brazo izquierdo extendido adelante, la palma hacia el enemigo.
const LEFT_REACH := {"shoulder_l": Vector3(78, -30, -34), "elbow_l": Vector3(8, 0, 0), "wrist_l": Vector3(70, 0, 0)}
## Zancada muy baja con la pierna izquierda adelante (golpes con todo el peso).
const HEAVY_STRIDE := {
	"hip_l": Vector3(66, 0, -8), "knee_l": Vector3(-84, 0, 0), "ankle_l": Vector3(18, 0, 0),
	"hip_r": Vector3(-40, 0, 10), "knee_r": Vector3(-20, 0, 0), "ankle_r": Vector3(58, 0, 0),
}
## Piernas muy abiertas y flexionadas, de frente (remate del barrido de vuelta).
const WIDE_STANCE := {
	"hip_l": Vector3(34, 0, -30), "knee_l": Vector3(-52, 0, 0), "ankle_l": Vector3(18, 0, 26),
	"hip_r": Vector3(-4, 0, 28), "knee_r": Vector3(-46, 0, 0), "ankle_r": Vector3(50, 0, -24),
}
## Peso atrás sobre la pierna derecha, la izquierda adelante y liviana (enrosque).
const COILED_LEGS := {
	"hip_l": Vector3(30, 0, -18), "knee_l": Vector3(-36, 0, 0), "ankle_l": Vector3(6, 0, 0),
	"hip_r": Vector3(-8, 0, 18), "knee_r": Vector3(-44, 0, 0), "ankle_r": Vector3(52, 0, 0),
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
	_add_spin(lib)
	_add_air_slash(lib)
	return lib


## Piernas `legs` con la cadera girada `yaw` grados: las caderas compensan el
## giro para que los pies sigan mirando adelante.
func _legs(legs: Dictionary, yaw: float) -> Dictionary:
	var out := legs.duplicate()
	for key: String in ["hip_l", "hip_r"]:
		var hip: Vector3 = out[key]
		out[key] = Vector3(hip.x, hip.y - yaw, hip.z)
	return out


## Cuerpo de un golpe: cadera (bajada y giro), torso y cabeza hacia el frente.
func _body(drop: float, yaw: float, torso: Vector3, legs: Dictionary) -> Dictionary:
	return _h.with({
		"hips_pos": Vector3(0, drop, 0), "hips": Vector3(0, yaw, 0), "torso": torso,
		"neck": Vector3(-torso.x * 0.6, -(yaw + torso.y) * 0.85, -torso.z),
	}, _legs(legs, yaw))


## Pose de golpe a dos manos: cuerpo, brazo derecho y la izquierda en el mango.
func _two_hands(body: Dictionary, right_arm: Dictionary) -> Dictionary:
	return _h.pose(_h.with(_h.with(body, right_arm), _h.with(LEFT_TO_HILT, {"left_grip": 1.0})))


# ---------------------------------------------------------------- GUARDIA

## Guardia de furia, erguida y confiada: el pecho afuera, las piernas abiertas
## con el peso en la derecha, el mandoble al hombro y el puño izquierdo suelto.
func _stance(over := {}) -> Dictionary:
	return _h.with(_h.pose(_h.with(_h.with({
		"hips_pos": Vector3(0, -0.04, 0),
		"hips": Vector3(0, -6, 0),
		"torso": Vector3(-3, -8, 0), "neck": Vector3(2, 12, 0),
		"hip_l": Vector3(14, -4, -14), "knee_l": Vector3(-16, 0, 0), "ankle_l": Vector3(2, 0, 10),
		"hip_r": Vector3(-6, 6, 12), "knee_r": Vector3(-10, 0, 0), "ankle_r": Vector3(16, 0, -8),
		"left_grip": 0.0,
	}, SHOULDER_REST), LEFT_RELAXED)), over)


func _add_idle(lib: AnimationLibrary) -> void:
	# Respiración agitada (1 s): el torso se vuelca con cada exhalación y la
	# cadera cae 3 cm; el mandoble sube y baja sobre el hombro.
	lib.add_animation("idle", _h.make_clip([
		[0.0, _stance()],
		[0.5, _stance({"hips_pos": Vector3(0, -0.09, 0), "torso": Vector3(-10, -8, 0), "neck": Vector3(8, 12, 0),
				"elbow_l": Vector3(26, 0, 0), "shoulder_r": Vector3(118, -29, 42)})],
		[1.0, _stance()],
	], true, true))


# ---------------------------------------------------------------- CARRERA

## Pisando fuerte con el mandoble al hombro: la cadera cae marcada en el apoyo,
## el torso inclinado y el puño izquierdo balanceando amplio.
func _run_contact(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with({
		"hips_pos": Vector3(0, -0.13, 0),
		"hips": Vector3(0, 12 * m, 0),
		"torso": Vector3(-16, -16 * m, 0), "neck": Vector3(12, 4 * m, 0),
		"hip_" + f: Vector3(46, 0, 0), "knee_" + f: Vector3(-22, 0, 0), "ankle_" + f: Vector3(-8, 0, 0),
		"hip_" + b: Vector3(-36, 0, 0), "knee_" + b: Vector3(-55, 0, 0), "ankle_" + b: Vector3(26, 0, 0),
		"shoulder_l": Vector3(66 if m == 1 else -48, 0, -20), "elbow_l": Vector3(70 if m == 1 else 24, 0, 0),
		"left_grip": 0.0,
	}, SHOULDER_REST))


func _run_pass(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with({
		"hips_pos": Vector3(0, 0.02, 0),
		"torso": Vector3(-13, 0, 0), "neck": Vector3(10, 0, 0),
		"hip_" + f: Vector3(5, 0, 0), "knee_" + f: Vector3(-22, 0, 0), "ankle_" + f: Vector3(15, 0, 0),
		"hip_" + b: Vector3(32, 0, 0), "knee_" + b: Vector3(-100, 0, 0), "ankle_" + b: Vector3(30, 0, 0),
		"shoulder_l": Vector3(8, 0, -22), "elbow_l": Vector3(45, 0, 0),
		"left_grip": 0.0,
	}, _h.with(SHOULDER_REST, {"shoulder_r": Vector3(124, -29, 42)})))


func _add_run(lib: AnimationLibrary) -> void:
	lib.add_animation("run", _h.make_clip([
		[0.0, _run_contact(1)], [0.18, _run_pass(1)],
		[0.36, _run_contact(-1)], [0.54, _run_pass(-1)],
		[0.72, _run_contact(1)],
	], true, true))

	# Derrape largo: el peso del mandoble lo tira adelante antes de clavarse.
	lib.add_animation("run_stop", _h.make_clip([
		[0.0, _run_contact(1)],
		[0.16, _stance({
			"hips_pos": Vector3(0, -0.2, 0), "torso": Vector3(-30, 4, 0), "neck": Vector3(22, 0, 0),
			"hip_l": Vector3(52, -4, -14), "knee_l": Vector3(-30, 0, 0), "ankle_l": Vector3(-16, 0, 0),
			"hip_r": Vector3(-26, 6, 12), "knee_r": Vector3(-60, 0, 0), "ankle_r": Vector3(58, 0, 0),
			"shoulder_l": Vector3(40, 0, -40), "elbow_l": Vector3(30, 0, 0)})],
		[0.5, _stance()],
	], false, true))


# ---------------------------------------------------------------- SPRINT

## Embestida (docs/specs/sprint-stamina.md): el mandoble sigue al hombro, el
## torso se vuelca bajo como un toro, la cadera cae fuerte en cada pisada y el
## puño izquierdo bombea amplio. m = 1 pie derecho adelante.
func _sprint_contact(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with({
		"hips_pos": Vector3(0, -0.17, 0),
		"hips": Vector3(0, 14 * m, 0),
		"torso": Vector3(-30, -18 * m, 0), "neck": Vector3(24, 6 * m, 0),
		"hip_" + f: Vector3(62, 0, 0), "knee_" + f: Vector3(-30, 0, 0), "ankle_" + f: Vector3(-8, 0, 0),
		"hip_" + b: Vector3(-44, 0, 0), "knee_" + b: Vector3(-62, 0, 0), "ankle_" + b: Vector3(32, 0, 0),
		"shoulder_l": Vector3(92 if m == 1 else -64, 0, -24), "elbow_l": Vector3(84 if m == 1 else 30, 0, 0),
		"left_grip": 0.0,
	}, SHOULDER_REST))


func _sprint_pass(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose(_h.with({
		"hips_pos": Vector3(0, 0.02, 0),
		"torso": Vector3(-26, 0, 0), "neck": Vector3(20, 0, 0),
		"hip_" + f: Vector3(4, 0, 0), "knee_" + f: Vector3(-26, 0, 0), "ankle_" + f: Vector3(16, 0, 0),
		"hip_" + b: Vector3(48, 0, 0), "knee_" + b: Vector3(-120, 0, 0), "ankle_" + b: Vector3(32, 0, 0),
		"shoulder_l": Vector3(12, 0, -26), "elbow_l": Vector3(55, 0, 0),
		"left_grip": 0.0,
	}, _h.with(SHOULDER_REST, {"shoulder_r": Vector3(126, -29, 42)})))


func _add_sprint(lib: AnimationLibrary) -> void:
	lib.add_animation("sprint", _h.make_clip([
		[0.0, _sprint_contact(1)], [0.13, _sprint_pass(1)],
		[0.26, _sprint_contact(-1)], [0.39, _sprint_pass(-1)],
		[0.52, _sprint_contact(1)],
	], true, true))

	# Arranque: se hunde y embiste con el hombro del mandoble adelante.
	lib.add_animation("sprint_start", _h.make_clip([
		[0.0, _stance()],
		[0.12, _h.with(_sprint_contact(1), {
			"hips_pos": Vector3(0, -0.24, 0), "hips": Vector3(0, 22, 0),
			"torso": Vector3(-40, -24, 0), "neck": Vector3(30, 10, 0),
			"hip_l": Vector3(-54, 0, 0), "knee_l": Vector3(-18, 0, 0), "ankle_l": Vector3(44, 0, 0)})],
		[0.3, _sprint_contact(1)],
	], false, true))

	# Derrape largo: el peso del mandoble lo arrastra y clava los pies; el puño
	# izquierdo se abre para frenar y vuelve a la guardia.
	lib.add_animation("sprint_stop", _h.make_clip([
		[0.0, _sprint_contact(1)],
		[0.18, _stance({
			"hips_pos": Vector3(0, -0.26, 0), "hips": Vector3(0, -14, 0),
			"torso": Vector3(-34, 6, 0), "neck": Vector3(26, 6, 0),
			"hip_l": Vector3(58, 10, -16), "knee_l": Vector3(-24, 0, 0), "ankle_l": Vector3(-20, 0, 0),
			"hip_r": Vector3(-30, 18, 14), "knee_r": Vector3(-70, 0, 0), "ankle_r": Vector3(62, 0, 0),
			"shoulder_l": Vector3(54, 0, -52), "elbow_l": Vector3(26, 0, 0)})],
		[0.34, _stance({
			"hips_pos": Vector3(0, -0.14, 0), "torso": Vector3(-14, -4, 0), "neck": Vector3(10, 10, 0),
			"hip_l": Vector3(34, -4, -14), "knee_l": Vector3(-26, 0, 0), "ankle_l": Vector3(-6, 0, 0),
			"hip_r": Vector3(-14, 6, 12), "knee_r": Vector3(-36, 0, 0), "ankle_r": Vector3(36, 0, 0)})],
		[0.55, _stance()],
	], false, true))


# ---------------------------------------------------------------- DASH

## Dash (docs/specs/dash-feel.md): impulso, estirado y el primer cuadro de
## sprint, en las fracciones 0, 0.35 y 1 (la regla de conexión). El mandoble
## sigue al hombro en todo el clip. Berserker: se lanza pesado con el hombro del
## arma adelante y cae clavado en la pisada del sprint.
func _add_dash(lib: AnimationLibrary) -> void:
	var run_in := _sprint_contact(1)
	lib.add_animation("dash", _h.make_clip([
		[0.0, _h.with(run_in, {
			"hips_pos": Vector3(0, -0.26, 0), "hips": Vector3(0, 24, 0),
			"torso": Vector3(-42, -26, 0), "neck": Vector3(32, 12, 0),
			"hip_l": Vector3(44, 0, 0), "knee_l": Vector3(-66, 0, 0), "ankle_l": Vector3(20, 0, 0),
			"hip_r": Vector3(-52, 0, 0), "knee_r": Vector3(-14, 0, 0), "ankle_r": Vector3(46, 0, 0),
			"shoulder_l": Vector3(-60, 0, -28), "elbow_l": Vector3(30, 0, 0)})],
		[0.084, _h.with(run_in, {
			"hips_pos": Vector3(0, -0.1, 0), "hips": Vector3(0, 20, 0),
			"torso": Vector3(-38, -22, 0), "neck": Vector3(28, 9, 0),
			"hip_r": Vector3(74, 0, 0), "knee_r": Vector3(-24, 0, 0), "ankle_r": Vector3(-12, 0, 0),
			"hip_l": Vector3(-58, 0, 0), "knee_l": Vector3(-50, 0, 0), "ankle_l": Vector3(36, 0, 0),
			"shoulder_l": Vector3(70, 0, -26), "elbow_l": Vector3(60, 0, 0)})],
		[0.24, run_in],
	], false, true))


# ---------------------------------------------------------------- SALTO

func _add_jump(lib: AnimationLibrary) -> void:
	# Agachada profunda antes de despegar, con el mandoble firme al hombro.
	lib.add_animation("jump_start", _h.make_clip([
		[0.0, _stance()],
		[0.1, _h.crouch(_h.with(_h.with(SHOULDER_REST, LEFT_RELAXED), {
				"hips_pos": Vector3(0, -0.26, 0), "torso": Vector3(-26, 0, 0),
				"shoulder_l": Vector3(-50, 0, -16), "left_grip": 0.0}))],
		[0.2, _h.pose(_h.with(SHOULDER_REST, {
			"hips_pos": Vector3(0, 0.05, 0), "torso": Vector3(-4, 0, 0),
			"hip_l": Vector3(-5, 0, 0), "ankle_l": Vector3(-35, 0, 0),
			"hip_r": Vector3(10, 0, 0), "knee_r": Vector3(-30, 0, 0), "ankle_r": Vector3(-20, 0, 0),
			"shoulder_l": Vector3(60, 0, -30), "elbow_l": Vector3(30, 0, 0), "left_grip": 0.0}))],
	]))

	var air := _h.with(SHOULDER_REST, {
		"torso": Vector3(-8, 0, 0),
		"hip_r": Vector3(60, 0, 0), "knee_r": Vector3(-100, 0, 0), "ankle_r": Vector3(20, 0, 0),
		"hip_l": Vector3(40, 0, 0), "knee_l": Vector3(-80, 0, 0), "ankle_l": Vector3(20, 0, 0),
		"shoulder_l": Vector3(40, 0, -55), "elbow_l": Vector3(30, 0, 0), "left_grip": 0.0,
	})
	lib.add_animation("jump_air", _h.make_clip([
		[0.0, _h.pose(air)],
		[0.3, _h.pose(_h.with(air, {"shoulder_l": Vector3(46, 0, -62), "hip_l": Vector3(46, 0, 0)}))],
		[0.6, _h.pose(air)],
	], true, true))

	# Aterrizaje pesado: la cadera baja 22 cm y tarda en volver a la guardia.
	var land := _h.crouch(_h.with(SHOULDER_REST, {"hips_pos": Vector3(0, -0.34, 0), "torso": Vector3(-30, 0, 0),
			"shoulder_l": Vector3(20, 0, -40), "elbow_l": Vector3(20, 0, 0), "left_grip": 0.0}))
	lib.add_animation("jump_land", _h.make_clip([
		[0.0, land], [0.12, land], [0.4, _stance()],
	]))


func _add_hit(lib: AnimationLibrary) -> void:
	# Casi no retrocede: encoge los hombros y aguanta con el mandoble al hombro.
	lib.add_animation("hit", _h.make_clip([
		[0.0, _stance()],
		[0.08, _stance({
			"hips_pos": Vector3(0, -0.1, 0.03), "torso": Vector3(6, -14, 0), "neck": Vector3(10, 20, 0),
			"shoulder_l": Vector3(20, 0, -20), "elbow_l": Vector3(70, 0, 0)})],
		[0.35, _stance()],
	]))


# ---------------------------------------------------------------- COMBO

func _add_attacks(lib: AnimationLibrary) -> void:
	_add_wide_sweep(lib)
	_add_return_sweep(lib)
	_add_woodcutter(lib)


## Fin del barrido de derecha a izquierda: el mandoble bien a la izquierda y
## atrás, el cuerpo arrastrado por el peso (también es el comienzo del golpe 2).
func _sweep_left_hold() -> Dictionary:
	return _two_hands(_body(-0.22, 28, Vector3(-30, 64, -13), HEAVY_STRIDE), {
		"shoulder_r": Vector3(53, 28, -34), "elbow_r": Vector3(81, 0, 0), "wrist_r": Vector3(-131, 13, 0)})


## Fin del barrido de vuelta: a una mano, el mandoble bajo, bien a la derecha y
## atrás, el brazo izquierdo extendido adelante y las piernas muy abiertas.
## Es el último cuadro del golpe 2 y el primero del golpe 3.
func _sweep_right_hold() -> Dictionary:
	return _h.pose(_h.with(_h.with(_body(-0.28, -24, Vector3(-16, -42, 6), WIDE_STANCE), {
		"shoulder_r": Vector3(25, -6, 5), "elbow_r": Vector3(97, 0, 0), "wrist_r": Vector3(-170, 56, 0),
	}), _h.with(LEFT_REACH, {"left_grip": 0.0})))


## Mitad del barrido de derecha a izquierda: la hoja cruza al frente, a dos
## manos, con todo el peso adelante (golpe 1 y Corte del Giro).
func _sweep_front_cross() -> Dictionary:
	return _two_hands(_body(-0.2, -6, Vector3(-22, -8, -4), HEAVY_STRIDE), {
		"shoulder_r": Vector3(105, 8, -21), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-64, -63, 0)})


## 1. Barrido horizontal amplio de derecha a izquierda: saca el mandoble del
## hombro, se enrosca con la hoja atrás a la derecha y la suelta con todo el
## cuerpo. Desde el *cancel point* queda en la pose con la que empieza el golpe 2.
func _add_wide_sweep(lib: AnimationLibrary) -> void:
	lib.add_animation("attack_1", _h.make_clip([
		[0.0, _stance()],
		[0.12, _two_hands(_body(-0.08, -18, Vector3(-8, -35, 4), COILED_LEGS), {  # la saca del hombro
			"shoulder_r": Vector3(20, -34, -36), "elbow_r": Vector3(92, 0, 0), "wrist_r": Vector3(-42, -61, 0)})],
		[0.24, _two_hands(_body(-0.16, -32, Vector3(-14, -62, 8), COILED_LEGS), {  # enrosque largo
			"shoulder_r": Vector3(27, -61, -62), "elbow_r": Vector3(59, 0, 0), "wrist_r": Vector3(-61, -60, 0)})],
		[0.3, _two_hands(_body(-0.18, -34, Vector3(-16, -68, 8), COILED_LEGS), {  # carga el peso
			"shoulder_r": Vector3(25, -58, -64), "elbow_r": Vector3(63, 0, 0), "wrist_r": Vector3(-63, -59, 0)})],
		[0.36, _sweep_front_cross()],
		[0.43, _two_hands(_body(-0.21, 16, Vector3(-24, 30, -8), HEAVY_STRIDE), {
			"shoulder_r": Vector3(64, -4, -7), "elbow_r": Vector3(108, 0, 0), "wrist_r": Vector3(-151, -6, 0)})],
		[0.5, _two_hands(_body(-0.22, 28, Vector3(-28, 60, -12), HEAVY_STRIDE), {
			"shoulder_r": Vector3(54, 30, -29), "elbow_r": Vector3(87, 0, 0), "wrist_r": Vector3(-135, 15, 0)})],
		[0.62, _sweep_left_hold()],
		[0.95, _sweep_left_hold()],
	], false, false, _h.strike_events(0.36, 0.5, 0.62, 0.95)))


## 2. Barrido de vuelta de izquierda a derecha: arranca donde terminó el golpe 1,
## se enrosca más a la izquierda, el cuerpo gira con el arma y termina a una
## mano, con la hoja bien atrás a la derecha: la pose con la que empieza el golpe 3.
func _add_return_sweep(lib: AnimationLibrary) -> void:
	lib.add_animation("attack_2", _h.make_clip([
		[0.0, _sweep_left_hold()],
		[0.28, _two_hands(_body(-0.18, 34, Vector3(-18, 76, -10), HEAVY_STRIDE), {  # más enroscado
			"shoulder_r": Vector3(119, -8, -69), "elbow_r": Vector3(10, 0, 0), "wrist_r": Vector3(-114, 61, 0)})],
		[0.4, _two_hands(_body(-0.22, 4, Vector3(-22, 6, 6), HEAVY_STRIDE), {  # la hoja cruza al frente
			"shoulder_r": Vector3(132, -40, -67), "elbow_r": Vector3(14, 0, 0), "wrist_r": Vector3(-129, 54, 0)})],
		[0.47, _two_hands(_body(-0.24, -18, Vector3(-22, -32, 8), WIDE_STANCE), {
			"shoulder_r": Vector3(131, -19, -72), "elbow_r": Vector3(0, 0, 0), "wrist_r": Vector3(-149, 61, 0)})],
		[0.54, _h.pose(_h.with(_h.with(_body(-0.27, -20, Vector3(-15, -34, 5), WIDE_STANCE), {  # suelta la izquierda
			"shoulder_r": Vector3(53, 8, 0), "elbow_r": Vector3(70, 0, 0), "wrist_r": Vector3(-155, 62, 0),
		}), _h.with(LEFT_REACH, {"left_grip": 0.0})))],
		[0.66, _sweep_right_hold()],
		[1.0, _sweep_right_hold()],
	], false, false, _h.strike_events(0.4, 0.54, 0.66, 1.0)))


## Mandoble alzado a dos manos sobre la cabeza, arqueado hacia atrás (golpe 3
## y comienzo de la carga del Tajo aéreo), con las piernas `legs`.
func _woodcutter_raised(legs: Dictionary) -> Dictionary:
	return _two_hands(_body(-0.04, -18, Vector3(14, -36, -8), legs), {
		"shoulder_r": Vector3(134, -6, -30), "elbow_r": Vector3(6, 0, 0), "wrist_r": Vector3(40, -22, 0)})


## Pisotón: la hoja cae al frente (golpe 3 y caída del Tajo aéreo).
func _woodcutter_fall() -> Dictionary:
	return _two_hands(_body(-0.24, 4, Vector3(-28, 8, 8), HEAVY_STRIDE), {
		"shoulder_r": Vector3(136, -73, -14), "elbow_r": Vector3(66, 0, 0), "wrist_r": Vector3(-148, -48, 0)})


## La hoja clavada en el piso, el cuerpo volcado adelante (golpe 3 y aterrizaje
## del Tajo aéreo).
func _woodcutter_buried() -> Dictionary:
	return _two_hands(_body(-0.3, 22, Vector3(-44, 40, 12), HEAVY_STRIDE), {
		"shoulder_r": Vector3(23, -47, -26), "elbow_r": Vector3(75, 0, 0), "wrist_r": Vector3(-83, -8, 0)})


## 3. Remate: "tajo de leñador". Arranca donde terminó el golpe 2: sube el
## mandoble desde atrás a la derecha, lo alza a dos manos sobre la cabeza,
## arqueado hacia atrás, y lo baja en diagonal del hombro derecho a la cadera
## izquierda con un pisotón; la hoja queda clavada en el piso un instante y
## vuelve a apoyarla en el hombro.
func _add_woodcutter(lib: AnimationLibrary) -> void:
<<<<<<< HEAD
	var raised := _two_hands(_body(-0.04, -18, Vector3(14, -36, -8), COILED_LEGS), {
		"shoulder_r": Vector3(134, -6, -30), "elbow_r": Vector3(6, 0, 0), "wrist_r": Vector3(40, -40, 0)})  # de canto: la hoja ancha no roza la cabeza
	var buried := _two_hands(_body(-0.3, 22, Vector3(-44, 40, 12), HEAVY_STRIDE), {
		"shoulder_r": Vector3(23, -47, -26), "elbow_r": Vector3(75, 0, 0), "wrist_r": Vector3(-83, -8, 0)})
=======
	var raised := _woodcutter_raised(COILED_LEGS)
	var buried := _woodcutter_buried()
>>>>>>> 75dfed6557b282d66346cbd5da8b97353cbb8990
	lib.add_animation("attack_3", _h.make_clip([
		[0.0, _sweep_right_hold()],
		[0.18, _two_hands(_body(-0.16, -20, Vector3(-6, -40, 0), COILED_LEGS), {  # junta las manos, lo sube por detrás
			"shoulder_r": Vector3(65, -43, -71), "elbow_r": Vector3(100, 0, 0), "wrist_r": Vector3(-51, -35, 0)})],
		[0.36, raised],
		[0.5, _two_hands(_body(-0.02, -20, Vector3(18, -40, -10), COILED_LEGS), {  # tensión
			"shoulder_r": Vector3(130, -3, -30), "elbow_r": Vector3(2, 0, 0), "wrist_r": Vector3(58, -30, 0)})],
		[0.62, _woodcutter_fall()],  # pisotón, la hoja cae
		[0.68, _two_hands(_body(-0.27, 14, Vector3(-36, 24, 10), HEAVY_STRIDE), {
			"shoulder_r": Vector3(55, -48, -17), "elbow_r": Vector3(111, 0, 0), "wrist_r": Vector3(-147, -17, 0)})],
		[0.74, buried],
		[1.1, _h.with(buried, {"torso": Vector3(-42, 38, 12), "shoulder_r": Vector3(24, -47, -30)})],  # clavado
		[1.3, _h.with(_stance(RAISED_UPRIGHT), {"hips_pos": Vector3(0, -0.1, 0)})],
		[1.45, _stance()],
	], false, false, _h.strike_events(0.62, 0.74, 1.1, 1.45)))


# ---------------------------------------------------------------- GIRO

## Giro (docs/specs/spin-visual-rework.md §2.1): el mandoble a dos manos, con
## los brazos casi estirados a la derecha y un poco adelante; la hoja horizontal
## a la altura de la cintura (~1 m), apuntando afuera, así el filo va adelante
## en el giro (el Visual gira en sentido antihorario visto desde arriba). El
## torso se inclina y se abre hacia la hoja, con el peso bajo. La pose del brazo
## derecho sale de la posición de la mano y la dirección de la hoja buscadas.
const SPIN_ARM := {
	"shoulder_r": Vector3(63, 54, 24), "elbow_r": Vector3(49, 0, 0), "wrist_r": Vector3(-34, -106, -20),
}
## Pisoteo del giro: apoyado en la izquierda, la derecha empuja por afuera.
const SPIN_LEGS_LEFT := {
	"hip_l": Vector3(26, 0, -26), "knee_l": Vector3(-44, 0, 0), "ankle_l": Vector3(16, 0, 20),
	"hip_r": Vector3(-14, 0, 30), "knee_r": Vector3(-34, 0, 0), "ankle_r": Vector3(44, 0, -22),
}
## Pisoteo del giro: apoyado en la derecha, la izquierda cruza por detrás.
const SPIN_LEGS_RIGHT := {
	"hip_l": Vector3(-10, 0, -30), "knee_l": Vector3(-38, 0, 0), "ankle_l": Vector3(40, 0, 20),
	"hip_r": Vector3(22, 0, 24), "knee_r": Vector3(-44, 0, 0), "ankle_r": Vector3(18, 0, -18),
}


## Pose del giro con las piernas `legs` y la cadera `drop` metros más abajo.
func _spin_pose(drop: float, legs: Dictionary) -> Dictionary:
	return _two_hands(_body(drop, -24, Vector3(-12, -30, 6), legs), SPIN_ARM)


func _add_spin(lib: AnimationLibrary) -> void:
	# Loop de dos pisadas (0.5 s): el giro lo da el Visual, el clip solo sostiene
	# el mandoble y arrastra los pies.
	var left_foot := _spin_pose(-0.18, SPIN_LEGS_LEFT)
	lib.add_animation("spin", _h.make_clip([
		[0.0, left_foot],
		[0.25, _spin_pose(-0.14, SPIN_LEGS_RIGHT)],
		[0.5, left_foot],
	], true, true))

	# Corte del Giro (§2.3): arranca en la pose del giro, barre a dos manos de
	# derecha a izquierda cruzando al frente, suelta la izquierda y cae en la
	# pisada del sprint (la regla de conexión del dash, AC786). Se estira a la
	# duración del dash.
	lib.add_animation("spin_dash_slash", _h.make_clip([
		[0.0, left_foot],
		[0.08, _sweep_front_cross()],
		[0.15, _sweep_left_hold()],
		[0.3, _sprint_contact(1)],
	], false, true))


# ---------------------------------------------------------------- TAJO AÉREO

## Piernas en el aire (las de jump_air).
const AIR_LEGS := {
	"hip_r": Vector3(60, 0, 0), "knee_r": Vector3(-100, 0, 0), "ankle_r": Vector3(20, 0, 0),
	"hip_l": Vector3(40, 0, 0), "knee_l": Vector3(-80, 0, 0), "ankle_l": Vector3(20, 0, 0),
}
## Piernas recogidas del todo, como un arco tensado.
const AIR_LEGS_TUCKED := {
	"hip_r": Vector3(84, 0, 0), "knee_r": Vector3(-128, 0, 0), "ankle_r": Vector3(30, 0, 0),
	"hip_l": Vector3(66, 0, 0), "knee_l": Vector3(-112, 0, 0), "ankle_l": Vector3(28, 0, 0),
}


## Tajo aéreo tensado al máximo: el torso arqueado atrás, el mandoble más alto
## y más atrás detrás de la cabeza y las rodillas recogidas. La pose del brazo
## derecho sale de buscar la mano 5 cm más alta y 30 cm más atrás que en la
## pose alzada, con la hoja apuntando atrás y arriba (docs/specs/air-slash-visual-rework.md).
func _air_slash_drawn() -> Dictionary:
	return _two_hands(_body(0.02, -20, Vector3(30, -40, -10), AIR_LEGS_TUCKED), {
		"shoulder_r": Vector3(114, -19, -46), "elbow_r": Vector3(-34, 0, 0), "wrist_r": Vector3(56, -56, -7)})


## Tajo aéreo (docs/specs/air-slash-visual-rework.md): la carga se posiciona
## por la carga del ataque (0 = alzado, 1 = tensado), la caída baja la hoja y
## la sostiene, y el aterrizaje la clava y vuelve a la guardia.
func _add_air_slash(lib: AnimationLibrary) -> void:
	var drawn := _air_slash_drawn()
	lib.add_animation("air_slash_charge", _h.make_clip([
		[0.0, _woodcutter_raised(AIR_LEGS)],
		[1.0, drawn],
	], false, true))

	var fall := _woodcutter_fall()
	lib.add_animation("air_slash_dive", _h.make_clip([
		[0.0, drawn],
		[0.08, fall],
		[0.15, fall],
	], false, true))

	var buried := _woodcutter_buried()
	lib.add_animation("air_slash_land", _h.make_clip([
		[0.0, buried],
		[0.25, _h.with(buried, {"torso": Vector3(-42, 38, 12), "shoulder_r": Vector3(24, -47, -30)})],  # clavado
		[0.45, _h.with(_stance(RAISED_UPRIGHT), {"hips_pos": Vector3(0, -0.1, 0)})],
		[0.6, _stance()],
	], false, true))
