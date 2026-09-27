@tool
extends HumanoidProfile
## Samurái (katana con funda): calma y precisión (docs/specs/class-combat-identity.md
## §3.3 revisada, sheath-socket-hand-grip.md). Firme y erguido, de costado al
## enemigo (hombro izquierdo adelante) con la cabeza al frente; la mano
## izquierda **nunca** suelta la funda (la funda cuelga de la muñeca izquierda,
## sheath-in-left-hand.md: el brazo izquierdo de cada pose la orienta) y la
## derecha lleva la katana a la altura de la cintura. Cortes a una mano con
## recorrido largo, tomados de los ocho cortes clásicos: horizontal, diagonal
## ascendente, vertical y un remate doble (diagonal ascendente y kesa; attack_4 encadena solo con attack_5).
## `sheathe_charge`: la pose de carga de Envainar (battōjutsu, la derecha sobre
## el mango).
## Los tiempos de los eventos coinciden con data/classes/samurai/samurai_combo.tres.

## Katana en la mano derecha a la altura de la cintura, la punta adelante y abajo.
const WAIST_BLADE := {
	"shoulder_r": Vector3(30, 32, 10), "elbow_r": Vector3(62, 0, 0), "wrist_r": Vector3(-118, 0, 0),
}

## La funda en la mano izquierda, en la cadera izquierda con la punta atrás y
## abajo (docs/specs/sheath-in-left-hand.md). La funda cuelga de la muñeca, así
## que el brazo la orienta: wrist_l X baja la punta (más negativo la sube), wrist_l Y la abre
## o la cierra respecto del cuerpo, y shoulder_l/elbow_l mueven la mano (la boca
## de la funda). Los brazos son invisibles: vale cualquier pose que deje bien
## la mano y la funda.
const LEFT_SHEATH_ARM := {
	"shoulder_l": Vector3(-34, 0, 14), "elbow_l": Vector3(87, 0, 0), "wrist_l": Vector3(-28, -41, 22),
}

var _h: LowPolyHumanoid


func build(humanoid: LowPolyHumanoid) -> AnimationLibrary:
	_h = humanoid
	var lib := AnimationLibrary.new()
	_add_idle(lib)
	_add_run(lib)
	_add_jump(lib)
	_add_hit(lib)
	_add_sheathe_charge(lib)
	_add_attacks(lib)
	return lib


## Arma un clip con la funda en la mano izquierda (docs/specs/sheath-in-left-hand.md):
## las poses que no escriben su propio brazo izquierdo (sin "wrist_l") llevan
## LEFT_SHEATH_ARM.
func _clip(keys: Array, loop := false, smooth := false, events := []) -> Animation:
	for i: int in keys.size():
		if not keys[i][1].has("wrist_l"):
			keys[i] = [keys[i][0], _h.with(keys[i][1], LEFT_SHEATH_ARM)]
	return _h.make_clip(keys, loop, smooth, events)


## Zancada larga con la pierna izquierda adelante (cortes que atraviesan).
func _stride(depth: float) -> Dictionary:
	return {
		"hips_pos": Vector3(0, -depth, 0),
		"hip_l": Vector3(55, 0, -6), "knee_l": Vector3(-68, 0, 0), "ankle_l": Vector3(12, 0, 0),
		"hip_r": Vector3(-36, 0, 8), "knee_r": Vector3(-12, 0, 0), "ankle_r": Vector3(48, 0, 0),
	}


# ---------------------------------------------------------------- GUARDIA

## Guardia de costado, firme y erguida: pierna y hombro izquierdos adelante,
## torso girado -40°, pecho arriba, la cabeza mirando al frente.
func _stance(over := {}) -> Dictionary:
	return _h.with(_h.pose(_h.with({
		"hips_pos": Vector3(0, -0.03, 0),
		"hips": Vector3(0, -20, 0),
		"torso": Vector3(3, -20, 0), "neck": Vector3(-3, 40, 0),
		"hip_l": Vector3(18, 20, -6), "knee_l": Vector3(-24, 0, 0), "ankle_l": Vector3(6, 0, 0),
		"hip_r": Vector3(-8, 20, 8), "knee_r": Vector3(-18, 0, 0), "ankle_r": Vector3(26, 0, 0),
	}, WAIST_BLADE)), over)


func _add_idle(lib: AnimationLibrary) -> void:
	# Respiración casi imperceptible (3 s): el pecho sube apenas.
	lib.add_animation("idle", _clip([
		[0.0, _stance()],
		[1.5, _stance({"hips_pos": Vector3(0, -0.04, 0), "torso": Vector3(4, -21, 0)})],
		[3.0, _stance()],
	], true, true))


# ---------------------------------------------------------------- CARRERA

## Deslizado y bajo: poco rebote, la mano izquierda no suelta la funda y la
## katana va atrás, cerca de la cadera.
func _run_contact(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose({
		"hips_pos": Vector3(0, -0.09, 0),
		"hips": Vector3(0, 8 * m, 0),
		"torso": Vector3(-15, -14 * m, 0), "neck": Vector3(12, 6 * m, 0),
		"hip_" + f: Vector3(42, 0, 0), "knee_" + f: Vector3(-25, 0, 0), "ankle_" + f: Vector3(-5, 0, 0),
		"hip_" + b: Vector3(-30, 0, 0), "knee_" + b: Vector3(-55, 0, 0), "ankle_" + b: Vector3(25, 0, 0),
		"shoulder_r": Vector3(-26 if m == 1 else -12, 0, 14), "elbow_r": Vector3(40, 0, 0),
		"wrist_r": Vector3(-30, 180, 0),
	})


func _run_pass(m: int) -> Dictionary:
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose({
		"hips_pos": Vector3(0, -0.06, 0),
		"torso": Vector3(-14, 0, 0), "neck": Vector3(11, 0, 0),
		"hip_" + f: Vector3(8, 0, 0), "knee_" + f: Vector3(-30, 0, 0), "ankle_" + f: Vector3(15, 0, 0),
		"hip_" + b: Vector3(35, 0, 0), "knee_" + b: Vector3(-95, 0, 0), "ankle_" + b: Vector3(30, 0, 0),
		"shoulder_r": Vector3(-19, 0, 14), "elbow_r": Vector3(40, 0, 0), "wrist_r": Vector3(-30, 180, 0),
	})


func _add_run(lib: AnimationLibrary) -> void:
	lib.add_animation("run", _clip([
		[0.0, _run_contact(1)], [0.14, _run_pass(1)],
		[0.28, _run_contact(-1)], [0.42, _run_pass(-1)],
		[0.56, _run_contact(1)],
	], true, true))

	# Frena corto, casi sin derrape, y vuelve enseguida a la guardia de costado.
	lib.add_animation("run_stop", _clip([
		[0.0, _run_contact(1)],
		[0.08, _stance({"hips_pos": Vector3(0, -0.1, 0), "torso": Vector3(-6, -20, 0),
				"hip_l": Vector3(34, 20, -6), "knee_l": Vector3(-46, 0, 0), "ankle_l": Vector3(12, 0, 0)})],
		[0.3, _stance()],
	], false, true))


# ---------------------------------------------------------------- SALTO

func _add_jump(lib: AnimationLibrary) -> void:
	# Salto liviano: piernas recogidas limpias, la mano sigue en la funda.
	lib.add_animation("jump_start", _clip([
		[0.0, _stance()],
		[0.07, _h.crouch(_h.with(WAIST_BLADE, {"hips_pos": Vector3(0, -0.16, 0), "wrist_r": Vector3(-95, 0, 0)}))],
		[0.16, _h.pose(_h.with(WAIST_BLADE, {
			"hips_pos": Vector3(0, 0.04, 0), "torso": Vector3(-6, 0, 0),
			"hip_l": Vector3(-5, 0, 0), "ankle_l": Vector3(-35, 0, 0),
			"hip_r": Vector3(12, 0, 0), "knee_r": Vector3(-30, 0, 0), "ankle_r": Vector3(-20, 0, 0)}))],
	]))

	var air := _h.with(WAIST_BLADE, {
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
	var land := _h.crouch(_h.with(WAIST_BLADE, {"hips_pos": Vector3(0, -0.14, 0), "wrist_r": Vector3(-95, 0, 0)}))
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
func _add_sheathe_charge(lib: AnimationLibrary) -> void:
	var ready := _h.pose({
		"hips_pos": Vector3(-0.04, -0.44, 0.12), "hips": Vector3(0, -35, 0),
		"torso": Vector3(-45, 55, -15), "neck": Vector3(45, -22, 0),
"hip_l": Vector3(-21, 52, -25), "knee_l": Vector3(-65, 0, 0), "ankle_l": Vector3(7, 67, 88),
"hip_r": Vector3(81, 35, 0), "knee_r": Vector3(-44, 0, 0), "ankle_r": Vector3(-37, 0, 0),
		"shoulder_r": Vector3(50, 45, 0), "elbow_r": Vector3(50, 0, 0),
		# La funda en la mano izquierda: wrist_l X más negativo sube la punta, Y la abre.
		"shoulder_l": Vector3(-34, 0, 14), "elbow_l": Vector3(87, 0, 0), "wrist_l": Vector3(-28, 50, -22),
		"right_grip": 1.0,
	})
	lib.add_animation("sheathe_charge", _clip([
		[0.0, ready],
		[1.0, _h.with(ready, {"hips_pos": Vector3(-0.04, -0.45, 0.12), "torso": Vector3(-46, 55, -15)})],
		[2.0, ready],
	], true, true))


# ---------------------------------------------------------------- COMBO

func _add_attacks(lib: AnimationLibrary) -> void:
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
	], false, false, _h.strike_events(0.14, 0.18, 0.22, 0.4)))


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
	], false, false, _h.strike_events(0.08, 0.12, 0.17, 0.34)))


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
	], false, false, _h.strike_events(0.1, 0.14, 0.2, 0.38)))


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
	], false, false, _h.strike_events(0.1, 0.13, 0.16, 0.24)))


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
	], false, false, _h.strike_events(0.08, 0.12, 0.34, 0.6)))
