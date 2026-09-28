# Estándar de animación de fantasy-slash

> Cómo se diseñan, construyen, verifican y ajustan las animaciones del proyecto. Lo exige el **Principio VIII** de la [constitución](constitution.md). Nació de la prueba de concepto del Samurái (`docs/specs/samurai-motion-poc.md`, combo "Nagare") y del vórtice de Envainar (`docs/specs/sheathe-vortex-vfx.md`).

---

## 1. Alcance

Toda animación del cuerpo del jugador (`LowPolyHumanoid` y sus perfiles), en especial combos y habilidades con arma. Los VFX que acompañan un golpe siguen la sección 8. Los enemigos y bosses lo adoptan cuando se rehagan sus animaciones.

---

## 2. Arquitectura: tres capas, cada una con su dueño

| Capa | Qué hace | Dónde vive | Cuándo corre |
|---|---|---|---|
| **1. Poses clave del cuerpo** | Cadera, torso, cuello, piernas y brazo de la funda o el escudo, en poses con su tiempo | Perfil de la clase (`profiles/<clase>_profile.gd`) | Se **hornean** al cargar |
| **2. Arcos del arma** | Recorrido de la mano y la hoja como geometría (`SlashArc`) | El mismo perfil (`_<combo>_arcs()`) | Se **hornean** al brazo con IK al cargar |
| **3. Capa en vivo** | Movimiento secundario (resortes) y pies clavados | `HumanoidMotion` + `HumanoidMotionSetup` del perfil (`build_motion()`) | Cada cuadro, después del mixer |

**Regla de oro (no negociable):** la capa en vivo **nunca** decide la pose de una articulación que el motor mezcla desde los clips (brazo del arma, torso para agarres…). Todo lo que tiene que verse al cancelar un golpe (dash, salto, daño o habilidad) tiene que estar **dentro del clip**. Si una pose se calcula, se hornea.

> **Por qué.** En la prueba, la mano seguía el arco con una corrección en tiempo real y los clips traían otro brazo. Cada cancelación mezclaba el motor desde el brazo equivocado: la mano "se bugeaba". Cada parche en vivo tapaba un caso y dejaba otro. Hornear lo resolvió de raíz.

### 2.1 Horneado del cuerpo

- `make_clip(keys, loop, smooth, events, overlap, arcs)`. Con `overlap`, cada articulación se hornea a 60 cuadros por segundo con una **cúbica monótona** entre poses (Fritsch-Carlson: velocidad continua, sin quiebres lineales ni overshoot entre claves).
- Cada articulación se muestrea `overlap[articulación]` segundos tarde. Es la **superposición**: la cadera lidera y el torso, la cabeza y los brazos siguen escalonados. Valores de referencia: cadera 0, torso 0.008 s, cuello 0.016 s y brazo libre 0.012 s.
- La primera y la última pose no se desplazan (el muestreo se recorta a los bordes).

### 2.2 Arcos del arma (`SlashArc`)

- Un corte es un **arco circular del agarre alrededor del hombro**, en el espacio del humanoide (adelante −Z, derecha +X, arriba +Y). La hoja apunta hacia afuera por el radio y el filo va adelante por la tangente.
- Se escribe con tres direcciones: `SlashArc.create(inicio, medio, final)`. El progreso `f` va de 0 a 2 (0 inicio, 1 medio o impacto, 2 final), y `timing` es la tabla (tiempo del clip, `f`).
- **Varios arcos por golpe** (carga, corte, chiburi…): cada uno manda desde el primer tiempo de su `timing`. Los arcos consecutivos comparten dirección de unión. Entre uno y otro, la orientación se mezcla en `ARC_BLEND` (0.05 s).
- **Recursos:**
  - `edge_flip`: el lomo va adelante (cargas y alzadas).
  - `radius_timing`: el radio cambia (estocadas).
  - `SlashArc.fixed()`: la hoja queda quieta y solo cambia el radio.
  - `tip_lag`: la punta se atrasa con la velocidad (latigazo; 0.02 s).
  - `blend_in` y `blend_out`: la mezcla con el brazo escrito, al entrar desde la guardia y al volver a ella.
- **Horneado al brazo:** `LowPolyHumanoid._bake_arm()`, por cuadro:
  1. reconstruye el torso y el hombro con las claves ya horneadas;
  2. ubica el agarre en el arco;
  3. resuelve hombro, codo y muñeca con **IK de dos huesos** (codo hacia `ARM_POLE`);
  4. escribe los ángulos Euler **desenrollados** (`_unwrap_euler`) para que no giren de golpe.
- El marco del arma (hoja, filo y agarre en la muñeca) lo da el perfil desde el `WeaponData` de la clase (`_set_bake_weapon()`), con la misma cuenta que `WeaponMount`.
- **Límite conocido:** si el arco pide más alcance que el brazo, la muñeca queda en el máximo del brazo.

### 2.3 Capa en vivo (`HumanoidMotion`)

- **Resortes** por articulación (frecuencia y amortiguación): la articulación persigue su rotación animada, con un límite de ángulo. Valores de referencia: cuello 7 Hz / 0.5, torso 10 Hz / 0.65. Si el resorte es demasiado blando, el cuerpo flota y el golpe pierde fuerza.
- **Pies clavados:** en una ventana del clip, el pie queda en su lugar del piso mientras el cuerpo avanza. Se suelta si se estira demasiado o cuando termina la ventana, y da un paso corto hasta su pose. Mueve solo la **malla** del pie, nunca la articulación.
- Los dos corren solo en los perfiles con `build_motion()`. Sin setup, el humanoide funciona como antes.
- `motion_enabled = false` en el humanoide vuelve al sistema clásico (con sus propias librerías), para comparar antes y después.

---

## 3. Diseño de un combo

1. **Continuidad (péndulo).** Cada golpe empieza donde terminó el anterior y, en lo posible, vuelve por el mismo camino. Hay que evitar que la hoja cruce el cuerpo "de vuelta" entre golpes: eso se lee como golpes desconectados.
2. **Sin vuelta a neutro.** Cada golpe termina sosteniendo su pose de remate. Si no se encadena, `PlayerAnimator` lo lleva a la guardia con `attack_exit_blend`.
3. **Pies alternados.** Los golpes caminan: izquierdo, derecho, izquierdo… El pie de atrás se clava mientras el otro entra.
4. **Ritmo variado.** No hay dos golpes seguidos con el mismo tempo (p. ej. medio, rápido, amplio, seco y pesado). El remate es distinto y más pesado.
5. **Familias variadas.** Hay que alternar diagonal, inversa, horizontal, estocada y vertical: cambiar de recorrido le da lectura al combo.
6. **Identidad de clase.** El combo cuenta quién es la clase. El Samurái termina con chiburi y vuelta a la guardia baja, que conecta con Envainar.

---

## 4. Timing de acción (técnicas profesionales)

| Fase | Qué pasa | Referencia |
|---|---|---|
| **Carga** | La hoja va a su marca, se pasa un poco y **sostiene** 1–2 cuadros (tensión). El cuerpo sigue enroscándose. | 0.04–0.10 s |
| **Golpe** | La hoja cruza casi todo el arco en **2–3 cuadros** (`f` de 0.15 a 1.7): la estela hace de smear. El impacto (`f` = 1) cae en `hit_start`. | ~0.03 s |
| **Follow-through** | Frena de a poco, se pasa apenas (`f` 2.03) y se asienta. | 0.1–0.2 s |
| **Sostén o recuperación** | Queda en su pose de remate hasta el `end_time`. | — |

- La helper `_cut(inicio, medio, final, radio, centro, soltado, impacto, fin)` del perfil del Samurái arma esa tabla de tiempos. Se reutiliza en los combos nuevos.
- La **estocada** (`lunge_start` a `lunge_end`) cae en los cuadros del golpe (~35 ms): es un impulso, no un deslizamiento.
- Las ventanas de encadenado (`cancel_point`) se abren cuando empieza el follow-through, para que el flujo se sostenga.
- Los eventos del clip (`strike_events`) están en los mismos tiempos que el `AttackComboStep` (AC641).
- **Espaciado:** en cámara lenta, los cuadros quedan juntos en la carga, muy separados en el golpe y juntos otra vez en el frenado. Si están parejos, el golpe se siente lento aunque dure poco.

---

## 5. Poses

- **Extremas en los extremos:** torsión de 50–75° en la carga y el remate, inclinación de −25 a −45°, zancadas hondas. Las poses tímidas se ven rígidas con este cuerpo low-poly.
- **La cadera lidera:** la pose del cuerpo en el impacto llega un poco antes que la hoja.
- **Contramovimiento:** antes de ir a un lado, el cuerpo va un poco al otro (la carga).
- Las poses del brazo del arma en los clips con arcos **solo importan** donde el arco entra o sale (`blend_in` y `blend_out`). El resto lo pone el horneado.

---

## 6. Flujo de trabajo

1. **Spec** (Principio I y flujo SDD): qué golpe o habilidad, su recorrido, su ritmo y qué no cambia (daño y tiempos de gameplay).
2. **Captura del "antes"** con la herramienta (§7).
3. **Implementación:** poses y arcos en el perfil, y tiempos en el `AttackComboStep`.
4. **Video antes/después**, a velocidad real y al 30 %. Se revisa:
   - el espaciado (§4);
   - que el recorrido de la punta sea continuo entre golpes;
   - que los pies no patinen.
5. **Escenarios de cancelación:** golpe cortado por dash (de 3 a 10 cuadros después), por salto, por daño y por una habilidad. Se mide que la mano quede donde dice su clip (§7.3).
6. **Ajuste a ojo** y vuelta al paso 4.
7. **Smoke test** en la arena con la clase y sus habilidades equipadas.

---

## 7. Herramientas

### 7.1 `assets/models/characters/low_poly_humanoid/tools/clip_capture.tscn`

Arma dos humanoides iguales, uno clásico (antes) y otro con la capa (después), con el arma y la funda de la clase, la estocada y el hit lag del combo. El clásico usa sus propios datos (`tools/<clase>_combo_classic.tres`). Deja puntos en el recorrido de la punta (amarillo) y en los pies (verde y magenta).

- Hojas por vista (frente, costado, juego y arriba):
  `godot --path <copia> --fixed-fps 60 res://assets/models/characters/low_poly_humanoid/tools/clip_capture.tscn -- --out=<carpeta>`
- Video 2×2 antes/después (combo a velocidad real, después al 30 %, y cada golpe al 30 %):
  `godot --path <copia> --fixed-fps 60 --resolution 1280x720 --write-movie <archivo>.avi res://…/clip_capture.tscn -- --movie`
- `ffmpeg` (instalado) convierte el video a mp4 y arma hojas de contacto de un tramo:
  `ffmpeg -i x.avi -vf "select='between(n\,A\,B)*not(mod(n\,5))',scale=640:-1,tile=4x4" -frames:v 1 hoja.png`

### 7.2 VFX

Una escena temporal que dispara el efecto en todos sus niveles (a velocidad real y al 30 %, con cámara del juego y vista de costado) y lo graba con `--write-movie`.

### 7.3 Escenarios con input

Un `extends Node` temporal en la copia, que carga la arena con la clase (`Session.character_class`):
- despausa el árbol;
- equipa habilidades por código (`player.basic_ability.equip(...)`);
- aprieta acciones del InputMap con `Input.action_press`;
- mide cada cuadro la diferencia entre la muñeca y la cadena de su clip.

Se corre con `--headless --fixed-fps 60`. Estos scripts no se commitean.

---

## 8. VFX de golpes: lenguaje compartido

- **Cintas** en un `ImmediateMesh` hecho una vez y rearmado por cuadro, con **sección en cruz** (dos quads por tramo), para que no se vean de canto.
- **Material:** blanco aditivo con color por vértice y desvanecido cerca de la cámara (`materials/vfx/circle_slash_material.tres`). Alpha ≤ 0.5 (piso ≤ 0.3).
- **Niveles 1–3** según la fuerza del golpe (nivel de mejora o carga), con `*_by_level` en su config: más trazos, banda más ancha, más chispas y más luz.
- **Tablas deterministas** (pasos de razón áurea) en vez de azar, calculadas una vez para el nivel máximo.
- El efecto dura lo que el golpe se lee (barrido ~0.2 s y desvanecido ~0.3 s) y no tapa al personaje.

---

## 9. Checklist de review de animación

- [ ] Los golpes encadenan sin que la hoja cruce el cuerpo de vuelta (video: recorrido continuo).
- [ ] El espaciado en cámara lenta es carga lenta, golpe de 2–3 cuadros y frenado largo.
- [ ] Los pies no patinan en las estocadas (vista cenital).
- [ ] Nada en vivo pisa articulaciones que el motor mezcla. Las cancelaciones (dash, salto, daño, habilidad) no desubican la mano.
- [ ] Los eventos del clip coinciden con el `AttackComboStep`.
- [ ] `motion_enabled = false` sigue funcionando (comparación).
- [ ] Hay video antes/después en la spec o en la conversación, y smoke test en la arena.

---

## 10. Pendientes conocidos

- Pasar el Guerrero y el Berserker a este estándar (arcos horneados, péndulo y pies alternados).
- Mover los valores de `HumanoidMotionSetup` (resortes, pies y mezclas) a un Resource `.tres` por perfil.
- Borrar el código de muñeca en vivo de `HumanoidMotion` (`_apply_grip`, `_clip_wrist`), que quedó sin uso al hornear los arcos.
- Capas (piernas y brazos por separado, reacciones sumadas) para la locomoción.
