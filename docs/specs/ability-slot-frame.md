# Feature: Marco de los círculos de habilidad

- **Estado:** Implementada (2026-09-25, 425 tests GdUnit4 en verde, 0 orphans; import y smoke test del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.7.0 (sin enmienda).
- **Pilares (Principio I):**
  - **Combate:** un borde limpio hace que el reloj de recarga se lea sin ruido visual en el HUD mientras se pelea.
- **Dependencias:** `cooldown-clock.md` (Implementada).
- **ACs reservados:** AC352–AC354 (reservados en `CLAUDE.md` al escribir la spec, por las colisiones con sesiones en paralelo).

## 1. Problema

En el borde del círculo de habilidad, durante la recarga, se ven **puntitos**. El círculo de fondo (`draw_circle`, con antialiasing) y el sector del reloj (`draw_colored_polygon`, sin antialiasing y con otra cantidad de lados) no coinciden exactamente en el borde. Los vértices del polígono asoman por fuera del círculo, y por los huecos entre ambos se ve el fondo.

## 2. Solución

Un **marco**: un anillo opaco con antialiasing, dibujado **encima de todo** en el borde exterior del círculo. Tapa la unión entre el círculo y el reloj.

- Se dibuja **siempre** (bloqueada, lista, en recarga y cargando), para que el slot se vea igual en todos los estados.
- Ancho `frame_width` = 3 px y color `frame_color` = `Color(0.08, 0.1, 0.12, 1)` (casi negro, con el mismo tono que el fondo de recarga). Los dos son datos y se ajustan con captura.
- El **anillo de carga** (Envainar mantenido) se corre hacia adentro `frame_width` px, para que el marco no lo tape.
- El reloj y el círculo de fondo no cambian: el marco cubre su borde.

## 3. Estructura

| Archivo | Cambio |
|---|---|
| `resources/ability_slot_view_config.gd` | `+ frame_width: float` (px), `+ frame_color: Color`. |
| `data/ui/ability_slot_view_config.tres` | `frame_width 3.0`, `frame_color Color(0.08, 0.1, 0.12, 1)`. |
| `ui/ability_slot_view.gd` | `_draw_slot()` termina siempre con `_draw_frame()`: `draw_arc` de vuelta completa, radio `radius − frame_width / 2`, ancho `frame_width`, con antialiasing y `arc_point_count` puntos. `_draw_ring()` usa radio `radius − frame_width − ring_width / 2`. `+ get_charge_ring_radius() -> float` (para tests). |

## 4. Criterios de aceptación

- **AC352** `AbilitySlotViewConfig` tiene `frame_width` 3 y `frame_color` `Color(0.08, 0.1, 0.12, 1)`.
- **AC353** El anillo de carga queda por dentro del marco: `get_charge_ring_radius()` es `radius − frame_width − ring_width / 2`. Su borde exterior (`+ ring_width / 2`) no pasa de `radius − frame_width`.
- **AC354** Regresión: suite completa en verde (reloj y timers intactos). Import y smoke test sin errores. En la captura de la arena, el círculo en recarga no muestra puntos en el borde.

## 5. Plan

1. Agregar los campos de config y el `.tres`.
2. Dibujar el marco en `AbilitySlotView` y correr hacia adentro el anillo de carga. Tests AC352 y AC353.
3. Captura de la arena con una habilidad en recarga (zoom al slot) y ajuste de ancho y color si hace falta.
4. Cierre: suite completa, smoke test, review de la constitución en esta spec, estado **Implementada** y `CLAUDE.md` (specs recientes).

## 6. Notas de implementación

- **Desvío menor de §2:** con el marco solo encima, la primera captura todavía mostraba puntitos tenues **por fuera** del marco. Los vértices del reloj caían justo en el radio exterior y el antialiasing del marco los dejaba asomar. Por eso el cuerpo (círculo de fondo y reloj) ahora se dibuja con radio `radius − frame_width / 2`: termina en la mitad del marco y queda totalmente cubierto. El tamaño visible del slot no cambia.
- Capturas ampliadas del slot en recarga (6.0 y 3.5 s de 6 s): borde limpio, sin puntos.
- `get_charge_ring_radius()` se usa para dibujar el anillo de carga y en el test AC353.

## 7. Review de la constitución (cierre)

- [x] **I:** Combate (reloj legible sin ruido visual), como declara la spec.
- [x] **II:** `draw_arc` y `draw_circle` de `Control`, sin shaders ni texturas.
- [x] **III:** `frame_width` y `frame_color` en `ability_slot_view_config.tres`.
- [x] **IV:** tipado completo; `_draw` sigue delegando (`_draw_slot` → `_draw_body` y `_draw_frame`).
- [x] **V:** sin allocations nuevas; el marco es un `draw_arc` por redibujo.
- [x] **VI:** sin input nuevo.
- [x] **Calidad:** 425 tests en verde, 0 orphans; import y smoke test sin errores ni warnings.
