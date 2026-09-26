# Feature: Críticos más legibles + vibración de la barra de vida

- **Estado:** Implementada (2026-09-25, 213 tests GdUnit4 en verde, smoke tests headless del menú y de la arena limpios)
- **Constitución:** `docs/constitution.md` **v2.4.0** (esta feature introduce la enmienda MINOR del §5)
- **Pilar (Principio I):** Combate. El jugador distingue al instante un crítico de un golpe normal y "siente" los golpes grandes sobre el enemigo, así que su build de crítico y daño se lee en pantalla.
- **Dependencias:** `combat-feedback.md` (números de daño, barra de vida), `enemy-levels.md`.

## 1. Objetivo

| | Golpe normal | Crítico |
|---|---|---|
| Color | Blanco | **Ámbar** `Color(1, 0.55, 0.1)` |
| Texto | `15` | `23!` |
| Escala | ×0.85, fija | **Pop**: nace en ×2.2 y en 0.12 s baja a ×1.6 |
| Transparencia inicial | 0.2 (un poco apagado) | 0 (opaco) |
| Vida / velocidad de subida | 0.7 s / 1.6 m/s | **1.0 s / 1.0 m/s** (flota más) |

Además, la **barra de vida del enemigo vibra** ligeramente cuando recibe un **crítico** o un golpe que le quita **al menos 1/3 de su vida máxima**.

- Los números de sangrado (ticks de debuff) siguen siendo "normales" y **no** hacen vibrar la barra.
- Las habilidades hoy nunca critican (`is_crit = false`), pero una estocada que saque ≥ 1/3 de la vida sí hace vibrar la barra.

## 2. Datos (Principio III)

### 2.1 `DamageNumberConfig` (cambios)

| Campo | Valor | Nota |
|---|---|---|
| `lifetime` | 0.7 | ahora solo para normales |
| `rise_speed` | 1.6 | ahora solo para normales |
| `normal_scale` | **0.85** | nuevo |
| `normal_transparency` | **0.2** | nuevo. El fade va de este valor a 1. |
| `crit_scale` | 1.5 → **1.6** | escala final del crítico |
| `crit_pop_scale` | **2.2** | nuevo. Escala al nacer. |
| `crit_pop_duration` | **0.12** s | nuevo. Transición lineal de pop → final. |
| `crit_lifetime` | **1.0** s | nuevo |
| `crit_rise_speed` | **1.0** m/s | nuevo |
| `crit_suffix` | **"!"** | nuevo |

`fade_start` se mantiene como fracción de la vida de cada tipo.

### 2.2 `HealthBarConfig` (campos nuevos)

```gdscript
## A hit removing at least this fraction of max health shakes the bar (critical hits always do).
@export var heavy_hit_fraction: float    # 0.3333
## Seconds the bar shakes.
@export var shake_duration: float        # 0.25
## Horizontal amplitude at the start of the shake, in meters; decays linearly to 0.
@export var shake_amplitude: float       # 0.05
## Oscillations per second.
@export var shake_frequency: float       # 30.0
```

### 2.3 Material nuevo

`materials/damage_number_crit_material.tres`: copia de `damage_number_material.tres` (unshaded, billboard, sin depth test) con `albedo_color = Color(1, 0.55, 0.1)`. Es compartido por todos los números críticos.

## 3. Escenas y nodos

### 3.1 `levels/arena/arena.tscn`

```
Arena
├── ...
├── DamageNumberPool (Node3D)   ← nuevo @export crit_material
└── EnemyHitFeedback (Node)     ← NUEVO
```

- **`EnemyHitFeedback`** (`effects/enemy_hit_feedback.gd`) escucha `enemy_hit(enemy, applied, is_crit)` de `player.attack`, `player.basic_ability` y `player.ultimate_ability` (las mismas fuentes que `DamageNumberPool`) y llama `enemy.health_bar.notify_hit(applied, is_crit)`. No escucha los ticks de debuff.
- Es un nodo aparte (en vez de meterlo en `DamageNumberPool`) para que cada nodo tenga una sola responsabilidad.

### 3.2 `enemy_health_bar.tscn`

Sin nodos nuevos. La vibración desplaza el nodo `HealthBar` entero, así que la etiqueta de nivel y los íconos de debuff vibran junto con la barra.

## 4. Interfaz pública y estado

### `DamageNumber`

```gdscript
func setup(config: DamageNumberConfig, material: StandardMaterial3D, crit_material: StandardMaterial3D) -> void
func show_damage(amount: float, is_crit: bool, at: Vector3) -> void
```

- `show_damage` asigna `material_override` (normal o crit) y el texto (`"23"` o `"23" + crit_suffix`). Guarda la vida, la velocidad y la transparencia base del tipo.
- `advance(delta)`: sube con la velocidad del tipo. La transparencia es `lerp(base, 1, fade)`. En críticos, la escala va de `crit_pop_scale` a `crit_scale` durante `crit_pop_duration`.
- El texto se arma solo al mostrar el número (una vez por golpe, como hoy), nunca por frame.

### `DamageNumberPool`

`@export var crit_material: StandardMaterial3D`, que pasa a `setup()`.

### `EnemyHealthBar`

```gdscript
## Pure: whether a hit should shake the bar.
static func should_shake(applied: float, max_health: float, is_crit: bool, bar_config: HealthBarConfig) -> bool
func notify_hit(applied: float, is_crit: bool) -> void   # starts (or restarts) the shake
func is_shaking() -> bool
```

- `should_shake`: `is_crit or applied >= max_health * heavy_hit_fraction`.
- **Vibración:** en `_process`, el desplazamiento horizontal en el plano de la cámara es `amplitude × (tiempo_restante / duración) × sin(t × frequency × TAU)`. Al terminar, la barra vuelve exacto a su posición de reposo (`(0, height_offset, 0)`).
- Si un golpe mata al enemigo, la barra se oculta con él. `reset()` corta cualquier vibración en curso.
- Un nuevo golpe fuerte durante una vibración la reinicia (no se suman).

### Performance (Principio V)

Sin allocations nuevas por frame: la vibración son unas pocas operaciones con `float` y `Vector3` en el `_process` que la barra ya tiene activo. Las conexiones de señales se hacen una sola vez en `_ready`.

## 5. Enmienda de la constitución (MINOR → 2.4.0)

En la tabla de colores del Principio II, los números de daño pasan a tener dos variantes, y el ámbar queda **reservado** para los críticos:

| Números de daño flotantes (normal) | `TextMesh` | **Blanco**: `Color(1, 1, 1)` |
| Números de daño flotantes (crítico) | `TextMesh` | **Ámbar**: `Color(1, 0.55, 0.1)` |

- **Alternativa conforme:** críticos blancos, distinguidos solo por pop, "!" y escala. Se descarta porque el responsable eligió el color (opción 1), que es la señal más legible.
- El ámbar se diferencia del dorado de las cartas únicas: la carta es UI 2D y el número es texto 3D efímero, y además los tonos difieren.

## 6. Criterios de aceptación

- **AC136** Golpe normal de 15: texto `"15"`, material normal, escala ×0.85 y transparencia 0.2 al nacer.
- **AC137** Crítico de 22.5: texto `"23!"`, material crit (ámbar) y escala `crit_pop_scale` al nacer. Tras `crit_pop_duration` queda en `crit_scale`, y a mitad de camino está entre ambos valores.
- **AC138** Vida y subida por tipo: un normal vuelve al pool tras 0.7 s. Un crítico sigue activo a los 0.9 s y vuelve tras 1.0 s. En el mismo `advance`, el crítico sube menos que el normal.
- **AC139** Fade: la transparencia se mantiene en la base (0.2 en normales, 0 en críticos) hasta `fade_start` y después sube hasta 1.
- **AC140** Un número reciclado de crítico a normal recupera el material, la escala, la vida y el texto normales.
- **AC141** `should_shake`: crítico de 1 → sí. Normal de 14 con vida máxima 40 → sí (≥ 13.33). Normal de 13 → no.
- **AC142** Un crítico sobre un enemigo vivo hace vibrar su barra: `is_shaking()` es verdadero y la barra se aparta de su posición de reposo. Tras `shake_duration` vuelve exacto a `(0, height_offset, 0)` y `is_shaking()` es falso.
- **AC143** Un tick de sangrado no hace vibrar la barra. Un ataque normal chico tampoco.
- **AC144** `reset()` (reciclado del pool) corta la vibración y deja la barra en reposo.
- **AC145** Regresión: la suite completa en verde. Los tests de AC33 y AC34 de `damage_number_pool_test.gd` se actualizan a los nuevos valores (escala normal 0.85, texto `"23!"`, transparencia base 0.2), sin cambiar lo que verifican.

## 7. Plan de implementación (cada paso deja el proyecto funcionando)

1. **Constitución:** enmienda 2.4.0 (§5) y su entrada en *Historial*.
2. **Datos:** campos nuevos en `DamageNumberConfig` y `HealthBarConfig`, con sus `.tres`, y `damage_number_crit_material.tres`.
3. **Números:** `DamageNumber.setup` / `show_damage` / `advance` según §4, y el `crit_material` en `DamageNumberPool` y `arena.tscn`. Actualizar AC33/AC34 y agregar AC136–AC140.
4. **Barra:** `should_shake`, `notify_hit`, `is_shaking`, la vibración en `_process` y el corte en `reset()`. Tests AC141, AC142 y AC144.
5. **Router:** `effects/enemy_hit_feedback.gd` y su nodo en `arena.tscn`. Test AC143 (sangrado y golpe chico) dentro de la arena o con un `Player` de test.
6. **Verificación:** la suite completa de GdUnit4 en una copia del scratchpad, smoke tests headless, la review con el checklist y la spec marcada como *Implementada*.

### Notas de implementación

- La vibración desplaza la barra a lo largo de su propio eje X (`basis.x`), que ya mira a la cámara. Así el movimiento siempre es lateral en pantalla, sin importar hacia dónde mire el enemigo.
- `EnemyHealthBar.advance_shake(delta)` es público, igual que `advance`, para que los tests avancen la vibración sin depender de frames.
- Tests nuevos: `test/effects/enemy_hit_feedback_test.gd` (AC141–AC144) y AC136–AC140 en `damage_number_pool_test.gd`.

### Review de la constitución (cierre, v2.4.0)
- **I:** Combate, como declara la spec.
- **II:** críticos en ámbar (`materials/damage_number_crit_material.tres`, compartido), cubierto por la enmienda 2.4.0. Los normales siguen blancos. Sin assets externos.
- **III:** escalas, pop, vidas, velocidades, transparencia, sufijo, umbral de 1/3 y parámetros de vibración viven en `DamageNumberConfig` y `HealthBarConfig`.
- **IV:** tipado completo. `_process` de la barra solo orquesta (`_face_camera`, `advance`, `advance_shake`).
- **V:** el texto se arma una vez por golpe (como antes) y la vibración son operaciones con `float`/`Vector3` sin allocations. Las señales se conectan una vez en `_ready`.
- **VI:** sin inputs nuevos.
- **Calidad:** los errores `use 'has' ... TypedArray` (de `AbilityComponent.owns_upgrade`) y el warning de 141 `ObjectDB` filtrados al salir ya existían antes de esta feature, con la misma cantidad.
