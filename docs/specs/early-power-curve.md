# Curva de poder temprana (Fase A)

- **Estado:** Implementada (2026-09-28), revisión 2: la defensa y la vida se calibran con el DPS medido del combo, porque los golpes reales son de 5 a 10 y no de ~20. Pendiente el playtest del usuario (paso 6).
- **Constitución:** `docs/constitution.md` **v5.0.0**, sin enmienda (el Principio I ya contempla Android y la pantalla táctil; todo lo ajustable queda en Resources, Principio III).
- **Pilar (Principio I):** Progresión + Supervivencia.
  - **Progresión:** el jugador se hace fuerte más rápido de lo que se hacen fuertes los enemigos. Matar es cada vez más rápido dentro de la run, que es el "farmeo" que buscan los jugadores.
  - **Supervivencia:** la presión llega en picos (un segundo atacante en la oleada 8, el boss en la 10, los tipos molestos después) en vez de estar al máximo desde la oleada 1.
- **Tipo:** balance (datos) con dos cambios chicos de comportamiento: tamaño de oleada y cantidad de cartas por oleada, y atacantes simultáneos según el nivel.
- **Dependencias:** `enemy-level-pace.md`, `boss-health-tuning.md`, `enemy-group-ai.md`, `enemy-types.md`, `boss-challenge.md`, `upgrade-ban.md` (si existe con otro nombre, la spec del bloqueo de cartas).
- **Relacionadas (Fase B, en paralelo):** `fodder-minion.md`, `kill-feedback.md`, `perfect-dodge.md`.
- **ACs reservados:** AC1121–AC1140.

## Problema

Feedback de los jugadores: las primeras oleadas cuestan mucho, los enemigos no dejan respirar, las mejoras tardan en llegar y los primeros bosses son "imposibles". Los datos lo confirman:

| | Por oleada | Oleada 10 (nivel 5) |
|---|---|---|
| Vida de un enemigo común (+20 % por nivel, 1 nivel cada 2 oleadas) | **+10 %** | ×1.8 |
| DPS del jugador (supuesto optimista: 1 carta por oleada, la mitad de daño, +10 % cada una) | **+5 %** | ×1.45 |
| Atacantes simultáneos | 2 desde la oleada 1 | 2 |
| Preparación del Hostigador a nivel 1 | 0.3 × 1.8 = **0.54 s** (sale en la oleada 3) | |
| Verdugo en la oleada 12 (primer boss hoy) | | ~2 040 de vida: 130–190 s pegando el 40 % del tiempo |

El tiempo para matar (TTK) de un enemigo común **sube** oleada a oleada, al revés de una fantasía de poder.

## Decisiones del usuario (2026-09-28)

1. Primer boss en la **oleada 10** (después cada 10: 10, 20, 30…).
2. Más mejoras al principio **de las dos formas**: oleadas 1–3 más cortas (4, 5 y 6 enemigos) y **2 cartas** al terminar cada una.
3. Crecimiento **suave** de los enemigos comunes: vida +8 % por nivel y defensa +0.2 por nivel, con topes más bajos.
4. Primer boss en **~60 s** para un jugador casual que pega el 40 % del tiempo.

## Cambios

### 1. Oleadas y cartas (`WaveConfig`, `WaveManager`)

**`resources/wave_config.gd`:**
- `+ @export var early_wave_sizes: Array[int]`: tamaño de las primeras oleadas regulares, por índice (oleada 1 → índice 0). Si falta el índice, vale `enemies_per_wave`.
- `+ @export var early_wave_picks: Array[int]`: cartas que se eligen al terminar las primeras oleadas. Si falta el índice, vale 1.
- `+ func enemies_for_wave(wave: int) -> int`: función pura.
- `+ func picks_for_wave(wave: int) -> int`: función pura. Una oleada de boss siempre vale 1, porque su oferta es la dorada.

**`data/waves/wave_config.tres`:**

| Campo | Antes | Después |
|---|---|---|
| `early_wave_sizes` | — | `[4, 5, 6]` |
| `early_wave_picks` | — | `[2, 2, 2]` |
| `enemies_per_wave` | 7 | 7 (sin cambios) |
| `boss_wave_interval` | 12 | **10** |

**`systems/wave_manager.gd`:**
- `start_wave()` genera `config.enemies_for_wave(run_state.wave)` enemigos, en lugar de `enemies_per_wave`.
- Se agrega `var _picks_left: int`. En `_on_all_dead()` vale `config.picks_for_wave(run_state.wave)`.
- `_on_upgrade_chosen()` aplica la carta y descuenta una elección. Si quedan elecciones, arma una oferta nueva con `build_offer()` (ya sin las cartas que llegaron a su tope) y la muestra **sin la carta de bloquear**. Si no quedan, avanza a la oleada siguiente.
- Bloquear una carta (`_on_ban_chosen`) consume una elección, igual que hoy reemplaza la carta de la oleada. Si quedan elecciones, se muestra una oferta nueva.
- Si la oferta de una elección extra queda vacía, se avanza a la oleada siguiente sin empezar el Rage. El Rage sigue empezando solo cuando la **primera** oferta de la oleada queda vacía (`endless-without-upgrades.md`).
- El sandbox no cambia: no muestra cartas y avanza solo.

**UI:** sin cambios de escena. La segunda oferta es otra apertura del mismo `UpgradePicker`.

### 2. Un solo atacante al principio (`GroupAIConfig`, `AttackCoordinator`)

**`resources/group_ai_config.gd`:**
- `+ @export var early_attackers: int`: atacantes simultáneos hasta `early_attackers_max_level`.
- `+ @export var early_attackers_max_level: int`.
- `max_attackers_for(rage_level)` pasa a ser `max_attackers_for(level: int, rage_level: int) -> int`: la base es `early_attackers` si `level ≤ early_attackers_max_level`, y `base_attackers` si no. Encima se suma el extra por Rage, con el mismo tope `max_attackers_cap`.

**`systems/attack_coordinator.gd`:**
- `get_max_attackers()` pasa a ser `get_max_attackers(level: int)`, y `request_token(enemy)` usa `enemy.level`. Todos los enemigos de una oleada comparten nivel, así que el resultado es el mismo para el grupo.

**`data/enemies/group_ai_config.tres`:** `early_attackers = 1`, `early_attackers_max_level = 4`. Resultado: oleadas 1–7 con 1 atacante y, desde la 8 (la previa al primer boss), con 2.

### 3. Preparaciones más largas al principio (`enemy_pace_config.tres`)

| Campo | Antes | Después |
|---|---|---|
| `windup_scale_first_level` | 1.8 | **2.2** |
| `interval_scale_first_level` | 2.5 | **3.0** |
| `*_last_level` y los valores de Rage | | sin cambios |

Preparaciones resultantes a nivel 1: Bruto 0.5 → **1.1 s**, Hostigador 0.3 → 0.66 s, Saltador 0.7 → 1.54 s, Embestidor 0.8 → 1.76 s. En el nivel 5 (oleada 10) la escala es 2.03. Todas quedan por encima de ~0.6 s (reacción de ~250 ms más la latencia táctil), y las de los tipos de la zona temprana, por encima de 1 s.

### 4. Tipos molestos más tarde (`data/enemies/spawn/*.tres`)

| Tipo | `first_wave` antes | Después |
|---|---|---|
| Bruto | 1 | 1 |
| Embestidor | 2 | **4** |
| Saltador | 5 | **8** |
| Escudero | 6 | **11** |
| Hostigador | 3 | **15** |

Pesos y máximos por oleada sin cambios. Las oleadas 1–3 son solo de Brutos. El Hostigador, el enemigo "molesto" por excelencia, llega cuando el jugador ya tiene ~15 cartas.

### 5. Crecimiento suave de los enemigos comunes (`data/enemies/<tipo>_stats.tres`)

Para los cinco tipos comunes (Bruto, Embestidor, Hostigador, Saltador y Escudero):

**Hallazgo (revisión 2, al escribir `fodder-minion.md`):** cada golpe del combo hace `DAMAGE × damage_multiplier`, con multiplicadores de 0.28 a 0.6. Los golpes reales a nivel 1 son de **5 a 10** (Guerrero 5.6–10.4, Berserker 10–15, Samurái 5.0–8.6), no de ~20. La defensa se **resta plana a cada golpe** (`DamageMath.mitigate`, mínimo 1). Por eso pega mucho más de lo que se pensaba:
- Un Bruto de nivel 5 con 2 de defensa le quita el 36 % al primer golpe del Guerrero.
- El Escudero, con 6, deja casi todos los golpes del Guerrero y del Samurái en el mínimo de 1.

Hoy el Bruto (40 de vida) necesita 7 golpes del primer paso del Guerrero. Parte del "cuesta demasiado matar" viene de acá.

Para los cinco tipos comunes (Bruto, Embestidor, Hostigador, Saltador y Escudero):

| Stat | Antes | Después |
|---|---|---|
| Crecimiento de vida (`Resource_max_health.amount`, %) | 0.20 | **0.08** |
| Crecimiento de defensa (`Resource_defense.amount`, plano) | 0.5 | **0** (la defensa de los comunes no crece; el objeto de crecimiento se saca de `level_growth`) |
| Defensa base | Embestidor 2, Saltador 1, Escudero 6 | **Embestidor 1, Saltador 0, Escudero 3** (Bruto y Hostigador siguen en 0) |
| Vida base | Bruto 40, Embestidor 60, Hostigador 35, Saltador 50, Escudero 90 | **Calibrada** (§6.1): el Bruto muere en **2 s** de combo continuo a nivel 1 con el DPS de referencia medido, y los demás mantienen su proporción con el Bruto (Embestidor ×1.5, Hostigador ×0.875, Saltador ×1.25, Escudero ×2.25) |

Daño y velocidad sin cambios. La vida crece +4 % por oleada, menos que el jugador (~5 %): el TTK baja suave dentro de la run.

### 6. Calibración con el DPS medido y vida de los bosses para ~60 s en la oleada 10

El DPS de referencia de `boss-health-tuning.md` (≈ 27) se calculó como `DAMAGE × ATTACK_SPEED` y no refleja los multiplicadores del combo actual. En lugar de estimarlo otra vez, **se mide**.

#### 6.1 DPS de referencia medido (paso 0 del plan)

- **Medición:** un test (`test/levels/class_dps_reference_test.gd`, AC1136) arma cada clase con `test/helpers/combo_driver.gd`, sin cartas ni habilidades, a nivel 1. Durante **10 s de combo continuo** le pega a un objetivo quieto sin defensa, con el crítico base promediado (`1 + crit_chance × crit_damage`) en vez de sorteado.
- **Referencia:** `DPS_ref` es el promedio de las tres clases. Los tres valores y el promedio se escriben en esta spec (tabla de abajo) antes de tocar los `.tres`, y el test los fija con una tolerancia del 5 %.

| Clase | DPS medido del combo |
|---|---|
| Guerrero | 18.73 |
| Berserker | 13.44 |
| Samurái | 28.24 |
| **`DPS_ref`** | **20.14** (promedio) |

**Vida base del Bruto:** `2 s × DPS_ref`, redondeada al entero. Los otros tipos, en proporción (§5).

#### 6.2 Bosses

**Referencia:**
- Cartas al llegar al boss de la oleada 10: 9 oleadas + 3 cartas extra = **12**. Se asume que el 40 % son de daño (el mazo también tiene cartas de habilidad y de Aflicción) y que cada una suma +10 %: DPS en la oleada 10 ≈ **`DPS_ref × 1.5`**.
- Las habilidades no entran en `DPS_ref`. Son el margen a favor del jugador, porque suman daño y reemplazan la parte optimista del supuesto de las cartas.
- Vida efectiva objetivo del Verdugo en la oleada 10 (multiplicador 1): `DPS_ref × 1.5 × 60 s × 0.4 = 36 × DPS_ref`.

**Defensa de los bosses:** misma lógica que en los comunes, porque una defensa plana contra golpes de 5–10 come demasiado.

| | Antes | Después |
|---|---|---|
| Defensa base | 2 | **0** |
| Crecimiento de defensa | +0.25 por nivel (tope 8) | **+0.1 por nivel (tope 2)** |

Queda en 0.4 en la oleada 10 (~5 % de un golpe de ~8) y llega al tope de 2 en el nivel 21.

**Vida:**
- Verdugo base = `36 × DPS_ref ÷ 1.38 ÷ 0.95`, redondeada. El 1.38 es el crecimiento a nivel 5 (1 + 0.095 × 4); el 0.95 es la parte del golpe que no come la defensa.
- Titán = Verdugo ÷ 1.5; Colmena = Verdugo ÷ 2.2 (multiplicadores relativos de `boss-health-tuning.md`, sin cambios).
- Se conserva el crecimiento de +9.5 % por nivel: `vida(nivel) = base × (1 + 0.095 × (nivel − 1))`.

**Ejemplo provisional** (si `DPS_ref` diera 27): Verdugo base ≈ 741 → 1 023 en la oleada 10; Titán 494 y Colmena 337 de base. Los valores finales salen del paso 0.

**Chequeo en la oleada 20:** con ~22 cartas el DPS es ≈ `DPS_ref × 1.88`, y el Verdugo tiene `base × 1.855` de vida. Queda ≈ 1.855 ÷ 1.88 × 60 s ≈ **~60 s**: la duración se mantiene cerca del minuto.

**Qué no cambia:** daño, velocidad, ataques, fases y resistencias de los bosses. Las manos del Titán siguen siendo el 30 % de su vida. Los esbirros de la Colmena usan la vida y el crecimiento de su tipo, que ahora son los calibrados.

## Interfaz pública (resumen)

```gdscript
# WaveConfig
@export var early_wave_sizes: Array[int]
@export var early_wave_picks: Array[int]
func enemies_for_wave(wave: int) -> int
func picks_for_wave(wave: int) -> int

# GroupAIConfig
@export var early_attackers: int
@export var early_attackers_max_level: int
func max_attackers_for(level: int, rage_level: int) -> int   # signature change

# AttackCoordinator
func get_max_attackers(level: int) -> int                    # signature change
```

## Criterios de aceptación (AC1121–AC1137)

- **AC1121** (`test/resources/wave_config_test.gd`): con `wave_config.tres`, `enemies_for_wave` devuelve 4, 5 y 6 en las oleadas 1, 2 y 3, y 7 en las oleadas 4, 9 y 11.
- **AC1122** (ídem): `picks_for_wave` devuelve 2 en las oleadas 1–3, 1 en las oleadas 4 y 9, y 1 en la oleada 10 (boss).
- **AC1123** (ídem): `is_boss_wave` es verdadero en las oleadas 10, 20 y 30, y falso en las 12 y 24.
- **AC1124** (`test/levels/early_power_curve_run_test.gd`): la oleada 1 genera 4 enemigos. Al matarlos se abre el picker; al elegir una carta, el picker se vuelve a abrir con una oferta nueva y la oleada sigue siendo la 1. Al elegir la segunda, empieza la oleada 2 con 5 enemigos, y el jugador tiene aplicadas las dos cartas.
- **AC1125** (ídem): en la oleada 4, una sola elección avanza a la oleada 5 (comportamiento de siempre).
- **AC1126** (ídem): en la oleada 3 (donde se ofrece bloquear), bloquear consume una elección: se vuelve a abrir el picker con una oferta nueva y sin la carta de bloquear, y al elegir se avanza a la oleada 4.
- **AC1127** (ídem): si al pedir la segunda oferta no quedan cartas disponibles, se avanza a la oleada siguiente y el Rage **no** empieza.
- **AC1128** (`test/resources/group_ai_config_test.gd`): `max_attackers_for(level, rage)` vale 1 para `(1, 0)` y `(4, 0)`; 2 para `(5, 0)` y `(25, 0)`; 2 para `(1, 3)` (el Rage suma encima de la base temprana); y 4 para `(5, 20)`, por el tope.
- **AC1129** (`test/systems/attack_coordinator_test.gd`): con dos enemigos de nivel 1 que piden turno, solo uno lo recibe; con dos de nivel 5, lo reciben los dos (respetando `token_gap`).
- **AC1130** (`test/resources/enemy_pace_config_test.gd`): `windup_scale_for(1, 0) = 2.2`, `interval_scale_for(1, 0) = 3.0`, y en el nivel 25 siguen valiendo 1.2 y 1.4. Un Bruto activado a nivel 1 con el ritmo aplicado tiene una preparación de 1.1 s (±0.001).
- **AC1131** (`test/entities/enemy/enemy_level_test.gd`): para los cinco tipos comunes, la vida en el nivel 5 es `base × 1.32` y la defensa en los niveles 5 y 25 es igual a la de nivel 1 (0, 1, 0, 0 y 3). La vida base del Bruto es `round(2 × DPS_ref)` y la de los demás respeta la proporción del §5 (±1).
- **AC1132** (`test/resources/boss_health_tuning_test.gd`, reescrito): la vida de los tres bosses en los niveles 5, 10, 15 y 25 es `base × (1 + 0.095 × (nivel − 1))` (tolerancia de 1 punto), con las bases que salen del §6.2. La defensa vale 0 en el nivel 1, 0.4 en el 5 y 2 en el 25.
- **AC1133** (ídem): la vida efectiva del Verdugo en la oleada 10 (`vida ÷ (1 − defensa ÷ golpe promedio medido)`) queda en `36 × DPS_ref` ± 5 %, que son los ~60 s de referencia.
- **AC1136** (`test/levels/class_dps_reference_test.gd`): el DPS del combo continuo de cada clase (10 s, nivel 1, sin cartas ni habilidades, crítico promediado, objetivo sin defensa) coincide con la tabla del §6.1 (±5 %).
- **AC1137** (ídem): un Bruto de nivel 1 recibe el combo continuo del Guerrero, del Berserker y del Samurái y muere en 2 s ± 0.6 s con cada uno.
- **AC1134** (`test/levels/early_power_curve_run_test.gd` o el test de la tabla de aparición): en las oleadas 1–3 solo aparecen Brutos; el Embestidor no aparece antes de la 4, el Saltador antes de la 8, el Escudero antes de la 11 ni el Hostigador antes de la 15 (con varias semillas).
- **AC1135:** los tests que fijaban los valores viejos se adaptan sin cambiar lo que verifican, y se anota cada uno en esta spec:
  - los que usan `WAVE_CONFIG.enemies_per_wave` para la oleada 1 pasan a `enemies_for_wave(wave)`: `arena_waves_test`, `ability_run_test`, `boss_challenge_run_test` y `sandbox_run_test`;
  - `upgrade_ban_run_test`, si el bloqueo cae en una oleada con 2 elecciones;
  - `group_ai_config_test` y `group_ai_test`, por la firma nueva de `max_attackers_for`;
  - `enemy_pace_test`, `enemy_level_test`, `enemy_types_common_test` y los tests de cada tipo que fijen vida o defensa por nivel;
  - `boss_challenge_run_test` (boss en la oleada 10 en lugar de la 12), y `titan_test`, `colmena_test`, `boss_hud_bar_test` y `cooldown_hud_test` si fijan la vida de un boss.

## Plan de implementación

0. **Medición:** escribir `class_dps_reference_test` (AC1136), medir el DPS de las tres clases, completar la tabla del §6.1 y calcular con ella la vida del Bruto, de los otros comunes y de los bosses. Anotar los valores en esta spec. Si algún número sale muy lejos del ejemplo provisional (`DPS_ref` fuera de 10–40), frenar y consultarlo con el usuario antes de seguir.
1. **Datos puros:** cambiar `enemy_pace_config.tres`, los cinco `*_spawn.tres`, los cinco `*_stats.tres` comunes y los tres de bosses, y `boss_wave_interval`. Correr los suites de enemigos y bosses y adaptar los tests con valores fijos (AC1130–AC1135).
2. **`WaveConfig`:** agregar los campos y las funciones puras con sus tests (AC1121–AC1123), y cargar los arrays en `wave_config.tres`.
3. **`WaveManager`:** usar el tamaño por oleada y agregar las elecciones múltiples y el bloqueo como elección (AC1124–AC1127). Adaptar los tests de la arena.
4. **`GroupAIConfig` y `AttackCoordinator`:** cambiar la firma, agregar los campos en el `.tres` y sus tests (AC1128–AC1129).
5. Correr con `godot-tester` los suites tocados (`test/resources`, `test/entities/enemy`, `test/levels`, `test/systems/attack_coordinator_test.gd`) y un smoke test de la arena con las tres clases.
6. **Playtest del usuario:** este balance es una estimación. Los números viven en los `.tres` para ajustarlos jugando. Si el primer boss sigue lejos de los 60 s, se corrige el factor ×0.45.

## Riesgos y notas

- **El mazo se agota antes:** con 3 cartas extra, el Rage (`endless-without-upgrades.md`) puede empezar unas oleadas antes. Es aceptable: el Rage es justamente el reto para una build completa.
- **Oleadas 1–7 con un solo atacante** pueden sentirse vacías con tan pocos enemigos. La Fase B (`fodder-minion.md`) suma hordas de Esbirros que llenan ese espacio.
- **Diferencias entre clases:** la vida del boss es una sola. El Berserker lo termina antes y el Guerrero después (ver `boss-health-tuning.md`).

## Checklist de review de la constitución

- [x] Principio I: el pilar está declarado (Progresión + Supervivencia).
- [x] Principio III: todo número nuevo vive en un `.tres` (`WaveConfig`, `GroupAIConfig`), sin constantes mágicas en código.
- [x] Principio IV: tipado estricto; firmas nuevas documentadas con `##`.
- [x] Principio V: sin costo de rendimiento nuevo (menos enemigos al principio).
- [x] Principio VII: sin cambios al feedback de impacto.

## Notas de implementación (2026-09-28)

- **Valores finales (paso 0):** con `DPS_ref` = 20.14, la vida base del Bruto sale en **40** (`round(2 × 20.14)`), igual que antes; Embestidor 60, Hostigador 35, Saltador 50 y Escudero 90 también quedan iguales. Solo cambian sus defensas y su crecimiento. Bosses: Verdugo **499**, Titán **333**, Colmena **227** (antes 1380, 920 y 630).
- **Corrección de la fórmula del §6.2:** la vida base del Verdugo se calcula como `36 × DPS_ref × 0.95 ÷ 1.38` (y no `÷ 0.95`): la vida efectiva es `vida ÷ 0.95`, y con `÷ 0.95` quedaba un 11 % por encima del objetivo de AC1133. El ejemplo provisional (741) era de la fórmula vieja.
- **AC1137 ajustado:** cada clase mata al Bruto en `40 ÷ su propio DPS` (Guerrero ≈ 2.1 s, Berserker ≈ 3.0 s, Samurái ≈ 1.4 s), ±0.6 s. Solo el promedio de las tres da los 2 s; pedir 2 s a cada clase era imposible con DPS de 13 a 28. El test además verifica `40 ÷ DPS_ref = 2 s`.
- **Tope de Brutos por oleada:** el pool del Bruto se dimensiona con `max_per_wave` (5) y las oleadas de solo Brutos con más de 5 enemigos quedaban cortas (la oleada 3 pedía 6). `grunt_spawn.tres` pasa a `max_per_wave = 7`.
- **Tests adaptados (AC1135):** `arena_waves_test`, `ability_run_test`, `sandbox_run_test`, `boss_challenge_run_test` (boss en la oleada 10, nivel 5, helper `_choose_all`), `upgrade_ban_run_test`, `group_ai_config_test`, `group_ai_test` (enemigos y bloqueadores de nivel 5, que permiten 2 atacantes), `attack_coordinator_test` (enemigos de nivel 5 por defecto), `enemy_pace_config_test` y `enemy_pace_test` (tiempos de preparación de 2.2), `enemy_level_test` (vida 52.8 en el nivel 5), `titan_test`, `colmena_test` y `shieldbearer_test` (golpes fijos sin la defensa vieja; vida de mano del Titán 99.9), `boss_health_tuning_test` (reescrito).
- **Fallos previos, no relacionados** (también fallan en HEAD limpio): `arena_waves_test` ac22/ac23 (valores de las clases), varios de `titan_test` y `verdugo_test`, `sandbox_run_test` ac113/ac115, `boss_challenge_run_test` ac155, `affliction_data_test`, `enemy_level_scaling_test` y `rage_config_test`.
