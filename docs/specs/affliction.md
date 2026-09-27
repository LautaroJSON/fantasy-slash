# Feature: Aflicción (barra de acumulación en los enemigos)

- **Estado:** Propuesta (2026-09-27). Pendiente de aprobación y de las decisiones de §3. ACs reservados: **AC851–AC900** (se usan AC851–AC888).
- **Constitución:** `docs/constitution.md` v4.15.0 → **enmienda MINOR a 4.16.0** (Principios II y III, ver §9). Si el re-work del Guerrero enmienda antes, el número se corre al cerrar.
- **Pilar (Principio I):** **progresión** y **combate.** Progresión: cada tipo de Aflicción es una carta que define una build (Veneno para bosses, Estallido para hordas, Escarcha para controlar) y el tope de tipos obliga a elegir. Combate: la barra debajo de la vida muestra cuánto falta para disparar el efecto, así que el jugador decide si terminar la barra de un enemigo o cambiar de objetivo; con Escarcha, el golpe que llena la barra desacelera las preparaciones enemigas.
- **Dependencias:** `enemy-rage.md` (lista de estados, `STAT_BOOST`), `spin-golden-upgrades.md` (Debilitar, `ARMOR_REDUCTION`), `unique-ability-upgrades.md` (Lacerante, `bleed`), `upgrade-caps.md`, `debuff-stacks-display.md`, `cooldown-timers.md`, `boss-hud-bar.md`, `stats-rework.md` (catálogo de cartas), `enemy-level-pace.md`. **En paralelo:** `warrior-abilities-rework.md` (AC801–AC850, otra sesión), ver §8.

## 1. Nombre

| Nombre | En una carta | En la pausa | Comentario |
|---|---|---|---|
| **Aflicción** (recomendado) | "Tus golpes acumulan Aflicción: Veneno" | "Aflicciones 1/2" | Se entiende sin explicación (algo malo que se le acumula al enemigo), sirve de paraguas para daño y control, y no choca con nada existente. |
| Estigma | "Tus golpes marcan Estigma: Veneno" | "Estigmas 1/2" | Evocador, pero suena a marca única y no a una barra que se llena. |
| Saturación | "Tus golpes saturan: Veneno" | "Saturación 1/2" | Describe bien la barra, pero es técnico y no suena a efecto. |
| Quiebre | "Quiebre: Veneno" | "Quiebres 1/2" | Se confunde con Debilitar / "Quiebre de armadura" (`armor_break`) y con un aturdimiento. |

**Recomendación: Aflicción.** En código: `affliction` (`AfflictionData`, `AfflictionComponent`…).

## 2. Relevamiento: qué existe y qué se reutiliza

| Pieza | Qué hay hoy | Uso en esta spec |
|---|---|---|
| `DebuffData` (`resources/debuff_data.gd`) | `id`, `effect` (`DAMAGE_OVER_TIME`, `ARMOR_REDUCTION`, `STAT_BOOST`, `STATUS`), `duration`, `tick_interval`, `max_stacks`, `permanent`, `icon_material`. La fuerza (`potency`) la pasa quien lo aplica. | **Se reutiliza tal cual** para el efecto de cada tipo. Se agrega **un** valor al enum: `SLOW` (ver §4.6). El aturdimiento del re-work sería otro valor (`STUN`) y un `.tres`. |
| `DebuffComponent` | Lista de estados por entidad, `apply(data, potency)` refresca y suma stacks, ticks con `ticked`, `get_defense_reduction()`. | **Se reutiliza**: el disparo de una Aflicción es `enemy.debuffs.apply(type.debuff, potency)`. Se agrega `get_speed_scale()` para `SLOW`. |
| `data/debuffs/` | `bleed` (DoT, 5 s, tick 1 s), `weaken` (armadura, 4 s, 3 stacks), `rage`, `shield`. | No se tocan. Se agregan `poison`, `frost` y `corrosion` (ids propios para no compartir stacks con Lacerante ni con Debilitar). |
| `DebuffIconRow` + `debuff_icon_config` | Fila de íconos arriba de la barra, con segundos y stacks. | **Se reutiliza sin cambios:** los estados de las Aflicciones aparecen ahí con su ícono (mismo material que su barra). |
| `EnemyHealthBar` + `health_bar_config` | Barra 3D (`QuadMesh` fondo/estela/relleno), oculta hasta el primer golpe, mira a la cámara, sacudida en golpes fuertes; los bosses la suprimen. | Las barras de Aflicción son un nodo hijo (`AfflictionBars`), como `DebuffIcons`: heredan visibilidad, orientación, escala y sacudida. |
| `BossHealthBar` + `boss_bar_config` | Barra del HUD para bosses (`ColorRect`), íconos de estado con reloj. | Se agregan las barras de Aflicción debajo de `BarFrame` (`ColorRect`, color del material de cada tipo, como los íconos). |
| `AttackComponent.enemy_hit` | Señal por enemigo golpeado por el combo (`_hit_enemy`), con el daño aplicado. | Fuente "ataque básico". |
| `AirSlashComponent.enemy_hit` | Tajo aéreo del Berserker. | Fuente "ataque básico" (es el ataque del aire). |
| `AbilityComponent.report_hit()` → `enemy_hit` | Lo llaman los behaviors (Estocada, Giro, Envainar, Golpe veloz) por cada enemigo dañado. | Fuente "habilidad", sin tocar los behaviors. |
| `EnemyHitFeedback` / `DamageNumberPool` | Se conectan a las 4 señales de arriba. `registry.enemy_debuff_ticked` para ticks. | Mismo patrón de conexión. El daño del Estallido se muestra con una señal nueva (`burst_hit`). |
| `UpgradeCard` / `UpgradeData` / `AbilityUniqueUpgradeData` | Cartas de stats (`max_stacks`) y únicas de habilidad (`max_level`, `level_values`, `level_descriptions`, `debuff`). | La carta de Aflicción copia el modelo de la única: niveles explícitos en arrays. |
| `UpgradeOffer`, `WaveManager.get_available_pool()`, `Player.apply_upgrade/is_maxed/count_upgrade` | Pool = catálogo + mejoras de habilidades; se excluyen baneadas y topadas; las doradas solo tras un boss. Sin cartas disponibles empieza Rage. | Se suma `affliction_catalog.tres` al pool. Una carta de un tipo nuevo cuenta como "topada" cuando ya se alcanzó el tope de tipos. Se banean como cualquier carta. |
| `EnemyStats` / `write_scaled` / Rage | Vida escalada por nivel; Rage sube stats sobre ese valor. | El umbral de la barra es una fracción de la vida máxima escalada, así que **nivel y Rage lo suben solos**. |

## 3. Decisiones de diseño (propuestas; confirmar o corregir)

Cada una lleva mi recomendación, que es lo que describe el resto de la spec.

1. **Cuánto carga cada golpe.** Propuesta: **por daño aplicado.** `carga = daño aplicado × factor de la fuente × buildup_multiplier del tipo`. Así las tres clases llenan a ritmo parecido (su DPS es similar: Guerrero ≈ 10.9, Berserker ≈ 10.5, Samurái ≈ 12.4 daño/s en combo a velocidad 1), el remate llena más que un golpe suelto, las habilidades cargan según lo que pegan sin agregar un campo a cada `AbilityData`, y las cartas de daño también aceleran la Aflicción. Factores por fuente en datos: básico 1.0, habilidad 1.0 (ajustables). Alternativa descartada: carga fija por golpe (el Samurái, que pega más veces, llenaría el doble que el Berserker).
2. **Umbral.** Propuesta: fracción de la vida máxima escalada del enemigo (`EnemyStats.affliction_threshold_ratio`): comunes 0.5 (el Bruto de 40 de vida se llena con 20 de daño, ≈ un combo del Guerrero), Escudero 0.4 (su defensa ya reduce el daño aplicado), bosses 0.12 (el Verdugo, 1380 de vida, se llena cada ≈ 15 s).
3. **¿Se vacía sola?** Propuesta: **sí**, tras 4 s sin carga baja un 15 % del umbral por segundo. Evita "marcar" un enemigo y volver mucho después, y la barra comunica "seguí pegándole".
4. **Varias barras.** Propuesta: **apiladas**, una fila fina por tipo conseguido, en el orden en que se consiguió, debajo de la barra de vida. Todas las barras del enemigo se cargan con cada golpe (cada una a su ritmo). Se muestran vacías desde que la barra de vida aparece, para que se vea qué se está cargando. Una sola barra rotando esconde información; una segmentada no deja ver el progreso de cada tipo.
5. **Bosses.** Propuesta: umbral bajo (0.12) y **resistencia** que crece +25 % del umbral con cada disparo, hasta ×2 (`EnemyStats.affliction_resistance_step`; el tope es global). Los comunes no tienen resistencia (mueren antes). Las barras del boss van en el HUD, debajo de su barra de vida.
6. **Rage.** Propuesta: **sin regla propia.** Rage sube la vida y el umbral es fracción de la vida, así que un enemigo con Rage ya tarda más en llenarse. Las cartas de Aflicción agrandan el pool, así que Rage empieza más tarde; cuando se llega al tope de tipos, las de tipos nuevos salen del pool.
7. **Niveles.** Propuesta: cada carta de tipo tiene `max_level = 3`. El nivel 1 da el tipo (cuenta para el tope); los niveles 2 y 3 **suben la fuerza del efecto** (potencia del estado o daño del Estallido), no la carga, para que el ritmo de la barra siga siendo legible. Subir de nivel no cuenta para el tope.
8. **Tope de tipos por run.** Propuesta: **2** (`AfflictionConfig.max_types`). Con 4 tipos y 2 barras bajo la vida la lectura sigue limpia; 3 ya tapa al enemigo en grupos.
9. **Fuentes.** Propuesta: la carta declara sus fuentes (`sources`: básico y/o habilidades). Las 4 cartas iniciales usan **ambas** ("Tus golpes acumulan…"). Queda preparado para que una mejora única de habilidad otorgue un tipo solo para esa habilidad, pero **no se hace en esta spec** (se decide en otra).
10. **Dónde se ofrecen.** Propuesta: cartas **normales** (no doradas), en su propio catálogo, con un color de carta nuevo (turquesa, ver §9). Se pueden banear.
11. **Colores de las barras** (no reservados, ver §9): Veneno verde, Estallido azul eléctrico, Escarcha cian, Corrosión violeta (el de Debilitar, que ya es "armadura rota"). Se evitan los reservados (blanco, gris, ámbar) y los que se confunden en combate (rojo de Rage, rojo anaranjado de los avisos, miel, amarillo de estamina).

## 4. Diseño

### 4.1 Qué se ve y cómo se juega

1. El jugador consigue una carta "Veneno" tras una oleada: "Tus golpes acumulan Aflicción: Veneno. Al llenarse, envenena: 1 % de vida por segundo durante 6 s".
2. Desde entonces, cada enemigo muestra una barra verde fina debajo de su barra de vida (vacía). Cada golpe la llena en proporción al daño.
3. Al llenarse: la barra destella (`flash_duration`), se vacía y se aplica el estado (aparece el ícono de Veneno arriba de la barra, con sus segundos). La barra vuelve a cargarse desde 0 con los golpes siguientes, aunque el veneno siga activo (un disparo nuevo lo refresca).
4. Con dos tipos, hay dos barras apiladas; cada golpe carga las dos.
5. Estallido no deja estado: al llenarse, hace daño en área alrededor del enemigo (números de daño normales). Ese daño **no** carga Aflicciones (sin reacciones en cadena).
6. Los ticks de veneno tampoco cargan (no son golpes).

### 4.2 Tipos iniciales (números)

| Tipo | Id | `buildup_multiplier` | Efecto al llenarse | Nivel 1 / 2 / 3 | Para qué |
|---|---|---|---|---|---|
| **Veneno** | `poison` | 1.0 | `poison.tres`: `DAMAGE_OVER_TIME`, 6 s, tick 1 s | 1 % / 1.5 % / 2 % de la vida máxima por tick | Bosses y enemigos grandes: en un boss de 1380, nivel 1 = 83 de daño por disparo. |
| **Estallido** | `burst` | 0.8 | Daño en área (radio 2.5 m) centrado en el enemigo, `receive_hit` (con defensa, sin crítico) | 1.2 / 1.6 / 2.0 × `DAMAGE` del jugador | Hordas: con el Guerrero (15) nivel 1 = 18 en área, casi un Bruto. |
| **Escarcha** | `frost` | 1.0 | `frost.tres`: `SLOW`, 3 s | 30 % / 40 % / 50 % más lento (movimiento, preparaciones y ataques) | Control: alarga las ventanas para esquivar y castigar. |
| **Corrosión** | `corrosion` | 1.0 | `corrosion.tres`: `ARMOR_REDUCTION`, 6 s, sin stacks | ignora 50 % / 75 % / 100 % de la defensa | Enemigos acorazados (Escudero, defensa 6) y niveles altos. Débil contra defensa baja: es situacional a propósito. |

Futuro, **no en esta spec**: **Aturdimiento** = un `AfflictionData` más con un `DebuffData` de efecto `STUN` que agregue el re-work del Guerrero (§8). No requiere código en esta mecánica.

### 4.3 Estructura de nodos

```
Player (player.tscn)
└── Afflictions (AfflictionLoadout)        ← nuevo: tipos conseguidos y su nivel; resuelve los disparos

Enemy (enemy.tscn)
├── AfflictionComponent                     ← nuevo: una barra de carga por tipo del jugador
└── HealthBar (EnemyHealthBar)
    ├── DebuffIcons (DebuffIconRow)         (sin cambios)
    └── AfflictionBars (AfflictionBarRow)   ← nuevo: filas Background + Fill (QuadMesh), creadas en _ready

HUD › BossBarStack › BossHealthBar
    └── AfflictionBars (VBoxContainer)      ← nuevo: filas ColorRect creadas en setup()
```

- Los slots (barras) de enemigos y del HUD se crean **una vez** (`AfflictionConfig.max_types`), nunca en runtime (Principio V).
- El slot *i* de cada enemigo corresponde al tipo *i* del `AfflictionLoadout` (orden de adquisición). El enemigo lo lee por `target.afflictions`.

### 4.4 Resources y datos

**`AfflictionData`** (`resources/affliction_data.gd`, `data/afflictions/<tipo>.tres`): qué es un tipo.

| Campo | Tipo | Qué es |
|---|---|---|
| `id` | `StringName` | Identidad estructural. |
| `title` | `String` | "Veneno" (carta y pausa). |
| `bar_material` | `StandardMaterial3D` | Relleno de su barra 3D; el HUD usa su `albedo_color`. También es el `icon_material` de su `DebuffData`. |
| `buildup_multiplier` | `float` | Carga por punto de daño (1.0 = estándar). |
| `debuff` | `DebuffData` | Estado que aplica al llenarse (nulo para Estallido). |
| `burst_radius` | `float` | Radio del daño en área (0 = sin estallido). |

Cálculo puro: `has_burst() -> bool` (`burst_radius > 0`).

**`AfflictionUpgradeData extends UpgradeCard`** (`resources/affliction_upgrade_data.gd`, `data/afflictions/cards/<tipo>_card.tres`): la carta.

| Campo | Tipo | Qué es |
|---|---|---|
| `affliction` | `AfflictionData` | Tipo que otorga. |
| `sources` | `int` (flags `Source.BASIC_ATTACK = 1`, `Source.ABILITIES = 2`) | Qué golpes cargan. Las 4 iniciales: 3. |
| `max_level` | `int` | 3. |
| `level_values` | `Array[float]` | Potencia del estado o multiplicador del Estallido por nivel. |
| `level_descriptions` | `Array[String]` | Texto de la carta por nivel. |
| `value_format` | `ValueFormat` | Valor en el panel del sandbox. |

`is_same_kind()` compara `affliction.id`; `get_value(level)` y `get_description(level)` como en `AbilityUniqueUpgradeData`.

**`AfflictionCatalog`** (`resources/affliction_catalog.gd`, `data/afflictions/affliction_catalog.tres`): `cards: Array[AfflictionUpgradeData]` (las 4).

**`AfflictionConfig`** (`resources/affliction_config.gd`, `data/combat/affliction_config.tres`): reglas globales y aspecto.

| Campo | Valor | Qué es |
|---|---|---|
| `max_types` | 2 | Tope de tipos por run (y de filas creadas por enemigo). |
| `basic_attack_factor` | 1.0 | Carga por punto de daño del ataque básico (y Tajo aéreo). |
| `ability_factor` | 1.0 | Carga por punto de daño de habilidad. |
| `decay_delay` | 4.0 | Segundos sin carga antes de empezar a vaciarse. |
| `decay_rate` | 0.15 | Fracción del umbral que se vacía por segundo. |
| `resistance_cap` | 2.0 | Máximo multiplicador del umbral por resistencia. |
| `flash_duration` | 0.2 | Segundos que la barra se muestra llena y brillante al disparar. |
| `bar_height` | 0.04 | Alto de cada fila 3D (m); el ancho es el de la barra de vida. |
| `bar_gap` | 0.02 | Separación entre filas 3D y con la barra de vida (m). |
| `background_material` | `health_bar_background_material.tres` | Fondo de cada fila. |
| `flash_material` | `affliction_flash_material.tres` | Relleno durante el destello (tipo más claro, ver §9). |
| `hud_bar_height_px` / `hud_bar_gap_px` | 6 / 3 | Filas del HUD de bosses. |
| `pause_format` | `"Aflicciones %d/%d"` | Título de la sección en la pausa. |
| `pause_entry_format` | `"%s nv. %d"` | Cada tipo en la pausa. |

**`EnemyStats`** (campos nuevos, escritos explícitamente en **todos** los `*_stats.tres`, porque un 0 omitido rompería la mecánica):

| Campo | Comunes | Escudero | Bosses (Verdugo, Titán, Colmena) |
|---|---|---|---|
| `affliction_threshold_ratio` | 0.5 | 0.4 | 0.12 |
| `affliction_resistance_step` | 0 (omitido) | 0 | 0.25 |

`write_scaled()` los copia sin crecer (el umbral crece con la vida).

**`DebuffData`:** `Effect.SLOW` (al final del enum = 4). `potency` = fracción de velocidad que se pierde. Con varios `SLOW` activos manda el más fuerte.

**Nuevos `.tres` de estado:** `data/debuffs/poison.tres`, `frost.tres`, `corrosion.tres` (ver §4.2), con `icon_material` = `bar_material` de su tipo.

**Materiales nuevos** (`materials/afflictions/`): `poison_material.tres`, `burst_material.tres`, `frost_material.tres`, `corrosion_material.tres` (unshaded, opacos), `affliction_flash_material.tres`.

**`UpgradePickerConfig`:** `affliction_card_color`, `affliction_card_hover_color`, `affliction_card_font_color`.

### 4.5 Interfaz pública

**`AfflictionLoadout`** (`components/affliction_loadout.gd`, en el jugador; estado mutable de la run):

```gdscript
signal changed                                   # tipo nuevo o nivel nuevo
signal triggered(enemy: Enemy, type: AfflictionData)
signal burst_hit(enemy: Enemy, applied: float)   # para los números de daño

@export var config: AfflictionConfig
@export var stats: StatsComponent                 # DAMAGE para el Estallido
@export var registry: EnemyRegistry               # enemigos en el radio del Estallido
@export var attack: AttackComponent
@export var air_slash: AirSlashComponent
@export var basic_ability: AbilityComponent
@export var ultimate_ability: AbilityComponent

func apply_card(card: AfflictionUpgradeData) -> void    # nivel 1 agrega el tipo; si no, sube un nivel
func remove_card(card: AfflictionUpgradeData) -> void   # sandbox
func count_card(card: AfflictionUpgradeData) -> int     # nivel (0 = no lo tiene)
func is_card_maxed(card: AfflictionUpgradeData) -> bool # en max_level, o tipo nuevo con el tope lleno
func get_type_count() -> int
func get_type(slot: int) -> AfflictionData
func get_level(slot: int) -> int
func clear() -> void
static func buildup_for(applied: float, factor: float, type: AfflictionData) -> float   # puro
```

`Player` enruta: `apply_upgrade`, `remove_upgrade`, `count_upgrade`, `max_count` e `is_maxed` aceptan `AfflictionUpgradeData` (a `afflictions`); `reset_upgrades()` llama `afflictions.clear()`.

**`AfflictionComponent`** (`components/affliction_component.gd`, en el enemigo):

```gdscript
signal changed           # cambió alguna carga (las barras se redibujan)
signal triggered(slot: int)

@export var config: AfflictionConfig
@export var health: HealthComponent

func setup(stats: EnemyStats) -> void                # al activar: cargas en 0, resistencia en 1
func add_buildup(slot: int, amount: float) -> bool   # true si llenó la barra (y la vació)
func get_ratio(slot: int) -> float                   # carga / umbral, en [0, 1]
func get_threshold() -> float                        # max_health × ratio × resistencia
func is_flashing(slot: int) -> bool
func advance(delta: float) -> void                   # vaciado y destello; lo llama _physics_process y los tests
func clear() -> void                                 # pool (activate/deactivate)
```

**`DebuffComponent.get_speed_scale() -> float`**: `1 - potencia` del `SLOW` más fuerte (1 sin `SLOW`).

**`Enemy`**: `var afflictions: AfflictionComponent` (`@onready`); `activate()` llama `afflictions.setup(_scaled)`; `deactivate()` llama `afflictions.clear()`.

### 4.6 Lógica interna

**Carga (jugador → enemigo).** `AfflictionLoadout` se conecta en `_ready` a `attack.enemy_hit` y `air_slash.enemy_hit` (fuente básica) y a `basic_ability.enemy_hit` y `ultimate_ability.enemy_hit` (fuente habilidad). Por cada golpe con `applied > 0`, recorre sus tipos (sin allocations): si la carta del tipo incluye la fuente, `enemy.afflictions.add_buildup(slot, buildup_for(applied, factor, type))`. Si devuelve `true`, resuelve el disparo.

**Disparo.**
- Con `debuff`: `enemy.debuffs.apply(type.debuff, card.get_value(level))`.
- Con estallido: `damage = get_value(level) × DAMAGE`; para cada enemigo activo del `registry` a ≤ `burst_radius` (+ su padding) del enemigo que disparó, incluido él: `applied = e.health.receive_hit(damage)` y `burst_hit.emit(e, applied)`. No emite `enemy_hit`, así que no carga Aflicciones, no da robo de vida ni hit lag.
- Emite `triggered(enemy, type)`.

**Barra (enemigo).** `add_buildup` suma la carga, reinicia el temporizador de vaciado y, si llega al umbral: carga a 0, empieza el destello, multiplica la resistencia por `(1 + resistance_step)` hasta `resistance_cap`, emite `triggered` y devuelve `true`. El sobrante de carga se descarta. Un enemigo muerto o invulnerable (el golpe aplicó 0) no carga. `advance()` descuenta el destello y, pasado `decay_delay`, resta `decay_rate × umbral × delta`; solo procesa mientras alguna barra tiene carga o destello (`set_physics_process`).

**Vista 3D (`AfflictionBarRow`).** Crea `max_types` filas en `_ready` debajo de la barra de vida (`-(size.y/2 + bar_gap + i × (bar_height + bar_gap))`). Muestra tantas filas como tipos tenga el jugador (`loadout.changed` → `refresh`), con `material_override = type.bar_material` (o `flash_material` mientras destella). El relleno es un segmento anclado a la izquierda como el de vida. Se redibuja con `afflictions.changed`. Al ser hija de `HealthBar`, hereda visibilidad (oculta hasta el primer golpe, suprimida en bosses), orientación y sacudida.

**Vista HUD (`BossHealthBar`).** En `setup()` crea `max_types` filas `ColorRect` (fondo + relleno) debajo de `BarFrame`; `track()` se conecta a `enemy.afflictions.changed` y al `changed` del loadout; el color es `bar_material.albedo_color` (como los íconos, Principio II).

**Lentitud (`SLOW`).** `Enemy._update_behaviour(delta)` pasa `delta × debuffs.get_speed_scale()` al behavior (preparaciones, ataques e intervalos se estiran) y `move_towards`, `walk` y `move_with_velocity` multiplican la velocidad horizontal por la misma escala. El empuje, la gravedad y el hit lag no se escalan. Un `STUN` del re-work puede enchufarse en este mismo punto (escala 0 y cancelar el ataque en curso) sin cambiar la Aflicción.

**Oferta.** `WaveManager` recibe `affliction_catalog` y `UpgradeOffer.build_pool` lo agrega al pool. `Player.is_maxed(card)` con una carta de Aflicción = `afflictions.is_card_maxed(card)`: sale del pool en `max_level` o cuando el tipo es nuevo y ya hay `max_types`. `UpgradePicker` pinta estas cartas con `affliction_card_color` y muestra la descripción del nivel siguiente (como las doradas). El ban funciona sin cambios.

**Pausa.** `PauseMenu` agrega una sección debajo de los stats: `"Aflicciones 1/2"` y una línea por tipo (`"Veneno nv. 2"`); sin tipos, `"Aflicciones 0/2"` sin líneas. El sandbox lista las cartas de Aflicción como las demás (vía el pool).

## 5. Criterios de aceptación (AC851–AC888)

**Datos**
- **AC851** Existen `AfflictionData`, `AfflictionUpgradeData`, `AfflictionCatalog` y `AfflictionConfig` con los campos de §4.4, y `affliction_config.tres` con `max_types = 2`, factores 1.0, `decay_delay = 4.0`, `decay_rate = 0.15`, `resistance_cap = 2.0`.
- **AC852** `affliction_catalog.tres` tiene las 4 cartas (Veneno, Estallido, Escarcha, Corrosión), cada una con `max_level = 3`, `sources = 3`, 3 `level_values` y 3 `level_descriptions`, con los valores de §4.2.
- **AC853** Todo `data/enemies/*_stats.tres` tiene `affliction_threshold_ratio > 0` (0.5 comunes, 0.4 Escudero, 0.12 bosses) y los bosses `affliction_resistance_step = 0.25`.
- **AC854** `poison.tres`, `frost.tres` y `corrosion.tres` tienen el efecto, la duración y el tick de §4.2, y su `icon_material` es el `bar_material` de su tipo.
- **AC855** Ningún script nuevo tiene literales de diseño: todo número sale de los Resources de §4.4 (review, Principio III).

**Carga y disparo**
- **AC856** Con Veneno, un golpe del combo que aplica 12 de daño a un Bruto nivel 1 (40 de vida, umbral 20) deja su barra en 0.6.
- **AC857** Un segundo golpe de 10 llena la barra: se aplica `poison` con potencia 0.01, la barra queda en 0 (sin sobrante) y destella `flash_duration`.
- **AC858** Un golpe de habilidad (vía `report_hit`) y un Tajo aéreo cargan igual que un golpe del combo con el mismo daño aplicado.
- **AC859** Una carta con `sources = BASIC_ATTACK` no carga con golpes de habilidad (y viceversa).
- **AC860** Con Estallido (`buildup_multiplier = 0.8`), 20 de daño aplicado cargan 16.
- **AC861** Un golpe que aplica 0 (enemigo invulnerable, p. ej. la Colmena con escudo) no carga.
- **AC862** Los ticks de un estado y el daño del Estallido no cargan ninguna barra.
- **AC863** Con dos tipos, un golpe carga las dos barras, cada una con su `buildup_multiplier`.
- **AC864** Tras 4 s sin carga, la barra baja 0.15 del umbral por segundo hasta 0; un golpe reinicia la espera.
- **AC865** El umbral de un enemigo de nivel alto, o con Rage, es `ratio × su vida máxima escalada`.
- **AC866** En un boss, cada disparo multiplica el umbral por 1.25, hasta ×2.0 (1.0 → 1.25 → 1.5625 → 1.953 → 2.0).
- **AC867** Al reactivar un enemigo del pool, todas sus barras están en 0 y su resistencia en ×1.

**Efectos**
- **AC868** Veneno nivel 2 aplica `poison` con potencia 0.015; un disparo con el veneno activo lo refresca (duración completa, potencia máxima).
- **AC869** Estallido nivel 1 con `DAMAGE = 15` golpea con 18 (antes de defensa) al enemigo que lo disparó y a los enemigos a ≤ 2.5 m (+ padding), y no a los que están más lejos; emite `burst_hit` por cada uno.
- **AC870** El Estallido no da robo de vida ni hit lag, y no emite `enemy_hit`.
- **AC871** Escarcha nivel 1 aplica `frost` (potencia 0.3): `get_speed_scale()` = 0.7; la velocidad de `walk` baja al 70 % y una preparación de 1 s del behavior dura ≈ 1.43 s.
- **AC872** Con dos `SLOW` activos manda el más fuerte; al expirar, la escala vuelve a 1.
- **AC873** Corrosión nivel 1 aplica `corrosion` (0.5): la defensa efectiva de un Escudero (6) pasa a 3 durante 6 s.

**Cartas y tope**
- **AC874** Tomar la carta de Veneno agrega el tipo en el slot 0 con nivel 1; tomarla de nuevo sube a nivel 2 sin ocupar otro slot.
- **AC875** Con 2 tipos, las cartas de los otros tipos cuentan como topadas y no se ofrecen; las de los tipos que se tienen sí, hasta nivel 3.
- **AC876** Una carta en nivel 3 sale del pool.
- **AC877** Las cartas de Aflicción se ofrecen en oleadas normales (no son doradas) y se pueden banear.
- **AC878** Con todas las cartas (incluidas las de Aflicción) topadas o baneadas, empieza Rage como antes.
- **AC879** `Player.reset_upgrades()` (sandbox) quita los tipos; `remove_upgrade` baja un nivel o quita el tipo.

**Vista**
- **AC880** Sin tipos, la barra de vida no muestra filas de Aflicción. Con un tipo, muestra una fila vacía debajo de la barra de vida, con el `bar_material` del tipo en el relleno.
- **AC881** Con dos tipos, hay dos filas apiladas en el orden de adquisición, separadas por `bar_gap`.
- **AC882** El relleno de la fila cubre `get_ratio()` del ancho, anclado a la izquierda.
- **AC883** Mientras destella, la fila usa `flash_material` y se ve llena; después vuelve a su material y a 0.
- **AC884** Las filas se ocultan y se muestran con la barra de vida, y en los bosses (barra suprimida) no se ven en 3D.
- **AC885** La barra del boss en el HUD muestra las filas con el color del tipo (`albedo_color`) y su relleno sigue la carga.
- **AC886** El ícono del estado disparado aparece en la fila de íconos del enemigo (sin cambios en `DebuffIconRow`).
- **AC887** La pausa muestra "Aflicciones 1/2" y "Veneno nv. 2" tras tomar Veneno dos veces.
- **AC888** Las cartas de Aflicción usan el color turquesa de `UpgradePickerConfig` y muestran la descripción del nivel siguiente.

## 6. Tests

- `test/resources/affliction_data_test.gd`, `affliction_upgrade_data_test.gd`, `affliction_config_test.gd`: AC851–AC854.
- `test/components/affliction_component_test.gd`: AC856–AC857, AC860–AC861, AC864–AC867, AC883 (sin escena: `EnemyStats` y `HealthComponent` en memoria).
- `test/components/affliction_loadout_test.gd`: AC858–AC859, AC862–AC863, AC868–AC870, AC874–AC876, AC879 (jugador y enemigos de test, `combo_driver.gd` para el combo).
- `test/components/status_effects_test.gd` (ampliado) y `test/entities/enemy_test.gd` (ampliado): AC871–AC873.
- `test/systems/wave_manager_test.gd` y `upgrade_offer_test.gd` (ampliados): AC875, AC877–AC878.
- `test/components/affliction_bar_row_test.gd`, `test/ui/boss_health_bar_test.gd`, `test/ui/pause_menu_test.gd`, `test/ui/upgrade_picker_test.gd`: AC880–AC888.
- AC855: review.
- Tests viejos con valores fijos que cambien (p. ej. cantidad de cartas del pool en `upgrade_offer_test` / `wave_manager_test`, o el orden del enum `Effect`) se adaptan sin cambiar lo que verifican y se anotan en §11.

## 7. Riesgos

1. **Balance del Veneno en bosses:** un % de vida máxima escala con la vida del boss. Por eso el umbral bajo va con resistencia creciente. Si en el smoke test domina, se baja la potencia o se sube `affliction_resistance_step` (datos).
2. **Carga por daño y cartas de daño:** acelera la Aflicción al subir `DAMAGE`. Es buscado (sinergia), pero hay que mirarlo en oleadas altas; el umbral también crece con el nivel del enemigo.
3. **Legibilidad con muchos enemigos:** dos filas finas por enemigo. Si molesta, `bar_height` es dato.
4. **Carga del Giro:** golpea muchas veces por segundo; por daño aplicado, carga lo mismo que su DPS, sin trato especial.
5. **Enum `Effect`:** ver §8.

## 8. Coordinación con el re-work del Guerrero

- **ACs:** esta spec usa AC851–AC900; el re-work, AC801–AC850. Anotado en `CLAUDE.md`.
- **`DebuffData.Effect`:** esta spec agrega `SLOW = 4` **al final**. Si el re-work agrega `STUN`, va después (`= 5`). Si se mergea al revés, al resolver el conflicto se revisan los `effect =` de los `.tres` nuevos (Godot guarda el entero).
- **Aturdimiento como tipo:** con `STUN` existente, es un `AfflictionData` (`stun.tres` como `debuff`) y una carta, sin código en esta mecánica. La escala de `Enemy._update_behaviour` (§4.6) es el punto de enganche.
- **Golpes nuevos del Guerrero:** si pasan por `AbilityComponent.report_hit()`, cargan Aflicciones sin cambios.
- **Constitución:** los dos pueden enmendar; el número de versión se asigna al cerrar, en el orden en que se mergeen.

## 9. Enmienda de la constitución (MINOR 4.15.0 → 4.16.0)

**Principio III**, nueva viñeta tras "Estados de entidades":

> - **Aflicciones** (desde 4.16.0): una barra de acumulación por enemigo y por tipo que se llena con el daño de los golpes del jugador y, al llenarse, se vacía y dispara un efecto (un estado o un daño en área). Cada tipo es un Resource de datos (`AfflictionData`) y se consigue con una carta con niveles (`AfflictionUpgradeData`, `max_level` y valores por nivel en el `.tres`). El tope de tipos por run, el vaciado y la resistencia de los enemigos son datos (`AfflictionConfig`, `EnemyStats`). Agregar un tipo es un `.tres` nuevo, no código nuevo.

**Principio III**, viñeta "Estados de entidades": el efecto de un estado incluye **lentitud** (`SLOW`: la entidad se mueve y actúa más lento).

**Principio II**, colores no reservados (registro): verde veneno `Color(0.3, 0.8, 0.35)`, azul eléctrico `Color(0.3, 0.5, 1.0)`, cian escarcha `Color(0.45, 0.9, 0.95)` y el violeta de Debilitar `Color(0.55, 0.35, 0.8)` para Corrosión, en las barras de Aflicción (`QuadMesh` unshaded bajo la barra de vida) y sus íconos; su destello `Color(0.85, 1.0, 0.9)` (unshaded, no es el blanco reservado); y turquesa `Color(0.15, 0.55, 0.55)` para las cartas de Aflicción.

**Historial:** `4.16.0 (fecha de cierre): Principio III: Aflicciones (barra de acumulación por tipo, cartas con niveles, tope por run) y el efecto de estado SLOW. Principio II: colores no reservados de las barras y cartas de Aflicción (ver affliction.md).`

## 10. Plan

Cada paso deja el proyecto abriendo y la suite en verde.

1. **Datos base:** `AfflictionData`, `AfflictionUpgradeData`, `AfflictionCatalog`, `AfflictionConfig`; materiales; `affliction_config.tres`; los 4 tipos y sus cartas; `poison`/`frost`/`corrosion.tres`; campos nuevos de `EnemyStats` en todos los `*_stats.tres`. Tests AC851–AC854.
2. **`SLOW`:** enum, `DebuffComponent.get_speed_scale()`, escala en `Enemy`. Tests AC871–AC873.
3. **`AfflictionComponent`** en `enemy.tscn`, con `setup`/`clear` en `activate`/`deactivate`. Tests AC856–AC857, AC860–AC861, AC864–AC867.
4. **`AfflictionLoadout`** en `player.tscn` (conexiones, disparos, Estallido, `burst_hit` en `DamageNumberPool`) y enrutado en `Player`. Tests AC858–AC859, AC862–AC863, AC868–AC870, AC874, AC879.
5. **Oferta:** catálogo en `WaveManager`/`UpgradeOffer`, tope, color de carta en `UpgradePicker`. Tests AC875–AC878, AC888.
6. **Vistas:** `AfflictionBarRow` en `enemy_health_bar.tscn`/`enemy.tscn`, filas en `BossHealthBar`, sección en la pausa. Tests AC880–AC887.
7. **Cierre:** enmienda de la constitución, `CLAUDE.md` ("Dónde se ajusta cada cosa": Aflicciones; próximo AC libre), suite completa, smoke test (`arena.tscn`) y captura con dos tipos, checklist §12 y estado **Implementada**.

## 11. Notas de implementación

(Se completa al implementar: tests viejos adaptados, desvíos aprobados.)

## 12. Checklist de review (constitución)

- [ ] **Identidad (I):** progresión (cartas de tipo con tope) y combate (barra legible, efectos que cambian la pelea).
- [ ] **Arte (II):** filas `QuadMesh` / `ColorRect`, materiales `.tres` compartidos, colores registrados, sin reservados.
- [ ] **Datos (III):** todo número en `AfflictionConfig`, `AfflictionData`, cartas y `EnemyStats`; cartas con `max_level` y valores por nivel; ningún Resource mutado (el nivel y las cargas viven en nodos).
- [ ] **GDScript (IV):** tipado estricto, callbacks delgados.
- [ ] **Performance (V):** filas creadas una vez; sin allocations por golpe ni por frame; el Estallido recorre el registry sin crear arrays; `AfflictionComponent` no procesa sin carga.
- [ ] **Input (VI):** sin acciones nuevas; la pausa sigue navegable con mando.
- [ ] **Combate (VII):** el Estallido no causa hit lag ni toca `Engine.time_scale`; `SLOW` no toca `Engine.time_scale`.
- [ ] **Calidad:** proyecto sin errores ni warnings nuevos, ACs y suite completa en verde.
