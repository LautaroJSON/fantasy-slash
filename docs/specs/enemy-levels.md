# Feature: Niveles de enemigo por oleada

- **Estado:** Implementada (2026-09-25, 202 tests GdUnit4 en verde, smoke tests headless del menú y de la arena limpios)
- **Constitución:** `docs/constitution.md` **v2.3.0** (esta feature introduce la enmienda MINOR del §6)
- **Pilar (Principio I):** Supervivencia. La presión crece con la run: cada cierto número de oleadas los enemigos pegan más fuerte y aguantan más, y eso obliga a que las mejoras elegidas importen. El nivel visible hace legible esa amenaza de un vistazo.
- **Dependencias:** `combat-mvp.md`, `combat-feedback.md`, `hit-feedback.md`.

## 1. Objetivo

Cada enemigo tiene un **nivel** que depende de la oleada en la que aparece. El nivel escala sus stats según datos y se muestra en blanco a la izquierda de su barra de vida: `lv. 3 [██████░░░]`.

## 2. Reglas de nivel (propuesta de balance)

### 2.1 Oleada → nivel

```
nivel = min(1 + floor((oleada - 1) / waves_per_enemy_level), max_enemy_level)
```

Con `waves_per_enemy_level = 2` y `max_enemy_level = 25`:

| Oleadas | 1–2 | 3–4 | 5–6 | 9–10 | 19–20 | 49+ |
|---|---|---|---|---|---|---|
| Nivel | 1 | 2 | 3 | 5 | 10 | 25 (tope) |

Cada 2 oleadas encaja con el ritmo de 1 carta por oleada: el jugador recibe 2 mejoras por cada nivel que suben los enemigos, así que la run se siente progresiva sin ahogar.

### 2.2 Crecimiento por nivel

El crecimiento es **lineal sobre el valor base** (no compuesto): `valor = base + amount × (nivel - 1)` en modo fijo, o `base × (1 + amount × (nivel - 1))` en modo porcentaje. Opcionalmente, un tope (`cap`) por stat.

| Stat | Modo | Por nivel | Tope | Grunt Nv 1 | Nv 5 | Nv 10 |
|---|---|---|---|---|---|---|
| `max_health` | % | +20 % | — | 40 | 72 | 112 |
| `damage` | % | +10 % | — | 8 | 11.2 | 15.2 |
| `defense` | fijo | +0.5 | 5 | 0 | 2 | 4.5 |
| `move_speed` | fijo | +0.1 m/s | 5.0 | 3.5 | 3.9 | 4.4 |
| `attack_interval`, `attack_range`, `knockback_friction` | — | sin cambio | — | | | |

- **Por qué lineal:** el compuesto (×1.2 por nivel) da 5.2× de vida en Nv 10 y explota enseguida. El lineal se balancea a ojo.
- **Defensa con tope bajo:** la defensa resta plano (`DamageMath.mitigate`) y castiga mucho a los golpes chicos (sangrado no, porque es daño verdadero). El tope 5 evita que el ataque básico quede en el piso de daño.
- **Velocidad con tope 5.0 < 6.0 del jugador:** un enemigo nunca debe correr más rápido que el jugador sin dash.

Todos estos números viven en `.tres` y se ajustan desde el inspector.

## 3. Datos (Principio III)

### 3.1 `WaveConfig` (campos nuevos)

```gdscript
## Waves needed for enemies to gain one level.
@export var waves_per_enemy_level: int
## Highest level an enemy can reach.
@export var max_enemy_level: int

## Pure: level of the enemies spawned in `wave` (1-based).
func enemy_level_for(wave: int) -> int
```

El ritmo de nivel es global de la run, por eso vive en `WaveConfig`. El *cuánto* crece cada stat depende del tipo de enemigo y vive en `EnemyStats`.

### 3.2 `EnemyStatGrowth` (Resource nuevo, `resources/enemy_stat_growth.gd`)

```gdscript
class_name EnemyStatGrowth
extends Resource
## How one enemy stat grows per level above 1.

enum Mode { PERCENT, FLAT }

@export var stat: EnemyStats.Stat
@export var mode: Mode
## PERCENT: fraction of the base per level (0.2 = +20 %). FLAT: units per level.
@export var amount: float
## Upper limit of the scaled value; ignored when has_cap is false.
@export var has_cap: bool
@export var cap: float

## Pure: `base` scaled to `level`.
func scale(base: float, level: int) -> float
```

### 3.3 `EnemyStats` (cambios)

```gdscript
enum Stat { DAMAGE, DEFENSE, MAX_HEALTH, ATTACK_INTERVAL, ATTACK_RANGE, MOVE_SPEED, KNOCKBACK_FRICTION }

## Per-level growth of this enemy type; stats not listed do not grow.
@export var level_growth: Array[EnemyStatGrowth]

func get_stat(stat: Stat) -> float
func set_stat(stat: Stat, value: float) -> void   # only used on the enemy's own duplicate
## Pure: writes into `out` this type's stats scaled to `level`.
func write_scaled(level: int, out: EnemyStats) -> void
```

Agregar crecimiento a otro stat = agregar un `EnemyStatGrowth` al array en el `.tres`, sin tocar código.

### 3.4 `HealthBarConfig` (campos nuevos)

```gdscript
## Text of the level label; %d is the level.
@export var level_format: String          # "lv. %d"
@export var level_font_size: int
## World size of one font pixel, in meters.
@export var level_pixel_size: float
## Gap between the label's right edge and the bar's left edge, in meters.
@export var level_gap: float
```

### 3.5 Instancias `.tres`

- `data/waves/wave_config.tres`: `waves_per_enemy_level = 2`, `max_enemy_level = 25`.
- `data/enemies/grunt_stats.tres`: `level_growth` con 4 sub-recursos (tabla §2.2).
- `data/ui/enemy_health_bar_config.tres`: `level_format = "lv. %d"`, `level_font_size = 48`, `level_pixel_size = 0.005`, `level_gap = 0.08` (valores de arranque, se ajustan a ojo).
- `materials/enemy_level_material.tres` (nuevo, compartido): `StandardMaterial3D` unshaded, blanco `Color(1, 1, 1)`, mismo depth test y prioridad que los materiales de la barra.

## 4. Escenas y nodos

### 4.1 `components/enemy_health_bar.tscn`

```
HealthBar (Node3D, enemy_health_bar.gd)
├── Background (MeshInstance3D, QuadMesh)
├── Trail      (MeshInstance3D, QuadMesh)
├── Fill       (MeshInstance3D, QuadMesh)
└── LevelLabel (MeshInstance3D, TextMesh)   ← NUEVO
```

- `LevelLabel`: `TextMesh` con `horizontal_alignment = RIGHT`, `depth = 0` y `enemy_level_material.tres`. Queda anclado a `x = -size.x / 2 - level_gap`, así el texto termina justo antes del borde izquierdo de la barra, sin importar cuántos dígitos tenga.
- Es hijo de la barra, así que ya mira a la cámara y comparte su visibilidad (ver pregunta abierta §8.1).
- `font_size`, `pixel_size` y posición se aplican una vez en `_ready` desde `HealthBarConfig`.

### 4.2 `entities/enemy/enemy.tscn`

Sin nodos nuevos.

## 5. Interfaz pública y estado

### `Enemy`

```gdscript
@export var stats: EnemyStats          # base compartida, NUNCA se muta

var level: int = 1                     # read-only desde afuera
## Own duplicate of `stats`, created once in _ready, rewritten on each activate().
var _scaled: EnemyStats

func activate(at: Vector3, new_target: Player, new_level: int = 1) -> void
func get_scaled_stats() -> EnemyStats
```

- `_ready`: `_scaled = stats.duplicate()` (una sola vez por enemigo del pool; documentado según el Principio III).
- `activate`: `level = new_level` → `stats.write_scaled(level, _scaled)` → `health.setup(_scaled.max_health, _scaled.defense)` → `health_bar.set_level(level)`.
- Todo el comportamiento (`_chase`, `_attack`, `_slide_back`) lee de `_scaled` en lugar de `stats`.
- Los enemigos colocados a mano (`start_active`) arrancan en nivel 1.

### `EnemyHealthBar`

```gdscript
func set_level(level: int) -> void     # updates the TextMesh text (only on activation)
func get_level_text() -> String
```

### `WaveManager.start_wave`

```gdscript
var level: int = config.enemy_level_for(run_state.wave)
enemy.activate(_pick_spawn_position(), player, level)
```

El sandbox usa el mismo camino, así que sus oleadas también escalan.

### Performance (Principio V)

- El texto se formatea una vez por activación, nunca por frame.
- `duplicate()` corre una vez por enemigo al cargar el pool. Cero allocations en `_physics_process`.

## 6. Enmienda de la constitución (MINOR → 2.3.0)

El pedido es texto **blanco**, y el blanco está **reservado** (Principio II) para el cuerpo del jugador y los números de daño. Para cumplirlo se propone agregar a la tabla de colores:

| Nivel de enemigo (junto a su barra de vida) | `TextMesh` | **Blanco**: `Color(1, 1, 1)` |

Con esta aclaración: *"El blanco se comparte entre el cuerpo del jugador y los textos flotantes (números de daño, nivel de enemigo): todos son texto, no cápsulas."*

- **Alternativa conforme:** usar un color no reservado (p. ej. amarillo pálido). Se descarta porque el pedido es blanco explícitamente y el texto no se confunde con el jugador.
- La precedente fue la **2.1.0**, que hizo lo mismo con los números de daño.

## 7. Criterios de aceptación

- **AC127** `WaveConfig.enemy_level_for`, con cada 2 y tope 25: oleada 1 → 1, 2 → 1, 3 → 2, 10 → 5, 20 → 10, 100 → 25.
- **AC128** `EnemyStatGrowth.scale`: PERCENT 0.2 con base 40 en Nv 5 → 72. FLAT 0.1 con base 3.5, tope 5.0, en Nv 10 → 4.4 y en Nv 25 → 5.0. En Nv 1, siempre la base.
- **AC129** `EnemyStats.write_scaled(10, out)` con `grunt_stats.tres`: `max_health` 112, `damage` 15.2, `defense` 4.5, `move_speed` 4.4, y `attack_interval`, `attack_range` y `knockback_friction` sin cambio.
- **AC130** Un `Enemy` activado en Nv 5 arranca con `health.max_health == 72` y le pega al jugador con daño 11.2 (antes de la defensa del jugador).
- **AC131** El `.tres` compartido no cambia: después de activar enemigos en Nv 10, `grunt_stats.tres` sigue con `max_health == 40`.
- **AC132** Pool: un enemigo activado en Nv 5, muerto y reactivado en Nv 1 vuelve a los stats de Nv 1 y su etiqueta dice `lv. 1`.
- **AC133** La etiqueta muestra `level_format` con el nivel (`"lv. 3"`) y su borde derecho queda a `level_gap` del borde izquierdo de la barra. Con la barra oculta (sin golpes), la etiqueta tampoco se ve; tras el primer golpe, se ve.
- **AC134** `WaveManager.start_wave` en la oleada 5 activa a todos los enemigos en Nv 3.
- **AC135** Regresión: la suite completa en verde y los tests existentes de `enemy_behaviour_test.gd` pasan sin cambios de expectativas (Nv 1 = stats base).

## 8. Decisiones (resueltas)

1. **Visibilidad:** el nivel aparece **junto con la barra**. Oculto hasta el primer golpe, visible mientras la barra se ve, y oculto de nuevo en `reset()` al reciclarse. Como `LevelLabel` es hijo de la barra, no hace falta lógica extra.
2. **Formato:** `"lv. N"` (`level_format = "lv. %d"`).

## 9. Plan de implementación (cada paso deja el proyecto funcionando)

1. **Constitución:** aplicar la enmienda 2.3.0 (§6) y registrarla en *Historial*.
2. **Datos puros + tests:** `EnemyStats.Stat`, `get_stat` / `set_stat` / `write_scaled`, `EnemyStatGrowth`, y `WaveConfig.enemy_level_for`. Tests de AC127–AC129 en `test/resources/`. Con `level_growth` vacío no cambia nada todavía.
3. **`.tres`:** campos nuevos en `wave_config.tres` y `grunt_stats.tres` (4 sub-recursos de crecimiento).
4. **Enemy:** `_scaled`, `level` y `activate(..., new_level = 1)`. El comportamiento pasa a leer de `_scaled`. Tests AC130–AC132. El parámetro por defecto mantiene compatibles las llamadas existentes.
5. **Barra:** `HealthBarConfig` y su `.tres`, `enemy_level_material.tres`, el nodo `LevelLabel`, y `set_level` / `get_level_text`. Test AC133.
6. **WaveManager:** pasar el nivel en `start_wave`. Test AC134.
7. **Verificación:** la suite completa de GdUnit4 (sobre una copia en el scratchpad), un smoke test headless de la arena, la review con el checklist de la constitución, y la spec marcada como *Implementada*.

### Notas de implementación

- El `TextMesh` de `LevelLabel` es `resource_local_to_scene`. Si no, todos los enemigos del pool compartirían el mismo texto.
- `EnemyStats.write_scaled` primero copia todos los stats base y después aplica los crecimientos, así que reactivar un enemigo en un nivel más bajo no arrastra valores del nivel anterior (AC132).
- Los valores de `level_font_size`, `level_pixel_size` y `level_gap` son de arranque y se ajustan a ojo en el editor.

### Review de la constitución (cierre, v2.3.0)
- **I:** Supervivencia, como declara la spec.
- **II:** la etiqueta es un `TextMesh` con `StandardMaterial3D` blanco plano y compartido (`materials/enemy_level_material.tres`), cubierto por la enmienda 2.3.0. Sin assets externos.
- **III:** el ritmo (`WaveConfig`), el crecimiento (`EnemyStatGrowth` en `grunt_stats.tres`) y el formato de la etiqueta (`HealthBarConfig`) son datos. El `.tres` compartido no se muta: cada enemigo escribe en su propio `duplicate()` (AC131).
- **IV:** tipado completo. `_ready` y `_physics_process` siguen delgados.
- **V:** `duplicate()` corre una vez por enemigo al cargar el pool, y el texto se formatea solo al activarse. Cero allocations por frame.
- **VI:** sin inputs nuevos.
- **Calidad:** los errores `use 'has' ... TypedArray` del log vienen de `AbilityComponent.owns_upgrade`, que esta feature no toca, y no hacen fallar tests.
