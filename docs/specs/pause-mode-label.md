# Feature: Modo de juego en la pausa (y fuera del HUD)

- **Estado:** Implementada (2026-09-25, 247 tests GdUnit4 en verde, smoke tests headless del menú y de la arena limpios)
- **Constitución:** `docs/constitution.md` **v2.4.0** (sin enmienda: solo UI 2D)
- **Pilar (Principio I):** Combate (legibilidad). Arriba al centro del HUD quedan solo las barras de jefe, sin el cartel "SANDBOX" compitiendo por el espacio. El modo se consulta en la pausa.
- **Dependencias:** `sandbox-mode.md` (reemplaza su cartel del HUD, AC116), `boss-hud-bar.md`.

## 1. Objetivo

- **HUD:** se elimina el cartel `SANDBOX` de arriba al centro. `TopCenter` queda solo con `BossBars`.
- **Pausa:** en la **esquina superior izquierda de la pantalla** aparece `Modo de juego: Normal` o `Modo de juego: Sandbox`, visible mientras la pausa está abierta.

## 2. Escenas y nodos

**`ui/hud.tscn`:** se borra el nodo `TopCenter/SandboxLabel`.

**`ui/pause_menu.tscn`:**

```
PauseMenu (Control, pantalla completa)
├── Dim
├── ModeLabel (Label, unique)   ← NUEVO: anclado arriba a la izquierda, offset (16, 16), font 22
├── Center/…                     (sin cambios)
```

Va encima del `Dim`, fuera del panel centrado, para que quede en la esquina de la pantalla.

## 3. Interfaz y datos

- **`GameSession.get_mode_name() -> String`:** `"Normal"` o `"Sandbox"`, los mismos nombres que muestran los botones del menú principal. Es texto de UI, no un valor tuneable.
- **`PauseMenu`:**
  - `open()` escribe `ModeLabel.text = "Modo de juego: %s" % Session.get_mode_name()`, en `_refresh()`, una vez por apertura.
  - `get_mode_text() -> String` (tests).
- **`Hud`:** se borran `_sandbox_label` y su línea en `_ready`.

## 4. Criterios de aceptación

- **AC166** El HUD ya no tiene `SandboxLabel`, en ningún modo.
- **AC167** Modo normal: al abrir la pausa, el label dice `Modo de juego: Normal`.
- **AC168** Sandbox: al abrir la pausa, el label dice `Modo de juego: Sandbox`. Reemplaza a AC116, que verificaba el cartel del HUD.
- **AC169** El label está anclado arriba a la izquierda de la pantalla (anchors 0,0) y es hijo directo de `PauseMenu`.
- **AC170** Regresión: la suite completa en verde. `pause_menu_test.gd` (AC112) deja de buscar el `SandboxLabel` del HUD y pasa a verificar AC167.

## 5. Plan de implementación

1. `GameSession.get_mode_name()`.
2. `pause_menu.tscn` + `pause_menu.gd`: el `ModeLabel`, el texto en `_refresh()` y `get_mode_text()`.
3. `hud.tscn` + `hud.gd`: sacar el `SandboxLabel`.
4. Tests: AC166–AC169 (en `pause_menu_test.gd` y `sandbox_run_test.gd`) y ajustar AC112/AC116.
5. Suite completa sobre una copia en el scratchpad, smoke tests headless, review de la constitución y la spec marcada como *Implementada*.

### Notas de implementación

- `ModeLabel` usa los anchors por defecto (0, 0) con offset (16, 16) y se escribe en `_refresh()`, así que también se actualiza si el panel sandbox cambia algo.
- **Tests:**
  - AC166, AC167 y AC169 en `test/ui/pause_menu_test.gd`.
  - AC168 en `test/levels/sandbox_run_test.gd`, donde reemplaza a AC116.
  - AC112 ya no mira el HUD.

### Review de la constitución (cierre, v2.4.0)
- **I:** legibilidad del combate: la parte superior central del HUD queda para los jefes.
- **II:** solo UI 2D.
- **III:** sin valores tuneables nuevos. Los nombres del modo son texto de UI, iguales a los del menú principal.
- **IV:** tipado completo.
- **V:** el texto se arma una vez por apertura de la pausa.
- **VI:** sin inputs nuevos.
