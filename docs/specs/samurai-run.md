# Feature: carrera del Samurái y arranque desde la guardia

- **Estado:** Implementada (2026-09-27).
- **Constitución:** `docs/constitution.md` v4.x (sin enmienda: ver §7).
- **Pilar (Principio I):** **combate / movimiento.** El jugador pasa la mitad del tiempo corriendo entre enemigos. Hoy la carrera del Samurái va volcada, con la katana pegada a la cadera, y al arrancar la hoja salta de la guardia baja de adelante (`samurai-rest-guard.md`) hacia atrás en 0.12 s. El responsable quiere la carrera de su referencia y un arranque que se lea.
- **Referencia:** foto del responsable de un samurái que corre hacia la cámara:
  - el torso casi erguido y la cabeza arriba;
  - el brazo derecho estirado al costado y hacia atrás, con la katana baja arrastrándose detrás, a la derecha;
  - la izquierda en la cadera, sobre la funda;
  - pasos casi en línea.
- **Decisión del responsable (2026-09-27):** la transición de quieto a correr es un **clip de arranque** (`run_start`), no solo una mezcla más larga.
- **Dependencias:**
  - `samurai-rest-guard.md` (la guardia desde la que se arranca);
  - `humanoid-player-model.md` (`PlayerAnimator`, la máquina de locomoción);
  - `sheath-in-left-hand.md` (AC672 y AC674 en todo clip);
  - `sheathe-release-animation.md` §10 (la recuperación libre se corta al moverse).

## 1. Estado actual

- `run` del Samurái (0.56 s, loop, cúbico):
  - el torso volcado 14–15° y la cadera baja 6–9 cm;
  - el brazo derecho colgando hacia atrás con la hoja cerca de la cadera;
  - la funda con el brazo base.
- `PlayerAnimator.next_locomotion()` pasa de `IDLE` a `RUN` en el primer cuadro con velocidad sobre `run_speed_threshold`, y `LowPolyHumanoid.play()` mezcla 0.12 s.
- La velocidad del Samurái (6.5 m/s) se alcanza en ≈ 0.16 s (aceleración de 40 m/s²).

## 2. Diseño

### 2.1 Carrera nueva (`run`, Samurái)

Mismo ciclo (0.56 s, 4 poses: contacto y paso de cada pierna, loop, cúbico), con otra silueta:

| Parte | Hoy | Nueva |
|---|---|---|
| Torso | Volcado 14–15° | **Casi erguido** (≈ 5–8°), con un contragiro leve con cada paso |
| Cabeza | Compensa el vuelco | Arriba, al frente |
| Piernas | Zancada abierta | **Pasos casi en línea** (los pies a ≤ 20 cm de lado), poco rebote |
| Brazo derecho y katana | Colgando atrás, la hoja junto a la cadera | **Estirado al costado y hacia atrás**: la mano a la derecha de la cadera, la hoja baja arrastrándose detrás y a la derecha, con un vaivén leve con los pasos |
| Brazo izquierdo | Brazo base | La mano en la cadera izquierda, sobre la funda; la funda atrás y abajo, firme |

Los ángulos de los brazos se calculan con el script de brazos (mano y dirección de la hoja o de la funda) y se ajustan con hojas de capturas al lado de la referencia.

### 2.2 Clip de arranque (`run_start`, Samurái)

- 0.2 s, sin loop, cúbico.
- **t = 0:** la guardia de `idle` (t = 0).
- **t ≈ 0.08:** el empuje. El cuerpo se inclina adelante (≈ 12°), la pierna derecha empuja y la katana barre desde adelante-abajo, pasando por el costado derecho.
- **t = 0.2:** el primer cuadro de `run`, así que la carrera entra sin salto.

### 2.3 La máquina de locomoción

- `PlayerAnimator.Locomotion` suma **`RUN_START`**, al final del enum para no mover los índices de `LOCOMOTION_CLIPS`, con el clip `&"run_start"`.
- `next_locomotion()` cambia así:
  - desde `IDLE` en el piso, con velocidad sobre el umbral, pasa a **`RUN_START`** (antes, a `RUN`);
  - `RUN_START` pasa a `RUN` cuando termina su clip;
  - si la velocidad cae bajo el umbral antes, pasa a `IDLE`;
  - en el aire, como desde `RUN`.

  El resto no cambia: `RUN_STOP`, `LAND` y `settled_locomotion()` con velocidad siguen yendo directo a `RUN`, porque el cuerpo ya viene en movimiento.
- **Perfiles sin `run_start`** (el Guerrero y el Berserker): `PlayerAnimator` pasa de `RUN_START` a `RUN` en el mismo `update()`. Suena `run` como hoy.
- La mezcla de `idle` a `run_start` es la de siempre (0.12 s). Como `run_start` arranca en la pose de `idle`, la mezcla no se nota.

### 2.4 Datos (Principio II/III)

Las poses son datos del asset, en el perfil. El estado nuevo y su clip viven en `PlayerAnimator`, junto a los demás estados de locomoción. No hay Resources nuevos.

## 3. Interfaz pública

- `PlayerAnimator.Locomotion.RUN_START` (nuevo).
- El comportamiento de `next_locomotion()` cambia desde `IDLE` (§2.3).

## 4. Criterios de aceptación (AC737–AC742)

Se miden en el espacio del `Visual` (−Z hacia donde corre, +X a la derecha del personaje), muestreando `run` cada 1/30 s:

- **AC737** La silueta de la carrera:
  - el torso se inclina ≤ 12° de la vertical y su frente queda a ≤ 20° de −Z;
  - la mano derecha está a la derecha de la cadera (x ≥ 0.2 m);
  - la punta de la hoja (`TrailTip`) está detrás de la cadera (z ≥ cadera + 0.3 m), a la derecha (x ≥ 0.3 m) y baja (y ≤ 0.7 m).
- **AC738** Pasos en línea: los tobillos quedan a ≤ 20 cm de lado entre sí. La funda sigue firme en la cadera (AC672 y AC674, que recorren todo clip).
- **AC739** `run_start`:
  - existe en el perfil del Samurái, dura 0.2 s (±0.01) y es cúbico;
  - su primer cuadro es `idle` en t = 0 y el último, `run` en t = 0 (todas las articulaciones, ±0.01°);
  - en t = 0.08 el torso se inclina ≥ 8° hacia adelante.
- **AC740** La máquina de locomoción:
  - `IDLE` con velocidad → `RUN_START`;
  - `RUN_START` con el clip terminado → `RUN`;
  - `RUN_START` sin velocidad → `IDLE`;
  - `RUN_START` en el aire, subiendo → `JUMP_START`, y bajando → `AIR`;
  - `RUN_STOP` y `LAND` con velocidad siguen yendo a `RUN`.
- **AC741** En juego:
  - un Samurái quieto que empieza a moverse reproduce `run_start` y, al terminar, `run`, sin pasar por otro clip;
  - con el Guerrero y el Berserker, empezar a moverse reproduce `run` en ese mismo cuadro.
- **AC742** Regresión:
  - pasan `player_animator_test` (AC de `IDLE` → `RUN` adaptado a `RUN_START`), `humanoid_model_test`, `class_combat_identity_test` (AC653: la hoja no atraviesa el cuerpo en `run` ni en `run_start`), `sheath_grip_test`, `samurai_rest_guard_test` y `sheathe_release_test`;
  - AC730, "moverse corta la recuperación", pasa a aceptar `run_start` o `run`;
  - quedan exceptuados los fallos previos registrados (AC363);
  - import y smoke test del arena sin errores ni warnings.

**Próximo libre después de esta spec: AC743.**

## 5. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC737–AC742 en `CLAUDE.md`.
2. **Carrera:**
   - poses nuevas de `_run_contact`/`_run_pass`, con los brazos calculados con el script;
   - hoja de capturas del ciclo (de frente, como en la foto, de perfil y con la cámara del juego). Te la muestro.
3. **Arranque:** clip `run_start` y hoja de capturas de la transición `idle` → `run_start` → `run`.
4. **Locomoción:** `RUN_START` en `PlayerAnimator` y el paso directo a `RUN` para los perfiles sin el clip.
5. **Tests:**
   - `test/entities/player/samurai_run_anim_test.gd` con AC737–AC739 y AC741;
   - AC740 en `player_animator_test`;
   - la adaptación de AC730 y del AC de `IDLE` → `RUN`;
   - las suites de AC742.
6. **Cierre:** notas y checklist en esta spec, `SOURCE.md` y `CLAUDE.md`.

## 6. Tests adaptados (se anotan al cerrar)

- `player_animator_test`: `IDLE` con velocidad pasa a `RUN_START` (antes `RUN`).
- AC730 (`sheathe_release_test`): moverse durante la recuperación pasa a `run_start` o a `run`.

## 7. Constitución

Sin enmienda:
- poses del asset y un estado de locomoción más;
- sin geometría, colores ni datos de juego nuevos;
- los clips se construyen una vez.

## 8. Riesgos

- **Deslizamiento de los pies:** a 6.5 m/s y con un ciclo de 0.56 s, cada paso cubre ≈ 1.8 m. Las piernas son invisibles y los pies chicos, así que casi no se nota. No se cambia el ciclo.
- **Arrancar y frenar enseguida** (un toque corto): `RUN_START` vuelve a `IDLE` con la mezcla de siempre, sin `run_stop`. Se revisa en juego.
- **La hoja atrás, cerca de las piernas:** AC653 no cuenta las piernas, que son invisibles. Se revisa con capturas que la hoja no cruce los pies.

## 9. Notas de implementación (2026-09-27)

- **Carrera:**
  - cuerpo y piernas en `_run_contact`/`_run_pass`: la cadera baja 3–6 cm, el torso se inclina 5–6° con un contragiro de ±8° y el cuello compensa;
  - las piernas se cierran 4° hacia el centro (`side_z(-4)`), así que los tobillos quedan a ≤ 20 cm de lado;
  - brazos por pose en la constante `RUN_ARMS`, calculados con el script: la mano derecha a ≈ (0.49, 0.89, 0.07), la hoja 23° bajo la horizontal hacia atrás y a la derecha, y la funda firme (boca a ≈ (−0.2, 0.78, 0), 23° hacia atrás y abajo).
  - Una primera versión con la mano a 0.38 m dejaba la hoja escondida detrás del cuerpo vista de frente; se abrió a ≈ 0.49 m, como en la foto.
- **`run_start`** (0.2 s, cúbico): `_stance()` → empuje en 0.08 (`_run_contact(1)` con la cadera 8 cm abajo, el torso −12° y la hoja apuntando abajo al costado derecho) → `_run_contact(1)`.
- **`PlayerAnimator`:**
  - `RUN_START` al final del enum, con su clip en `LOCOMOTION_CLIPS`;
  - `next_locomotion()` pasa de `IDLE` a `RUN_START`, sigue en `RUN_START` hasta que termina el clip y vuelve a `IDLE` sin velocidad;
  - `_advance_locomotion()` salta a `RUN` si el perfil no tiene el clip;
  - la recuperación libre de Envainar (`_tail_clip`) se sigue cortando al salir de `IDLE`.
- **`run_stop`:** su pose de frenado todavía giraba el torso −20° de la guardia de costado. Pasa a (−6, 0, 0), con la pierna izquierda (34, 12, −3).
- **Tests:**
  - `samurai_run_anim_test` (4 casos, AC737–AC739 y AC741);
  - AC740 en `player_animator_test` (13 casos);
  - regresión de AC742 en verde: `humanoid_model_test`, `class_combat_identity_test` (25), `sheath_grip_test` (16), `samurai_rest_guard_test`, `sheathe_release_test` (13), `attack_component_test` y `combat_feel_test`, salvo AC363 (previo y registrado);
  - smoke test del arena sin errores ni warnings.
- **Tests adaptados:**
  - `player_animator_test` (AC593): `IDLE` con velocidad pasa a `RUN_START`;
  - AC730 (`sheathe_release_test`): moverse durante la recuperación pasa a `run_start` o a `run`.

### Checklist de la constitución

- [x] Principio I: pilar de combate y movimiento.
- [x] Principio II: sin geometría, colores ni assets nuevos; los clips se construyen una vez.
- [x] Principio III: poses como datos del asset; sin literales de diseño nuevos en scripts de comportamiento (el nombre del clip vive con los demás clips de locomoción).
- [x] Principio IV: tipado estricto; código y comentarios de código en inglés.
- [x] Principio V: sin allocations nuevas por cuadro.
- [x] Principios VI y VII: sin cambios.
