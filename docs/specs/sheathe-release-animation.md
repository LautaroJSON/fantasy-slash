# Feature: el desenvaine de Envainar anima el cuerpo

- **Estado:** Implementada (2026-09-27). **Revisión 2 (§10) implementada.** ACs AC721–AC727 (AC678–AC684 ya estaban tomados por otras specs; AC698–AC720 los propone `sprint-stamina.md`).
- **Constitución:** `docs/constitution.md` v4.10.x (sin enmienda: ver §7).
- **Pilar (Principio I):** **combate.** Al soltar la carga hoy solo se mueve la katana: un arco de 0.25 s mientras el cuerpo vuelve a `idle`. El golpe más fuerte del Samurái no se lee como un *iai*. Con el cuerpo acompañando el desenvaine, el seguimiento y el *chiburi*, el golpe se ve y el jugador paga el compromiso que lo hace poderoso.
- **Referencia:** video del responsable (`D:\user\Descargas\2b337158…mp4`, 3.5 s). La secuencia es:
  1. guardia agachada (0–0.5 s);
  2. desenvaine explosivo ascendente hacia la derecha y arriba (0.6–0.7 s);
  3. seguimiento con el cuerpo muy volcado y la hoja arriba, detrás de la espalda, mientras la izquierda tira la funda hacia atrás (0.8–1.1 s);
  4. se incorpora y hace el *chiburi*, la sacudida de la hoja al costado (1.2–1.7 s);
  5. *nōtō*, el envainado lento (1.8–3.4 s).
- **Decisiones del responsable (2026-09-27):**
  - el jugador queda comprometido **1.1 s** (desenvaine, seguimiento y chiburi), y **el dash lo corta** para recuperarse antes a costa de gastar la carga del dash;
  - **sin nōtō**: termina en la guardia, con la katana en la mano;
  - el desenvaine sale **como en el video**: ascendente, hacia la derecha y arriba.
- **Dependencias:**
  - `sheath-in-left-hand.md`: la funda va en la mano izquierda y AC674 rige para todo clip;
  - `sheath-socket-hand-grip.md` (§2.7, pose de carga);
  - `samurai.md` y `sheathe-dash-cancel.md` (el dash corta la recuperación);
  - `humanoid-player-model.md` (`WeaponMount`, `PlayerAnimator`).

## 1. Estado actual

1. Al soltar, `SheatheAbility.begin()` hace todo en el mismo cuadro:
   - aplica el golpe (AC361);
   - dispara el corte de viento;
   - reproduce `sheathe_slash` en el `SwingPlayer`, una animación de 1 s del pivot del arma en el espacio del `Visual`, acelerada a `CAST_DURATION` = **0.25 s**.
2. Mientras dura el casteo, `PlayerAnimator` pide `get_body_clip()`, pero Envainar devuelve `&""` fuera de la carga, así que el cuerpo hace `idle`. La mano derecha y la katana van por caminos separados: la mano sigue a su brazo y la katana a `sheathe_slash`.
3. El primer cuadro de `sheathe_slash` tiene que coincidir a mano con la funda en la pose de carga (AC675). Cada cambio de esa pose obliga a volver a medirlo.
4. El jugador no se mueve mientras castea (`Player._handle_movement`). Con `dash_cancels_cast = true`, el dash corta el casteo (`cancel_cast`).

## 2. Diseño

### 2.1 Clip nuevo del Samurái: `sheathe_release`

Es un clip de **1.1 s**, sin loop, en `samurai_profile.gd`. Las poses clave son el punto de partida y se ajustan con hojas de capturas:

| t (s) | Pose | Qué pasa |
|---|---|---|
| 0.0 | **La pose de carga** (el mismo diccionario que `sheathe_charge` en t = 0, compartido) | Sin salto al soltar. `right_grip` 1: la mano en el mango. |
| 0.05 | Arranque | `right_grip` → 0. La mano derecha tira del mango hacia adelante y la cadera empieza a subir y a girar. |
| 0.15 | **Desenvaine** (*nukitsuke*) | El brazo derecho estirado hacia arriba y a la derecha, con la hoja siguiendo el arco. El torso gira y se abre hacia la derecha, y el vuelco se mantiene. La izquierda tira la funda hacia atrás (*saya-biki*). |
| 0.3 | **Seguimiento** | La hoja pasa por arriba y queda detrás de la cabeza, casi vertical. El cuerpo, muy volcado (≈ 55°), y la cabeza baja. La funda, atrás y arriba. |
| 0.5 | Seguimiento sostenido | Mismo cuerpo, con la respiración contenida (≈ 1° y 1 cm): *zanshin*. |
| 0.7 | Se incorpora | Cadera arriba y torso casi erguido. La hoja baja por el costado derecho, alzada para la sacudida. |
| 0.85 | **Chiburi** | Sacudida seca: la hoja cae adelante y abajo, a la derecha, con el brazo estirado. |
| 1.1 | **Guardia** (`_stance()`) | Termina en la misma guardia de `idle`, así que la vuelta es suave. |

- La funda sigue en la mano izquierda en todo el clip, y cada pose escribe su brazo izquierdo cuando hace falta (`sheath-in-left-hand.md`). AC674, que recorre todos los clips, también lo cubre.
- Las piernas parten de la pose de carga y vuelven a la guardia.

### 2.2 Quién pide el clip

- `SheatheConfig` suma `@export var release_body_clip: StringName` = `&"sheathe_release"`.
- `SheatheAbility.get_body_clip()` devuelve:
  - `charge_body_clip` mientras carga;
  - `release_body_clip` mientras castea el suelte.
- `PlayerAnimator` ya pide el clip de la habilidad mientras castea. Como el clip cambia, arranca desde el principio.
- Si el perfil no tiene el clip, queda `idle` como hoy (el Guerrero y el Berserker no tienen Envainar).

### 2.3 La katana sale de la funda con la mano

- `AbilityBehavior` suma `holds_weapon_in_hand(ability) -> bool`, que por defecto devuelve `false`. Envainar devuelve `true` mientras castea el suelte.
- `AbilityComponent` y `Player` lo exponen: `Player.is_weapon_in_hand_cast()`.
- `WeaponMount.is_hand_free()` pasa a ser verdadero también durante un casteo que tiene el arma en la mano. Así, al soltar, el pivot sale de la funda (`hold_in_sheath(false)`) y **se mezcla hacia la mano** en `weapon_mount_blend` (0.1 s), que es la mezcla de siempre. Después sigue a la muñeca derecha, igual que en los golpes del combo.
- **El recorrido de la hoja lo da el brazo derecho del clip** (`shoulder_r`, `elbow_r`, `wrist_r`), igual que en los golpes del combo.
- **Se borra `sheathe_slash`**:
  - la animación de `player.tscn`;
  - `SLASH_ANIMATION` de `SheatheAbility`;
  - la llamada a `play_cast_animation`.

  Con eso desaparece el ajuste manual del primer cuadro (AC675): la hoja arranca siempre desde la funda.
- `cancel_cast` (el dash) ya no detiene el `SwingPlayer` ni llama `sword_swing.recover()`, porque el arma ya está en la mano. El cuerpo pasa al clip del dash como siempre.
- La estela del arma sigue encendida durante el casteo (`cast_started` → `cast_released`), como hoy: también acompaña el chiburi.

### 2.4 Tiempo y compromiso

- `sheathe.tres`: `cast_duration` y `min_cast_duration` pasan de 0.25 a **1.1** s. Ninguna carta reduce el casteo de Envainar.
- **El golpe sigue cayendo al soltar** (AC361 sin cambios). Lo mismo el empuje, el corte de viento, Zanshin y Tsubame Gaeshi.
- Durante los 1.1 s el jugador:
  - no se mueve;
  - no ataca;
  - no salta;
  - no usa otra habilidad (reglas de casteo de hoy).
- **El dash corta el casteo al instante** (`dash_cancels_cast = true`, sin cambios): el jugador se recupera antes a cambio de gastar la carga del dash. Con Zanshin, si el tajo mató, el dash ya está listo.
- **Tsubame Gaeshi** (el Envainar potenciado se castea sin cargar): el clip arranca desde la pose en la que esté el cuerpo, con la mezcla de siempre del `AnimationPlayer`.

### 2.5 Datos (Principio III)

| Resource / escena | Cambio |
|---|---|
| `SheatheConfig` | + `release_body_clip` (`&"sheathe_release"`). |
| `sheathe.tres` | `cast_duration` y `min_cast_duration`: 0.25 → 1.1. |
| `player.tscn` | − la animación `sheathe_slash` de la librería del `SwingPlayer`. |
| Perfil del Samurái | + `sheathe_release`; la pose de carga pasa a una función compartida (`_charge_pose()`). |

## 3. Interfaz pública

- `AbilityBehavior.holds_weapon_in_hand(ability) -> bool` (nuevo; por defecto `false`).
- `AbilityComponent.holds_weapon_in_hand() -> bool` y `Player.is_weapon_in_hand_cast() -> bool` (nuevos).
- `SheatheConfig.release_body_clip` (nuevo).
- `SheatheAbility`: − `SLASH_ANIMATION`.

## 4. Criterios de aceptación (AC721–AC727)

- **AC721** Al soltar Envainar, mientras dura el casteo, `Player.get_body_clip()` es `release_body_clip` y el humanoide del Samurái reproduce `sheathe_release` desde t = 0. Mientras carga sigue siendo `sheathe_charge`.
- **AC722** Tiempo y compromiso:
  - el casteo dura 1.1 s (`CAST_DURATION` = 1.1, `min_cast_duration` = 1.1);
  - el golpe cae en el cuadro del suelte (AC361 sin cambios);
  - durante el casteo el jugador no se mueve ni ataca;
  - un dash en medio del casteo lo corta en el mismo cuadro, el cuerpo deja `sheathe_release` y la katana sigue en la mano.
- **AC723** La katana sale de la funda con la mano:
  - en el cuadro del suelte, el pivot está en la pose de la funda (±1 mm);
  - pasada la mezcla (`weapon_mount_blend`) y hasta el final del clip, muestreado cada 1/30 s, el pivot está en la pose de la mano (`WeaponMount.get_hand_pose()`, ±1 mm);
  - el `SwingPlayer` no reproduce nada durante el casteo;
  - `player.tscn` ya no tiene `sheathe_slash`.

  *(Reemplaza la parte del primer cuadro de AC667/AC675.)*
- **AC724** El recorrido sigue al video. Se mide con la punta de la hoja (`TrailTip`), en el espacio del `Visual` (−Z hacia el enemigo, +X a la derecha del personaje):
  - t = 0: todas las articulaciones y pesos de agarre de `sheathe_release` son iguales a los de `sheathe_charge` (±0.01°);
  - desenvaine, t = 0.15: la punta está a la derecha (x ≥ 0.3 m) y por encima de los hombros (y ≥ 1.4 m);
  - seguimiento, t = 0.3: la punta está detrás de la cadera (z mayor que el de la cadera), por encima de los hombros (y ≥ 1.4 m), y el torso está volcado ≥ 45°;
  - chiburi, t = 0.85: la punta está adelante (z < 0), a la derecha (x ≥ 0.3 m) y abajo (y ≤ 0.6 m);
  - t = 1.1: la pose es la guardia de `idle` en t = 0 (todas las articulaciones, ±0.01°).
- **AC725** La funda sigue en la mano izquierda en `sheathe_release`. Lo cubren AC672 y AC674, que recorren todos los clips del Samurái.
- **AC726** Datos:
  - `SheatheConfig.release_body_clip` = `&"sheathe_release"`;
  - `SheatheAbility` ya no tiene `SLASH_ANIMATION`;
  - `holds_weapon_in_hand()` devuelve `false` en las demás habilidades;
  - no hay literales de diseño nuevos en scripts de comportamiento.
- **AC727** Regresión: pasan `sheath_grip_test`, `sheathe_test`, `sheathe_feel_test`, `tsubame_gaeshi_test`, `nuki_test`, `zanshin_test`, `wind_step_test`, `wind_cut_vfx_test`, `dash_cancel_test`, `class_combat_identity_test`, `weapon_mount_test` y `player_animator_test`, salvo los fallos previos y ajenos ya registrados (AC236, AC363). Los tests con 0.25 s fijos se adaptan sin cambiar lo que verifican y se anotan en §6. Import y smoke test del arena con el Samurái sin errores ni warnings.

**Próximo libre después de esta spec: AC728.**

## 5. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC721–AC727 en `CLAUDE.md` (próximo libre → AC728).
2. **La katana en la mano durante el casteo:**
   - `holds_weapon_in_hand` en `AbilityBehavior`, `AbilityComponent` y `Player`;
   - `WeaponMount.is_hand_free()`;
   - Envainar deja de reproducir `sheathe_slash` y se borra la animación.

   Mientras tanto, el cuerpo sigue haciendo `idle`.
3. **Clip `sheathe_release`:**
   - `_charge_pose()` compartida;
   - las 8 poses clave de §2.1;
   - `release_body_clip` en `SheatheConfig` y su `.tres`;
   - `get_body_clip()` durante el casteo.
4. **Tiempo:** `cast_duration`/`min_cast_duration` a 1.1 en `sheathe.tres`.
5. **Ajuste con capturas:** hojas de frente, de perfil, en tres cuartos y con la cámara del juego, en t = 0, 0.05, 0.15, 0.3, 0.5, 0.7, 0.85 y 1.1, al lado de los cuadros del video. Te las muestro antes de pasar a los tests.
6. **Tests:** AC721–AC726 en `test/components/abilities/sheathe_release_test.gd`, más la adaptación de los tests con 0.25 s fijos. Corro solo las suites de AC727.
7. **Cierre:** notas y checklist en esta spec, `SOURCE.md` del humanoide y mapa de `CLAUDE.md` (Envainar).

## 6. Tests adaptados (se anotan al cerrar)

- **AC667/AC675:** la parte del primer cuadro de `sheathe_slash` pasa a AC723.
- Los que asumen un casteo de 0.25 s (probablemente `sheathe_test`, `dash_cancel_test` y `tsubame_gaeshi_test`) se adaptan al nuevo `CAST_DURATION`, leyéndolo del dato en lugar de un número fijo.

## 7. Constitución

Sin enmienda:
- Principio III: tiempos y nombre del clip en datos.
- Principio VII: el golpe sigue comprometido y cancelable solo por el dash, como hoy, ahora más largo.
- No hay geometría, colores ni assets nuevos.
- Las animaciones del humanoide se siguen construyendo una vez.

## 8. Riesgos

- **Más riesgo para el jugador:** 1.1 s quieto después del golpe más fuerte. Está elegido a propósito, y el dash es la salida. Si en juego se siente lento, `cast_duration` es un dato.
- **La mezcla de 0.1 s de la funda a la mano** puede verse como un salto si el brazo del primer cuadro queda lejos del mango. Mitigación: en t = 0.05 el brazo ya lleva la muñeca cerca del mango, y la mezcla hace el resto. Se revisa con capturas.
- **El arco del seguimiento pasa por encima de la cabeza:** la hoja no debe cruzar el cuerpo. Se revisa con capturas, pero no hay test de colisión con el cuerpo.

## 9. Notas de implementación (2026-09-27)

- **Pose de partida:** la pose de carga final del responsable, sin commitear al empezar: torso (−5, 130, −15), cuello (10, −100, −8), el pie derecho adelante y `wrist_l` (−28, −40, −22). Pasó tal cual a `_charge_pose()`, que comparten `sheathe_charge` y el primer cuadro de `sheathe_release`.
- **Poses clave:** son 10, porque se sumaron dos intermedias a las 8 de §2.1:
  - 0.1: la mano cruza por delante del pecho;
  - 0.6: la hoja vuelve por el costado derecho.

  Sin ellas, la hoja atravesaba la cabeza (AC653). Los brazos se calcularon con un script temporal que pone la mano y la hoja (o la funda) en puntos del video, prefiriendo ángulos cercanos a la pose anterior para que la interpolación no dé vueltas.
- **Recorrido medido de la punta** (espacio del `Visual`):
  - 0.15 s: (1.0, 2.2, −0.5);
  - 0.3 s: (0.05, 1.7, 1.15), con el torso volcado 55°;
  - 0.85 s: (0.8, 0.3, −1.3);
  - 0.85–1.1 s: queda quieta en la guardia.
- **La funda en el suelte:** la boca queda a ≤ 29 cm de la cadera, la funda nunca apunta adelante y se inclina a lo sumo 38°. AC672 y AC674 pasan con el clip nuevo.
- **La katana:**
  - `WeaponMount.is_hand_free()` deja el arma a la mano durante un casteo con `holds_weapon_in_hand()`;
  - `SheatheAbility` ya no tiene `SLASH_ANIMATION` ni reimplementa `cancel_cast` (el de la base no hace nada);
  - `sheathe_slash` se borró de `player.tscn`.
- **Tests:**
  - `sheathe_release_test` (7 casos: AC721–AC724 y AC726), en verde;
  - regresión de AC727 en verde: `sheathe_test` (18), `sheathe_feel_test` (11), `tsubame_gaeshi_test` (10), `nuki_test`, `zanshin_test`, `wind_step_test`, `wind_cut_vfx_test`, `class_combat_identity_test` (25), `weapon_mount_test` y `player_animator_test`;
  - smoke test del arena sin errores ni warnings.
- **Fallos previos y ajenos** (también fallan en `HEAD`, antes de este cambio):
  - **AC363** (`dash_cancel_test`), ya registrado.
  - **AC670** (`sheath_grip_test`): la pose de carga final del responsable ya no cumple la revisión 4 de `sheath-socket-hand-grip.md` §2.7 (vuelco 16°, pie derecho adelante, funda 10° hacia abajo, centro a 6 cm). Queda pendiente reescribir AC670 con esa pose, si el responsable lo aprueba.
- **Tests adaptados** (verifican lo mismo):
  - AC250 (`sheathe_test`): tras soltar, la katana vuelve a la mano (antes, al final de `sheathe_slash`).
  - AC675 (`sheath_grip_test`): el suelte arranca desde la funda misma, sin `sheathe_slash`; el primer cuadro pasa a AC723.
  - AC665: en `sheathe_release`, `right_grip` vale 1 en el primer cuadro y 0 después.
  - AC653 (`class_combat_identity_test`): el cuadro del suelte se mide con la katana en la funda, como en el juego.
  - AC260 (`sheathe_feel_test`), AC393 (`tsubame_gaeshi_test`) y el helper `_slash` de `dash_cancel_test`: esperan el casteo entero leyendo `cast_duration` del dato, en lugar de un número fijo que suponía 0.25 s.

### Checklist de la constitución

- [x] Principio I: pilar de combate.
- [x] Principio II: sin geometría, colores ni assets nuevos; los clips del humanoide se construyen una vez.
- [x] Principio III: tiempo (`cast_duration`) y clip (`release_body_clip`) en datos.
- [x] Principio IV: tipado estricto; código y comentarios de código en inglés (los del perfil, en español como el resto del asset).
- [x] Principio V: sin allocations nuevas por cuadro.
- [x] Principio VI: sin cambios de input.
- [x] Principio VII: golpe comprometido 1.1 s, cancelable solo con el dash.

## 10. Revisión 2: compromiso de 0.5 s y animación más rápida y fluida (implementada, 2026-09-27)

**Pedido del responsable:** que el suelte comprometa solo ≈ 0.5 s (la opción que se recomendó al principio) y que la animación se vea más rápida y fluida. Hoy se ve lineal porque lo es: `sheathe_release` se arma sin `smooth`, con interpolación lineal entre poses clave.

### 10.1 Compromiso y recuperación

- `sheathe.tres`: `cast_duration` y `min_cast_duration` pasan de 1.1 a **0.5 s**. Ese es el compromiso: desenvaine, seguimiento y el *zanshin* sostenido. El golpe sigue cayendo al soltar.
- **El resto del clip es una recuperación libre.** Al terminar el casteo, el cuerpo sigue con `sheathe_release` (vuelta, chiburi y guardia) mientras el jugador no haga nada. La recuperación se corta en el mismo cuadro:
  - al **moverse**: pasa a `run` con la mezcla de salida de los golpes (`attack_exit_blend`);
  - al **atacar**, hacer **dash**, **saltar** o usar una **habilidad**: pasa a su clip, como hoy;
  - si **recibe daño**: pasa a `hit`.

  Si nadie la corta, al terminar el clip vuelve a `idle`.
- **Cómo se hace (genérico, en `PlayerAnimator`):** cuando termina el casteo o la carga que pedía un clip del cuerpo que **no es un loop**, el animador deja terminar ese clip mientras la locomoción quede en `IDLE` y nada más pida el cuerpo. La carga (`sheathe_charge`) es un loop, así que no queda sonando al cancelarla.
- La katana ya queda en la mano al terminar el casteo (`WeaponMount` sigue a la mano), así que el chiburi de la recuperación la mueve bien.

### 10.2 Más rápido y fluido

- **Interpolación cúbica:** `sheathe_release` se arma con `smooth` (`INTERPOLATION_CUBIC` en todas sus pistas), igual que `idle` y `run`. Las poses clave pasan a ser puntos de una curva: se acelera al salir de una y frena al llegar a la siguiente, sin los quiebres de la lineal.
- **Tiempos nuevos** (el clip pasa de 1.1 a **0.9 s**; el desenvaine, de 0.15 a 0.1 s):

  | t (s) | Pose | Antes |
  |---|---|---|
  | 0.0 | Pose de carga | 0.0 |
  | 0.03 | Tira del mango | 0.05 |
  | 0.06 | La mano cruza por delante | 0.1 |
  | **0.1** | **Desenvaine** | 0.15 |
  | **0.2** | **Seguimiento** | 0.3 |
  | 0.4 | Zanshin sostenido (**fin del compromiso: 0.5**) | 0.5 |
  | 0.5 | Vuelve por el costado derecho | 0.6 |
  | 0.58 | Se incorpora | 0.7 |
  | **0.66** | **Chiburi** | 0.85 |
  | 0.9 | Guardia | 1.1 |

- Las poses no cambian: solo sus tiempos y la interpolación. Si con la curva cúbica la hoja pasa por el cuerpo o da vueltas (los brazos tienen ángulos grandes), se corrige con poses intermedias, verificando con AC653 y las capturas.

### 10.3 Criterios de aceptación

**Revisados:**
- **AC722** (rev. 2): el casteo dura 0.5 s (`CAST_DURATION` = `min_cast_duration` = 0.5). Durante el casteo, el jugador no se mueve ni ataca. El dash lo corta en el mismo cuadro, el cuerpo deja `sheathe_release` y la katana sigue en la mano.
- **AC723** (rev. 2): el pivot sigue la mano pasada la mezcla y hasta el final del **clip** (0.9 s), también durante la recuperación.
- **AC724** (rev. 2): mismas condiciones con los tiempos nuevos:
  - desenvaine en t = 0.1;
  - seguimiento en t = 0.2;
  - chiburi en t = 0.66;
  - el clip dura 0.9 s y su último cuadro es la guardia de `idle`.

**Nuevos (AC728–AC730):**
- **AC728** Fluidez: todas las pistas de `sheathe_release` usan `INTERPOLATION_CUBIC`.
- **AC729** Recuperación libre: al terminar el casteo (0.5 s), sin input, el cuerpo sigue en `sheathe_release` hasta su final (0.9 s) y después pasa a `idle`. La katana sigue en la mano.
- **AC730** La recuperación se corta:
  - moverse durante la recuperación pasa el cuerpo a `run` en ese cuadro (≤ 2 cuadros de física);
  - atacar pasa a `attack_1`;
  - el dash, a su clip.

  Cancelar la carga de Envainar (`sheathe_charge`, en loop) no deja el clip sonando: pasa a `idle`.

**Próximo libre después de esta revisión: AC731.**

### 10.4 Plan

1. **Reserva:** AC728–AC730 en `CLAUDE.md`.
2. **Datos:** `cast_duration`/`min_cast_duration` a 0.5.
3. **`PlayerAnimator`:** la cola de un clip de habilidad que no es un loop, y cómo se corta.
4. **Clip:** `smooth` y los tiempos nuevos. Hoja de capturas y trayectoria de la punta; poses intermedias si la curva cúbica lo pide. Te la muestro.
5. **Tests:** AC728–AC730 nuevos y AC722–AC724 revisados en `sheathe_release_test.gd`, más los tests que esperaban el casteo leyendo `cast_duration` (se adaptan solos). Corro las suites de AC727.
6. **Cierre:** notas en esta sección y `CLAUDE.md`.

### 10.5 Notas de implementación (revisión 2)

- **Recuperación libre:** `PlayerAnimator._tail_clip`. Al pedir el clip de una habilidad que no es un loop, lo guarda y marca la pose de golpe, así que al cortarlo con locomoción se mezcla con `attack_exit_blend`. Terminado el casteo, `update()` deja sonar ese clip mientras la locomoción sea `IDLE`, y lo suelta cuando:
  - la locomoción cambia;
  - otro clip toma el cuerpo (golpe, `hit` o dash);
  - el clip termina.
- **La curva cúbica se pasaba** en dos tramos y se agregaron poses de sostén:
  - en el seguimiento, el torso llegaba a 63° en lugar de 55°: sostén en 0.26 (`follow`);
  - después del chiburi, la punta bajaba por debajo del piso (y = −0.23): sostén en 0.72 (`chiburi`).

  Además, el brazo izquierdo del desenvaine se volvió a calcular (boca de la funda 5 cm más cerca), porque en t = 0.07 la curva la llevaba a 31 cm de la cadera.
- **Recorrido de la punta medido:**
  - 0.1 s: (1.15, 2.13, −0.59);
  - 0.2–0.4 s: (0.05, ≈1.7, ≈1.15), con el torso volcado 55–59°;
  - 0.66 s: (0.79, 0.23, −1.29);
  - la punta nunca baja de 17 cm.

  La funda: boca a ≤ 28 cm de la cadera, inclinación de 40° como máximo.
- **Tests:**
  - `sheathe_release_test`, 13 casos: AC721–AC724, AC726 y AC728–AC730;
  - regresión de AC727 en verde, salvo los fallos previos ya registrados, AC670 y AC363;
  - smoke test del arena sin errores ni warnings.
- Los tests adaptados en la revisión 1 leen `cast_duration` del dato, así que no hubo que tocarlos otra vez.
- **Próximo libre:** AC731.
- **AC670 ya no es un fallo previo:** se reescribió con la pose final del responsable (revisión 5 en `sheath-socket-hand-grip.md`), y `sheath_grip_test` pasa entero (16 casos). Queda solo AC363 como fallo previo registrado.
