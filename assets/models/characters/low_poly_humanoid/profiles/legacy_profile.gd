@tool
extends HumanoidProfile
## Perfil provisorio con los clips originales del asset (combo de 3 golpes).
## Lo usan las clases que todavía no tienen perfil propio; se borra al terminar
## docs/specs/class-combat-identity.md.

var _h: LowPolyHumanoid


func build(humanoid: LowPolyHumanoid) -> AnimationLibrary:
	_h = humanoid
	var lib := AnimationLibrary.new()
	_add_locomotion(lib)
	_add_attacks(lib)
	return lib


func _stance(over := {}) -> Dictionary:  # guardia de combate
	return _h.with(_h.pose({
		"hips_pos": Vector3(0, -0.04, 0),
		"torso": Vector3(-6, -10, 0), "neck": Vector3(4, 10, 0),
		"hip_l": Vector3(20, 0, -4), "knee_l": Vector3(-30, 0, 0), "ankle_l": Vector3(10, 0, 0),
		"hip_r": Vector3(-5, 0, 4), "knee_r": Vector3(-20, 0, 0), "ankle_r": Vector3(25, 0, 0),
		"shoulder_r": Vector3(25, 0, 12), "elbow_r": Vector3(55, 0, 0),
		"shoulder_l": Vector3(15, 0, -15), "elbow_l": Vector3(40, 0, 0),
	}), over)


func _run_contact(m: int) -> Dictionary:  # m = 1: pie derecho adelante
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose({
		"hips_pos": Vector3(0, -0.05, 0),
		"torso": Vector3(-14, -8 * m, 0), "neck": Vector3(10, 8 * m, 0),
		"hip_" + f: Vector3(40, 0, 0), "knee_" + f: Vector3(-15, 0, 0), "ankle_" + f: Vector3(-10, 0, 0),
		"hip_" + b: Vector3(-35, 0, 0), "knee_" + b: Vector3(-50, 0, 0), "ankle_" + b: Vector3(25, 0, 0),
		"shoulder_" + b: Vector3(45, 0, _h.side_z(b, 10)), "elbow_" + b: Vector3(70, 0, 0),
		"shoulder_" + f: Vector3(-35, 0, _h.side_z(f, 10)), "elbow_" + f: Vector3(45, 0, 0),
	})


func _run_pass(m: int) -> Dictionary:  # la pierna "m" apoya, la otra pasa recogida
	var f := "r" if m == 1 else "l"
	var b := "l" if m == 1 else "r"
	return _h.pose({
		"hips_pos": Vector3(0, 0.03, 0),
		"torso": Vector3(-12, 0, 0), "neck": Vector3(8, 0, 0),
		"hip_" + f: Vector3(5, 0, 0), "knee_" + f: Vector3(-20, 0, 0), "ankle_" + f: Vector3(15, 0, 0),
		"hip_" + b: Vector3(30, 0, 0), "knee_" + b: Vector3(-100, 0, 0), "ankle_" + b: Vector3(30, 0, 0),
		"shoulder_l": Vector3(5, 0, -10), "elbow_l": Vector3(70, 0, 0),
		"shoulder_r": Vector3(5, 0, 10), "elbow_r": Vector3(70, 0, 0),
	})


func _add_locomotion(lib: AnimationLibrary) -> void:
	lib.add_animation("idle", _h.make_clip([
		[0.0, _stance()],
		[1.0, _stance({"hips_pos": Vector3(0, -0.055, 0), "torso": Vector3(-9, -10, 0),
				"shoulder_l": Vector3(12, 0, -18), "shoulder_r": Vector3(22, 0, 14)})],
		[2.0, _stance()],
	], true, true))

	lib.add_animation("run", _h.make_clip([
		[0.0, _run_contact(1)], [0.15, _run_pass(1)],
		[0.3, _run_contact(-1)], [0.45, _run_pass(-1)],
		[0.6, _run_contact(1)],
	], true, true))

	lib.add_animation("run_stop", _h.make_clip([
		[0.0, _run_contact(1)],
		[0.12, _h.pose({  # derrape: se echa hacia atrás y frena con la pierna adelante
			"hips_pos": Vector3(0, -0.12, 0), "torso": Vector3(8, 0, 0), "neck": Vector3(-5, 0, 0),
			"hip_r": Vector3(45, 0, 0), "knee_r": Vector3(-10, 0, 0), "ankle_r": Vector3(-30, 0, 0),
			"hip_l": Vector3(-15, 0, 0), "knee_l": Vector3(-70, 0, 0), "ankle_l": Vector3(60, 0, 0),
			"shoulder_l": Vector3(40, 0, -30), "elbow_l": Vector3(30, 0, 0),
			"shoulder_r": Vector3(40, 0, 30), "elbow_r": Vector3(30, 0, 0)})],
		[0.4, _stance()],
	], false, true))

	lib.add_animation("jump_start", _h.make_clip([
		[0.0, _stance()],
		[0.08, _h.crouch()],
		[0.18, _h.pose({  # despegue: todo estirado, brazos arriba
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
	var air2 := _h.with(air, {"shoulder_l": Vector3(25, 0, -70), "shoulder_r": Vector3(25, 0, 70),
			"hip_l": Vector3(22, 0, 0)})
	lib.add_animation("jump_air", _h.make_clip([
		[0.0, _h.pose(air)], [0.3, _h.pose(air2)], [0.6, _h.pose(air)],
	], true, true))

	var land := _h.crouch({"hips_pos": Vector3(0, -0.22, 0),
			"shoulder_l": Vector3(30, 0, -40), "shoulder_r": Vector3(30, 0, 40)})
	lib.add_animation("jump_land", _h.make_clip([
		[0.0, land], [0.08, land], [0.3, _stance()],
	]))

	lib.add_animation("hit", _h.make_clip([
		[0.0, _stance()],
		[0.08, _stance({
			"hips_pos": Vector3(0, -0.05, 0.06),
			"torso": Vector3(20, 0, 0), "neck": Vector3(25, 0, 0),
			"shoulder_l": Vector3(10, 0, -35), "shoulder_r": Vector3(10, 0, 35)})],
		[0.35, _stance()],
	]))


func _add_attacks(lib: AnimationLibrary) -> void:
	# --- ATAQUE 1: tajo horizontal rápido de derecha a izquierda
	lib.add_animation("attack_1", _h.make_clip([
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
	], false, false, _h.strike_events(0.12, 0.22, 0.24, 0.45)))

	# --- ATAQUE 2: revés de izquierda a derecha
	lib.add_animation("attack_2", _h.make_clip([
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
	], false, false, _h.strike_events(0.14, 0.24, 0.26, 0.5)))

	# --- ATAQUE 3: golpe pesado desde arriba (final del combo)
	var slam := _stance({
		"hips_pos": Vector3(0, -0.16, 0),
		"torso": Vector3(-35, 0, 0), "neck": Vector3(25, 0, 0),
		"hip_l": Vector3(50, 0, -4), "knee_l": Vector3(-70, 0, 0), "ankle_l": Vector3(20, 0, 0),
		"hip_r": Vector3(-30, 0, 4), "knee_r": Vector3(-20, 0, 0), "ankle_r": Vector3(50, 0, 0),
		"shoulder_r": Vector3(100, 0, 5), "elbow_r": Vector3(10, 0, 0), "wrist_r": Vector3(-100, 0, 0),
		"shoulder_l": Vector3(90, 0, -10), "elbow_l": Vector3(20, 0, 0),
	})
	lib.add_animation("attack_3", _h.make_clip([
		[0.0, _stance()],
		[0.28, _h.pose({  # anticipación larga: se estira y levanta la espada
			"hips_pos": Vector3(0, 0.0, 0),
			"torso": Vector3(12, 0, 0), "neck": Vector3(-10, 0, 0),
			"hip_l": Vector3(10, 0, -4), "knee_l": Vector3(-10, 0, 0),
			"hip_r": Vector3(-10, 0, 4), "knee_r": Vector3(-5, 0, 0), "ankle_r": Vector3(15, 0, 0),
			"shoulder_r": Vector3(165, 0, 10), "elbow_r": Vector3(30, 0, 0), "wrist_r": Vector3(-30, 0, 0),
			"shoulder_l": Vector3(150, 0, -20), "elbow_l": Vector3(40, 0, 0)})],
		[0.38, slam],   # cae rápido
		[0.55, slam],   # se queda clavado: peso
		[0.85, _stance()],
	], false, false, _h.strike_events(0.32, 0.44, 0.6, 0.85)))
