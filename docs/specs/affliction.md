# Feature: Aflicción (acumulación de estados en los enemigos)

- **Estado:** Aprobada (2026-09-27), con las decisiones del responsable (§3) y los supuestos confirmados. En implementación. ACs reservados: **AC851–AC900** (se usan AC851–AC896).
- **Constitución:** `docs/constitution.md` v4.16.0 (con la enmienda de `status-icons.md` aplicada) → **enmienda MINOR a 4.17.0** (Principios II y III, ver §9).
- **Pilar (Principio I):** **progresión** y **combate.**
  - Progresión: cada carta violeta suma una Aflicción a una fuente (básicos o habilidad) y el tope de 3 tipos obliga a armar la build. El stat "Acumulación de Aflicción" las potencia a todas.
  - Combate: la barra debajo de la vida muestra cuánto falta para disparar el efecto, así que el jugador decide si terminar la barra de un enemigo, cambiar de objetivo o guardar la habilidad para el golpe que la llena. Escarcha estira las preparaciones enemigas y Estallido limpia grupos.
- **Requiere implementada:** `status-icons.md` (AC901–AC930, aprobada): `StatusIconView`, `DebuffData.icon`/`icon_color`/`is_beneficial`, `DebuffComponent.revision` y `EnemyStatusOverlay`. Esta spec **no toca** los íconos: solo agrega estados que ellos muestran.
- **Dependencias:** `enemy-rage.md`, `spin-golden-upgrades.md` (Debilitar, `ARMOR_REDUCTION` con stacks), `unique-ability-upgrades.md` (Lacerante, `bleed`), `upgrade-caps.md`, `stats-rework.md` (catálogo y pausa), `class-combat-identity.md` (combos por clase), `boss-hud-bar.md`. **En paralelo:** `warrior-abilities-rework.md` (AC801–AC850, otra sesión), que crea el estado aturdido (§8).

## 1. Nombre

**Aflicción** (en código `affliction`). Otros candidatos descartados: Estigma (suena a marca única), Saturación (técnico) y Quiebre (se confunde con Debilitar y con un aturdimiento). En las cartas: "Aflicción: Veneno"; en la pausa: "Aflicciones 2/3".

## 2. Relevamiento: qué existe y qué se reutiliza

| Pieza | Qué hay hoy | Uso en esta spec |
|---|---|---|
| `DebuffData` | `id`, `effect` (`DAMAGE_OVER_TIME`, `ARMOR_REDUCTION`, `STAT_BOOST`, `STATUS`), `duration`, `tick_interval`, `max_stacks`, `permanent`; con `status-icons.md`: `icon`, `icon_color`, `is_beneficial`. | Se reutiliza para el efecto de cada tipo. Se agregan: `Effect.SLOW`, `stack_mode` (**mejorable** o **acumulable**) y `damage_scaling` (daño por tick en % de vida o fijo). Los `.tres` existentes no cambian (los defaults dan el comportamiento de hoy). |
| `DebuffComponent` | Lista de estados; `apply(data, potency)` refresca, suma stacks y guarda la potencia máxima; los stacks solo multiplican `ARMOR_REDUCTION`. | Se amplía con los dos modos de stack, el daño fijo y `get_speed_scale()`. |
| Íconos (`status-icons.md`) | `EnemyStatusOverlay` (enemigos comunes, arriba de la barra de vida) y la `StatusIconRow` de `BossHealthBar`, que se reescriben cuando cambia `DebuffComponent.revision`. | **Sin cambios.** Los estados nuevos aparecen solos. Cada uno trae su SVG en `assets/icons/status/` con crédito en `SOURCE.md` (AC905, AC908). |
| `EnemyHealthBar` | Barra 3D, oculta hasta el primer golpe, mira a la cámara, se sacude; suprimida en bosses. | Las barras de Aflicción son un hijo nuevo (`AfflictionBars`) **debajo** de la barra de vida. |
| `BossHealthBar` | Barra del HUD con su `StatusIconRow`. | Se agrega `AfflictionBars` debajo de `BarFrame`, sin tocar la fila de íconos. |
| `AttackComponent.enemy_hit`, `AirSlashComponent.enemy_hit` | Golpes del combo y Tajo aéreo, con el daño aplicado. | Fuente **ataque básico**. |
| `AbilityComponent.enemy_hit` (vía `report_hit()`) | Lo emiten los behaviors por cada enemigo dañado. | Fuente **habilidad** = el slot `basic_ability` (E). El de la ultimate (R) no carga hasta que exista una fuente "ultimate" (§8). |
| `UpgradeCard`, `UpgradeData`, `AbilityUniqueUpgradeData`, `UpgradeOffer`, `WaveManager`, `Player.apply_upgrade`/`is_maxed` | Cartas de stats y únicas; pool = catálogo + mejoras de habilidades, sin baneadas ni topadas; doradas solo tras un boss. | La carta de Aflicción copia el modelo de la única (niveles en arrays). Se suma un catálogo violeta al pool. |
| `PlayerStats` + `stat_display_table.tres` | Stats mejorables con cartas y su fila en la pausa. | Stat nuevo `AFFLICTION_BUILDUP`, con carta y fila. |
| Rage | Buff de los enemigos cuando no quedan mejoras. | **Sin interacción** (§3.7). |

## 3. Decisiones (del responsable, 2026-09-27)

1. **Acumulación por golpe:** cada golpe o habilidad que "aplica Aflicción: X" suma una cantidad **fija** a la barra de X, potenciada por el stat del jugador y reducida por la resistencia del enemigo. Umbral: **100 puntos**, que el jugador no ve (solo ve la barra). Fórmula en §4.1.
2. **Resistencia:** una sola, **general** (vale para todos los tipos), por tipo de enemigo.
3. **Vaciado:** si una barra no recibe acumulación durante **5 s**, empieza a perder **15 puntos por segundo** (15 % del umbral). Si recibe acumulación, deja de perder y vuelven a correr los 5 s. Queda previsto (no se implementa) un buff enemigo "no puede recibir Aflicción".
4. **Barras apiladas, una por tipo conseguido.** Un golpe solo carga las barras de los tipos que **esa fuente** aplica. Ejemplo: con "Veneno (básicos)", "Estallido (básicos)" y "Escarcha (habilidad)", cada básico carga Veneno y Estallido, y solo la habilidad carga Escarcha.
5. **Sin resistencia creciente** en los bosses.
6. **Dos modos de stack** en los estados:
   - **Acumulable:** cada stack es una instancia completa que espera su turno. No sube el daño, alarga el efecto. "Veneno 10/s durante 5 s" con 3 stacks = 15 s de veneno a 10/s.
   - **Mejorable:** una sola instancia. Reaplicarla reinicia la duración y sube la fuerza (3 % → 6 %), hasta su tope.
   - **De una sola aplicación:** `max_stacks = 1`; reaplicarla solo reinicia la duración.
   - Siempre: si la barra se vuelve a llenar, se reinicia el tiempo del estado y, si puede, suma un stack. *(Confirmado: en el acumulable, un stack nuevo se encola sin reiniciar la instancia en curso; con el tope lleno, reaplicarlo reinicia el timer de la instancia en curso. §4.7.)*
7. **Rage:** es un buff que ganan los enemigos; no interactúa con las Aflicciones.
8. **Tope: 3 tipos** por run (`AfflictionConfig.max_types`). Tener el mismo tipo en básicos y en habilidad **no ocupa dos lugares**: es una sola barra que se carga desde las dos fuentes. *(Confirmado: 1 estado = 1 barra, que se puede llenar por varios medios (hoy básicos y habilidad; a futuro ataque cargado o ultimate). El tope cuenta tipos, no cartas.)*
9. **Fuentes:** ataque básico y habilidad (E). Las cartas para la ultimate llegan cuando exista.
10. **Cartas globales** (cualquier clase), **violetas** (tier nuevo), todas iguales sin importar el tipo. El stat "Acumulación de Aflicción" se ofrece **siempre**, aunque no se tenga ninguna Aflicción.
11. **MVP:** Veneno, Estallido, Escarcha y Corrosión. Sangrado como Aflicción queda para una mejora rara futura (sigue en % de vida). El aturdimiento lo crea el re-work del Guerrero; una Aflicción que aturda queda para el futuro (§8).

## 4. Diseño

### 4.1 Fórmula

Cada golpe con daño aplicado > 0, por cada carta de Aflicción cuya fuente sea la de ese golpe:

```
acumulado = B × E × (1 + P) × (1 − R)
```

| Término | Qué es | Dónde vive | Valores |
|---|---|---|---|
| **B** | Base de la carta, por nivel | `AfflictionUpgradeData.level_values` | Básicos 20 / 30 / 40; habilidad 35 / 50 / 65 |
| **E** | Escala de la fuente, para que las clases y habilidades llenen a un ritmo parecido | `AttackComboConfig.affliction_scale`, `AirSlashConfig.affliction_scale`, `AbilityData.affliction_scale` | Guerrero 1.0, Berserker 2.3, Samurái 0.8, Tajo aéreo 2.3; Estocada 1.0, Golpe veloz 1.0, Giro 0.4 (5 golpes por enemigo), Envainar 2.0 |
| **P** | Stat del jugador "Acumulación de Aflicción" (bonus, como `crit_damage`) | `PlayerStats.Stat.AFFLICTION_BUILDUP` | Base 0 en las tres clases; carta +10 %, hasta 5 veces |
| **R** | Resistencia general del enemigo | `EnemyStats.affliction_resistance`, acotada a `[0, AfflictionConfig.max_resistance]` | Comunes 0, Escudero 0.25, bosses 0.5; tope 0.9 |

- Umbral: `AfflictionConfig.threshold = 100`. Al llegar, la barra vuelve a 0 (el sobrante se descarta) y se dispara el efecto.
- Por qué E: con una cantidad fija por golpe, el Samurái (≈2.5 golpes/s de combo) llenaría casi tres veces más rápido que el Berserker (≈0.9 golpes/s). Con E, las tres clases disparan cada ≈2.5–3.4 s de combo contra un común con la carta en nivel 1. Las cartas de velocidad de ataque siguen acelerando la acumulación (sinergia buscada).
- Ejemplos (nivel 1, P = 0): Guerrero contra un Bruto, 20 por golpe → 5 golpes. Contra un boss (R = 0.5), 10 → 10 golpes (≈5 s). Envainar sobre un común: 35 × 2.0 = 70.
- `R = 1` queda reservado para la inmunidad (un buff futuro "no puede recibir Aflicción" la daría; §8).

### 4.2 Tipos del MVP

| Tipo | Id | Efecto al llenarse | Datos | Modo de stack | Para qué |
|---|---|---|---|---|---|
| **Veneno** | `poison` | `poison.tres`: `DAMAGE_OVER_TIME`, **daño fijo** | 0.3 × `DAMAGE` del jugador por tick (al aplicarlo), tick 1 s, 5 s, hasta 3 stacks | **acumulable** | Presión constante; con el Guerrero (15), 4.5/s durante 5 s por stack. En un boss se mantiene casi siempre activo, pero no se multiplica. |
| **Estallido** | `burst` | Daño en área centrado en el enemigo, `receive_hit` (con defensa, sin crítico) | 1.5 × `DAMAGE`, radio 2.5 m | — (sin estado) | Hordas: con el Guerrero, 22.5 en área. |
| **Escarcha** | `frost` | `frost.tres`: `SLOW` | 40 % más lento (movimiento, preparaciones y ataques), 3 s | **una sola aplicación** | Control: alarga las ventanas para esquivar y castigar. |
| **Corrosión** | `corrosion` | `corrosion.tres`: `ARMOR_REDUCTION` | 25 % de la defensa ignorada por stack, 5 s, hasta 4 stacks (100 %) | **mejorable** | Acorazados (Escudero) y niveles altos; sinergia con los golpes pesados. |

- El daño del Estallido y los ticks no emiten `enemy_hit`: no cargan Aflicciones (sin reacciones en cadena), no dan robo de vida ni hit lag.
- El valor de cada efecto vive en su `AfflictionData` (`effect_value`, `effect_scaling`), no en la carta: la carta sube la **acumulación** (B), y el efecto es el mismo venga de la fuente que venga.

**Íconos** (SVG de game-icons.net, CC BY 3.0, preparados como indica `status-icons.md` §2.3; el nombre exacto se confirma al bajarlos del repo `game-icons/icons`):

| Estado | Archivo | Origen propuesto | `icon_color` = color de su barra | `is_beneficial` |
|---|---|---|---|---|
| `poison` | `poison_bottle.svg` | lorc/poison-bottle | `Color(0.25, 0.6, 0.2)` | `false` |
| `frost` | `snowflake.svg` | lorc/snowflake-1 | `Color(0.45, 0.9, 0.95)` | `false` |
| `corrosion` | `acid_blob.svg` | lorc/acid-blob | `Color(0.55, 0.35, 0.8)` | `false` |

Estallido no deja estado: su barra es azul eléctrico `Color(0.3, 0.5, 1.0)` y no tiene ícono. El verde del Veneno es más oscuro que el `Color(0.3, 0.8, 0.35)` del marco de buff de `status-icons.md`, para que no se lea como buff.

### 4.3 Qué se ve y cómo se juega

1. Tras una oleada sale una carta violeta: **"Aflicción: Veneno"**: "Tus ataques básicos acumulan Veneno. Al llenarse: Veneno, 30 % de tu daño por segundo durante 5 s (acumulable ×3)".
2. Desde entonces, cada enemigo golpeado muestra una barra verde fina debajo de su barra de vida. Cada básico la carga.
3. Al llenarse, la barra destella (`flash_duration`), vuelve a 0 y se aplica el estado. Su ícono aparece en la fila de estados del enemigo (`EnemyStatusOverlay`), con su reloj y sus stacks, como cualquier estado.
4. Con varios tipos hay varias barras apiladas, en el orden en que se consiguieron. Cada golpe carga solo las de su fuente.
5. Si una barra no recibe carga en 5 s, baja sola hasta 0.

### 4.4 Estructura de nodos

```
Player (player.tscn)
└── Afflictions (AfflictionLoadout)          ← nuevo: cartas tomadas, tipos y niveles; resuelve la carga y los disparos

Enemy (enemy.tscn)
├── AfflictionComponent                       ← nuevo: una carga por slot (tipo del jugador)
└── HealthBar (EnemyHealthBar)
    ├── Background / Trail / Fill / LevelLabel   (sin cambios)
    └── AfflictionBars (AfflictionBarRow)     ← nuevo: max_types filas Background + Fill (QuadMesh), creadas en _ready

Hud
├── EnemyStatusOverlay                        (status-icons.md, sin cambios)
└── BossBarStack › BossHealthBar
    ├── DebuffIcons (StatusIconRow)           (status-icons.md, sin cambios)
    └── AfflictionBars (VBoxContainer)        ← nuevo: max_types filas ColorRect, creadas en setup()
```

- Todas las filas se crean una vez (`max_types`), nunca en runtime (Principio V).
- El slot *i* de cada enemigo es el tipo *i* del `AfflictionLoadout` (orden de adquisición). El enemigo lo lee por `target.afflictions`.
- Las barras van en 3D y no en el overlay porque pertenecen a la barra de vida (ancho, sacudida, visibilidad) y solo tienen sentido después del primer golpe. No se cruzan con la fila de íconos, que va arriba (`row_offset_px`).

### 4.5 Resources y datos

**`AfflictionData`** (`resources/affliction_data.gd`; `data/afflictions/<tipo>.tres`): qué es un tipo.

| Campo | Tipo | Qué es |
|---|---|---|
| `id` | `StringName` | Identidad estructural. |
| `title` | `String` | "Veneno". |
| `bar_material` | `StandardMaterial3D` | Relleno de su barra 3D; el HUD del boss usa su `albedo_color`. Igual al `icon_color` de su estado (AC855). |
| `debuff` | `DebuffData` | Estado al llenarse (nulo en Estallido). |
| `effect_value` | `float` | Potencia del estado o multiplicador del Estallido. |
| `effect_scaling` | `enum EffectScaling { FIXED, PLAYER_DAMAGE }` | `PLAYER_DAMAGE`: la potencia es `effect_value × DAMAGE` al disparar (Veneno, Estallido). |
| `burst_radius` | `float` | Radio del daño en área (0 = sin estallido). |

Cálculos puros: `has_burst()`, `potency_for(player_damage: float) -> float`.

**`AfflictionUpgradeData extends UpgradeCard`** (`resources/affliction_upgrade_data.gd`; `data/afflictions/cards/<tipo>_<fuente>.tres`): la carta.

| Campo | Tipo | Qué es |
|---|---|---|
| `affliction` | `AfflictionData` | Tipo que carga. |
| `source` | `enum Source { BASIC_ATTACK, ABILITY }` | Qué golpes la cargan. Una fuente por carta. |
| `max_level` | `int` | 3. |
| `level_values` | `Array[float]` | B por nivel. |
| `level_descriptions` | `Array[String]` | Texto por nivel. |
| `value_format` | `ValueFormat` | Valor en el panel del sandbox. |

`is_same_kind()`: mismo `affliction.id` **y** misma `source`. MVP: 8 cartas (4 tipos × 2 fuentes). Justificación de `max_level = 3` (Principio III): subir de nivel acelera la acumulación, un número con sentido en cualquier tipo.

**`AfflictionCatalog`** (`data/afflictions/affliction_catalog.tres`): `cards: Array[AfflictionUpgradeData]` (las 8).

**`AfflictionConfig`** (`data/combat/affliction_config.tres`):

| Campo | Valor | Qué es |
|---|---|---|
| `max_types` | 3 | Tope de tipos por run; filas creadas por barra. |
| `threshold` | 100 | Puntos para disparar. |
| `max_resistance` | 0.9 | Tope de R en los datos de enemigos (1 queda para la inmunidad futura). |
| `decay_delay` | 5.0 | Segundos sin carga antes de vaciarse (por barra). |
| `decay_per_second` | 15 | Puntos que pierde por segundo al vaciarse. |
| `flash_duration` | 0.2 | Segundos que la barra se ve llena y clara al disparar. |
| `bar_height` / `bar_gap` | 0.04 / 0.02 | Filas 3D (m). |
| `hud_bar_height_px` / `hud_bar_gap_px` | 6 / 3 | Filas del boss en el HUD. |
| `background_material` | `health_bar_background_material.tres` | Fondo de cada fila. |
| `flash_material` | `materials/afflictions/affliction_flash_material.tres` | Relleno durante el destello. |
| `pause_title_format` / `pause_entry_format` | `"Aflicciones %d/%d"` / `"%s (%s) nv. %d"` | Sección de la pausa: "Veneno (básicos) nv. 2". |
| `source_names` | `["básicos", "habilidad"]` | Texto de cada fuente. |

**`DebuffData`** (defaults = comportamiento de hoy, así los `.tres` existentes no cambian):
- `Effect.SLOW` al final del enum (= 4). `potency` = fracción de velocidad perdida.
- `stack_mode: StackMode { INTENSITY, QUEUE }` (default `INTENSITY`). `INTENSITY` = mejorable (hoy); `QUEUE` = acumulable.
- `damage_scaling: DamageScaling { MAX_HEALTH, FLAT }` (default `MAX_HEALTH`). `FLAT`: cada tick quita `potency` puntos (sin defensa, como hoy).

**Estados nuevos:** `data/debuffs/poison.tres` (`DAMAGE_OVER_TIME`, `FLAT`, `QUEUE`, 5 s, tick 1 s, `max_stacks = 3`), `frost.tres` (`SLOW`, 3 s, sin stacks), `corrosion.tres` (`ARMOR_REDUCTION`, `INTENSITY`, 5 s, `max_stacks = 4`). Los tres con `icon`, `icon_color` e `is_beneficial = false` (§4.2).

**`AfflictionData` del MVP:** `poison` (0.3, `PLAYER_DAMAGE`), `burst` (1.5, `PLAYER_DAMAGE`, radio 2.5), `frost` (0.4, `FIXED`), `corrosion` (0.25, `FIXED`).

**Escalas de fuente** (campos nuevos, escritos explícitamente en cada `.tres`, porque un 0 omitido anularía la carga; AC857): `AttackComboConfig.affliction_scale`, `AirSlashConfig.affliction_scale`, `AbilityData.affliction_scale` (valores en §4.1).

**`EnemyStats.affliction_resistance`**: 0 en los comunes (se omite), 0.25 en el Escudero, 0.5 en Verdugo, Titán y Colmena. `write_scaled()` la copia sin crecer.

**Stat y carta:** `PlayerStats.Stat.AFFLICTION_BUILDUP` (base 0 en las tres clases, fila "Acumulación de Aflicción" en `stat_display_table.tres`, formato `+%d %%`). Carta `data/upgrades/affliction_buildup.tres` (`amount = 0.1`, `max_stacks = 5`) en `upgrade_catalog.tres` (pasa a 11 cartas). Es una carta de stat común (no violeta; confirmado).

**Materiales nuevos** (`materials/afflictions/`, unshaded, opacos): `poison_material.tres`, `burst_material.tres`, `frost_material.tres`, `corrosion_material.tres`, `affliction_flash_material.tres` (`Color(0.85, 1.0, 0.9)`).

**Íconos nuevos:** los tres SVG de §4.2 en `assets/icons/status/`, con sus `.import` y una fila cada uno en su `SOURCE.md`.

**`UpgradePickerConfig`:** `affliction_card_color` `Color(0.45, 0.25, 0.7)`, `affliction_card_hover_color`, `affliction_card_font_color`.

### 4.6 Interfaz pública

```gdscript
class_name AfflictionLoadout extends Node   # en el jugador; estado mutable de la run
signal changed                                   # tipo, fuente o nivel nuevo
signal triggered(enemy: Enemy, type: AfflictionData)
signal burst_hit(enemy: Enemy, applied: float)   # números de daño

@export var config: AfflictionConfig
@export var stats: StatsComponent
@export var registry: EnemyRegistry
@export var attack: AttackComponent
@export var air_slash: AirSlashComponent
@export var basic_ability: AbilityComponent

func apply_card(card: AfflictionUpgradeData) -> void
func remove_card(card: AfflictionUpgradeData) -> void    # sandbox: baja un nivel
func count_card(card: AfflictionUpgradeData) -> int      # nivel (0 = no la tiene)
func is_card_maxed(card: AfflictionUpgradeData) -> bool  # en max_level, o su tipo es nuevo y ya hay max_types
func get_type_count() -> int
func get_type(slot: int) -> AfflictionData
func clear() -> void
static func buildup(base: float, source_scale: float, player_bonus: float, resistance: float) -> float  # puro
```

`Player` enruta `apply_upgrade`, `remove_upgrade`, `count_upgrade`, `max_count` e `is_maxed` para `AfflictionUpgradeData`, y `reset_upgrades()` llama `afflictions.clear()`.

```gdscript
class_name AfflictionComponent extends Node  # en el enemigo
signal changed
@export var config: AfflictionConfig
func setup(stats: EnemyStats) -> void                 # al activar: cargas en 0
func add_buildup(slot: int, amount: float) -> bool    # true si llegó al umbral (y volvió a 0)
func get_ratio(slot: int) -> float                    # carga / threshold
func get_resistance() -> float                        # acotada a max_resistance
func is_flashing(slot: int) -> bool
func advance(delta: float) -> void                    # vaciado y destello
func clear() -> void
```

- `DebuffComponent.get_speed_scale() -> float`: `1 − potencia` del `SLOW` más fuerte (1 sin `SLOW`).
- `Enemy`: `@onready var afflictions: AfflictionComponent`; `activate()` llama `afflictions.setup(_scaled)` y `deactivate()` llama `afflictions.clear()`.

### 4.7 Lógica interna

**Carga.** `AfflictionLoadout` se conecta en `_ready` a `attack.enemy_hit` y `air_slash.enemy_hit` (fuente básica, E = escala del combo de la clase o del Tajo aéreo) y a `basic_ability.enemy_hit` (fuente habilidad, E = `affliction_scale` de la habilidad equipada). Por cada golpe con `applied > 0` recorre sus cartas sin crear arrays; por cada carta de esa fuente: `enemy.afflictions.add_buildup(slot_del_tipo, buildup(B, E, P, R))`. Si un tipo tiene cartas de las dos fuentes, cada fuente carga con la suya. Si `add_buildup` devuelve `true`, resuelve el disparo.

**Disparo.**
- Con estado: `enemy.debuffs.apply(type.debuff, type.potency_for(DAMAGE))`.
- Con Estallido: `damage = potency_for(DAMAGE)`; para cada enemigo activo del `registry` a ≤ `burst_radius` (+ su padding) del que disparó, incluido él: `applied = e.health.receive_hit(damage)` y `burst_hit.emit(e, applied)`. `DamageNumberPool` se conecta a `burst_hit`.
- Emite `triggered(enemy, type)`.

**Barra del enemigo.** `add_buildup` suma, reinicia la espera de vaciado **de esa barra** y, si llega a `threshold`: carga a 0, destello y devuelve `true`. `advance()` descuenta los destellos y, en las barras cuya espera pasó `decay_delay`, resta `decay_per_second × delta` hasta 0. Solo procesa mientras alguna barra tiene carga o destello.

**Modos de stack (`DebuffComponent.apply`).**
- `INTENSITY` (mejorable, hoy): stacks + 1 hasta el tope, duración completa, potencia máxima. La fuerza se multiplica por los stacks en `ARMOR_REDUCTION` (hoy), en `DAMAGE_OVER_TIME` y en `SLOW` (nuevo; los `.tres` existentes no cambian: `bleed` no apila y ningún `SLOW` existía).
- `QUEUE` (acumulable): si hay lugar, stacks + 1 y la instancia en curso sigue su tiempo; al vencer una instancia con stacks > 1, stacks − 1 y empieza otra completa (en un DoT, sus ticks). Si ya está en el tope, reinicia la instancia en curso. La fuerza **no** se multiplica por los stacks. La potencia es la máxima aplicada.
- Con `max_stacks ≤ 1`, los dos modos solo reinician la duración.
- El ícono (`status-icons.md`) muestra los stacks (`get_stack_cap() > 1`) y el reloj de la instancia en curso (`get_remaining_ratio`), sin cambios en su código.

**Daño fijo.** Con `damage_scaling = FLAT`, `_tick` quita `potency` (× stacks si es `INTENSITY`) en vez de `potency × max_health`.

**Lentitud.** `Enemy._update_behaviour(delta)` pasa `delta × debuffs.get_speed_scale()` al behavior (preparaciones, ataques e intervalos se estiran) y `move_towards`, `walk` y `move_with_velocity` multiplican la velocidad horizontal por la misma escala. El empuje, la gravedad, la aparición y el hit lag no se escalan.

**Vistas.** `AfflictionBarRow` (3D) crea `max_types` filas debajo de la barra de vida en `_ready`, muestra tantas como tipos tenga el loadout (`loadout.changed`), con `type.bar_material` o `flash_material` mientras destella, y un relleno anclado a la izquierda de ancho `get_ratio()`. Se redibuja con `afflictions.changed`. `BossHealthBar` hace lo mismo con `ColorRect` (`albedo_color`) debajo de `BarFrame`, sin tocar su `StatusIconRow`.

**Oferta.** `WaveManager.affliction_catalog` se suma al pool en `UpgradeOffer.build_pool`. `Player.is_maxed()` usa `afflictions.is_card_maxed()`. Las violetas se ofrecen en todas las oleadas (no son doradas) y se pueden banear. `UpgradePicker` las pinta con `affliction_card_color` y muestra la descripción del nivel siguiente.

**Pausa.** Fila del stat "Acumulación de Aflicción" en su tabla y sección "Aflicciones 2/3" con una línea por carta ("Veneno (básicos) nv. 2").

## 5. Criterios de aceptación (AC851–AC896)

**Datos**
- **AC851** Existen `AfflictionData`, `AfflictionUpgradeData`, `AfflictionCatalog` y `AfflictionConfig` con los campos de §4.5; `affliction_config.tres` tiene `max_types = 3`, `threshold = 100`, `max_resistance = 0.9`, `decay_delay = 5`, `decay_per_second = 15`.
- **AC852** `affliction_catalog.tres` tiene 8 cartas (4 tipos × 2 fuentes), todas con `max_level = 3` y 3 valores y descripciones; B = 20/30/40 (básicos) y 35/50/65 (habilidad).
- **AC853** Los 4 `AfflictionData` tienen los valores de §4.2 (`effect_value`, `effect_scaling`, `burst_radius`).
- **AC854** `poison.tres`, `frost.tres` y `corrosion.tres` tienen efecto, `stack_mode`, `damage_scaling`, duración, tick y `max_stacks` de §4.5, `is_beneficial = false` y un `icon` de `assets/icons/status/` (cumplen AC905).
- **AC855** El `icon_color` de cada estado es el `albedo_color` del `bar_material` de su tipo.
- **AC856** `bleed`, `weaken`, `rage` y `shield` no cambian: `stack_mode = INTENSITY`, `damage_scaling = MAX_HEALTH`.
- **AC857** `affliction_scale` > 0 en los tres combos, en `air_slash_config.tres` y en las cuatro habilidades, con los valores de §4.1.
- **AC858** `affliction_resistance`: 0 en Bruto, Embestidor, Saltador y Hostigador; 0.25 en el Escudero; 0.5 en los tres bosses.
- **AC859** `AFFLICTION_BUILDUP` vale 0 en las tres clases; `affliction_buildup.tres` (+0.1, `max_stacks = 5`) está en `upgrade_catalog.tres` (11 cartas).
- **AC860** Ningún script nuevo tiene literales de diseño (review, Principio III).

**Carga**
- **AC861** `buildup(20, 1.0, 0.0, 0.0) = 20`; `buildup(20, 2.3, 0.2, 0.5) = 27.6`.
- **AC862** Guerrero con "Veneno (básicos)" nivel 1 contra un Bruto: cada golpe del combo con daño carga 20; el quinto dispara `poison` y la barra vuelve a 0.
- **AC863** Con la barra en 90, un golpe de 20 dispara y la barra queda en 0 (sin sobrante).
- **AC864** Una carta de básicos no carga con la habilidad (E), y una de habilidad no carga con el combo ni con el Tajo aéreo. La ultimate (R) no carga ninguna.
- **AC865** Con "Veneno (básicos)" y "Veneno (habilidad)", el combo carga 20 y la Estocada 35 en la misma barra; hay un solo tipo en el loadout.
- **AC866** Con "Veneno (básicos)", "Estallido (básicos)" y "Escarcha (habilidad)", un básico carga las dos primeras barras y no la tercera.
- **AC867** Un golpe que aplica 0 (enemigo invulnerable) no carga. Los ticks y el daño del Estallido no cargan.
- **AC868** Contra un boss (R = 0.5), un básico del Guerrero carga 10. Con `AFFLICTION_BUILDUP = 0.3`, 13.
- **AC869** Vaciado: una barra en 60 sin carga durante 5 s sigue en 60; a los 6 s está en 45; a los 9 s, en 0. Una carga a los 7 s detiene la pérdida y la espera vuelve a 5 s. Las otras barras del enemigo no se afectan.
- **AC870** Al reactivar un enemigo del pool, sus barras están en 0.

**Efectos y stacks**
- **AC871** Veneno con `DAMAGE = 15`: aplica `poison` con potencia 4.5; cada tick quita 4.5 (daño fijo, sin defensa).
- **AC872** Veneno acumulable: tres disparos seguidos dejan 3 stacks; el daño por tick sigue en 4.5; el veneno dura 15 s en total (5 + 5 + 5) y los stacks bajan de a uno al vencer cada instancia. Un cuarto disparo con 3 stacks reinicia la instancia en curso.
- **AC873** Corrosión mejorable: un disparo ignora el 25 % de la defensa; el segundo, antes de vencer, el 50 % y reinicia los 5 s; con 4 stacks, el 100 %; un quinto solo reinicia.
- **AC874** Escarcha: `get_speed_scale() = 0.6`; `walk` va al 60 %; una preparación de 1 s dura ≈ 1.67 s; un segundo disparo reinicia los 3 s sin sumar lentitud. Al vencer, la escala vuelve a 1.
- **AC875** Estallido con `DAMAGE = 15`: `receive_hit(22.5)` al enemigo que disparó y a los que están a ≤ 2.5 m (+ padding), no a los de más lejos; `burst_hit` por cada uno; sin robo de vida, hit lag ni `enemy_hit`.
- **AC876** Sangrado de Lacerante se comporta igual que antes (daño en % de vida, sin stacks).

**Cartas y tope**
- **AC877** Tomar "Veneno (básicos)" agrega el tipo en el slot 0 con nivel 1; tomarla de nuevo sube a nivel 2 (B = 30) sin ocupar otro slot.
- **AC878** Con 3 tipos, las cartas de un 4.º tipo cuentan como topadas y no se ofrecen; las de los tipos que se tienen (cualquier fuente) sí, hasta nivel 3.
- **AC879** Una carta en nivel 3 sale del pool.
- **AC880** Las cartas violetas se ofrecen en oleadas normales y tras un boss, se pueden banear, y la de "Acumulación de Aflicción" se ofrece sin tener ninguna Aflicción.
- **AC881** Con todas las cartas (incluidas las violetas) topadas o baneadas, empieza Rage como antes.
- **AC882** `Player.reset_upgrades()` quita las Aflicciones; `remove_upgrade` baja un nivel o quita la carta, y el tipo desaparece si no le queda ninguna carta.

**Vistas**
- **AC883** Sin Aflicciones, la barra de vida no muestra filas. Con una, muestra una fila vacía debajo, con el `bar_material` del tipo.
- **AC884** Con tres tipos hay tres filas apiladas en orden de adquisición, separadas por `bar_gap`.
- **AC885** El relleno cubre `get_ratio()` del ancho, anclado a la izquierda.
- **AC886** Durante `flash_duration` tras un disparo, la fila usa `flash_material` y se ve llena; después vuelve a su material y a 0.
- **AC887** Las filas se muestran y ocultan con la barra de vida; en bosses (barra suprimida) no se ven en 3D.
- **AC888** La barra del boss en el HUD muestra las filas con el color del tipo y su relleno sigue la carga; su `StatusIconRow` no cambia (8 casillas).
- **AC889** Al disparar Veneno sobre un enemigo común, su fila de `EnemyStatusOverlay` muestra el ícono de `poison` (marco de debuff, reloj en 1, stacks "1") en el siguiente `update_rows()`; con 3 stacks muestra "3".
- **AC890** La pausa muestra "Acumulación de Aflicción +20 %" con dos cartas del stat, y "Aflicciones 2/3" con "Veneno (básicos) nv. 2" y "Escarcha (habilidad) nv. 1".
- **AC891** Las cartas de Aflicción usan `affliction_card_color` (violeta) sin importar el tipo, y muestran la descripción del nivel siguiente.

**`status-icons.md` y coordinación**
- **AC892** `assets/icons/status/SOURCE.md` lista `poison_bottle.svg`, `snowflake.svg` y `acid_blob.svg` con autor, URL y CC BY 3.0 (AC908 sigue en verde), y ninguno tiene el path de fondo.
- **AC893** Esta spec no modifica `StatusIconView`, `StatusIconRow`, `EnemyStatusOverlay` ni sus configs (review del diff).
- **AC894** `DebuffData.Effect.SLOW` vale 4 y es el último valor agregado por esta spec (§8).

**Integración**
- **AC895** En `arena.tscn`, con el Guerrero y "Veneno (básicos)", un Bruto golpeado 5 veces queda envenenado y su barra verde vuelve a 0.
- **AC896** Con un Samurái y un Berserker con la misma carta, los golpes hasta el primer disparo contra un Bruto son 7 y 3 (escala del combo).

## 6. Tests

- `test/resources/affliction_data_test.gd`: AC851–AC859.
- `test/components/affliction_component_test.gd`: AC861, AC863, AC869–AC870, AC886.
- `test/components/affliction_loadout_test.gd`: AC862, AC864–AC868, AC871, AC875, AC877–AC879, AC882, AC896 (con `combo_driver.gd`).
- `test/components/status_effects_test.gd` (ampliado): AC872–AC874, AC876.
- `test/systems/upgrade_offer_test.gd` y `wave_manager_test.gd` (ampliados): AC878, AC880–AC881.
- `test/components/affliction_bar_row_test.gd`, `test/ui/boss_health_bar_test.gd`, `test/ui/pause_menu_test.gd`, `test/ui/upgrade_picker_test.gd`, `test/ui/enemy_status_overlay_test.gd`: AC883–AC891.
- El test de assets de `status-icons.md` (AC905/AC908): AC892.
- `test/levels/arena_test.gd`: AC895.
- AC860, AC893, AC894: review.
- Tests viejos que cambian (se adaptan sin cambiar lo que verifican y se anotan en §11): cantidad de cartas del catálogo (10 → 11), filas de la tabla de stats de la pausa, tamaño del pool en `upgrade_offer_test`/`wave_manager_test`.

## 7. Riesgos

1. **Balance:** los valores de B, E, P y R son un punto de partida; se ajustan en datos tras el smoke test. El más sensible es el Giro (E = 0.4), que golpea 5 veces por enemigo.
2. **Veneno en bosses:** al escalar con `DAMAGE` y no con la vida, con uptime casi total suma ≈ 4.5/s al Guerrero sin cartas de daño (≈ +40 %). Si domina, se baja `effect_value`.
3. **Muchos íconos:** con 3 Aflicciones de estado más Debilitar, Sangrado y Rage, un enemigo puede pasar de 5 estados; el "+" de `status-icons.md` (AC918) lo resuelve.
4. **Legibilidad:** tres filas finas por enemigo; `bar_height` es dato.
5. **Orden:** esta spec se implementa después de `status-icons.md`.

## 8. Coordinación y futuro

- **Re-work del Guerrero (AC801–AC850):** crea el estado aturdido. Si agrega `STUN` a `DebuffData.Effect`, va **después** de `SLOW` (= 5). Si se mergea antes, al resolver el conflicto se revisan los `effect =` de los `.tres` nuevos (Godot guarda el entero). Sus golpes nuevos que pasen por `report_hit()` ya cargan Aflicciones de habilidad.
- **Aflicción que aturde (futuro):** un `AfflictionData` con `debuff = stun.tres` del re-work, más sus cartas. Sin código nuevo en esta mecánica; `Enemy._update_behaviour` (escala de `SLOW`) es el punto de enganche para un aturdimiento.
- **Inmunidad (futuro):** un buff enemigo "no puede recibir Aflicción" haría que `AfflictionComponent.get_resistance()` devuelva 1 mientras esté activo.
- **Ultimate (futuro):** `Source.ULTIMATE` y cartas propias cuando exista la R.
- **Sangrado como Aflicción rara (futuro):** requiere un sistema de rareza; fuera de alcance.
- **Constitución:** `status-icons.md` toma la 4.16.0; esta, la 4.17.0. Si el re-work enmienda antes, el número se corre al cerrar.

## 9. Enmienda de la constitución (MINOR 4.16.0 → 4.17.0)

**Principio III**, nueva viñeta tras "Estados de entidades":

> - **Aflicciones** (desde 4.17.0): los golpes del jugador pueden cargar una barra por tipo de Aflicción en el enemigo; al llenarse, se vacía y dispara un efecto (un estado o un daño en área). La carga por golpe es fija por carta y fuente (básicos o habilidad), escalada por la fuente, por el stat mejorable "Acumulación de Aflicción" del jugador y por la resistencia general del enemigo; umbral, vaciado, tope de tipos por run y resistencias son datos (`AfflictionConfig`, `EnemyStats`). Cada tipo es un Resource (`AfflictionData`) y cada carta un `AfflictionUpgradeData` con niveles en el `.tres`. Agregar un tipo es un `.tres` nuevo, no código nuevo.

**Principio III**, viñeta "Estados de entidades": el efecto incluye **lentitud** (`SLOW`); los stacks pueden ser **mejorables** (una instancia que se fortalece) o **acumulables** (instancias que se encadenan sin sumar fuerza); el daño por tick puede ser un % de la vida o un valor fijo que calcula quien lo aplica.

**Principio II**, colores no reservados (registro): verde veneno `Color(0.25, 0.6, 0.2)`, azul eléctrico `Color(0.3, 0.5, 1.0)`, cian escarcha `Color(0.45, 0.9, 0.95)` y el violeta de Debilitar `Color(0.55, 0.35, 0.8)` para Corrosión, en las barras de Aflicción (`QuadMesh` unshaded bajo la barra de vida, `ColorRect` en la del boss) y como `icon_color` de sus estados; su destello `Color(0.85, 1.0, 0.9)` (no es el blanco reservado); y violeta `Color(0.45, 0.25, 0.7)` para el tier de cartas de Aflicción.

**Historial:** `4.17.0 (fecha de cierre): Principio III: Aflicciones (carga por golpe, cartas por fuente con niveles, stat mejorable, resistencia general, tope por run), el estado SLOW, stacks mejorables y acumulables y daño por tick fijo. Principio II: colores de las barras y del tier violeta de cartas (ver affliction.md).`

## 10. Plan

Cada paso deja el proyecto abriendo y la suite en verde.

0. **Requisito:** `status-icons.md` implementada.
1. **Estados:** `SLOW`, `stack_mode`, `damage_scaling` y `get_speed_scale()` en `DebuffData`/`DebuffComponent`; escala en `Enemy`. Tests AC856, AC872–AC874, AC876, AC894.
2. **Datos:** Resources nuevos, materiales, los 4 tipos y las 8 cartas, `poison`/`frost`/`corrosion.tres`, los 3 SVG (bajados, sin fondo, `.import` desde la copia del scratchpad, filas en `SOURCE.md`), `affliction_scale` en combos, Tajo aéreo y habilidades, `affliction_resistance` en enemigos, stat y carta nuevos. Tests AC851–AC859, AC892.
3. **`AfflictionComponent`** en `enemy.tscn` (`setup`/`clear` en `activate`/`deactivate`). Tests AC861, AC863, AC869–AC870.
4. **`AfflictionLoadout`** en `player.tscn`, disparos, Estallido y `burst_hit` en `DamageNumberPool`; enrutado en `Player`. Tests AC862, AC864–AC868, AC871, AC875, AC877, AC882, AC896.
5. **Oferta y cartas:** catálogo en `WaveManager`/`UpgradeOffer`, tope, color violeta en `UpgradePicker`. Tests AC878–AC881, AC891.
6. **Vistas:** `AfflictionBarRow`, filas en `BossHealthBar`, pausa. Tests AC883–AC890.
7. **Cierre:** enmienda 4.17.0, `CLAUDE.md` ("Dónde se ajusta cada cosa": Aflicciones; catálogo de 11 cartas; próximo AC libre), suite completa, import, smoke test (AC895) y captura con tres tipos, checklist §12 y estado **Implementada**.

## 11. Notas de implementación

(Se completa al implementar: tests viejos adaptados, desvíos aprobados.)

## 12. Checklist de review (constitución)

- [ ] **Identidad (I):** progresión (cartas violetas, stat, tope de 3) y combate (barras legibles, efectos que cambian la pelea).
- [ ] **Arte (II):** filas `QuadMesh`/`ColorRect`, materiales `.tres` compartidos, colores registrados; íconos SVG en `assets/icons/status/` con crédito, según 4.16.0.
- [ ] **Datos (III):** todo número en `AfflictionConfig`, `AfflictionData`, cartas, escalas y `EnemyStats`; stat mejorable con carta; cartas con `max_level` y valores por nivel; ningún Resource mutado.
- [ ] **GDScript (IV):** tipado estricto, callbacks delgados.
- [ ] **Performance (V):** filas creadas una vez; sin allocations por golpe ni por frame; el Estallido recorre el registry sin crear arrays; `AfflictionComponent` no procesa sin carga.
- [ ] **Input (VI):** sin acciones nuevas; la pausa sigue navegable con mando.
- [ ] **Combate (VII):** el Estallido no causa hit lag; nada toca `Engine.time_scale`.
- [ ] **Calidad:** proyecto sin errores ni warnings nuevos, ACs y suite completa en verde.
