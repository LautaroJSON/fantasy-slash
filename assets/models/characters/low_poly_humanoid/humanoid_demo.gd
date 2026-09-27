extends Node3D
## Escena de prueba: creá una escena nueva con un Node3D, pegale este script y dale Play.
## Teclas: 1 idle · 2 run · 3 run_stop · 4 jump_start · 5 jump_air · 6 jump_land
##         7 hit · 8 siguiente golpe del combo · 9 primer golpe · 0 siguiente perfil

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.28, 0.3, 0.34)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.57, 0.62)
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	add_child(floor_mesh)

	var cam := Camera3D.new()
	cam.position = Vector3(2.4, 1.6, 2.4)
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))

	var hero := LowPolyHumanoid.new()
	hero.demo_controls = true
	add_child(hero)

	var label := Label.new()
	label.text = "1 idle  2 run  3 run_stop  4 jump_start  5 jump_air  6 jump_land  7 hit  8 golpe siguiente  9 primer golpe  0 perfil siguiente"
	label.position = Vector2(12, 12)
	add_child(label)
