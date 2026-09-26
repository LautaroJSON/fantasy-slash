# Feature: Reloj de recarga estilo LoL en habilidades, buffs y debuffs

- **Estado:** Implementada (2026-09-25, 423 tests GdUnit4 en verde, 0 orphans; import y smoke test del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.7.0 (sin enmienda).
- **Pilares (Principio I):**
  - **Combate:** el reloj muestra de un vistazo, sin leer el número, qué tan cerca está una habilidad de volver. Con la visión periférica alcanza para decidir si esperar o esquivar.
  - **Progresión:** el tiempo de los stacks de Conmoción y de los debuffs de las mejoras doradas se lee como una proporción, así se ve cuándo hay que encadenar la próxima kill o golpe.
- **Dependencias:** `cooldown-timers.md` (Implementada). Esta spec la extiende: los números quedan como están.

## 1. Objetivo

Un **reloj translúcido** (sector oscuro, como en League of Legends) sobre cada ícono 2D con temporizador. Los segundos siguen en el medio.

- El sector oscuro tapa la **parte que falta**. A medida que pasa el tiempo se destapa en **sentido horario desde las 12**, hasta desaparecer cuando el tiempo llega a 0.
- Es translúcido: debajo se ve el color del ícono.

| Elemento | Forma del reloj | Proporción que tapa | Cambio respecto de hoy |
|---|---|---|---|
| Habilidades | Círculo | Recarga restante / recarga total (`get_cooldown_ratio()`) | **Reemplaza el anillo de recarga.** Durante la recarga el círculo se pinta con `ready_color` y el reloj va encima. El anillo de **carga** (Envainar mantenido) no cambia. |
| Buffs | Cuadrado | `time_left / stack_duration` (el stack actual) | Se suma el reloj. Tiempo y stacks siguen encima. |
| Debuffs en la barra del jefe | Cuadrado | Tiempo restante / `duration` | Se suma el reloj. |
| Debuffs sobre enemigos comunes (3D) | — | — | **Sin reloj**, solo el número (decisión: evita una malla procedural fuera de VFX, Principio II). |
| Dash | — | — | Sin cambios (ya es una barra). |

En el cuadrado, el sector se recorta al borde del ícono: el ángulo avanza igual que en el círculo y las esquinas quedan tapadas mientras les corresponda.

## 2. Estructura

### 2.1 Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `resources/cooldown_clock_config.gd` (nuevo) | `color: Color` (sector oscuro translúcido), `steps_per_turn: int` (puntos del borde por vuelta completa; múltiplo de 8, para que las esquinas del cuadrado caigan justo en un punto). |
| `data/ui/cooldown_clock_config.tres` (nuevo) | `color Color(0, 0, 0, 0.55)`, `steps_per_turn 48`. |
| `resources/ability_slot_view_config.gd` | `+ clock: CooldownClockConfig`. `− cooldown_ring_color` (el anillo de recarga desaparece). `cooldown_color` queda solo como fondo mientras se carga. |
| `resources/buff_bar_config.gd` | `+ clock: CooldownClockConfig`. |
| `resources/boss_bar_config.gd` | `+ clock: CooldownClockConfig`. |

### 2.2 Clases y nodos

| Archivo | Cambio |
|---|---|
| `ui/cooldown_clock.gd` (nuevo) | `class_name CooldownClock extends Control`, con anclas a todo el ícono y `mouse_filter` en ignorar. Dibuja el sector con `draw_colored_polygon` y solo redibuja cuando cambia la fracción. Tiene una función estática pura que arma el polígono (círculo o cuadrado) en un `PackedVector2Array` miembro que se reutiliza. |
| `ui/ability_slot_view.gd` | Durante la recarga dibuja `ready_color` y encima el sector con la misma función estática (sin nodo extra, porque el slot ya dibuja en su `_draw`). Se elimina `_draw_ring` para la recarga; se conserva para la carga. |
| `ui/buff_bar.gd` | Cada ícono suma un `CooldownClock` (forma cuadrada) como **primer hijo**, debajo de los labels. `update_times()` también actualiza la fracción. |
| `ui/boss_health_bar.gd` | Ídem para cada ícono de debuff, desde `_update_debuff_times()`. |
| `components/debuff_component.gd` | `+ static func get_remaining_ratio(debuff: ActiveDebuff) -> float`: `get_remaining(debuff) / data.duration`, entre 0 y 1. |

## 3. Interfaz pública

```gdscript
# ui/cooldown_clock.gd
class_name CooldownClock extends Control
enum Shape { CIRCLE, SQUARE }
@export var config: CooldownClockConfig
@export var shape: Shape
## 0 = nothing drawn, 1 = the whole icon covered.
func set_fraction(fraction: float) -> void
func get_fraction() -> float
## Pure: fills `points` with the dark sector (centre first). Empty when fraction <= 0.
## `half_size` is the radius (CIRCLE) or half the side (SQUARE).
static func build_sector(points: PackedVector2Array, center: Vector2, half_size: float,
		fraction: float, shape: Shape, steps_per_turn: int) -> void

# AbilitySlotView
func get_clock_fraction() -> float        # 0 when ready or charging

# BuffBar
func get_clock(index: int) -> CooldownClock

# BossHealthBar
func get_debuff_clock(index: int) -> CooldownClock

# DebuffComponent
static func get_remaining_ratio(debuff: ActiveDebuff) -> float
```

## 4. Lógica interna

- **Ángulos:** 0 es las 12 y crece en sentido horario. El sector oscuro va desde `(1 − fraction) × TAU` hasta `TAU`.
- **Polígono:** centro → punto del borde en el ángulo inicial → cada punto de la grilla (`TAU / steps_per_turn`) estrictamente dentro del rango → punto de las 12. Con `fraction` en 1 es la vuelta completa.
- **Borde:** en el círculo, `center + dir × radio`. En el cuadrado, el mismo rayo proyectado sobre el borde: `center + dir × half / max(|dir.x|, |dir.y|)`. Como `steps_per_turn` es múltiplo de 8, las esquinas (45°, 135°…) son puntos de la grilla y el recorte es exacto.
- **Redibujo:** `set_fraction` solo llama a `queue_redraw()` si cambió la fracción. Mientras corre un temporizador cambia cada frame, pero el costo es un polígono de ≤ 50 puntos por ícono visible (≤ 2 habilidades, 4 buffs y 8 debuffs de jefe). El buffer de puntos es miembro y se reutiliza (Principio V).
- **Habilidad cargando:** fondo `cooldown_color` y anillo de carga, igual que hoy, sin reloj (no hay recarga).

## 5. Criterios de aceptación

- **AC346** `build_sector` (círculo, radio 10, centro 0, 48 pasos):
  - `fraction 0` → vacío.
  - `0.25` → tapa el cuadrante de arriba a la izquierda: todos los puntos tienen `x ≤ 0` e `y ≤ 0`, e incluye `(−10, 0)` y `(0, −10)`.
  - `1` → vuelta completa: solo los 48 puntos del borde, sin el centro (polígono convexo; con el centro el primer y el último lado se superponen).
- **AC347** `build_sector` cuadrado (lado 20, centro 0): `fraction 0.5` tapa la mitad izquierda, incluye las esquinas `(−10, 10)` y `(−10, −10)` y ningún punto con `x > 0`. `fraction 0.125` va de `(−10, −10)` a `(0, −10)`, con todos los puntos sobre el borde superior.
- **AC348** Habilidad: tras lanzar Golpe Veloz (6 s), `get_clock_fraction()` vale 1. Tras 1.5 s vale 0.75. Lista, vale 0. Mientras se carga Envainar vale 0 y sigue el anillo de carga. `AbilitySlotViewConfig` ya no tiene `cooldown_ring_color`.
- **AC349** Buffs: con 2 stacks de Conmoción, el reloj del slot 0 es cuadrado, es el primer hijo del ícono y vale 1. A 1.0 s vale 0.6. Al perder un stack vuelve a 1.
- **AC350** Jefe: con Debilitar el reloj del ícono vale 1 y a 1.5 s vale 0.625. Con Sangrado recién aplicado vale 1. Los íconos 3D de los enemigos comunes no tienen reloj (sin hijos nuevos más allá del texto).
- **AC351** Regresión: suite completa en verde (los tests de `cooldown-timers` siguen pasando), import y smoke test (menú y arena) sin errores ni warnings.

## 6. Tests que pueden necesitar adaptación

- Ningún test verifica el anillo de recarga por color. `get_shown_ratio()` sigue existiendo y vale lo mismo.

## 7. Enmienda

No hace falta: el reloj 2D se dibuja con la API de `Control` (sin shaders ni texturas), y los íconos 3D quedan como están.

## 8. Plan

1. Reservar AC346–AC351 en `CLAUDE.md` (próximo libre → AC352) al empezar, para evitar colisiones con sesiones en paralelo.
2. **Base:** `CooldownClockConfig` + `.tres`, `CooldownClock` con `build_sector`, y `DebuffComponent.get_remaining_ratio`. Tests AC346 y AC347.
3. **Habilidades:** el reloj reemplaza el anillo de recarga y se quita `cooldown_ring_color`. Test AC348.
4. **Buffs y jefe:** `CooldownClock` en cada ícono, actualizado junto con el tiempo. Tests AC349 y AC350.
5. **Ajuste visual:** captura de la arena (habilidad en recarga, Conmoción, jefe con debuff) y ajuste de `color` si hace falta.
6. **Cierre:**
   - Suite completa, import y smoke test (copia en el scratchpad).
   - Copiar al proyecto los `.uid` nuevos.
   - Review de la constitución en esta spec y estado Implementada.
   - `CLAUDE.md`: specs recientes.

## 9. Notas de implementación

- **Números de AC:** la spec se escribió con AC327–AC332, pero `enemy-rage` los usó en paralelo. Se renumeró a **AC346–AC351** y se reservaron en `CLAUDE.md` (próximo libre AC352) antes de implementar.
- **Vuelta completa:** el polígono es solo el borde (48 puntos, sin el centro). Con el centro, el primer y el último lado se superponen y la triangulación puede fallar. AC346 se ajustó a eso.
- `CooldownClock.create()` arma el nodo con anclas a todo el ícono y el mouse ignorado. `BuffBar` y `BossHealthBar` lo agregan como primer hijo, así el reloj queda debajo de los números.
- Captura de la arena: habilidad con 2.8 s de 4 s (reloj en ~70 %), Conmoción a 1.6 s y dos debuffs en la barra de jefe (2.5 s y 3.5 s). El color `Color(0, 0, 0, 0.55)` se lee bien sobre el celeste, el verde lima y los colores de debuff, así que no se ajustó.
- Los tests de `cooldown-timers` no cambiaron. AC325 pasó a usar el helper `_start_colossus()`, compartido con AC350.

## 10. Review de la constitución (cierre)

- [x] **I:** Combate (recarga legible de un vistazo) y Progresión (buffs y debuffs de las mejoras doradas), como declara la spec.
- [x] **II:** reloj 2D dibujado con `draw_colored_polygon` de `Control`, sin shaders ni texturas. Los íconos 3D no cambian (sin mallas procedurales nuevas).
- [x] **III:** color y puntos por vuelta en `cooldown_clock_config.tres`, referenciado desde las configs de habilidades, buffs y jefe. Se eliminó `cooldown_ring_color`, que ya no se usa.
- [x] **IV:** tipado completo; `build_sector` es estática y pura; sin lógica nueva en callbacks de ciclo de vida.
- [x] **V:** el buffer de puntos es miembro y se reutiliza; cada reloj solo redibuja cuando cambia la fracción; nodos creados una vez por slot.
- [x] **VI:** sin input nuevo.
- [x] **Calidad:** 423 tests en verde, 0 orphans; import y smoke test sin errores ni warnings.
