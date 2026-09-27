# low_poly_humanoid

- **Origen:** script `low_poly_humanoid.gd` (`class_name LowPolyHumanoid`) provisto por el responsable del proyecto. Es un personaje low-poly estilo Rayman: torso, cabeza, manos y pies flotantes, con las mallas (`ArrayMesh` de normales planas) y el `AnimationPlayer` generados por código. No hay `.glb` ni esqueleto.
- **Licencia:** propia del proyecto.
- **Uso:** solo desde la escena adaptadora `entities/player/humanoid.tscn` (Principio II, 4.9.0). `humanoid_demo.gd` es una escena de prueba del asset: teclas 1-7 para la locomoción y `hit`, 8/9 para el combo y 0 para cambiar de perfil.

## Perfiles de animación (`docs/specs/class-combat-identity.md`)

- Cada clase tiene un perfil en `profiles/`: `warrior_profile.gd` (Guerrero), `berserker_profile.gd` (Berserker) y `samurai_profile.gd` (Samurái). Todos extienden `HumanoidProfile` y arman una librería con `idle`, `run`, `run_stop`, `jump_start`, `jump_air`, `jump_land`, `hit` y su combo `attack_1` … `attack_N`.
- El perfil del Guerrero (`docs/specs/warrior-sword-and-shield.md`) reposa y marcha como un caballero: espada baja a la derecha (`REST_BLADE`) y escudo al costado izquierdo (`SHIELD_ARM`). El escudo cuelga de `wrist_l` (socket del jugador, no del asset), así que cada pose lo orienta con el brazo izquierdo.
- `LowPolyHumanoid.PROFILES` lista los perfiles. En `_ready` se construyen **todas** las librerías, una sola vez. `set_profile(id)` solo elige cuál es la librería por defecto del `AnimationPlayer`, así que los nombres de clip no cambian entre perfiles.
- El kit de poses (`pose`, `with`, `crouch`, `side_z`, `make_clip`, `strike_events`) vive en `low_poly_humanoid.gd`. Cada perfil escribe su guardia (`_stance`), su locomoción y sus golpes con ese kit.
- **Objetivos de mano** (`docs/specs/sheath-socket-hand-grip.md`): `set_hand_target(Hand.LEFT/RIGHT, marker)` y los pesos `left_hand_grip_weight`/`right_hand_grip_weight` (0 = la mano sigue su animación, 1 = pegada al marcador). Cada clip anima los pesos: en las poses del perfil van como `"left_grip"`/`"right_grip"` (si faltan, siguen el valor anterior; el primero vale 0). Después de que el `AnimationPlayer` aplica cada cuadro (`mixer_applied`) se mueve **solo la malla visual** de la mano; las muñecas no se tocan.
- **Colgar algo del cuerpo:** `attach_to_joint(joint, node, posición, rotación)` lo cuelga de una articulación compensando la escala del humanoide. La funda del Samurái cuelga de `wrist_l` (`docs/specs/sheath-in-left-hand.md`): el brazo izquierdo de cada pose la orienta. `wrist_l` X más negativo sube la punta, `wrist_l` Y la abre o la cierra, y `shoulder_l`/`elbow_l` mueven la mano (la boca de la funda). Las poses sin `wrist_l` propio llevan `LEFT_SHEATH_ARM`.
- La guardia del Samurái (`_stance()`, base de `idle` y de todos sus clips) es un reposo de frente con la katana baja adelante a la derecha (`LOW_BLADE`) y la funda atrás y abajo (`docs/specs/samurai-rest-guard.md`).
- El Samurái corre erguido con la katana arrastrándose detrás a la derecha (`RUN_ARMS`) y arranca desde la guardia con `run_start` (estado `RUN_START` de `PlayerAnimator`; los perfiles sin ese clip van directo a `run`, ver `docs/specs/samurai-run.md`).
- El Samurái tiene además `sheathe_charge`, la pose de carga de Envainar (la pide `SheatheConfig.charge_body_clip`), y `sheathe_release`, el suelte (desenvaine, seguimiento y chiburi; `SheatheConfig.release_body_clip`, `docs/specs/sheathe-release-animation.md`). Las dos parten de `_charge_pose()`.
- **Ajustar una pose:** editá los ángulos del keyframe en el perfil (la convención de ejes está en el comentario del kit de poses). Con hombro + codo + muñeca en X = 0 la hoja apunta adelante: si el torso se inclina, compensá con la muñeca.
- **Ajustar un tiempo de golpe:** los tiempos de `strike_events(hit_on, hit_off, combo, end)` y el último keyframe (el largo del clip) tienen que coincidir con `hit_start`, `hit_end`, `cancel_point` y `end_time` del `AttackComboStep` en `data/classes/<clase>/<clase>_combo.tres`. El gameplay usa el `.tres`; `class_combat_identity_test.gd` (AC641) falla si no coinciden.

## Modificaciones al script original

- Ver `docs/specs/humanoid-player-model.md` §2.1:
  - tipos estáticos en las variables de `for` y en la lambda del demo, porque el proyecto trata `untyped_declaration` como error;
  - `body_material`, `accent_material` y `weapon_material`: si están asignados, reemplazan los materiales que se creaban por instancia;
  - `use_hitbox`: con `false` no se crea el `Area3D` de la espada;
  - `get_right_hand()`, que devuelve la muñeca derecha para montar un arma externa.
- Ver `docs/specs/class-combat-identity.md`:
  - perfiles de animación, `set_profile()` y el kit de poses público;
  - librerías compartidas por todas las instancias (se construyen una vez por ejecución);
  - objetivos de mano con peso animado y `attach_to_joint()` (ver `docs/specs/sheath-socket-hand-grip.md`);
  - `get_joint()`;
  - `refresh_hand_targets()`, para volver a llevar las manos a sus objetivos después de mover el arma;
  - los clips genéricos originales se borraron: cada clase tiene su perfil (`warrior`, `samurai`, `berserker`) y el perfil inicial es `warrior`.
