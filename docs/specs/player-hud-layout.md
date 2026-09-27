# Feature: Barra de vida del jugador abajo al centro (verde, redondeada) y dash abajo a la izquierda

- **Estado:** Implementada (2026-09-25, 251 tests GdUnit4 en verde, smoke tests headless del menú y de la arena limpios)
- **Constitución:** `docs/constitution.md` **v2.4.0** (sin enmienda: UI 2D; el verde no es un color reservado)
- **Pilar (Principio I):** Supervivencia. La vida propia queda en el centro inferior, cerca del personaje y de la mirada, y el verde la separa a simple vista de las barras rojas de los enemigos y los jefes.
- **Dependencias:** `combat-mvp.md` (HUD), `boss-hud-bar.md`.

## 1. Objetivo

| Elemento | Antes | Después |
|---|---|---|
| Barra de vida del jugador | arriba a la izquierda, estilo por defecto | **abajo al centro**, relleno **verde** y fondo oscuro, **bordes redondeados** |
| Texto `100 / 100` | sobre la barra | igual (sigue centrado sobre la barra) |
| Barra de dash | arriba a la izquierda, debajo de la vida | **esquina inferior izquierda** (estilo sin cambios) |

- La oleada (arriba a la derecha), las barras de jefe (arriba al centro) y las habilidades (abajo a la derecha) no cambian.
- El tamaño de la barra de vida se mantiene en 300 × 28 px y el del dash en 150 × 20 px. Los márgenes contra el borde de la pantalla son de 16 px, igual que el resto del HUD.

## 2. Datos (Principio III)

`PlayerHealthBarStyle` (Resource nuevo, `resources/player_health_bar_style.gd`), con los valores en `data/ui/player_health_bar_style.tres`:

| Campo | Valor |
|---|---|
| `fill_color` | `Color(0.2, 0.75, 0.3)` (verde) |
| `background_color` | `Color(0.1, 0.12, 0.1, 0.85)` |
| `corner_radius` | 8 px |

## 3. Escenas y código

- **`ui/hud.tscn`:**
  - **`HealthBar`:** anchors abajo al centro (`anchor_left = anchor_right = 0.5`, `anchor_top = anchor_bottom = 1`), offsets `(-150, -44) → (150, -16)`, `grow_horizontal = both`, `grow_vertical = begin`.
  - **`DashBar`:** anchors abajo a la izquierda (`anchor_top = anchor_bottom = 1`), offsets `(16, -36) → (166, -16)`.
- **`Hud`:**
  - `@export var health_bar_style: PlayerHealthBarStyle`.
  - En `_ready`, `_apply_health_bar_style()` crea **una vez** dos `StyleBoxFlat` (`fill` y `background`) con el color y el radio de las cuatro esquinas, y los asigna como overrides `fill` y `background` del `ProgressBar`, igual que `CardStyle` con las cartas.

## 4. Criterios de aceptación

- **AC171** La barra de vida está anclada abajo al centro (anchors x = 0.5, y = 1) y centrada horizontalmente (`offset_left = -offset_right`).
- **AC172** El relleno de la barra usa un `StyleBoxFlat` con `bg_color` igual a `fill_color` (verde) y las 4 esquinas con `corner_radius`. El fondo usa `background_color` con el mismo radio.
- **AC173** (_reemplazado por AC769 de `dash-button.md`_) La barra de dash está anclada abajo a la izquierda (anchors x = 0, y = 1).
- **AC174** La barra sigue reflejando la vida: tras un golpe de 20 (17 tras la defensa), `value = 83` y el texto dice `83 / 100`.
- **AC175** Regresión: la suite completa en verde.

## 5. Plan de implementación

1. `PlayerHealthBarStyle` y su `.tres`.
2. `hud.tscn`: nuevos anchors y offsets de `HealthBar` y `DashBar`, y el export `health_bar_style`.
3. `hud.gd`: `_apply_health_bar_style()` desde `_ready`.
4. Tests `test/ui/player_hud_test.gd` (AC171–AC174) sobre la arena.
5. Suite completa sobre una copia en el scratchpad, smoke tests headless, review de la constitución y la spec marcada como *Implementada*.

### Notas de implementación

- `Hud._apply_health_bar_style()` crea los dos `StyleBoxFlat` con `set_corner_radius_all` y los asigna a los overrides `fill` y `background` del `ProgressBar`.
- Tests nuevos en `test/ui/player_hud_test.gd` (AC171–AC174). Ningún test existente cambió.

### Review de la constitución (cierre, v2.4.0)
- **I:** Supervivencia: la vida propia se lee en el centro inferior y en otro color que las barras enemigas.
- **II:** solo UI 2D. El verde no está reservado y ya no se confunde con el rojo de las barras enemigas.
- **III:** los colores y el radio viven en `PlayerHealthBarStyle` (`data/ui/player_health_bar_style.tres`). La posición y el tamaño son layout de la escena, como en el resto del HUD.
- **IV:** tipado completo. `_ready` delega en `_apply_health_bar_style()`.
- **V:** los estilos se crean una sola vez en `_ready`.
- **VI:** sin inputs nuevos.
