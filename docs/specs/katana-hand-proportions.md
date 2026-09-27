# Feature: proporciones de la katana acordes a la mano

- **Estado:** Implementada (2026-09-27).
- **Constitución:** `docs/constitution.md` v4.10.1 → **enmienda MINOR 4.11.0** (ver §8).
- **Pilar (Principio I):** **combate.** La silueta del arma es parte de la lectura del Samurái. Hoy la mano del humanoide (una gema de ~21 cm) tapa el mango entero y la tsuba, así que la katana parece salir del puño sin guarda. Con un mango y una tsuba a la escala de la mano, se lee como katana en la guardia, en cada corte y en la carga de Envainar.
- **Dependencias:** `samurai.md` (malla derivada `katana_blade.res`, AC237), `weapon-reach.md` (regla de AC211), `sheath-in-left-hand.md` (AC671–AC677: funda en la mano izquierda), `sheath-socket-hand-grip.md` (`Hilt`, AC675).
- **Decisiones del responsable (2026-09-27):**
  - **Se mantiene el alcance:** la punta queda donde está; la hoja se acorta lo que avanza la tsuba.
  - **Tsuba en proporción real (~×2):** de 8.7 cm a ~17 cm de diámetro.

## 1. Estado actual (medido, espacio local del arma, −Z = hacia la punta)

| Parte | Medida hoy |
|---|---|
| Mano derecha (gema de `_gem(0.08)` × 1.333) | ~21 × 23 × 21 cm; centro en z ≈ −0.053 (por `grip_position`) → cubre z ∈ [−0.168, +0.062] |
| Mango (tsuka) | 16.5 cm, z ∈ [+0.055, −0.110]; sección 3.4 × 2.9 cm. **Tapado entero** por la mano. |
| Tsuba | Ø 8.7 cm, ~2.4 cm de espesor, z ≈ [−0.121, −0.145]. **Adentro de la mano** (su centro está a 7 cm del centro de la gema). |
| Hoja | de z ≈ −0.145 a la punta z = −1.27; 5.5 cm de ancho, 2.2 mm de espesor. |
| Funda (`katana_sheath.res`) | desde la boca z ≈ −0.117 hasta más allá de la punta. `Grip` (mano izquierda) en z = −0.03: **sobre el mango**, así que al envainar la mano izquierda también tapa la tsuba. |
| `Hilt` (mano derecha en la carga de Envainar) | z = +0.10, detrás del pomo. |

## 2. Diseño

### 2.1 Nuevas proporciones (espacio local del arma)

`h` = medio largo de la gema de la mano sobre el eje del arma (≈ 0.115 m, se mide en la implementación). `g` = holgura de 1 cm. La mano derecha no se mueve (`grip_position`/`grip_rotation` no cambian), así que ninguna pose del combate cambia.

| Parte | Nueva medida |
|---|---|
| Tsuba | cara trasera en z = −0.053 − h − g ≈ **−0.178**; Ø **×2** (~17.4 cm); espesor ×1.25 (~3 cm) → cara delantera ≈ **−0.206**. |
| Mango | desde la tsuba hasta el pomo en z ≈ +0.053 + h + **0.08** ≈ **+0.137**: largo ≈ **31 cm** (hoy 16.5, ×1.9). Asoman ~8 cm detrás del puño. Sección **×1.5** (~5 × 4.4 cm), para que no se vea como un palito al lado de la mano. |
| Hoja | desde la tsuba (−0.206) hasta la punta, que **queda en −1.27**: se comprime a lo largo ~5 % (1.13 → 1.06 m). Ancho y espesor sin cambios. |
| Funda | el mismo mapeo que la hoja: la boca acompaña a la tsuba y la punta queda donde está. Sección sin cambios. |

Relación mango/hoja ≈ 0.29, como una katana real (~0.3).

### 2.2 Cómo se construyen las mallas (derivadas, Principio II)

Se regeneran `katana_blade.res` y `katana_sheath.res` desde el `katana.glb`, igual que hoy (vértices por hueso), aplicando un **mapeo por regiones** según la altura Y original del vértice:

- **Mango** (Y < inicio de la tsuba): Y se estira linealmente hasta el nuevo intervalo; X y Z se escalan ×1.5.
- **Tsuba** (franja de la tsuba): X y Z se escalan ×2; Y se estira ×1.25 y se ubica en su nuevo lugar.
- **Hoja y funda** (Y > fin de la tsuba): Y se mapea linealmente para que la boca quede en su nuevo lugar y la punta no se mueva; X y Z sin cambios.

Las normales se recalculan para las regiones con escala no uniforme (normal × inversa transpuesta). Las UV, los índices y la cantidad de vértices no cambian, así que el material y la paleta siguen iguales. Los anillos del mango se estiran junto con él.

El generador queda en el repo, reproducible: `assets/models/weapons/katana/tools/build_katana_meshes.gd` (`extends SceneTree`, tipado estricto). Los límites de las regiones y los factores viven como constantes del script, documentadas en `SOURCE.md`. No son datos de gameplay: son parte de la preparación del asset, como los keyframes de un `.glb`.

El `Model` de `katana.tscn` y el de `katana_sheath.tscn` conservan su transform (×1.1, origen z = 0.055). El mapeo ya deja cada parte en su lugar.

### 2.3 Marcadores de `katana.tscn`

- `TrailTip`: sin cambios (z = −1.27).
- `TrailBase`: pasa al comienzo de la hoja, delante de la tsuba (z ≈ −0.22; hoy −0.15, que quedaría adentro de la tsuba nueva). La estela se acorta unos 7 cm.
- `Hilt`: pasa a z = −0.053, **el mismo punto en que la mano derecha toma el arma en combate**. En la carga de Envainar la mano derecha queda sobre el mango, entre la tsuba y el pomo.

### 2.4 La funda en la mano izquierda

- El `Grip` de `katana_sheath.tscn` pasa a la **boca de la funda** (*koiguchi*): z = cara delantera de la tsuba − g − h ≈ **−0.331**. Así la mano izquierda sostiene la funda justo delante de la tsuba, con la tsuba entre las dos manos (la toma del *iai*).
- `sheath_position` de `katana.tres` se recalcula para que el `Grip` siga cayendo en el centro de la mano izquierda (AC672), con la misma `sheath_rotation`. Consecuencia: respecto de la cadera, la funda se desplaza ~30 cm hacia la punta del mango. **El mango asoma adelante de la cadera** (como una katana en el *obi*) y la punta de la funda queda más cerca del cuerpo. AC674 acota que siga en la cintura, sin apuntar adelante ni tocar el piso.
- El primer cuadro de `sheathe_slash` en `player.tscn` se vuelve a medir (AC675).

### 2.5 Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `assets/models/weapons/katana/katana_blade.res`, `katana_sheath.res` | Regeneradas con el mapeo de §2.2. |
| `assets/models/weapons/katana/tools/build_katana_meshes.gd` | Nuevo: el generador. |
| `entities/player/weapons/katana.tscn` | `TrailBase`, `Hilt`. |
| `entities/player/weapons/katana_sheath.tscn` | `Grip`. |
| `data/classes/samurai/katana.tres` | `sheath_position`. |
| `entities/player/player.tscn` | Primer cuadro de `sheathe_slash`. |

Sin cambios: `samurai_stats.tres` (`attack_range` 2.3), `katana_swing_config.tres` (`hilt_offset` 0.35), `grip_position`/`grip_rotation`, las poses del perfil del Samurái y todo el código de comportamiento.

## 3. Interfaz pública

Sin cambios.

## 4. Criterios de aceptación (AC683–AC688)

- **AC683** Proporciones de la malla, en el espacio local de `katana.tscn`: el mango mide entre 0.29 y 0.33 m y su sección es ≥ 4.5 cm; la tsuba mide entre 16 y 18.5 cm de diámetro y ≤ 3.5 cm de espesor; la punta está en z = −1.27 (±0.05, como AC237).
- **AC684** La tsuba y el pomo se ven con el arma en la mano derecha: con el pivot en `WeaponMount.get_hand_pose()`, ningún vértice de la tsuba cae dentro de la caja de la malla de la mano derecha, y el pomo sobresale ≥ 5 cm detrás de esa caja sobre el eje del arma.
- **AC685** Envainada, las dos manos quedan a los lados de la tsuba: con la katana en el socket (`sheathe_charge`, t = 0), ningún vértice de la tsuba cae dentro de la caja de ninguna de las dos manos. El `Hilt` está sobre el mango, a ≤ 1 cm del punto de agarre de la mano derecha en combate. La boca de la funda coincide con la cara delantera de la tsuba (≤ 1 cm), y la hoja queda dentro del largo de la funda.
- **AC686** Se mantiene el alcance: `attack_range` (2.3) y `hilt_offset` (0.35) no cambian y la regla de AC211 sigue valiendo. `TrailBase` está delante de la tsuba, a ≤ 5 cm de su cara delantera, y `TrailTip` sigue en la punta (AC214).
- **AC687** La funda en la mano sigue valiendo con el nuevo agarre: pasan AC671–AC677, con `sheath_position` y el primer cuadro de `sheathe_slash` medidos de nuevo.
- **AC688** Asset y regresión:
  - las dos mallas tienen la misma cantidad de vértices, índices y UV que su parte del `katana.glb`;
  - correr `build_katana_meshes.gd` reproduce las mallas del repo;
  - `SOURCE.md` documenta el mapeo;
  - pasan `weapon_model_test`, `sheath_grip_test`, `sheathe_test` y `class_combat_identity_test` (salvo los fallos previos registrados en `sheath-in-left-hand.md` §9);
  - el import y el smoke test del arena con el Samurái corren sin errores ni warnings.

**Próximo libre después de esta spec: AC689.**

## 5. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC683–AC688 en `CLAUDE.md` (próximo libre → AC689). Enmienda 4.11.0 en la constitución (§8).
2. **Generador:** `build_katana_meshes.gd` mide primero `h` y los límites de las regiones en el glb y en la mano, y después regenera las dos `.res`. Corre sobre la copia del scratchpad y las mallas se copian al proyecto.
3. **Escenas y datos:** `TrailBase` y `Hilt` en `katana.tscn`; `Grip` en `katana_sheath.tscn`; `sheath_position` en `katana.tres`.
4. **Hoja de capturas:** katana suelta, en la mano en la guardia y en un corte, envainada en la carga, y la vista de la cámara del juego. Te la muestro antes de seguir y ajusto las medidas si hace falta, dentro de los rangos de AC683.
5. **Envainar:** volver a medir el primer cuadro de `sheathe_slash`.
6. **Tests:** AC683–AC686 y AC688 en `weapon_model_test.gd` y `sheath_grip_test.gd`. Corro solo las suites de AC688.
7. **Cierre:** notas y checklist en esta spec, `SOURCE.md` de la katana y mapa de `CLAUDE.md` ("Funda del arma" y "Largo visual del arma").

## 6. Tests adaptados

- Ninguno: ningún test tenía fijos el `Grip`, el `Hilt`, el `TrailBase` ni `sheath_position`.

## 7. Riesgos

- **El mango adelante de la cadera** al envainar puede atravesar el muslo derecho o el torso en poses giradas. AC674 no lo cubre (mide la funda), así que se revisa en las capturas. Si pasa, se ajusta el `wrist_l` de `LEFT_SHEATH_ARM`.
- **Las manos en la carga quedan más separadas** (~28 cm contra ~13 cm hoy). Como los brazos son invisibles y la mano derecha va al `Hilt` por objetivo, no hay brazo que se estire de más. Igual se revisa que la pose se siga leyendo.
- **Normales con escala no uniforme:** si quedan mal, el mango se ve facetado raro. Se corrige con la inversa transpuesta, y las capturas lo revisan.
- **Tsuba grande en combate:** 17 cm cerca del torso pueden cortar el cuerpo en algunos cuadros de los golpes. Se revisa en las capturas; si molesta, se baja dentro del rango de AC683 (≥ 16 cm).

## 8. Enmienda propuesta: 4.11.0 (MINOR)

La regla de **mallas derivadas** (Principio II) hoy solo permite separar partes. Pasa a decir:

> **Mallas derivadas:** si el archivo fuente no permite mostrar por separado una parte que el juego necesita (p. ej. una malla skinned con hoja y funda), se puede derivar una malla estática por parte (`.res` en la carpeta del asset). **Una malla derivada también puede reproporcionar regiones del modelo (estirar o escalar un mango, una guarda) para que encaje con el cuerpo del jugador, sin agregar ni quitar vértices ni cambiar UV o materiales.** El procedimiento queda documentado en su `SOURCE.md`, **y el script que la genera vive en la carpeta del asset**.

Historial: *4.11.0 (2026-09-27): Principio II: las mallas derivadas pueden reproporcionar regiones del modelo para encajar con el cuerpo del jugador; su generador vive en la carpeta del asset (ver `katana-hand-proportions.md`).*

Es MINOR porque agrega un permiso nuevo, como las enmiendas 4.5.0 y 4.9.0.

## 9. Notas de implementación

- **Medido antes de generar:** la gema de la mano derecha mide `h` = **0.1067 m** de medio largo sobre el eje del arma (su caja va de z = −0.160 a +0.053) y su centro está en z = −0.0533, como decía §1. Con eso, el generador ubica la tsuba y el pomo con `NEW_GUARD_BACK_Y` = 0.20455 y `NEW_POMMEL_Y` = −0.07091.
- **Medidas finales** (espacio de `katana.tscn`):

  | Parte | Spec (§2.1) | Resultado |
  |---|---|---|
  | Mango | ~31 cm, ~5 × 4.4 cm | **30.3 cm** (de −0.170 a +0.133), **5.0 × 4.3 cm** |
  | Tsuba | Ø ~17.4 cm, ~3 cm de espesor, de −0.178 a −0.206 | **Ø 16.6 × 17.4 cm**, **1.65 cm** de espesor, de **−0.170 a −0.187** |
  | Pomo detrás del puño | ~8 cm | **8.0 cm** |
  | Hoja | punta en −1.27 | punta en **−1.267** (1.14 → 1.08 m) |
  | Funda | boca en la tsuba, punta igual | boca en **−0.187**, punta en **−1.270** |

  - **Tsuba y funda algo más atrás que en §2.1:** el `h` medido (0.107) es menor que el estimado (0.115).
  - **Tsuba más fina que lo estimado:** en §1 se midió en franjas de 1 cm y se sobreestimó; la franja real del glb es de 1.2 mm × 1.1 = 1.3 cm, y ×1.25 da 1.65 cm. Igual está dentro de AC683 (≤ 3.5 cm).
  - **Sección del mango:** AC683 mide el ancho (5.0 cm ≥ 4.5). El espesor es 4.3 cm, que es ×1.5 de los 2.9 cm originales.
- **Marcadores y datos** (con el mismo criterio que §2.3/§2.4, recalculado con las medidas finales):
  - `TrailBase` en z = **−0.20** (1.35 cm delante de la tsuba; §2.3 estimaba −0.22);
  - `Hilt` en z = **−0.0533**;
  - `Grip` de la funda en z = **−0.3032** (cara delantera de la tsuba − 1 cm − `h`; §2.4 estimaba −0.331);
  - `sheath_position` = **(0, −0.0533, −0.3032)**, con la misma `sheath_rotation`.
- **Primer cuadro de `sheathe_slash`:** posición (−0.5067, 0.4411, −0.0342), rotación (0.2803, −1.8888, 0.3483).
  - El cuadro anterior ya estaba desactualizado antes de este cambio (AC675 fallaba en `main`: 3.3 cm y 78°), porque `class-combat-identity` cambió la pose de `sheathe_charge`. Con este valor, AC675 vuelve a pasar.
  - Envainada, la hoja apunta a la derecha del jugador (+X, la carga es en *hanmi*). Se dejó el ángulo Y tal como sale (−1.889 → 0.7 en el segundo cuadro), así que el desenvaine barre por delante del cuerpo, de derecha a izquierda (*nukitsuke*), y no por detrás.
- **Generador:**
  - pasó a funciones estáticas (`source_arrays()`, `build(bone)`, `new_guard_front_y()`, `main_bone()`), para que los tests reconstruyan las mallas en memoria sin guardar;
  - libera la escena del glb (antes dejaba leaks al salir);
  - dos corridas dan archivos idénticos.
- **Capturas** (Xvfb + OpenGL, antes y después): katana suelta desde arriba, primer plano del mango, guardia, primer golpe en `hit_start`, carga de Envainar y vista alta.
  - Tsuba y pomo se ven a los dos lados del puño en la guardia y en el golpe.
  - En la carga el orden es mano izquierda, tsuba, mano derecha, pomo.
  - El mango delante de la cadera no atraviesa el muslo en las capturas (riesgo de §7). La tsuba de 17 cm no corta el torso en los cuadros revisados.
- **Tests nuevos:**
  - `weapon_model_test`: AC683, AC686 y AC688;
  - `sheath_grip_test`: AC684 y AC685;
  - helper `test/helpers/katana_parts.gd`, que separa tsuba y mango usando las constantes del generador.
- **Resultado de las suites de AC688:** `weapon_model_test` (12), `sheath_grip_test` (15), `sheathe_test` (18) y `class_combat_identity_test` en verde, salvo los fallos previos de abajo. AC675 vuelve a pasar.
- **Fallos previos, ajenos a este cambio** (reproducidos en `main`, con los mismos valores):
  - **AC653** del Samurái en `sheathe_charge`: la hoja atraviesa el torso durante la carga. Ya registrado en `class-combat-identity.md` §9.
  - **AC670:** alcance de los tobillos y subida de la funda en la pose de carga. Antes no se veía porque la suite cortaba en AC675.
  - **AC211** (`weapon_reach_test`): `attack_range` del Samurái 2.3 contra ~2.0 por la regla. Es el mismo cambio de stats fuera de spec registrado con AC236. Este cambio no toca la punta ni el `attack_range`, así que AC686 se cumple en lo que depende de él (valores sin cambios, punta en el mismo lugar); la regla de AC211 sigue fallando igual que antes.
- **Suite completa:** 689 casos, comparados uno a uno con `main` en las mismas condiciones. Este cambio arregla AC675 y deja a la vista AC670 (previo, ver arriba). No agrega ningún fallo.
  - AC684 y AC685 se corrieron aparte, en una copia de la suite sin AC670 (GdUnit corta la suite en el primer fallo): 14/14 en verde.
  - `attack_component_test` AC9 y AC601 y `boss_challenge_run_test` AC152 fallaron una vez solo de este lado. Corridos aislados dos veces en las dos copias: AC9 falla y pasa igual en `main` (enemigo liberado durante la estocada, `attack_component.gd:358`), y AC601 y AC152 pasan en las dos. Son intermitentes y ajenos a la katana.
  - Los demás fallos son los mismos que en `main`: AC188, AC211, AC221, AC236, AC285/AC298, AC288, AC298, AC363, AC578, AC619, AC620 y AC653.
- **Smoke test:** escena principal, arena y arena con el Samurái (`--quit-after 300`), sin errores ni warnings, salvo los de UID inválido que produce cualquier copia limpia porque los `.uid` están en el `.gitignore`.
- **Entorno:** los tests se corrieron en Linux con Godot 4.7.2 y el `addons/gdUnit4/bin/` de gdUnit4 v6.2.0 (esa carpeta la ignora el `bin/` del `.gitignore`, así que no está en el repo).

### Checklist de la constitución

- [x] Principio I: pilar de combate (la silueta del Samurái).
- [x] Principio II: la malla derivada sigue en la carpeta del asset, con `SOURCE.md` y su generador (4.11.0); mismo material de paleta; sin colores nuevos.
- [x] Principio III: el alcance sigue en datos (`attack_range`, `hilt_offset`) y el modelo se alinea con ellos.
- [x] Principio IV: el generador con tipado estricto, en inglés.
- [x] Principio V: sin cambios en runtime (solo mallas precalculadas).
- [x] Principios VI y VII: sin cambios.
