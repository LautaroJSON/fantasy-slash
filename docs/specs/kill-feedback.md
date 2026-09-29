# Feature: Refuerzo de las muertes (racha, multi-kill, hit lag extra y muerte con vuelo)

- **Estado:** Propuesta (2026-09-28). Fase B, 2 de 3: `fodder-minion` → **`kill-feedback`** → `perfect-dodge`.
- **Constitución:** `docs/constitution.md` **v5.0.0** → propuesta de enmienda **PATCH 5.0.1** (registro de colores, §9).
- **Criterios de aceptación:** reserva **AC1156–AC1170** (dentro del rango AC1141–AC1190 de la Fase B).
- **Pilar (Principio I):** Combate.
  - Hoy un enemigo que muere **desaparece en el acto** (`Enemy._on_died()` → `deactivate()`): el golpe que mata se siente igual que uno que no mata, y matar a cuatro de un barrido se ve igual que matar a uno.
  - Con esta spec, matar se ve (el cuerpo sale volando y se encoge, el impacto es más grande), se siente (un poco más de hit lag cuando un golpe mata a varios) y se cuenta (racha en el HUD y textos "×3", "×5"…). Es la recompensa inmediata del "farmeo" que la horda de `fodder-minion.md` hace posible.
- **Tipo:** feature (feedback de combate y HUD).
- **Dependencias:** `bdo-combat-feel.md` (hit lag local, Principio VII), `hit-impact-vfx.md` (`HitImpactVfxHost`), `readable-damage-numbers.md`, `player-hud-layout.md` y `mobile-touch-controls.md` (HUD y área segura), `status-icons.md` (no se tocan, solo se evita pisarlos), `fodder-minion.md` (no bloqueante: sin horda todo funciona igual, solo con menos muertes múltiples).
- **Fuera de alcance:** botín (oro e ítems son de la **Fase C**; acá solo queda un punto de extensión, §6), sonido (el proyecto no tiene sistema de audio; ver §11), cambios de daño o de balance.

## Preguntas abiertas (para el responsable)

1. **¿Racha (se corta si pasás un rato sin matar) o contador total de la run?** *Recomendación: racha*, con `streak_timeout` de 3 s y una barrita que se vacía: premia seguir cortando, que es lo que queremos. El total de la run ya existe (`RunState.kills`) y se sigue viendo en la pausa y en el Game Over, ahora junto con la **mejor racha**.
2. **¿Recibir daño corta la racha?** *Recomendación: no.* El público es casual: la racha es una recompensa, no un castigo. Si se quiere más tensión, es un `bool` en el config (`damage_breaks_streak`, por defecto `false`).
3. **¿Qué cuenta como muerte múltiple?** *Recomendación:* muertes encadenadas con menos de `multi_kill_window` (0.35 s) entre una y la siguiente, de cualquier fuente (combo, habilidades, sangrado, estallidos). Un barrido que mata a 4 en el mismo cuadro es "×4"; un Giro que mata a 5 en medio segundo también.
4. **Textos de los niveles de multi-kill.** *Recomendación:* siempre "×N" y, a partir de 3, un título corto: 3 "¡Triple!", 5 "¡Masacre!", 8 "¡Carnicería!". Viven en el `.tres`: se cambian o se quitan sin tocar código.
5. **Dónde se ve.** *Recomendación:* arriba a la izquierda (hoy vacío en PC y en táctil: la vida está abajo al centro, la oleada y la pausa arriba a la derecha, los bosses arriba al centro). No se pone nada en el centro de la pantalla, que en el teléfono ya está tapado por los pulgares y el personaje.
6. **¿Los bosses también "vuelan" al morir?** *Recomendación: no.* Mantienen su final actual (desaparecen); su muerte merece una spec propia. La muerte con vuelo es para los enemigos comunes y los Esbirros.

## 1. Objetivo

1. **Muerte con vuelo:** el enemigo común que muere sale despedido en la dirección del golpe, gira y se encoge durante `death_time` (0.3 s), sin colisión y ya fuera del registro. Después vuelve al pool.
2. **Impacto de muerte:** el golpe con hoja que mata muestra el `HitImpactVfx` más grande (`kill_scale`).
3. **Hit lag extra por muerte múltiple:** un golpe del combo (o de una habilidad no canalizada) que mata a 2 o más enemigos pausa el clip del jugador y sacude la cámara un poco más.
4. **Racha y multi-kill en el HUD:** un contador de racha con barra de tiempo, y un texto "×N" (con título según el nivel) que aparece y "salta" con cada muerte de la ráfaga.
5. **Mejor racha** de la run en la pausa y el Game Over.
6. **Punto de extensión** para el botín de la Fase C: una señal por cada muerte con el enemigo y la racha.

## 2. Qué se ve y qué se siente

### 2.1 Muerte con vuelo (`Enemy`)

- Al morir (`HealthComponent.died`), el enemigo:
  1. emite `killed` (como hoy: el registro lo saca, el coordinador libera token y lugar, `RunState.kills` suma, el pool lo recupera);
  2. si su `EnemyStats.death_config` no es nulo, entra en **estado de muerte** en vez de desactivarse: colisión deshabilitada, comportamiento detenido, aviso en el piso y barra de vida ocultos, estados y Aflicciones limpiados;
  3. durante `death_time`, el cuerpo y las manos se mueven con una velocidad inicial = dirección del empuje del golpe que mató × `fling_speed` + `fling_up_speed` hacia arriba (con gravedad), giran a `spin_speed` sobre un eje horizontal y su escala baja de 1 a 0 con *ease in* (`shrink_ease`);
  4. al terminar, `deactivate()` (invisible y deshabilitado, como hoy).
- **El empuje llega después de la muerte** (`AttackComponent._hit_enemy()` llama a `apply_knockback` después de `receive_hit`): en estado de muerte, `apply_knockback` guarda la dirección para el vuelo en vez de empujar. Sin empuje (sangrado, estallido), la dirección es desde el jugador hacia el enemigo.
- Si el golpe que mata también le aplica hit lag, el cuerpo tiembla ese tiempo y **después** vuela (el golpe se lee antes de que salga despedido).
- `activate()` cancela la muerte en curso y deja cuerpo, manos y escala en reposo (como ya cancela la aparición). `EnemyPool.acquire()` **prefiere** un enemigo que no esté muriendo; si todos lo están, toma uno igual (su vuelo se corta).
- Bosses: `death_config` vacío → desaparecen como hoy (pregunta 6).

### 2.2 Impacto de muerte (`HitImpactVfxHost`)

- Si el enemigo del `enemy_hit` quedó muerto (`enemy.health.is_dead()`), el efecto se reproduce escalado por `kill_scale` (1.5) y con `kill_spark_multiplier` (×2) chispas. Si además es crítico, las dos escalas se multiplican, con tope `max_kill_crit_scale` (1.8). Mismo blanco y material (Principio II): solo cambia el tamaño.

### 2.3 Hit lag extra por muerte múltiple (`HitstopComponent`)

- `AttackComponent` cuenta cuántos enemigos quedaron muertos en el golpe (`_strike()` y `strike_enemies()`) y lo expone con `get_last_strike_kills()` **antes** de emitir `attacked`.
- `HitstopComponent._on_attacked`: hit lag del jugador = `step.hitlag + config.hitlag_bonus_for(kills)` y sacudida = `step.shake_strength + config.shake_bonus_for(kills)`.
- `HitstopComponent._on_struck` (habilidades no canalizadas): lo mismo con los enemigos muertos de la lista, sobre el `StrikeFeel`.
- **Tablas:** `multi_kill_hitlag_bonus` = [0.02, 0.035, 0.05] para 2, 3 y 4+ muertes (el último valor se repite), y `multi_kill_shake_bonus` = [0.05, 0.1, 0.15]. Una muerte sola no suma nada.
- Las habilidades canalizadas (el Giro) **no pausan al jugador** (Principio VII): solo suman la sacudida.
- No se toca `Engine.time_scale` (Principio VII).

### 2.4 Racha y multi-kill en el HUD (`KillStreakView`)

```
┌──────────────────────────────────────────────┐
│ 23                              Oleada 4 [II]│
│ ▬▬▬▬▬▬▬▬▬▭▭▭   ← barra de racha (se vacía)   │
│ ×4 ¡Masacre!   ← aparece con la ráfaga        │
│                                              │
```

- **Número de racha** (arriba a la izquierda, `font_size` 40): aparece desde la 2.ª muerte encadenada (`min_streak_shown`). Con cada muerte "salta" (`pop_scale` 1.25 → 1 en `pop_time` 0.12 s).
- **Barra de racha** debajo del número: el tiempo que queda de `streak_timeout`. Al llegar a 0 la racha termina: el número se desvanece en `fade_time` (0.4 s) y se reinicia.
- **Texto de multi-kill** debajo de la barra: "×N" desde `min_multi_kill` (2), con el título del nivel más alto alcanzado ("¡Triple!", "¡Masacre!"…). Cada muerte de la ráfaga lo actualiza y lo hace saltar (`multi_pop_scale` 1.4). Cuando la ráfaga se cierra, queda `multi_hold_time` (0.8 s) y se desvanece.
- `mouse_filter = IGNORE` en todo el widget: no bloquea toques ni clics. Queda dentro del área segura porque es hijo del `Hud` (que ya aplica `SafeArea.inset`).
- Colores: texto **blanco** con contorno oscuro (`outline_color` negro, `outline_size` 6), la barra blanca translúcida. Se registran en el anexo de colores (§9).
- Todos los tamaños, tiempos, posiciones y textos viven en `KillFeedbackConfig`.

### 2.5 Mejor racha

- `RunState.best_streak: int`, actualizado por `KillTracker` al terminar cada racha (y al morir el jugador, por la racha en curso). Se reinicia con la run.
- La pausa y el Game Over agregan "· mejor racha N" a su línea de resumen.

## 3. Estructura de nodos

```
levels/arena/arena.tscn
└─ KillTracker (Node, systems/kill_tracker.gd)          ← nuevo
     exports: registry, player, run_state, config

ui/hud.tscn
└─ KillStreakView (Control, ui/kill_streak_view.gd)     ← nuevo, arriba a la izquierda
     ├─ StreakLabel (Label)
     ├─ StreakBar (ProgressBar)
     └─ MultiKillLabel (Label)
```

- `Hud` suma `@export var kill_tracker: KillTracker` y en `_ready` llama a `KillStreakView.setup(kill_tracker)`. En `arena.tscn` se enlaza `Hud.kill_tracker`.

## 4. Resources y datos

- **`resources/kill_feedback_config.gd`** (`KillFeedbackConfig`), instancia en `data/ui/kill_feedback_config.tres`:

| Grupo | Campos (valor inicial) |
|---|---|
| Racha | `streak_timeout` (3.0 s), `min_streak_shown` (2), `damage_breaks_streak` (`false`) |
| Multi-kill | `multi_kill_window` (0.35 s), `min_multi_kill` (2), `tier_counts` ([3, 5, 8]), `tier_titles` (["¡Triple!", "¡Masacre!", "¡Carnicería!"]), `count_format` ("×%d") |
| Hit lag | `multi_kill_hitlag_bonus` ([0.02, 0.035, 0.05]), `multi_kill_shake_bonus` ([0.05, 0.1, 0.15]) |
| HUD | `anchor_offset` (Vector2(16, 16)), `streak_font_size` (40), `multi_font_size` (30), `bar_size` (Vector2(120, 6)), `pop_scale` (1.25), `multi_pop_scale` (1.4), `pop_time` (0.12), `multi_hold_time` (0.8), `fade_time` (0.4), `text_color`, `outline_color`, `outline_size` (6), `bar_color` |

  Funciones puras: `hitlag_bonus_for(kills) -> float`, `shake_bonus_for(kills) -> float` (0 con menos de `min_multi_kill`; el último valor para las cantidades más altas) y `title_for(count) -> String` ("" bajo el primer nivel).
- **`resources/enemy_death_config.gd`** (`EnemyDeathConfig`), instancia en `data/enemies/death_config.tres`: `death_time` (0.3 s), `fling_speed` (7 m/s), `fling_up_speed` (3 m/s), `spin_speed` (720°/s), `shrink_ease` (2.0, exponente del *ease in*).
- **`EnemyStats.death_config: EnemyDeathConfig`**: asignado en Bruto, Embestidor, Saltador, Hostigador, Escudero y Esbirro; vacío en los bosses.
- **`HitImpactVfxConfig`** suma `kill_scale` (1.5), `kill_spark_multiplier` (2.0) y `max_kill_crit_scale` (1.8), con sus valores en `hit_impact_vfx_config.tres`.
- `HitstopComponent` suma `@export var kill_feedback: KillFeedbackConfig` (el mismo `.tres`).

## 5. Interfaz pública

- **`KillTracker`:**
  - señales: `streak_changed(count: int)`, `streak_ended(count: int)`, `multi_kill_changed(count: int)`, `multi_kill_ended(count: int)` y **`kill_registered(enemy: Enemy, streak: int)`** (punto de extensión, §6);
  - `get_streak() -> int`, `get_streak_time_left() -> float`, `get_multi_kill() -> int`;
  - `advance(delta: float)` (temporizadores; lo llama `_physics_process`; público para los tests).
- **`KillStreakView`:** `setup(tracker: KillTracker)`; getters para los tests (`get_streak_text()`, `get_multi_text()`, `is_streak_visible()`).
- **`AttackComponent.get_last_strike_kills() -> int`.**
- **`Enemy`:** `is_dying() -> bool`; `apply_knockback()` en estado de muerte guarda la dirección del vuelo.
- **`EnemyPool.acquire()`:** misma firma; prefiere enemigos que no estén muriendo.
- **`RunState.best_streak`** y `RunState.record_streak(count: int)`.

## 6. Punto de extensión para la Fase C (botín)

- `KillTracker.kill_registered(enemy, streak)` se emite **una vez por muerte**, después de actualizar la racha, con el enemigo todavía en su posición de muerte (antes del vuelo). Un futuro `LootDropper` puede conectarse ahí y leer `enemy.stats` (tipo), `enemy.level`, `enemy.global_position` y la racha (p. ej. más oro con racha alta), sin tocar `Enemy` ni el HUD.
- Esta spec **no** agrega campos de botín a `EnemyStats` ni define probabilidades.

## 7. Lógica interna

- **`KillTracker`** (solo miembros `int`/`float`, sin allocations):
  - `_on_enemy_killed(enemy)`: `_streak += 1`; `_streak_left = streak_timeout`; si `_burst_left > 0` (dentro de la ventana), `_burst += 1`, si no `_burst = 1`; `_burst_left = multi_kill_window`; emite `streak_changed`, y `multi_kill_changed` si `_burst ≥ min_multi_kill`; emite `kill_registered`.
  - `advance(delta)`: descuenta `_burst_left` (al llegar a 0 cierra la ráfaga: `multi_kill_ended` si llegó al mínimo) y `_streak_left` (al llegar a 0: `run_state.record_streak(_streak)`, `streak_ended`, `_streak = 0`).
  - Si `damage_breaks_streak`, `player.health.damaged` termina la racha en el acto. La muerte del jugador siempre la termina (y la registra).
- **`KillStreakView`:** reacciona a las señales (sin sondear); en `_process` solo avanza sus animaciones de salto y desvanecido y la barra con `tracker.get_streak_time_left()`. Los textos se arman con `count_format` y `title_for` solo cuando cambia la cuenta (no por cuadro).
- **Muerte del enemigo:** `_physics_process` de `Enemy` suma una rama al principio, como la aparición: `if _dying_left > 0.0: _advance_death(delta); return`. El estado se guarda en miembros (`_dying_left`, `_fling_velocity`, `_death_spin_axis`).

## 8. Criterios de aceptación (AC1156–AC1170)

**Racha y multi-kill** (`test/systems/kill_tracker_test.gd`):
- **AC1156:** tres muertes separadas por 1 s dan racha 3; sin muertes durante `streak_timeout`, se emite `streak_ended(3)` una vez, la racha vuelve a 0 y `RunState.best_streak` queda en 3 (una racha menor después no lo baja).
- **AC1157:** cuatro muertes en el mismo cuadro emiten `multi_kill_changed` con 2, 3 y 4, y al cerrarse la ventana `multi_kill_ended(4)` una sola vez.
- **AC1158:** con `multi_kill_window` 0.35 s, muertes a 0.3 s una de otra siguen en la misma ráfaga; a 0.4 s empiezan una nueva (`multi_kill_changed` no llega a 2).
- **AC1159:** `kill_registered(enemy, streak)` se emite una vez por muerte, con el enemigo muerto y la racha ya actualizada; `RunState.kills` sigue sumando como antes.
- **AC1160:** con `damage_breaks_streak` en `false`, recibir daño no corta la racha; con `true`, la corta y la registra. La muerte del jugador siempre la corta y la registra.

**HUD** (`test/ui/kill_streak_view_test.gd`):
- **AC1161:** con racha 1 el número no se ve; con 2 se ve "2"; la barra vale `get_streak_time_left() / streak_timeout`; al terminar la racha, a los `fade_time` el widget queda invisible.
- **AC1162:** una ráfaga de 3 muestra "×3 ¡Triple!"; una de 5, "×5 ¡Masacre!"; una de 2, "×2" sin título (textos de `kill_feedback_config.tres`).
- **AC1163:** en la arena, `KillStreakView` está anclado arriba a la izquierda del `Hud` en `anchor_offset`, tiene `mouse_filter = IGNORE` en todos sus nodos y no se superpone con los rectángulos de `WaveLabel`, `BossBars`, `BuffBar` ni con los botones de `TouchControls` (incluida la pausa) en la resolución base.

**Hit lag y sacudida** (`test/components/hitstop_test.gd`, casos nuevos):
- **AC1164:** un golpe del combo que mata a 1 enemigo pausa el clip `step.hitlag`; uno que mata a 3, `step.hitlag + 0.035`; uno que mata a 6, `step.hitlag + 0.05` (tope de la tabla). La sacudida de cámara suma lo mismo con `multi_kill_shake_bonus`. `Engine.time_scale` queda en 1.
- **AC1165:** un `struck` de habilidad no canalizada con 2 enemigos muertos suma el bonus de 2 a su `StrikeFeel`; un golpe del Giro que mata a 3 no pausa el clip del jugador y solo suma la sacudida.

**Muerte e impacto** (`test/entities/enemy/enemy_death_test.gd` y `test/components/vfx/hit_impact_vfx_test.gd`):
- **AC1166:** el golpe que mata a un enemigo con hoja reproduce el impacto con escala `kill_scale` (con crítico, `min(crit_scale × kill_scale, max_kill_crit_scale)`).
- **AC1167:** en el cuadro de la muerte, el enemigo ya no está en el registro y su colisión está deshabilitada, pero sigue visible; durante `death_time` se aleja en la dirección del empuje del golpe y su escala baja; al terminar está invisible y con `process_mode` deshabilitado.
- **AC1168:** `activate()` durante la muerte la cancela (escala 1, cuerpo y manos en reposo); con un enemigo muriendo y otro libre en el pool, `acquire()` devuelve el libre.
- **AC1169:** un boss (sin `death_config`) desaparece en el cuadro de su muerte, como hoy, y su barra del HUD no cambia.

**Resumen de la run** (`test/ui/pause_menu_test.gd`, casos nuevos, y `test/ui/game_over_screen_test.gd`, nuevo):
- **AC1170:** la pausa y el Game Over muestran "mejor racha N" con `RunState.best_streak`; una run nueva lo reinicia a 0.

## 9. Enmienda de la constitución (PATCH 5.0.0 → 5.0.1)

- **Anexo `color-registry.md`, colores no reservados en uso:** se registra el **blanco** `Color(1, 1, 1)` con contorno negro para los textos 2D de racha y multi-kill del HUD, y el blanco translúcido (alpha ≤ 0.6) de su barra. Es UI 2D, igual que los controles táctiles (desde 5.0.0), así que no se confunde con el blanco reservado de los elementos 3D. No cambia ninguna regla: es un registro (PATCH).
- **Sin enmienda al Principio VII:** el hit lag extra es local (pausa del clip y sacudida de cámara), dentro de lo que ya permite; la muerte con vuelo es una animación del enemigo en su pool, no una entidad nueva.

## 10. Plan de implementación

1. Reservar AC1156–AC1170 al empezar. Releer `hud.tscn`, `hitstop_component.gd` y `enemy.gd` (los tocan otras sesiones).
2. `KillFeedbackConfig` y su `.tres`; `KillTracker` y su nodo en `arena.tscn`; `RunState.best_streak`. Tests AC1156–AC1160.
3. `KillStreakView` en `hud.tscn` (primero sin animaciones) y el enlace del `Hud`. Tests AC1161–AC1163.
4. `AttackComponent.get_last_strike_kills()` y los bonus de `HitstopComponent`. Tests AC1164–AC1165; los tests de hit lag existentes siguen en verde (una muerte sola no suma).
5. `EnemyDeathConfig`, `EnemyStats.death_config` y la muerte con vuelo en `Enemy`; `EnemyPool.acquire()` que prefiere los libres. Tests AC1167–AC1169. Revisar los tests que esperan `visible == false` en el cuadro de la muerte: se adaptan a "fuera del registro y sin colisión" (lo que verifican) y se anotan abajo.
6. `kill_scale` en `HitImpactVfxHost`. Test AC1166.
7. Resumen en pausa y Game Over. Test AC1170.
8. Enmienda PATCH (anexo de colores e historial).
9. Tests de la spec con `godot-tester`; **video antes/después** con `godot-capture` (Principio VIII §8, VFX de golpe): un barrido del Guerrero sobre 4 Esbirros a velocidad real y al 30 %, vista de juego, para revisar el vuelo, el impacto de muerte y el hit lag extra. Smoke test en la arena con las tres clases.
10. Checklist, spec **Implementada**, `where-to-tune.md` (viñetas nuevas "Racha y multi-kill" y "Muerte de los enemigos"; "Impacto de golpe" suma `kill_scale`) y próximo AC libre.

## 11. Review (checklist de la constitución)

- [ ] **I.** Combate: matar se ve, se siente y se cuenta.
- [ ] **II.** Sin mallas ni materiales nuevos en 3D: el vuelo mueve el cuerpo gris del propio enemigo y el impacto reusa el blanco del `HitImpactVfx`. Textos 2D registrados (PATCH).
- [ ] **III.** Todo número y texto en `kill_feedback_config.tres`, `death_config.tres` y `hit_impact_vfx_config.tres`. Funciones puras en los configs.
- [ ] **IV.** Tipado estático; `_physics_process` y `_process` delgados.
- [ ] **V.** Sin allocations por cuadro (contadores y temporizadores en miembros; textos armados solo al cambiar la cuenta). La muerte con vuelo usa el enemigo del pool, sin nodos nuevos.
- [ ] **VI.** Sin input nuevo; el widget ignora el mouse y los toques.
- [ ] **VII.** Hit lag local, sin `Engine.time_scale`; las habilidades canalizadas no pausan al jugador.
- [ ] **VIII.** VFX de golpe: el impacto de muerte sigue el lenguaje compartido (mismo efecto, más grande). Video antes/después en la spec o en la conversación.
- [ ] **Calidad:** tests en verde, suite sin fallos nuevos, smoke test.

## 12. Notas

- **Sonido:** no hay `AudioStreamPlayer` en el proyecto. Cuando exista un sistema de audio, sus disparadores naturales son `KillTracker.kill_registered`, `multi_kill_changed` y el hit lag extra de `HitstopComponent`; esta spec no agrega nada más.
- La vibración del teléfono (háptica) en la muerte múltiple sería barata y muy efectiva en móvil; queda como idea para otra spec (necesita decidir si se puede desactivar desde un menú).
