# Feature: Esbirro (carne de cañón) y oleadas de horda

- **Estado:** Implementada en la rama `feat/fodder-minion` (2026-09-29), con pendientes: la medición en el teléfono (§3.3), el smoke test con las tres clases y la captura de una oleada 1 (ver Notas). El rango AC1141–AC1155 ya está reservado en `docs/ac-registry.md` (rama principal): no se toca acá.
- **Constitución:** `docs/constitution.md` **v5.0.0**, sin enmienda (ver *Arte* y *Performance*).
- **Criterios de aceptación:** reserva **AC1141–AC1155** (dentro del rango AC1141–AC1190 de la Fase B).
- **Pilar (Principio I):** Combate + Supervivencia.
  - **Combate:** un barrido que alcanza a un grupo mata a varios de una vez. Aprovechar el arco y el alcance de cada golpe (posicionarse para agarrar a cuatro en vez de a uno) pasa a ser la decisión de todos los segundos. Es el "farmeo" que los jugadores piden: pegar mucho y sentir poder.
  - **Supervivencia:** la horda es presión de volumen, no de precisión. Cada Esbirro pega poco y avisa mucho, pero muchos a la vez castigan quedarse quieto. Los tipos que piden respuesta (Bruto, Embestidor, Hostigador…) siguen siendo los picos de la curva en diente de sierra.
- **Tipo:** feature (tipo de enemigo nuevo + cambio en la composición de la oleada).
- **Dependencias:**
  - `enemy-types.md` (`EnemySpawnEntry`, `EnemySpawnTable`, un `EnemyPool` por tipo), `enemy-group-ai.md` (turnos, anillo, separación, aparición), `enemy-pace.md` y `enemy-level-pace.md` (preparaciones estiradas por nivel), `enemy-levels.md`.
  - **`early-power-curve.md` (Fase A, en redacción en otra sesión):** decide `enemies_per_wave`, el crecimiento de vida y defensa enemigas, los atacantes simultáneos del principio y las oleadas en que entran los tipos molestos. Esta spec **no toca esos números**: la horda se suma encima de la oleada que defina la Fase A y todos sus valores viven en un `.tres` propio.
  - `kill-feedback.md` (Fase B, 2/3) usa esta horda para las muertes múltiples, pero esta spec no depende de ella.

## Preguntas abiertas (para el responsable)

1. **Nombre e identificador.** La Colmena ya llama "esbirros" a lo que invoca (`ColmenaBehavior.add_minion()`, `SummonData`), y esos son Brutos y Embestidores. Para no mezclar términos en el código propongo el nombre visible **"Esbirro"** y el identificador **`fodder`** (`fodder_stats.tres`, `FodderBehavior`, `HordeConfig`). *Recomendación: así.*
2. **¿La horda cuenta dentro de `enemies_per_wave` o aparte?** *Recomendación: aparte.* `enemies_per_wave` sigue siendo la cantidad de enemigos "de verdad" (la decide la Fase A) y la horda suma Esbirros encima. Así la Fase A y esta spec no se pisan, y el 80 % de carne de cañón de la zona 1 sale de sumar las dos (p. ej. 3 de la Fase A + 12 de la horda = 80 %).
3. **¿La vida del Esbirro crece con el nivel?** *Recomendación: no.* Muere siempre de un golpe; lo que crece es su daño y la cantidad por oleada. Si crece con el nivel, a mitad de la run deja de ser carne de cañón y vuelve la queja de "enemigos esponja".
4. **Turnos de ataque.** Con un solo token al principio (lo que propone la Fase A), si los Esbirros compiten por él, o nunca pegan o le quitan el turno al Bruto. Opciones: (a) compartir los tokens, (b) **un cupo propio de tokens para los Esbirros** (`fodder_max_attackers`), (c) sin tokens. *Recomendación: (b), con 2.* Pegan poco y avisan mucho, así que dos a la vez es presión leve, y no le roban el turno a nadie.
5. **¿Tandas o todos juntos?** *Recomendación: tandas.* La oleada arranca con 2 grupos y cada vez que quedan pocos Esbirros vivos aparece otro grupo, hasta completar el total. Mantiene el flujo de "siempre hay algo para cortar" y limita los cuerpos simultáneos en el teléfono (`max_alive`).
6. **Cantidades de partida** (todas en `horde_config.tres`, a ajustar jugando): total 10 en la oleada 1, +2 por oleada, tope 30; grupos de 4 a 6; 16 vivos como máximo. *Recomendación: estos valores y ajustar después de la Fase A.*
7. **¿Horda en las oleadas de boss?** *Recomendación: no en esta spec.* Los desafíos de boss quedan iguales. Que la Colmena invoque Esbirros en vez de Brutos es una buena idea para otra spec (solo cambia su `SummonData`).
8. **Hallazgo que afecta el pedido "muere de 1 golpe con Guerrero 20, Berserker 25 y Samurái 18":** el daño de cada golpe del combo es `DAMAGE × damage_multiplier` del paso (`AttackComponent._strike()`), y los multiplicadores van de 0.28 a 0.6. El golpe **más débil** a nivel 1, sin crítico, es de **5.04** (Samurái, pasos 2 y 4: 18 × 0.28); el del Guerrero es 5.6 (20 × 0.28) y el del Berserker 10 (25 × 0.4). Por eso el Esbirro tiene **5 de vida y 0 de defensa**, y AC1141 protege esa regla contra cualquier ajuste futuro de clases o combos. (Dato para la Fase A: hoy el Bruto, con 40 de vida, necesita 7 golpes del primer paso del Guerrero.)

## 1. Objetivo

1. Un tipo nuevo, el **Esbirro**: vida mínima (muere de cualquier golpe del combo básico de cualquier clase a nivel 1), ataque lento y muy avisado que casi no obliga a esquivar, cuerpo chico. Reutiliza `enemy.tscn`.
2. **Oleadas de horda:** además de la mezcla de tipos de siempre, cada oleada normal trae Esbirros **en grupos apretados** (para que un barrido agarre a varios) y **en tandas** (siempre hay algo para cortar, sin superar un tope de cuerpos vivos).
3. Nada de lo que decide la Fase A cambia: la mezcla de tipos, `enemies_per_wave`, los niveles, el ritmo y los atacantes del grupo principal siguen leyendo sus datos.

## 2. El Esbirro (`fodder`)

Valores iniciales de los `.tres`, a nivel 1.

| Vida | Daño | Defensa | Velocidad | `body_scale` | Fricción del empuje |
|---|---|---|---|---|---|
| 5 | 6 | 0 | 3.0 m/s | 0.7 | 12 (vuela más lejos que el Bruto, que tiene 20) |

- **Crecimiento por nivel (`level_growth`):** daño +10 % por nivel (como el Bruto) y velocidad +0.05 m/s por nivel con tope 4.0. **Vida y defensa no crecen** (pregunta 3).
- **Ataque `fodder_swipe.tres`** (`EnemyAttackData`):

| Campo | Valor | Por qué |
|---|---|---|
| `damage_multiplier` | 1.0 | 6 de daño: el Guerrero recibe 1 (piso), el Samurái 5, el Berserker 1. |
| `windup_time` | 0.9 s | Con el ritmo de nivel 1 (×1.8 hoy, ×2.2 con la Fase A) son **1.62 s** (**1.98 s** con la Fase A) de aviso: sobra para reaccionar en el teléfono (~250 ms de reacción + latencia táctil). |
| `active_time` / `recovery_time` | 0.15 s / 0.8 s | Recuperación larga: ventana de castigo. |
| `trigger_range` / `hit_range` | 1.6 m / 1.7 m | Tiene que estar pegado para pegar. |
| `hit_arc_degrees` | 70° | Un paso al costado lo esquiva sin dash. |
| `windup_turn_speed` | 45°/s | Casi no te sigue durante la preparación. |
| `interruptible` | `true` | Cualquier golpe con empuje lo cancela (y de paso lo mata). |
| `hands` | `RIGHT` | Un manotazo con una mano. |

- `attack_interval`: 2.0 s (×2.5 a nivel 1 = 5 s entre ataques de un mismo Esbirro; ×3.0 = 6 s con la Fase A).
- `affliction_resistance` 0, `stun_duration_scale` 1, sin `resists_*`.
- **Aviso en el piso:** el sector rojo anaranjado de siempre (`GroundTelegraph.show_sector`), sin cambios.

### Comportamiento (`FodderBehavior extends MeleeBehavior`)

- Igual que el Bruto (perseguir → preparación → golpe → recuperación), con dos diferencias:
  1. **No ocupa lugares del anillo** (`claim_slot`). Sin token, camina hasta `FodderConfig.swarm_distance` (2.2 m) del jugador por el camino más corto, con la separación de siempre, y espera ahí mirándolo. Así la horda se amontona alrededor en vez de quitarle los 8 lugares del anillo al Bruto y al Escudero, y queda agrupada para el barrido.
  2. Pide el token al **cupo de Esbirros** (pregunta 4).
- Sin coordinador (tests unitarios) ataca como el Bruto.

### Turnos: cupo propio

- **`EnemyStats.token_group: AttackTokenGroup`** (enum nuevo en `EnemyStats`: `MAIN`, `FODDER`; por defecto `MAIN`, así los `.tres` actuales no cambian).
- **`GroupAIConfig.fodder_max_attackers: int`** (2). El Rage no lo sube.
- `AttackCoordinator` lleva los portadores por grupo: `request_token()` compara contra el tope del grupo del enemigo. Un Esbirro atacando no ocupa un token `MAIN` y viceversa. `token_gap` y el descanso entre turnos (`rest_for`) se aplican **por grupo**, así un Esbirro no demora el golpe del Bruto.

## 3. Oleadas de horda

### 3.1 Datos

- **`HordeConfig`** (Resource nuevo, `resources/horde_config.gd`), instancia en `data/waves/horde_config.tres`, referenciada desde **`WaveConfig.horde`** (vacío = sin horda, como hoy):

| Campo | Valor | Qué es |
|---|---|---|
| `entry` | `data/enemies/spawn/fodder_spawn.tres` | El tipo de la horda. Su `max_per_wave` es el tamaño del pool. |
| `first_wave` | 1 | Primera oleada con horda. |
| `base_total` | 10 | Esbirros de la oleada `first_wave`. |
| `total_per_wave` | 2 | Esbirros extra por cada oleada siguiente. |
| `max_total` | 30 | Tope de Esbirros por oleada. |
| `group_size_min` / `group_size_max` | 4 / 6 | Tamaño de cada grupo (sorteado). |
| `initial_groups` | 2 | Grupos que salen al empezar la oleada. |
| `max_alive` | 16 | Tope de Esbirros vivos a la vez (rendimiento). |
| `refill_below` | 4 | Con esta cantidad de Esbirros vivos o menos, se programa el próximo grupo. |
| `refill_delay` | 0.6 s | Pausa antes de que aparezca ese grupo. |
| `group_radius` | 1.6 m | Radio del disco donde aparece un grupo. |
| `member_separation` | 0.9 m | Distancia mínima entre dos Esbirros del mismo grupo al aparecer. |

- Funciones puras de `HordeConfig`:
  - `total_for(wave: int, is_boss_wave: bool) -> int`: 0 antes de `first_wave` y en oleadas de boss; si no, `mini(base_total + total_per_wave × (wave − first_wave), max_total)`.
  - `group_size(roll: float) -> int`: entre `group_size_min` y `group_size_max`, con `roll` en [0, 1).
  - `member_offset(index: int) -> Vector3`: punto `index` de un disco de Vogel (ángulo áureo) de radio `group_radius`; determinista, sin azar ni allocations.
- **`data/enemies/spawn/fodder_spawn.tres`** (`EnemySpawnEntry`): `stats` = `fodder_stats.tres`, `max_per_wave` = 20 (`max_alive` + 4 de margen para los cuerpos que todavía estén volando cuando entre `kill-feedback`; AC1152 verifica que cubre `max_alive`), `weight` 0 y `first_wave` 1. **No se agrega a `WaveConfig.enemy_types`**: la mezcla ponderada no lo sortea; lo maneja solo la horda.
- **`data/enemies/configs/fodder_config.tres`** (`FodderConfig`: `swarm_distance`), en `EnemyStats.behavior_config`.

### 3.2 Flujo de una oleada normal

1. `start_wave()` hace la mezcla de siempre (`_spawn_mix(config.enemies_per_wave)`, sin cambios) y después `_start_horde()`: calcula `total_for(wave)` y saca `initial_groups` grupos (sin pasar `max_alive` ni el total).
2. **Un grupo:** centro con `_pick_spawn_position()` (lejos del jugador y de lo ya puesto en esta oleada); cada miembro en `centro + member_offset(i)`, recortado al cuadrado de aparición. Cada Esbirro pasa por `_place()`: nivel, Rage, ritmo y aparición desde el piso, igual que los demás.
3. **Refuerzos:** `WaveManager` escucha `registry.enemy_killed`. Si el muerto es de la horda, quedan Esbirros por salir y los Esbirros vivos son `≤ refill_below`, arranca un temporizador de `refill_delay`. Al vencer, saca un grupo (recortado a lo que falte y a `max_alive`). El temporizador avanza en `_physics_process` (un `float` miembro; nada se crea por cuadro).
4. **Fin de la oleada:** `registry.all_dead` solo ofrece las cartas si **la horda terminó** (salieron todos). Si el jugador mató todo antes de que salga el próximo grupo, ese grupo sale en el acto y no hay cartas todavía.
5. Oleadas de boss: sin horda (`total_for` = 0). La invocación de la Colmena no cambia.

### 3.3 Pool y rendimiento (Principio V)

- `arena.tscn` suma **`EnemyPoolFodder`** (`EnemyPool` con `spawn_entry = fodder_spawn.tres`: 16 Esbirros creados al cargar), enlazado en `WaveManager.horde_pool` (export nuevo; los Esbirros no pasan por `pools` ni por `_type_pools`).
- **Cuerpos simultáneos:** oleada normal = `enemies_per_wave` de la Fase A (hoy 7) + hasta 16 Esbirros ≈ 23 `CharacterBody3D`. La separación (`AttackCoordinator.separation_for`) recorre la lista del registro: con 23 son ~500 distancias por cuadro, sin allocations.
- La barra de vida flotante de un Esbirro nunca llega a verse: está oculta hasta el primer golpe y ese golpe lo mata (se desactiva en el mismo cuadro).
- **Medición en el dispositivo (obligatoria antes de cerrar):** smoke test en el teléfono con 16 Esbirros + la oleada normal, midiendo el tiempo de cuadro (monitor de rendimiento de Godot). Si pasa de 16.6 ms en el teléfono de prueba, se baja `max_alive` en el `.tres` y se anota en la spec. No se decide un "modo móvil" por las dudas (Principio V, *Render*).

## 4. Arte (sin enmienda)

- Cápsula gris + dos esferas grises (`enemy_material.tres`), como todos. Se distingue por **tamaño** (`body_scale` 0.7, el enemigo más chico del juego) y por las **manos chicas y caídas**: `data/enemies/hands/fodder_hands.tres` con `hand_scale` 0.7 y reposo bajo a los costados (brazos colgando, postura encorvada).
- Sin colores nuevos ni mallas nuevas.

## 5. Estructura de nodos

```
components/enemies/
└─ fodder_behavior.gd / .tscn          ← nuevo (extends MeleeBehavior)

levels/arena/arena.tscn
├─ EnemyPoolFodder (EnemyPool, spawn_entry = fodder_spawn.tres)   ← nuevo
└─ WaveManager                          (horde_pool = ../EnemyPoolFodder)
```

`enemy.tscn` no cambia.

## 6. Resources y datos

- **Nuevos scripts:** `resources/horde_config.gd` (`HordeConfig`), `resources/fodder_config.gd` (`FodderConfig`).
- **Cambios de scripts de datos:**
  - `EnemyStats`: `enum AttackTokenGroup { MAIN, FODDER }` y `@export var token_group: AttackTokenGroup`.
  - `GroupAIConfig`: `fodder_max_attackers: int` y `max_attackers_for_group(group, rage_level) -> int` (puro: el `MAIN` sigue con `max_attackers_for`; `FODDER` devuelve `fodder_max_attackers`).
  - `WaveConfig`: `@export var horde: HordeConfig`.
- **Nuevos `.tres`:**
  - `data/enemies/fodder_stats.tres`, `data/enemies/attacks/fodder_swipe.tres`, `data/enemies/hands/fodder_hands.tres`, `data/enemies/configs/fodder_config.tres`, `data/enemies/spawn/fodder_spawn.tres`;
  - `data/waves/horde_config.tres`.
- **Cambios de `.tres`:** `wave_config.tres` (`horde`), `group_ai_config.tres` (`fodder_max_attackers = 2`).

## 7. Interfaz pública

- **`HordeConfig`:** `total_for(wave, is_boss_wave)`, `group_size(roll)` y `member_offset(index)` (puras).
- **`WaveManager`:**
  - `@export var horde_pool: EnemyPool`.
  - `get_horde_remaining() -> int` (Esbirros que faltan salir en esta oleada) y `get_horde_alive() -> int`.
  - `spawn_horde_group() -> int` (público para los tests: saca un grupo y devuelve cuántos salieron).
- **`AttackCoordinator`:** `get_holder_count(group := AttackTokenGroup.MAIN)`. `request_token`, `release_token` y `withdraw` no cambian de firma: leen el grupo del enemigo.
- **`FodderBehavior`:** sin API nueva (sobrescribe `_chase_in_turns`).

## 8. Criterios de aceptación (AC1141–AC1155)

**Datos del Esbirro** (`test/resources/fodder_stats_test.gd`):
- **AC1141:** para cada clase (`warrior`, `berserker`, `samurai`), el golpe más débil de su combo a nivel 1 sin crítico (`DAMAGE × (1 + DAMAGE_BONUS) × damage_multiplier`, mínimo sobre todos los `AttackComboStep`) menos la defensa del Esbirro es **≥ `max_health`** del Esbirro. Lee los `.tres` reales: si alguien baja un multiplicador o sube la vida, el test falla.
- **AC1142:** `fodder_stats.write_scaled(25, …)` deja `max_health` y `defense` iguales a nivel 1, y el daño a nivel 25 es 6 × (1 + 0.1 × 24).

**Comportamiento** (`test/entities/enemy/fodder_test.gd`):
- **AC1143:** con cada una de las tres clases a nivel 1, un solo golpe del combo (cualquier paso, `crit_roll` 0.99) mata a un Esbirro dentro del arco: `killed` se emite y vuelve al pool.
- **AC1144:** cuatro Esbirros a 1.2 m del jugador, dentro del arco del segundo golpe del Guerrero, mueren con ese único golpe, y `AttackComponent.attacked` informa `hit_count` 4.
- **AC1145:** a nivel 1 con el ritmo aplicado, la preparación del Esbirro dura ≥ 1.5 s; un empuje durante la preparación la cancela; si conecta, el jugador recibe `maxf(6 × 1.0 − defensa, 1)`.
- **AC1146:** con coordinador, un Esbirro sin token no ocupa lugar del anillo (`get_slot` = −1) y a los 3 s está a `swarm_distance` ± 0.5 m del jugador.

**Turnos** (`test/systems/attack_coordinator_test.gd`, casos nuevos):
- **AC1147:** con `fodder_max_attackers` 2, un tercer Esbirro no recibe token hasta que se libera uno; con 2 Esbirros atacando, un Bruto recibe su token `MAIN` igual. `get_holder_count(MAIN)` y `get_holder_count(FODDER)` cuentan por separado.

**Horda** (`test/resources/horde_config_test.gd` y `test/levels/arena_horde_test.gd`):
- **AC1148:** `total_for`: 0 si `wave < first_wave` o si es de boss; 10 en la 1, 12 en la 2 y 30 en la 20 (tope). `group_size(0.0)` = 4 y `group_size(0.999)` = 6.
- **AC1149:** `member_offset(i)` queda dentro de `group_radius` para `i` < `group_size_max`, y dos miembros de un mismo grupo quedan a ≥ `member_separation`.
- **AC1150:** en la arena (semilla fija), al empezar la oleada 1 hay `enemies_per_wave` enemigos de la mezcla (igual que sin horda) más `min(initial_groups × tamaño, total, max_alive)` Esbirros; el centro de cada grupo está a ≥ `min_spawn_distance` del jugador y todos quedan dentro del cuadrado de aparición.
- **AC1151:** al matar Esbirros hasta dejar `refill_below`, aparece un grupo nuevo a los `refill_delay` (± 1 cuadro), y los Esbirros vivos nunca superan `max_alive`.
- **AC1152:** en una oleada con `total_for` = 30, salen exactamente 30 Esbirros en total; el pool nunca se agota (sin `push_error`), y `fodder_spawn.tres` tiene `max_per_wave` ≥ `horde_config.max_alive`.
- **AC1153:** si el jugador mata a todos (mezcla y Esbirros) antes de que salga la tanda siguiente, no se ofrecen cartas: sale el próximo grupo. Las cartas aparecen solo cuando `get_horde_remaining()` = 0 y no queda nadie vivo.
- **AC1154:** una oleada de boss no saca Esbirros, y la invocación de la Colmena sigue usando sus tipos.

**Comunes:**
- **AC1155:** el Esbirro aplica su `body_scale` 0.7 y sus manos (`hand_scale` 0.7), usa `enemy_material.tres`, y reutilizarlo del pool en plena preparación (`deactivate` + `activate`) lo devuelve al estado inicial (como AC439). Sus muertes suman a `RunState.kills`.

## 9. Plan de implementación

1. Leer `early-power-curve.md` si ya existe y confirmar que no toca `WaveConfig.horde`, `GroupAIConfig.fodder_max_attackers` ni los archivos nuevos. Reservar AC1141–AC1155 en `CLAUDE.md`/`ac-registry.md` al empezar (rango ya asignado a la Fase B).
2. Datos del Esbirro (`fodder_stats`, `fodder_swipe`, `fodder_hands`, `fodder_config`, `fodder_spawn`) y `FodderBehavior` (primero idéntico a `MeleeBehavior`). Tests AC1141–AC1145 y AC1155 con enemigos sueltos.
3. `EnemyStats.token_group`, `GroupAIConfig.fodder_max_attackers` y los cupos por grupo en `AttackCoordinator`. Test AC1147; los tests de `enemy-group-ai` siguen en verde sin cambios (todo es `MAIN` por defecto).
4. `FodderBehavior._chase_in_turns` sin anillo. Test AC1146.
5. `HordeConfig` y su `.tres`. Tests AC1148–AC1149.
6. `WaveManager`: `horde_pool`, `_start_horde`, grupos, refuerzos y el cambio en `_on_all_dead`. `EnemyPoolFodder` en `arena.tscn`. Con `WaveConfig.horde` vacío la arena se comporta como hoy (se prueba antes de asignarlo). Tests AC1150–AC1154.
7. Asignar `horde_config.tres` en `wave_config.tres`. Tests de oleadas existentes (`arena_waves_test.gd`, AC415) en verde: si alguno cuenta enemigos vivos con un número fijo, se adapta para contar solo los de la mezcla, sin cambiar lo que verifica, y se anota abajo.
8. Tests del Esbirro y de la horda con `godot-tester`, smoke test en la arena con las tres clases, y captura con `godot-capture` de una oleada 1 (vista de juego) para revisar que los grupos se lean y que un barrido mate a varios.
9. Medición en el teléfono (§3.3). Checklist, spec **Implementada**, `where-to-tune.md` (viñetas "Tipos de enemigo" e "IA de grupo") y próximo AC libre.

## 10. Review (checklist de la constitución)

- [ ] **I.** Combate (barridos que matan a varios) y Supervivencia (presión de volumen), como se explica arriba.
- [ ] **II.** Cápsula y esferas grises con `enemy_material.tres`; se distingue por escala y pose de las manos. Sin colores ni mallas nuevas.
- [ ] **III.** Todo número en `.tres` (`fodder_*`, `horde_config`, `group_ai_config`). `HordeConfig` es puro. Ningún Resource compartido se muta.
- [ ] **IV.** Tipado estático; `_physics_process` de `WaveManager` solo llama a `_advance_horde_refill(delta)`.
- [ ] **V.** Pool de 16 creado al cargar; refuerzos con un temporizador `float`; grupos con `member_offset` puro; sin allocations por cuadro. Medición en el dispositivo registrada.
- [ ] **VI.** Sin input nuevo.
- [ ] **VII.** Sin cambios en el golpe del jugador.
- [ ] **VIII.** No aplica (enemigos; las manos usan poses de datos como los demás tipos).
- [ ] **Calidad:** tests de esta spec en verde, suite completa sin fallos nuevos, smoke test.

## 11. Notas

- Los números son punto de partida. El balance fino (cuántos Esbirros por oleada, cuándo entran los tipos molestos) se hace junto con la Fase A, en `horde_config.tres` y `wave_config.tres`, sin tocar código.
- El Esbirro no cuenta para la mezcla ponderada ni para el respaldo (`enemy_types[0]` sigue siendo el Bruto).
- Idea para después (fuera de alcance): que la Colmena invoque Esbirros; que el Rage sume Esbirros por oleada en vez de solo fuerza.
- **Implementación sobre `main` sin la Fase A:** la rama parte del último commit de `main`, donde `WaveConfig.enemies_for_wave` y `GroupAIConfig.max_attackers_for(level, rage)` todavía no existen. Al fusionar con la Fase A: `AttackCoordinator.get_max_attackers` / `max_attackers_for_group` pasan a recibir también el nivel (el grupo `MAIN` llama a `max_attackers_for(level, rage)`; `FODDER` sigue con `fodder_max_attackers`), y `arena_horde_test` (AC1150) cambia `enemies_per_wave` por `enemies_for_wave(1)`.
- **Números de la horda:** los valores de `horde_config.tres` son los de partida. Se recalibran cuando la Fase A publique el DPS medido (§6.1 de `early-power-curve.md`); hoy esa tabla está vacía. La vida del Esbirro no depende de ella (muere de un golpe).
- **Estado de la verificación (2026-09-29):** tests nuevos en verde (`fodder_stats_test`, `horde_config_test`, `fodder_test`, `arena_horde_test`, caso AC1147 en `attack_coordinator_test`). Comparando la corrida de `test/resources`, `test/entities/enemy`, `test/systems`, `test/levels` y dos de `test/ui` contra `main` limpio (`1f7b458`): ningún test falla en la rama y no en `main`. Los 49 fallos restantes ya fallaban en `main` (p. ej. `enemy_attack_test`, `charger_test`, `affliction_data_test`); cinco tests que fallaban en `main` (AC19, AC24, AC53, AC415, AC456) pasan porque `grunt_spawn.tres` tenía `max_per_wave = 5` con 7 enemigos por oleada.
- **Adaptación de tests (AC1135 de la Fase A, mismo criterio):** los tests de arena que cuentan enemigos o limpian una oleada (`ability_run`, `affliction_run`, `arena_waves`, `berserker_run`, `boss_challenge_run`, `character_class_run`, `samurai_run`, `sandbox_run`, `unique_upgrade_run`, `upgrade_ban_run` y `pause_menu`) llaman a `TestWorld.without_horde(arena)` (deja `WaveManager.horde_pool` vacío) y verifican lo mismo que antes sobre la mezcla común. La horda se prueba en `arena_horde_test`.
- **Desviación del AC1144:** el barrido de prueba usa el primer golpe del Guerrero (arco 0.35× ≈ 42°) con un grupo apretado (±9°, como un grupo de la horda) y no el segundo golpe: el driver de combos no encadena el segundo paso sin agregar helpers. Verifica lo mismo (un golpe, `hit_count` 4, todos mueren).
- **Pendiente antes de dar la spec por cerrada:** (1) medir el tiempo de cuadro en el teléfono con 16 Esbirros + oleada; (2) smoke test manual en la arena con las tres clases; (3) captura con `godot-capture` de la oleada 1; (4) al fusionar con la Fase A: firma de `get_max_attackers`/`max_attackers_for_group` con nivel, `enemies_for_wave` en AC1150, `grunt_spawn.max_per_wave = 7` (igual en las dos ramas), y actualizar `CLAUDE.md`/`ac-registry.md`.
