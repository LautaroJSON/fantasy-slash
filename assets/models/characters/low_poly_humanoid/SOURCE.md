# low_poly_humanoid

- **Origen:** script `low_poly_humanoid.gd` (`class_name LowPolyHumanoid`) provisto por el responsable del proyecto. Es un personaje low-poly estilo Rayman: torso, cabeza, manos y pies flotantes, con las mallas (`ArrayMesh` de normales planas) y el `AnimationPlayer` generados por código. No hay `.glb` ni esqueleto.
- **Licencia:** propia del proyecto.
- **Uso:** solo desde la escena adaptadora `entities/player/humanoid.tscn` (Principio II, 4.9.0). `humanoid_demo.gd` es una escena de prueba del asset: teclas 1-0 reproducen cada animación.
- **Animaciones:** `idle`, `run`, `run_stop`, `jump_start`, `jump_air`, `jump_land`, `attack_1`, `attack_2`, `attack_3`, `hit`. Las de ataque emiten `hit_window(active)`, `combo_window_opened` y `attack_finished`.
- **Modificaciones** (ver `docs/specs/humanoid-player-model.md` §2.1), sin cambios en poses, tiempos ni eventos:
  - Se agregaron tipos estáticos a las variables de `for` y a la lambda del demo, porque el proyecto trata `untyped_declaration` como error.
  - Se agregaron `body_material`, `accent_material` y `weapon_material`: si están asignados, reemplazan los materiales que se creaban por instancia.
  - Se agregó `use_hitbox`: con `false` no se crea el `Area3D` de la espada.
  - Se agregó `get_right_hand()`, que devuelve la muñeca derecha para montar un arma externa.
