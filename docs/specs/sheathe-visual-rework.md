# Feature: Carga y corte de Envainar con más peso visual

- **Estado:** Implementada (2026-09-28). Suites de la spec y las que toca en verde, salvo fallos previos y ajenos (§9.3); import y smoke test del arena sin errores ni warnings; capturas en tiempo real revisadas.
- **Constitución:** `docs/constitution.md` v4.23.0 → enmienda **MINOR 4.24.0** (ver §7).
- **Pilar (Principio I):** **combate.** Envainar es el golpe más fuerte del Samurái. El jugador lo paga con 3 s de exposición, pero hoy la carga solo sacude la cámara y el corte es una V de dos placas rígidas.
  - Mientras carga, la tensión tiene que crecer: la cámara se cierra, la funda brilla y el cuerpo se hunde.
  - Al soltar, el golpe tiene que leerse como un *iai*: la línea del corte aparece primero, el mundo se sostiene un instante y recién ahí estalla el viento.
- **Reemplaza en parte:** `wind-cut-v.md`. AC271 y AC272 (las dos paredes) pasan a AC1043–AC1044. AC273–AC276 siguen vigentes, pero las chispas, el polvo y el destello salen en el estallido (§2.5) y no al soltar.
- **Pedido del responsable:** ideas A1, A2, A3 y A6 (carga), B7 y B8 (soltada) y C10–C14 (corte), con estas decisiones:
  - acercamiento por **FOV**;
  - **≈10°** a carga completa;
  - **media luna + V**: la media luna viaja a la altura del pecho, debajo sube la V por tramos y el eco es una segunda media luna.

## 1. Estado actual

- **Carga** (`CHARGE_TIME` 3 s, piso 1.5 s): en cada hito (cada segundo y al completar), `ChargeFeedbackComponent` sacude la cámara, hace temblar el cuerpo y hace latir el área del piso. La pose es `sheathe_charge`, estática salvo una respiración.
- **Soltada:** el tajo cae en el mismo cuadro (daño, números, empuje) y `WindCutVfx.play()` levanta a la vez dos `BoxMesh` inclinados ±25°, con chispas, polvo y un destello en la punta. El casteo compromete 0.5 s y el clip `sheathe_release` dura 0.9 s, con el desenvaine en su punto más alto a los 0.1 s.
- **Cámara:** `ThirdPersonCamera` tiene `shake()` y `kick_fov()` (abre el FOV de golpe y lo devuelve con una curva ease-out). No existe un acercamiento sostenido.

## 2. Diseño

### 2.1 A1: la cámara se cierra en cada hito (FOV)

- `ThirdPersonCamera` suma un **FOV sostenido**: `hold_fov(offset_deg, blend_time)`. El FOV final pasa a ser `base + sostenido + kick`, y el sostenido va hacia el objetivo en `blend_time` con una curva ease-out. Con un offset negativo la vista se cierra.
- En cada hito, `ChargeFeedbackComponent` llama `hold_fov(-zoom_for(index, is_full), zoom_blend)`:
  - `zoom_for` sigue el patrón de `shake_for`: `zoom_base_deg + zoom_step_deg × (index − 1)` hasta `zoom_full_deg`, y `zoom_full_deg` al completar;
  - con los datos: **−3° al 1.er segundo, −6° al 2.º y −10° al completar**;
  - con una carga más corta (1.5 s): −3° y después −10°.
- **Carga cancelada** (agarre, muerte o reemplazo de la habilidad): el FOV sostenido vuelve a 0 en `zoom_return`, sin latigazo.

### 2.2 A2: latigazo al estallar

- Cuando estalla el corte (§2.5), la habilidad avisa `AbilityComponent.charge_unleashed`. `ChargeFeedbackComponent` entonces:
  - pone el FOV sostenido en 0 en el acto;
  - llama `kick_fov(unleash_kick_deg, unleash_kick_return)`: la vista se abre +6° por encima de la base y se asienta en 0.45 s.
- Un Envainar potenciado (Tsubame Gaeshi, sin carga) también da el latigazo.
- **Si un dash corta el casteo antes del estallido**, `cast_released` devuelve el FOV sostenido en `zoom_return`. El estallido queda solo visual: sin latigazo, sin sacudida y sin `charge_unleashed`. Así no pisa el FOV del dash.

### 2.3 A3: la funda brilla en cada hito

- Nodo nuevo `ChargeGlow` (`SheatheChargeGlow`, `top_level`) en `sheathe_ability.tscn`: una `OmniLight3D` y una esfera chica con el material blanco aditivo del corte, creadas una vez.
- En cada hito se enciende en la **boca de la funda** (`WeaponMount.get_sheath_pose().origin`) y la sigue mientras dure el pulso:
  - la energía crece en cada hito: `glow_energy_base + glow_energy_step × (index − 1)`, y `glow_energy_full` al completar;
  - la esfera crece hasta `glow_radius` (`glow_full_radius` al completar) mientras se desvanece;
  - todo se apaga en `glow_duration` (`glow_full_duration` al completar), en décimas de segundo, como pide el Principio II. No hay brillo sostenido.

### 2.4 A6: la postura se hunde

- `samurai_profile.gd` suma tres clips de carga: `sheathe_charge_1`, `sheathe_charge_2` y `sheathe_charge_full`. Son `_charge_pose()` con la cadera más baja (−0.03, −0.06 y −0.10 m), las rodillas más flexionadas y el torso más volcado hacia adelante (+4°, +8° y +12°), con la misma respiración.
  - Los pies siguen apoyados: los ángulos de cadera, rodilla y tobillo se ajustan para eso.
- `SheatheConfig.charge_body_clips` (`Array[StringName]`) reemplaza a `charge_body_clip`: `[sheathe_charge, sheathe_charge_1, sheathe_charge_2, sheathe_charge_full]`.
  - Nivel = 0 al empezar, `index` en cada hito y el último al completar (con una carga de 1.5 s: 0 → 1 → full).
  - `get_body_clip()` devuelve el clip del nivel y `get_body_clip_blend()` devuelve `charge_sink_blend` (0.2 s) mientras carga.
  - Al soltar devuelve `release_body_blend` (0.04 s). El primer cuadro de `sheathe_release` sigue siendo `_charge_pose()`, así que desde una postura hundida la mezcla corta evita el salto.

### 2.5 B7 + B8: línea, pausa y estallido

Línea de tiempo desde que se suelta (t = 0), con los datos de `SheatheConfig`:

| t | Qué pasa |
|---|---|
| **0** | Cae el tajo **igual que hoy**: daño, crítico, números, impacto, empuje y Zanshin/Tsubame. `WindCutVfx.play()` dibuja solo la **línea de corte**: una franja blanca finísima en el piso, que crece del jugador a `L` en `line_grow_duration` (0.05 s). |
| **0.10** (`strike_pause_at`) | **Pausa del desenvaine:** `report_strike(release_feel, enemigos golpeados)` con `hitlag` 0.12. `HitstopComponent` congela el clip en el punto alto del desenvaine y congela y sacude a los golpeados (su empuje queda en suspenso). Pasa aunque no haya golpeados: el desenvaine se sostiene siempre. |
| **0.22** (`burst_at`) | **Estallido:** la línea se apaga y `WindCutVfx.burst()` levanta la V por tramos, la media luna y su eco, la grieta, las chispas, el polvo y el destello. `report_strike(burst_feel)` sacude la cámara (sin enemigos) y `report_charge_unleashed()` da el latigazo (§2.2). Los enemigos golpeados salen despedidos al terminar su pausa. |

- **Dash durante el casteo** (lo corta, AC722): si el corte llega antes de 0.10, no hay pausa. Si llega antes de 0.22, el estallido sale igual en su tiempo, pero solo como VFX (§2.2). La línea y el estallido viven en `WindCutVfx`, que es `top_level` y se queda donde cayó el tajo.
- **Compromiso y clip:** el casteo sigue durando 0.5 s. La pausa detiene el clip 0.12 s, así que al terminar el casteo el clip va por 0.38 s en vez de 0.5 s. La recuperación libre sigue igual (AC729).
- `Engine.time_scale` no se toca (Principio VII).
- Un solo `Timer` creado una vez en `SheatheAbility` maneja las dos etapas (pausa y estallido). Una soltada nueva reinicia la secuencia.

### 2.6 C10 + C11: V por tramos que se afina al irse

- Cada pared pasa a ser `segment_count` (7) tramos `BoxMesh` a lo largo de `L`. Cada tramo mide `L / N × segment_fill` (0.9) de largo, así que quedan cortes finos entre ellos. Siguen inclinados ±`half_angle` y apoyados en el piso.
- **Perfil:** el tramo `i` llega a `altura × lerp(edge_height_ratio, 1, sin(π·(i + 0.5)/N))` (`edge_height_ratio` 0.35). Queda más alto al centro y afilado en los extremos. `altura = max_height × factor`, como hoy.
- **Ola:** el tramo `i` (0 = el más cercano al jugador) empieza a subir a los `i × wave_step` (0.02 s) del estallido y tarda `grow_duration` en llegar. El viento corre hacia la punta.
- **Afinado (C11):** después de subir, cada tramo se desvanece en `fade_duration`. En ese tiempo su espesor va a 0 y su altura baja a `fade_height_ratio` (0.6), además de ganar transparencia (de `start_transparency` a 1).
  - Los tramos de los extremos empiezan antes: el retraso de cada uno es `fade_stagger × (1 − distancia normalizada al centro)` (`fade_stagger` 0.1 s). El tajo se cierra desde los bordes hacia adentro.

### 2.7 C12 + C13: media luna y eco

- **Malla:** `ArrayMesh` plano construido **una vez** en `_ready` de `WindCutVfx` (enmienda §7). Es un arco de `crescent_arc_degrees` (150°) con radio exterior `crescent_radius` (1.6 m) y `crescent_segments` (24) divisiones.
  - Su espesor radial es `crescent_width` (0.35 m) en el centro y va a 0 en las puntas (`sin` del ángulo): forma de media luna.
  - Usa el material blanco aditivo del corte.
- **Movimiento:** nace en el estallido a `crescent_height` (1.1 m, el pecho) con la curva hacia adelante (la cara convexa hacia la punta).
  - Se inclina `crescent_roll_degrees` (30°) alrededor del eje del tajo, como el *gyaku kesa-giri* que sube hacia la derecha.
  - Viaja de `z = −crescent_start` (0.5 m) a `z = −L` en `crescent_travel` (0.2 s), con una curva ease-out.
  - Su escala va de `crescent_start_scale` (0.6) a 1 × `lerp(crescent_min_scale, 1, carga)` (`crescent_min_scale` 0.6).
  - Su transparencia va de `crescent_start_transparency` (0.3) a 1 durante `crescent_travel + crescent_fade` (0.2 + 0.25 s). Después se oculta.
- **Eco (C13):** una segunda instancia de la misma malla, que sale `echo_delay` (0.05 s) después con escala × `echo_scale` (1.35) y transparencia inicial `echo_start_transparency` (0.7). Sigue el mismo recorrido y dura lo mismo.

### 2.8 C14: la grieta en el piso

- `crack_count` (9) piezas `BoxMesh` finas (`crack_width` 0.07 m, 0.01 m de alto, apenas sobre el piso), repartidas a lo largo de `[0, L]`, cada una de `L / N × 1.1` de largo.
  - Cada una gira hasta ±`crack_jitter_degrees` (14°) y se corre de costado hasta ±`crack_offset` (0.06 m), con un `RandomNumberGenerator` propio del nodo. Queda una línea quebrada.
- Material nuevo `materials/vfx/ground_crack_material.tres`: gris muy oscuro, unshaded, transparente, sin sombras.
- Se abre en el estallido del jugador hacia la punta: la pieza `i` aparece a los `i × crack_open_step` (0.012 s). Dura `crack_duration` (1.2 s) desde el estallido y se desvanece en `crack_fade` (0.4 s). Después se oculta.

### 2.9 Chispas, polvo y destello

Son los de hoy (AC273–AC276), pero salen en el **estallido** y no al soltar. No cambian sus datos.

## 3. Resources y datos (Principio III)

- **`ChargeFeedbackConfig`** (`data/player/charge_feedback_config.tres`), grupo "Zoom":
  - `zoom_base_deg` 3, `zoom_step_deg` 3, `zoom_full_deg` 10, `zoom_blend` 0.2, `zoom_return` 0.25;
  - `unleash_kick_deg` 6, `unleash_kick_return` 0.45;
  - método `zoom_for(index, is_full)`.
- **`SheatheConfig`** (`sheathe_config.tres`):
  - `charge_body_clips` reemplaza a `charge_body_clip`;
  - `charge_sink_blend` 0.2, `release_body_blend` 0.04;
  - grupo "Release": `strike_pause_at` 0.1, `release_feel` (`StrikeFeel`: `hitlag` 0.12, `shake_strength` 0), `burst_at` 0.22, `burst_feel` (`StrikeFeel`: `hitlag` 0, `shake_strength` 0.6);
  - grupo "Charge glow": `glow_energy_base` 1.0, `glow_energy_step` 1.0, `glow_energy_full` 3.0, `glow_range` 2.0, `glow_radius` 0.25, `glow_full_radius` 0.45, `glow_duration` 0.2, `glow_full_duration` 0.35.
- **`WindCutConfig`** (`wind_cut_config.tres`):
  - grupo "Line": `line_width` 0.04, `line_grow_duration` 0.05, `line_transparency` 0.2;
  - "Walls" suma `segment_count` 7, `segment_fill` 0.9, `edge_height_ratio` 0.35, `wave_step` 0.02, `fade_height_ratio` 0.6 y `fade_stagger` 0.1 (siguen `max_height`, `half_angle_degrees`, `wall_thickness`, `grow_duration` → 0.12, `fade_duration` y `start_transparency`);
  - grupo "Crescent": `crescent_arc_degrees`, `crescent_radius`, `crescent_width`, `crescent_segments`, `crescent_height`, `crescent_roll_degrees`, `crescent_start`, `crescent_travel`, `crescent_fade`, `crescent_start_scale`, `crescent_min_scale`, `crescent_start_transparency`, `echo_delay`, `echo_scale` y `echo_start_transparency`;
  - grupo "Crack": `crack_count`, `crack_width`, `crack_jitter_degrees`, `crack_offset`, `crack_open_step`, `crack_duration` y `crack_fade`.
- Todos los valores son de partida y se ajustan con las capturas.

## 4. Interfaz pública

- `ThirdPersonCamera`: `hold_fov(offset_deg: float, blend_time: float)` y `get_fov_hold() -> float` (el valor actual del sostenido).
- `AbilityComponent`:
  - señales `charge_cancelled` (la emite `cancel_charge()`) y `charge_unleashed`;
  - método `report_charge_unleashed()`.
- `SheatheAbility`: `get_charge_glow() -> SheatheChargeGlow`, `get_release_stage()` (para tests) y `get_body_clip_blend()`.
- `SheatheChargeGlow` (nuevo, `components/abilities/sheathe_charge_glow.gd`): `pulse(index, is_full)`, `follow(position)`, `advance(delta)`, `is_pulsing()`, `get_light()`, `get_sphere()`.
- `WindCutVfx`:
  - `play(origin, yaw, length, factor)` pasa a dibujar solo la línea;
  - `burst()` nuevo, para el estallido;
  - getters `get_line()`, `get_segment(side, i)`, `get_crescent()`, `get_echo()`, `get_crack_piece(i)` y `is_bursting()`.
  - `get_wall()`, `get_wall_height()` y `get_wall_length()` se reemplazan por los getters de tramos.

## 5. Criterios de aceptación (AC1034–AC1052)

> AC1017–AC1033 los usa `parry-riposte-rework.md` (sesión en paralelo). Se reservan AC1034–AC1055 al empezar la implementación.

**Carga**

- **AC1034** Con `CHARGE_TIME` 3 s, el FOV sostenido pasa a −3° al 1.er hito, −6° al 2.º y −10° al completar. Llega a cada valor en ≤ `zoom_blend` y se mantiene mientras siga cargando.
- **AC1035** Con `CHARGE_TIME` 1.5 s, el FOV sostenido pasa a −3° y después a −10°.
- **AC1036** Si la carga se cancela, el FOV vuelve a la base en ≤ `zoom_return`, sin latigazo.
- **AC1037** En cada hito se enciende la luz de la funda a ≤ 0.05 m de la boca de la funda, con más energía en cada hito y `glow_energy_full` al completar. Se apaga y se oculta pasados `glow_duration` (`glow_full_duration` al completar). Fuera de un pulso no hay luz.
- **AC1038** La postura se hunde: el clip pedido es `sheathe_charge`, después `sheathe_charge_1` y `sheathe_charge_2`, y `sheathe_charge_full` al completar (con 1.5 s: `sheathe_charge_1` y después `sheathe_charge_full`). En cada nivel la cadera queda más baja que en el anterior y los dos pies quedan a ≤ 0.02 m del piso. Mientras carga la mezcla es `charge_sink_blend`, y al soltar es `release_body_blend`.

**Soltada**

- **AC1039** Al soltar caen en el mismo cuadro el daño, los números y el empuje (sin cambios en `sheathe_test` ni en `sheathe_feel_test`). Aparece solo la línea: crece hasta `L` en `line_grow_duration`, apoyada en el piso, y los tramos, la media luna, el eco y la grieta siguen ocultos hasta `burst_at`.
- **AC1040** A `strike_pause_at` de soltar, el clip del jugador se detiene `release_feel.hitlag` y los enemigos golpeados entran en hit lag esa misma duración. Sin golpeados, el clip se detiene igual. El casteo sigue durando `cast_duration` (0.5 s).
- **AC1041** A `burst_at`:
  - la línea se oculta y el corte estalla;
  - la cámara se sacude con `burst_feel.shake_strength`;
  - `charge_unleashed` se emite una vez;
  - el FOV sostenido pasa a 0 y el FOV queda en base + 6°, y vuelve a la base en `unleash_kick_return`;
  - un Envainar potenciado también da el latigazo.
- **AC1042** Un dash que corta el casteo antes de `strike_pause_at` evita la pausa. El estallido sale igual a `burst_at`, pero sin `charge_unleashed`, sin sacudida y sin latigazo, y el FOV sostenido vuelve a 0 en `zoom_return`.

**Corte**

- **AC1043** V por tramos (reemplaza a AC271):
  - hay `segment_count` tramos por lado sobre `[0, L]`, inclinados ±`half_angle` y con el borde inferior en el piso;
  - con N impar, el del medio llega a `max_height × factor` y los de los extremos a `edge_height_ratio` de eso (± la forma del seno);
  - el tramo `i` empieza a subir a los `i × wave_step` del estallido;
  - una carga baja da tramos más bajos.
- **AC1044** Afinado (reemplaza a AC272):
  - la transparencia de los tramos es ≥ 0.5 en todo momento;
  - durante el desvanecimiento, el espesor baja hacia 0 y la altura hacia `fade_height_ratio`;
  - los tramos de los extremos empiezan a desvanecerse antes que los del centro;
  - todos se ocultan al terminar.
- **AC1045** Media luna:
  - la malla se construye una vez (la misma instancia de `Mesh` y la misma cantidad de vértices en dos tajos);
  - su espesor es `crescent_width` en el centro y ≤ 0.01 m en las puntas;
  - nace a `crescent_height` con la inclinación `crescent_roll_degrees`, avanza de `−crescent_start` a `−L` en `crescent_travel` y se desvanece;
  - a carga completa termina con escala 1; con carga mínima, con `crescent_min_scale`;
  - se oculta después de `crescent_travel + crescent_fade`.
- **AC1046** El eco sale `echo_delay` después de la media luna, es `echo_scale` veces más grande y, a la misma edad, más transparente que ella.
- **AC1047** Grieta:
  - hay `crack_count` piezas sobre `[0, L]`, a ≤ 0.02 m del piso, con giro ≤ `crack_jitter_degrees` y corrimiento ≤ `crack_offset`;
  - la pieza `i` aparece a los `i × crack_open_step` del estallido;
  - usa el material de la grieta;
  - se desvanece a partir de `crack_duration` y se oculta a los `crack_duration + crack_fade`.
- **AC1048** Chispas, polvo y destello (AC273–AC275) emiten en el estallido y no al soltar.
- **AC1049** Dos tajos seguidos reutilizan los mismos nodos, igual que AC276: la cantidad de hijos de `WindCutVfx` y de `SheatheChargeGlow` no cambia. Un segundo tajo antes de que termine el primero lo reinicia.

**Reglas**

- **AC1050** `Engine.time_scale` vale 1 durante toda la carga y la soltada.
- **AC1051** Sin shaders propios: la luz de la funda, la línea, los tramos y la media luna usan el material blanco aditivo compartido (`.tres`), y la grieta usa `ground_crack_material.tres`.
- **AC1052** Regresión:
  - pasan `sheathe_test`, `sheathe_feel_test`, `sheathe_release_test`, `tsubame_gaeshi_test`, `zanshin_test`, `nuki_test`, `wind_step_test`, `dash_cancel_test`, `hitstop_test`, `ability_strike_feel_test`, `dash_vfx_test` (FOV del dash), `player_animator_test` y `wind_cut_vfx_test` (adaptado);
  - también AC641 del Samurái;
  - import y smoke test del arena con el Samurái sin errores ni warnings.

## 6. Plan

Cada paso deja el proyecto funcionando.

1. **Reserva:** `CLAUDE.md` → próximo AC libre AC1056.
2. **Cámara y carga:**
   - `hold_fov`/`get_fov_hold` en `ThirdPersonCamera`;
   - `charge_cancelled`, `charge_unleashed` y `report_charge_unleashed()` en `AbilityComponent`;
   - zoom y latigazo en `ChargeFeedbackComponent` y `ChargeFeedbackConfig`;
   - tests AC1034–AC1036.
3. **Brillo:** `SheatheChargeGlow` y su nodo en `sheathe_ability.tscn`, más el grupo "Charge glow" en `SheatheConfig`. Test AC1037.
4. **Postura:**
   - los tres clips en `samurai_profile.gd`, `charge_body_clips` y las mezclas;
   - test AC1038 con los pies en el piso;
   - hoja de capturas de los cuatro niveles.
5. **Secuencia de soltada:**
   - `Timer` de etapas en `SheatheAbility` y `play()`/`burst()` en `WindCutVfx`;
   - por ahora el estallido usa las paredes actuales;
   - tests AC1039–AC1042 y AC1050.
6. **Corte nuevo:** tramos con ola y afinado, media luna con eco, grieta y su material. Tests AC1043–AC1049 y AC1051, reemplazando los de AC271/AC272 en `wind_cut_vfx_test.gd` y adaptando AC273–AC276 al estallido.
7. **Enmienda 4.24.0** en la constitución (§7). `wind-cut-v.md` se marca como parcialmente reemplazada.
8. **Cierre:**
   - las suites de AC1052 en verde (solo las de esta spec, como pidió el responsable);
   - import y smoke test;
   - **capturas en tiempo real**: carga en sus cuatro niveles, pausa, estallido a 0.05/0.15/0.3 s y grieta, para ajustar valores de datos;
   - checklist de la constitución y estado **Implementada**;
   - `CLAUDE.md`: fila de "Dónde se ajusta" para Envainar y specs recientes.

## 7. Enmienda de la constitución: MINOR 4.24.0

- **Principio II, mallas planas procedurales:** la regla de 4.5.0 (sectores `ArrayMesh` para avisos enemigos) se extiende a los **VFX de habilidades del jugador**: mallas planas `ArrayMesh` construidas **una vez al cargar** el nodo del VFX, con material `.tres` compartido y sin texturas. Primer uso: la media luna de Envainar.
- **Principio II, tabla de colores:**
  - la fila del corte de viento de Envainar pasa a "línea, tramos en V y media luna con su eco (blanco translúcido, aditivo)";
  - fila nueva: "Grieta del corte de Envainar: gris muy oscuro translúcido, unshaded, en el piso; se desvanece en ~1.5 s";
  - fila nueva: "Brillo de carga de Envainar: luz breve y esfera blanca translúcida en la boca de la funda";
  - la lista de elementos que comparten el blanco suma el brillo de carga.
- El FOV sostenido y la pausa del desenvaine ya caben en el Principio VII (hit lag local con `StrikeFeel`, 4.22.0). No hace falta tocarlo.

> Si la sesión del Parry cierra antes con otra versión, esta enmienda toma el número MINOR siguiente.

## 8. Riesgos

- **La pausa sin enemigos** puede sentirse lenta al practicar en el aire. Mitigación: es un dato (`release_feel.hitlag`). Si molesta, se puede limitar a cuando haya golpeados.
- **Los enemigos empujados 0.1 s y después congelados** pueden verse como un tirón. Si las capturas lo muestran, se congela primero y se empuja en el estallido: es un cambio de orden en `_slash()`, sin cambiar la distancia final.
- **Hundir la cadera** sin mover los pies obliga a ajustar cadera, rodilla y tobillo por nivel. AC1038 mide los pies, y la hoja de capturas confirma que no se atraviesa la funda.
- **La media luna vista de canto** (cámara baja) es casi invisible. Por eso tiene inclinación, y el eco y la V dan volumen desde cualquier ángulo.
- **Sesiones en paralelo** (`parry-riposte-rework`, `berserker-greatsword`) tocan la constitución y `CLAUDE.md`. Se relee el estado de los dos antes de editarlos.

## 9. Notas de implementación (2026-09-28)

### 9.1 Desvíos menores de la spec

- **`charge_body_clip` se conserva** como nivel 0, y `charge_sink_clips` guarda los tres niveles siguientes (§2.4 decía "reemplaza"). La conducta es la misma, y así no se tocan los ~20 tests que leen `charge_body_clip`. `SheatheConfig.charge_clip_for(index, is_full)` elige el clip.
- **La secuencia de soltada no usa un `Timer`**, porque no avanzaría en los tests que manejan la habilidad a mano. Hay un hook genérico nuevo, `AbilityBehavior.tick(ability, delta)`, que `AbilityComponent.advance()` llama en cada paso, esté casteando o no. `SheatheAbility.tick()` cuenta desde la soltada y dispara la pausa y el estallido.
- **La pausa congela a los golpeados que siguen vivos**, filtrados al soltar (`_pause_buffer`). Así no se congela a un enemigo muerto que vuelve al pool.
- **Profundidad de la postura:** la cadera baja 0.04, 0.08 y 0.13 en unidades de pose, que son ≈2.6, 5.2 y 8.5 cm en el mundo (§2.4 decía −0.03/−0.06/−0.10 sin unidad). El torso se vuelca 4°, 8° y 12°. Las piernas se resolvieron con un script de Godot (descenso por coordenadas sobre cadera y rodilla, más la rotación del tobillo que conserva la orientación del pie). Los tobillos quedan a < 1 mm de donde están en `_charge_pose()`.
- **Media luna con carga mínima:** su escala final es `max(factor, crescent_min_scale)`. Como Envainar solo pasa el factor de carga, la escala es 1 a carga completa y `crescent_min_scale` con carga mínima, como pide AC1045.
- **`WindCutConfig.fade_thickness_ratio`** (nuevo; Envainar 0) controla el afinado. El Tajo aéreo del Berserker reutiliza `WindCutVfx` y conserva su aspecto así:
  - `air_slash_wind_cut_config.tres` usa 1 tramo por lado, sin afinado, sin media luna (`crescent_segments = 0`) y sin grieta;
  - `AirSlashComponent._impact()` llama `burst()` justo después de `play()`.
- **El enum de lados** se llama `WindCutVfx.WallSide`, porque `Side` choca con el enum global de Godot.
- **La cámara** expone `advance_fov(delta)` (lo llama `_process`) y `get_fov_hold_target()`, para testear el acercamiento sin cuadros reales. El FOV se recalcula siempre como base + sostenido + kick.

### 9.2 Tests adaptados

- `wind_cut_vfx_test.gd`: los tests de AC271–AC272 se reemplazaron por AC1043–AC1047, AC1049 y AC1051. AC273–AC276 siguen igual: en el helper `_slash` el casteo entero ya pasa por el estallido.
- `air_slash_test.gd` AC587: lee la altura del único tramo (`get_segment(LEFT, 0).scale.y`) en lugar de `get_wall_height()`.
- `sheath_grip_test.gd` AC672 (pesos de agarre) y `class_combat_identity_test.gd` (la hoja no atraviesa el cuerpo): los clips de carga hundidos cuentan como carga, con la katana envainada y la derecha en el mango.
- `sheathe_release_test.gd` AC729: la espera hasta `idle` suma `release_feel.hitlag`, porque la pausa del desenvaine atrasa el final del clip.

### 9.3 Suites corridas

- `sheathe_visual_rework_test` (16) y `wind_cut_vfx_test` (12): en verde.
- En verde también: `sheathe_feel_test`, `sheathe_release_test`, `sheath_grip_test`, `class_combat_identity_test`, `hitstop_test`, `dash_vfx_test`, `tsubame_gaeshi_test`, `zanshin_test`, `nuki_test`, `wind_step_test` y `player_animator_test`.
- Fallan **igual en una copia sin los cambios de esta spec** (ajenos):
  - `sheathe_test` AC241;
  - `air_slash_test` AC578, AC581, AC584 y AC586 (×2);
  - `dash_cancel_test` AC355, AC363 y AC364;
  - `ability_strike_feel_test` AC844;
  - `air_slash_visual_rework_test` AC1016 y AC1017.

### 9.4 Capturas

Carga en sus cuatro niveles, soltada y estallido, desde la cámara del jugador y de costado:

- el FOV pasa de 75° a 72°, 69° y 65°, y en el estallido salta a ≈81° y se asienta;
- la luz de la funda ilumina el piso en cada hito;
- la línea aparece antes que el resto;
- la V sube en ola, más alta al centro;
- la media luna inclinada viaja hacia la punta y la sigue su eco;
- la grieta queda en el piso cuando la V ya se fue.

Con la cámara detrás y baja, la media luna se ve bastante de canto. Si hace falta más presencia, `crescent_roll_degrees` y `crescent_width` son datos.

### 9.5 Checklist de la constitución

- [x] **Arte (II):** primitivas, `ArrayMesh` plano construido una vez (enmienda 4.24.0), partículas y luces breves. Sin shaders propios. Materiales `.tres` compartidos (`wind_cut_additive_material`, `ground_crack_material` nuevo). Blanco translúcido y gris oscuro de la grieta registrados.
- [x] **Datos (III):** todos los valores viven en `SheatheConfig`, `WindCutConfig` y `ChargeFeedbackConfig`. Las poses son datos del perfil.
- [x] **GDScript (IV):** tipado estricto, identificadores y comentarios en inglés.
- [x] **Performance (V):** los nodos se crean una vez y se reutilizan (AC1049), y el `_pause_buffer` se reutiliza.
- [x] **Sensación (VII):** la pausa es hit lag local con `StrikeFeel`. `Engine.time_scale` no se toca (AC1050).
