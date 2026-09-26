# Boss: la Colmena (reemplaza a los Gemelos)

- **Estado:** Implementada (2026-09-26). A pedido del usuario se corrieron solo los suites de esta spec y los que toca: `colmena_data_test`, `test/entities/enemy` y `test/systems` (184 tests), `boss_challenge_run_test`, `boss_hud_bar_test`, y los tests de nivel y UI cuyo helper `_kill_all_active` se adaptó (`ability_run`, `arena_waves`, `sandbox_run`, `unique_upgrade_run`, `upgrade_ban_run`, `pause_menu`). Todos en verde, 0 orphans. Smoke test de la arena sin errores; capturas de la invocación, el escudo y la exposición revisadas. La suite completa no se corrió.
- **Constitución:** `docs/constitution.md` **v4.5.0** → **v4.6.0** (enmienda MINOR, ver abajo)
- **Pilar (Principio I):** Supervivencia + Combate.
  - **Supervivencia:** es una pelea contra la multitud. La Colmena invoca esbirros y es invulnerable mientras alguno viva, así que hay que limpiar la oleada rápido y bien.
  - **Combate:** cuando cae el escudo hay una ventana corta para castigarla. Además, si el jugador se le pega, lo repele con un pulso.
- **Tipo:** feature. Última de la hoja de ruta: … → `boss-titan` → **`boss-colmena`**.
- **Dependencias:** `boss-verdugo.md` (`BossBehavior`, onda de choque, fase 2), `enemy-types.md` (pools por tipo), `enemy-group-ai.md` (aparición y turnos), `enemy-rage.md` (estados permanentes), `enemy-pace.md`.

## Objetivo

- **Quién es:** un boss que se mantiene a distancia y pelea con **esbirros**. Es una cápsula gris grande (`body_scale` 2.6) con las manos altas a los costados.
- **Reemplaza a los Gemelos:** se borran `twin_stats.tres`, `twin_punch.tres` y el desafío `twins.tres`; entran `colmena.tres` y `BossPoolColmena`.
- **Barra:** la del HUD, con el nombre "Colmena".
- **Turnos y aparición:** no pide turno. Sus esbirros sí piden turno, igual que en una oleada normal.

## Ciclo de pelea

1. **Invocación:** al terminar de aparecer, y cada vez que termina una ventana de exposición, levanta las manos 1.5 s (preparación, escalada por el ritmo) e **invoca una tanda** de esbirros. Los esbirros salen del piso con la aparición normal (agujero negro), repartidos alrededor de la Colmena, a 3–5 m de ella y a ≥ 3 m del jugador. Tienen el nivel de la Colmena, el Rage de la oleada y el ritmo de la run.
   - **Fase 1:** 3 Brutos + 1 Embestidor.
   - **Fase 2:** 2 Brutos + 1 Hostigador + 1 Saltador + 1 Embestidor.
2. **Escudo:** mientras quede algún esbirro de la tanda vivo, la Colmena es **invulnerable**. Se ve con un **aura de caparazón** color miel y un ícono "Escudo" en su barra del HUD.
3. **Expuesta:** cuando muere el último esbirro, el escudo cae durante `exposed_time` (6 s en la fase 1, 4 s en la fase 2). Recibe daño completo y no invoca. Después vuelve al paso 1.
4. **Distancia:** trata de mantenerse entre 6 y 10 m del jugador. Si está más cerca retrocede, si está más lejos se acerca, y en ese rango se queda quieta mirándolo.
5. **Pulso:** si el jugador está a ≤ 4 m, lanza una onda de choque corta (`ShockwaveMoveData`: preparación 0.8 s, hasta 7 m, `Mult.` 1.0). Se esquiva saltando o con el dash, como las demás ondas. Puede usarlo con escudo o expuesta, pero no durante una invocación.
6. **Muerte:** si la Colmena muere, los esbirros que queden mueren con ella y la oleada termina.

## Fase 2 (vida ≤ 50 %)

Usa la fase 2 de `BossBehavior` (una pausa invulnerable de 1.5 s y tiempos × 0.8). Además cambia la tanda de invocación, acorta la ventana de exposición a 4 s y las manos crecen un 10 %. Como solo puede recibir daño estando expuesta, en la práctica entra en la fase 2 durante una ventana. La transición la corta, y después vuelve a invocar.

## Enmienda a la constitución (MINOR → 4.6.0)

- **Principio II, colores no reservados:** se registra el **miel** `Color(0.95, 0.78, 0.25)` del aura de escudo de la Colmena (cápsula unshaded translúcida, alpha ≤ 0.3, más grande que el cuerpo, como el aura de Rage) y de su ícono "Escudo". Es distinto del ámbar de los críticos, que es más naranja y es texto.

## Estructura de nodos

- **`enemy.tscn`** suma `ShieldAura` (`MeshInstance3D`, `CapsuleMesh` más grande que el cuerpo, `StatusAura` enlazado al estado `shield`). Es igual que `RageAura`.
- **`arena.tscn`:** `BossPoolColmena` reemplaza a `BossPoolTwins`.

## Resources y datos

- **`DebuffData.Effect`** suma `STATUS`: solo se lista, y el dueño aplica su efecto. Se usa en `data/debuffs/shield.tres`: permanente, ícono miel.
- **`SummonData`** (`resources/summon_data.gd`): `stats: Array[EnemyStats]` (una entrada por esbirro), `min_radius`, `max_radius` y `min_player_distance`.
- **`ColmenaConfig`** (`BossConfig`):
  - `summon_attack: EnemyAttackData` (preparación de la invocación y pose de manos);
  - `summon_phase_one` y `summon_phase_two: SummonData`;
  - `exposed_time_phase_one` y `exposed_time_phase_two`;
  - `keep_min_distance` y `keep_max_distance`;
  - `shield_status: DebuffData`.
  - `moves` tiene solo el pulso.
- **Datos:**
  - `data/enemies/colmena_stats.tres`: vida 700, daño 14, defensa 4, velocidad 2.0, `body_scale` 2.6, "Colmena", barra en el HUD, `ignores_attack_tokens`, crecimiento por nivel como el resto.
  - `data/enemies/hands/colmena_hands.tres`.
  - `data/enemies/configs/colmena_boss.tres`.
  - `data/enemies/attacks/colmena_*.tres`.
  - `data/enemies/boss_challenges/colmena.tres` (1 enemigo).
  - `data/debuffs/shield.tres` y los materiales `materials/debuff_shield_material.tres` y `materials/vfx/shield_aura_material.tres`.

## Interfaz pública

- **`Enemy`:** señal `summon_requested(enemy: Enemy, summon: SummonData)`.
- **`WaveManager`:** al empezar una oleada de boss, se conecta a `summon_requested` de cada boss. Para cada entrada toma un enemigo del pool de ese tipo (`_type_pools`, que están libres durante una oleada de boss), lo ubica según `SummonData`, lo activa con nivel, Rage, ritmo y aparición, y se lo entrega al boss con `ColmenaBehavior.add_minion(enemy)`. Si un pool no tiene enemigos libres, se saltea esa entrada.
- **`ColmenaBehavior`** (extiende `BossBehavior`):
  - `add_minion(enemy)`, `get_minion_count()`, `is_shielded()`, `is_exposed()` e `is_summoning()`.
  - Escucha `killed` de sus esbirros. El escudo es `health.is_invulnerable` más el estado `shield`.
  - `deactivated()` mata a los esbirros que queden con `health.execute()`. Así cuentan como bajas y el registro emite `all_dead` con el último.
- **`BossBehavior`:** suma el hook `_chase_motion(offset, distance, delta)`, que por defecto se acerca. La Colmena lo usa para mantener la distancia.

## Criterios de aceptación (AC527–AC545, reservados)

**Datos** (`test/resources/colmena_data_test.gd`):
- **AC527:** `SummonData` y `ColmenaConfig`: tandas de 4 y 5 esbirros, 6 y 4 s de exposición, rango de 6 a 10 m, y el estado `shield` es `STATUS` y permanente.

**Colmena** (`test/entities/enemy/colmena_test.gd`, con un `WaveManager` falso que atiende las invocaciones):
- **AC528:** al empezar pide una invocación después de su preparación escalada, con la tanda de la fase 1.
- **AC529:** con esbirros vivos es invulnerable, tiene el estado `shield` y el aura es visible.
- **AC530:** al morir el último esbirro queda expuesta: recibe daño, sin estado ni aura, durante `exposed_time`. Después vuelve a invocar.
- **AC531:** mantiene la distancia: a 3 m retrocede, a 15 m se acerca y a 8 m se queda quieta.
- **AC532:** con el jugador a ≤ 4 m lanza el pulso (anillo activo). A 8 m no lo lanza.
- **AC533:** fase 2: la tanda es la de la fase 2 y la exposición dura 4 s.
- **AC534:** si la Colmena muere con esbirros vivos, los esbirros mueren.
- **AC535:** `activate()` limpia los esbirros, el escudo y el estado, y la devuelve a la fase 1.
- **AC536:** escala con nivel y Rage.

**Oleada** (`test/levels/boss_challenge_run_test.gd`):
- **AC537:** forzar el desafío Colmena genera 1 Colmena (aparece desde el piso, no usa turnos, muestra "Colmena" en la barra del HUD). Su invocación trae esbirros de los pools de tipos, a 3–5 m de ella y a ≥ 3 m del jugador, con el nivel de la Colmena, apareciendo desde el piso y usando turnos.
- **AC538:** matar a todos los esbirros y después a la Colmena termina la oleada y ofrece las cartas doradas.
- **AC539:** si la Colmena muere con esbirros vivos, la oleada termina igual.
- **AC540:** `WaveConfig.boss_challenges` tiene al Titán, al Verdugo y a la Colmena, y no a los Gemelos. La arena tiene `BossPoolColmena` y no `BossPoolTwins`.
- **AC541:** el HUD muestra el ícono "Escudo" en la barra mientras el escudo está activo.

**Tests viejos que usaban a los Gemelos** (se adaptan sin cambiar lo que verifican):
- **AC542:** `enemy_attack_test` (AC407 "preparación no interrumpible de un enemigo cuerpo a cuerpo" y AC410 "manos escaladas") pasa a usar al **Escudero** (no interrumpible, escala 1.2).
- **AC543:** `attack_coordinator_test` (AC445) y `ground_telegraph_integration_test` (AC507) pasan a usar al **Verdugo** y al Escudero.
- **AC544:** `boss_hud_bar_test`: AC159 (dos barras apiladas) y AC163 (una barra se va al morir y la otra queda) llaman a `BossBarStack.show_bosses()` con dos enemigos de la oleada, porque ya no hay desafíos de dos bosses. El soporte de varias barras se mantiene.
- **AC545:** `boss_challenge_run_test`: AC152 ("los gemelos aparecen separados") pasa a verificar que los esbirros de una invocación aparecen separados (`min_spawn_separation`). AC490 lista los desafíos nuevos.

## Plan de implementación

1. Reservar AC527–AC545 en `CLAUDE.md` (próximo libre → AC546).
2. Enmienda de la constitución (4.6.0). `DebuffData.Effect.STATUS`, `shield.tres`, materiales y el nodo `ShieldAura`.
3. `SummonData`, `ColmenaConfig`, el hook `_chase_motion` de `BossBehavior` y `ColmenaBehavior`. Datos de la Colmena. Tests AC527–AC536.
4. `Enemy.summon_requested` y la invocación en `WaveManager`. Desafío y pool en `wave_config.tres` y `arena.tscn`. Borrar los archivos de los Gemelos. Tests AC537–AC541.
5. Adaptar los tests viejos (AC542–AC545).
6. Correr los suites de esta spec, `test/entities/enemy`, `test/levels/boss_challenge_run_test`, `test/ui/boss_hud_bar_test` y `test/systems`. Import, smoke test y captura (invocación, escudo y pulso). Checklist, spec **Implementada** y `CLAUDE.md`.

## Review (checklist de la constitución)

- [x] **I.** Supervivencia y Combate, como se explica arriba.
- [x] **II.** Cápsulas y esferas grises. El aura es una cápsula translúcida y el color miel queda registrado en 4.6.0.
- [x] **III.** Todos los números en `.tres`.
- [x] **IV.** Tipado estático.
- [x] **V.** No se asigna memoria por frame: los esbirros salen de los pools creados al cargar y la lista de esbirros es un array reutilizado.
- [x] **VI.** Sin input nuevo.

## Notas

- **Pools prestados:** los esbirros usan los pools de los tipos normales, que están libres durante una oleada de boss. Si en el futuro hay oleadas mixtas (enemigos normales y boss a la vez), habrá que darle pools propios a la Colmena.
- **Bajas de los esbirros:** cuentan en el contador de la run, como cualquier enemigo.
- **Con esto se completa la hoja de ruta de enemigos.** En la rotación de bosses quedan el Titán, el Verdugo y la Colmena.

### Implementación: ajustes respecto de lo aprobado

- **`EnemyBehavior.state_restored()`:** hook nuevo que `Enemy` llama al final de `activate()` y de `enrage()`. Los dos reinician la vida (sacan la invulnerabilidad) y la lista de estados después de que el comportamiento puso el escudo, y durante la aparición el comportamiento no corre, así que sin el hook la Colmena quedaba vulnerable mientras salía del piso.
- **`DebuffComponent.remove(id)`:** método nuevo, para sacar el estado `shield` cuando cae el escudo.
- **`WaveManager._place(enemy, at)`:** ahora recibe la posición. Las oleadas usan `_pick_spawn_position()` y la invocación `_pick_summon_position()`, dentro del cuadrado de aparición.
- **Error corregido gracias a los tests:** la transición a la fase 2 no cortaba la ventana de exposición, como pide la spec. Ahora, al terminar la transición, la Colmena vuelve a invocar enseguida.
- **Tests de nivel y UI:** su helper `_kill_all_active` apaga la invulnerabilidad antes del golpe letal. Si no, un test que pasa por una oleada de boss sorteada fallaría al azar cuando sale la Colmena con escudo. Siguen verificando lo mismo.
- **AC544:** las dos barras del HUD se prueban dentro de una oleada de boss (Titán + un Bruto del pool normal), porque en una oleada normal el HUD limpia las barras de boss con cada baja.
- **AC155** (oferta sin cartas doradas) pasó de los Gemelos al Titán.
