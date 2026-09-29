# Feature: la invulnerabilidad dura lo mismo que el dash
> **Nota (2026-09-29):** la invulnerabilidad ya no dura "exactamente lo que el dash": tiene su propio parámetro, `DASH_INVULNERABILITY`, que puede ser mayor que el movimiento (`DASH_DURATION`). Ver `dash-duration-parameter.md` y `dash-invulnerability-parameter.md`.

- **Estado:** Implementada (2026-09-26). 598 tests GdUnit4: los de esta spec en verde; 7 tests fallan por cambios de datos previos y ajenos (ver notas). 0 orphans. Import y smoke test sin errores ni warnings.
- **Constitución:** `docs/constitution.md` v4.6.0 → **v4.6.1** (enmienda PATCH aplicada, ver §5).
- **Pilar (Principio I):** combate. El dash pasa a ser una esquiva que exige timing: protege solo mientras el cuerpo se mueve, así que hay que dashear en el momento del golpe y no "antes, por las dudas". Leer los avisos de los enemigos y de los bosses (`enemy-attack-telegraph`, `boss-*`) gana peso.
- **Dependencias:** `dash-speed.md` (Implementada).

## 1. Objetivo

- **Hoy:** el dash da `IFRAME_DURATION` segundos de invulnerabilidad (1.0 s en las tres clases), mucho más que lo que dura el movimiento. Si Envainar corta el dash, la invulnerabilidad sigue igual (AC357).
- **Nuevo:**
  - El jugador es invulnerable **exactamente mientras dura el dash**: desde que empieza hasta el cuadro en que termina, `DASH_DISTANCE / DASH_SPEED`.
  - Con los datos actuales: guerrero y berserker **0.2 s** (3.0 m a 15 m/s), samurái **0.14 s** (3.5 m a 25 m/s).
  - Si el dash se corta (Envainar), la invulnerabilidad **termina en ese mismo cuadro**.
  - **Se elimina el stat `IFRAME_DURATION`.** La invulnerabilidad no se mejora por separado: solo cambia si cambia la duración del dash (distancia o velocidad).
- **Regla que se mantiene:** "el enfriamiento del dash siempre supera la invulnerabilidad". El piso pasa a ser `DASH_DISTANCE / DASH_SPEED + min_dash_cooldown_gap` (hoy 0.7 s; el enfriamiento base es 1.5 s, así que no cambia nada en juego).

## 2. Diseño

- **`PlayerStats`**
  - Se borran `iframe_duration`, `Stat.IFRAME_DURATION` y su rama en `get_base()`.
  - El enum queda: `…, JUMP_VELOCITY, DASH_DISTANCE, DASH_COOLDOWN, ATTACK_ARC, DASH_SPEED`. Los índices de `DASH_COOLDOWN`, `ATTACK_ARC` y `DASH_SPEED` bajan en 1. Ningún `.tres` guarda esos índices (ninguna carta ni fila de la pausa usa esos stats), así que no hay datos que migrar. Se verifica en la implementación.
- **Datos:** se borra la línea `iframe_duration` de los tres `<clase>_stats.tres`.
- **`DashComponent`**
  - Se borran `_iframe_time_left` y `_advance_iframes()`. `advance_timers()` solo avanza el enfriamiento.
  - `try_dash()`: `health.is_invulnerable = true` (como hoy).
  - Nuevo método privado `_end_dash()`: `_dash_time_left = 0` y `health.is_invulnerable = false`. Lo llaman `move_body()` cuando el dash termina y `cancel()`.
  - Se actualiza el comentario de la clase: la invulnerabilidad dura lo que el dash.
- **`StatsComponent._apply_limits()`:** el piso del enfriamiento usa `DASH_DISTANCE / DASH_SPEED` en lugar de `IFRAME_DURATION`.
- **`CombatRules.min_dash_cooldown_gap`:** solo se actualiza su comentario ("dash duration + this gap").
- **Sin cambios** en `HealthComponent`, enemigos ni bosses: siguen consultando `health.is_invulnerable`.

## 3. Criterios de aceptación (reservados al empezar la implementación)

- **AC546** `PlayerStats` no tiene `iframe_duration` ni `Stat.IFRAME_DURATION`, y los tres `<clase>_stats.tres` no tienen esa línea. El catálogo de mejoras y la tabla de la pausa cargan con sus stats intactos, y ninguna carta del catálogo sube la invulnerabilidad.
- **AC547** Al dashear, el jugador es invulnerable en todos los cuadros en que `is_dashing()` es verdadero y deja de serlo en el mismo cuadro en que el dash termina. Dura `DASH_DISTANCE / DASH_SPEED` con tolerancia de un cuadro: 0.2 s con el guerrero y 0.14 s con el samurái.
- **AC548** Si Envainar corta el dash, el jugador deja de ser invulnerable en ese cuadro y el enfriamiento del dash sigue corriendo. *(Reemplaza a AC357.)*
- **AC549** Con una mejora de `DASH_DISTANCE` o de `DASH_SPEED`, la invulnerabilidad sigue la nueva duración del dash.
- **AC550** El enfriamiento efectivo del dash nunca baja de `DASH_DISTANCE / DASH_SPEED + min_dash_cooldown_gap`, y ese piso sigue a las mejoras de distancia. *(Reemplaza a "AC6: el piso sigue a las mejoras de iframes".)*
- **AC551** Un golpe enemigo que cae durante el dash no hace daño. El mismo golpe, si cae apenas terminado el dash, sí hace daño. *(Adapta AC14/AC404.)* Regresión: suite completa en verde, salvo los fallos previos ajenos a esta spec.

## 4. Plan de implementación

1. Reservar AC546–AC551 en `CLAUDE.md` (próximo libre → AC552) y aplicar la enmienda PATCH 4.6.1.
2. `DashComponent`: invulnerabilidad atada al dash (`_end_dash()`), sin tocar todavía el stat. El juego ya funciona con la regla nueva.
3. `StatsComponent`: piso del enfriamiento con la duración del dash.
4. Borrar `IFRAME_DURATION` de `PlayerStats` y `iframe_duration` de los tres `.tres`. Verificar que ningún `.tres` o `.tscn` guarde índices de stat corridos.
5. Tests:
   - nuevos AC546–AC551;
   - reemplazar AC357 (`dash_cancel_test`) y el test de AC6 del piso con iframes (`stats_component_test`);
   - adaptar AC14 (`dash_component_test`), AC14/AC404 (`enemy_behaviour_test`, el dash se hace justo antes del golpe), AC236 (`samurai_run_test`, línea de `iframe_duration`) y las listas `FIXED_STATS`/`HIDDEN_STATS`.
6. Documentación: `CLAUDE.md` (línea del dash), marcar AC357 como reemplazado en `sheathe-dash-cancel.md`, y el AC14 de `combat-mvp.md`.
7. Import, suite completa, smoke test, review de la constitución y estado **Implementada**.

## 5. Enmienda propuesta: PATCH 4.6.1

Principio III, viñeta "Stats de gameplay del jugador = mejorables":

- **Antes:** "(daño, defensa, vida, velocidad de movimiento, salto, dash, iframes, cooldowns, rango y arco de ataque…)" y el ejemplo "el cooldown del dash siempre supera la invencibilidad".
- **Después:** se quita "iframes" de la lista y se agrega: *"La invulnerabilidad del dash no es un stat propio: dura lo que el dash (`DASH_DISTANCE / DASH_SPEED`), así que sigue dependiendo de stats en `.tres`."* El ejemplo pasa a ser "el cooldown del dash siempre supera la duración del dash".
- **Por qué PATCH:** el principio no cambia: la invulnerabilidad sigue saliendo de datos mejorables (distancia y velocidad). Solo se ajusta el ejemplo, que ya no describe el código.

## 6. Notas de implementación

- **Índices del enum:** al borrar `IFRAME_DURATION` bajan `DASH_COOLDOWN`, `ATTACK_ARC` y `DASH_SPEED`. Se revisaron todos los `.tres`/`.tscn`: el índice de stat más alto guardado es 9 (`MOVE_SPEED`), así que no hubo datos que migrar.
- **Agarre del Verdugo:** `Player.begin_hold()` ya llamaba `dash.cancel()`, así que ahora también apaga la invulnerabilidad. No cambia nada en juego: el agarre no puede enganchar a un jugador invulnerable.
- **Tests reemplazados o adaptados (sin cambiar lo que verifican, salvo donde la regla cambió):**
  - AC14 (`dash_component_test`): verifica que el dash da invulnerabilidad al empezar; el final lo cubre AC547.
  - AC357 → AC548 (`dash_cancel_test`); AC357 queda marcado como reemplazado en `sheathe-dash-cancel.md`.
  - AC6 (`stats_component_test`): el piso del enfriamiento pasa a `DASH_DISTANCE / DASH_SPEED + gap` (0.7 s), y "el piso sigue a las mejoras de iframes" pasa a seguir a las mejoras de distancia (AC550).
  - AC14/AC404 (`enemy_behaviour_test`): el dash se hace en el cuadro 25, justo antes del golpe (cuadro ~30); el test nuevo AC551 dashea en el cuadro 10 y el golpe entra.
  - AC236 (`samurai_run_test`): se quitó la línea de `iframe_duration`. `FIXED_STATS` y `HIDDEN_STATS` ya no listan el stat.
  - AC395 (`dash-speed`): el samurái tiene `dash_speed = 25` por un ajuste de datos, así que el test pasa a verificar que cada clase tenga `dash_speed` > 0.
- **Fallos previos ajenos** (los mismos que registra `enemy-attack-telegraph.md`, por datos cambiados fuera de sus specs): AC188, AC211, AC221, AC236 (`attack_speed` 1.6 y `dash_distance` 3.5 del samurái), AC285/AC298 y AC288.
- `combat-mvp.md`: las menciones a `IFRAME_DURATION` quedan marcadas como reemplazadas.

### Review de la constitución (cierre)
- **I:** combate. El dash premia el timing.
- **II:** sin cambios visuales.
- **III:** la invulnerabilidad sale de dos stats en `.tres` (distancia y velocidad); el piso del enfriamiento sigue siendo un dato (`min_dash_cooldown_gap`). Enmienda PATCH 4.6.1 aplicada.
- **IV:** tipado estricto; `_physics_process` sigue delegando.
- **V:** sin allocations por frame; se quitó un timer.
- **VI:** sin cambios de input.
- **Calidad:** import y smoke test sin errores ni warnings; los tests de esta spec en verde. Los fallos restantes son previos y ajenos.
