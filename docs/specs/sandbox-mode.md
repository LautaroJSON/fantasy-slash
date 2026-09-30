# Feature: Menú principal + modo Sandbox

- **Estado:** Implementada (2026-09-25, 180 tests GdUnit4 en verde, smoke tests headless del menú y de la arena limpios)
- **Reemplazada en parte:** la §2 "Oleadas sin cartas" la reemplaza `sandbox-arena-control.md` (el sandbox ya no tiene oleadas; AC110 → AC1333). `SandboxUpgradePanel` ahora es `UpgradePanel`.
- **Constitución:** `docs/constitution.md` v2.2.0 (sin enmiendas ni excepciones)
- **Pilar (Principio I):** Progresión, como herramienta. El sandbox permite probar builds y medir daño, y el menú principal es el punto de entrada al ciclo de runs.
- **Dependencias:** todas las features de combate, habilidades y cartas.

## 1. Flujo

```
Menú principal [Jugar] → Modo de juego [Normal | Sandbox | Volver] → Elegir habilidad → Arena
```

- `ui/main_menu.tscn` es la escena principal del proyecto: un panel principal y un panel de modos en la misma escena.
- El modo se guarda en el autoload `Session` (`systems/game_session.gd`, `class_name GameSession`, enum `Mode {NORMAL, SANDBOX}`). Así **Reintentar** (que recarga la arena) conserva el modo.
- "Menú principal" en la pausa y en el Game Over despausa y carga el menú. Las rutas de escena son `@export_file`, porque un `PackedScene` crearía una referencia circular entre el menú y la arena.

## 2. Sandbox

- **Oleadas sin cartas:** al limpiar una oleada arranca la siguiente (diferido un frame).
- **Inmortal:** `HealthComponent.death_protected`. El daño nunca baja la vida de `CombatRules.protected_min_health` (1). El feedback de daño sigue funcionando.
- **Panel de mejoras en la pausa** (`SandboxUpgradePanel`):
  - Una fila por carta del pool: nombre, contador, **−** y **+**.
  - Las mejoras únicas respetan su `max_level`: el **+** se desactiva al llegar y el **−** se desactiva en 0.
  - Tiene un botón "Reiniciar mejoras" y actualiza al instante los stats de la pausa.
- **HUD:** una etiqueta "SANDBOX".
- El modo **Normal** no cambia.

## 3. Código

- `StatsComponent`: `remove_upgrade`, `count_upgrade`, `clear_upgrades`.
- `AbilityComponent`: `remove_card`, `count_card`, `clear_upgrades`.
- `Player`: `remove_upgrade(card)`, `count_upgrade(card)`, `max_count(card)` (−1 = sin tope), `reset_upgrades()`.
- `WaveManager`: en sandbox no ofrece cartas.
- `Arena`: aplica `death_protected` según el modo.
- `PauseMenu`: exports `wave_manager` y `main_menu_path`, el panel de sandbox y el botón "Menú principal".
- `GameOverScreen`: botón "Menú principal".
- `Hud`: etiqueta de sandbox.

## 4. Criterios de aceptación

- **AC107** La escena principal del proyecto es `main_menu.tscn` y `Session` es un autoload.
- **AC108** El menú arranca en el panel principal. "Jugar" muestra los modos y "Volver" regresa.
- **AC109** Elegir un modo lo guarda en `Session` y emite `mode_chosen`.
- **AC110** En sandbox, limpiar una oleada no abre cartas y la oleada siguiente arranca.
- **AC111** En sandbox, un golpe letal deja al jugador en `protected_min_health`, sin Game Over. En normal, el jugador muere como siempre.
- **AC112** El panel de sandbox solo se ve en ese modo y lista todo el pool (personaje, habilidad y únicas).
- **AC113** "+" en Daño sube el DAMAGE y el valor mostrado en la pausa. "−" lo baja. "−" está desactivado en 0.
- **AC114** Una única en su nivel máximo desactiva el "+". El "−" baja su nivel.
- **AC115** "Reiniciar mejoras" deja al personaje y la habilidad sin mejoras.
- **AC116** La etiqueta SANDBOX solo se ve en sandbox.
- **AC117** Los botones "Menú principal" de la pausa y del Game Over apuntan a una escena que existe.
- **AC118** Regresión: la suite completa en verde.
  - *Notas:*
    - `levels/arena/arena.gd` existía pero no estaba conectado a la escena. Tenía una recarga al morir que había quedado de un bloque anterior y era código muerto. Ahora está conectado y solo aplica el modo.
    - En sandbox, con 1 de vida, los golpes ya no quitan vida, así que tampoco disparan el feedback de daño (`damaged` solo se emite con daño aplicado).
    - `MainMenu.game_scene_path` vacío solo guarda el modo. Se usa en los tests para no reemplazar la escena del runner.

### Review de la constitución (cierre)
- **I:** Progresión, como herramienta de testeo de builds. El modo Normal no cambia.
- **II:** solo UI 2D, sin assets.
- **III:** el piso de vida del sandbox es dato (`protected_min_health`). El modo es estado de sesión en un Node (autoload) y ningún Resource se muta.
- **IV:** tipado completo, callbacks delgados.
- **V:** las filas del panel se construyen al abrir la pausa, solo si cambió el pool. Nada corre por frame.
- **VI:** los menús usan mouse y `pause` sigue en el InputMap.

## 5. Fuera de alcance

- Otros modos, opciones o configuración.
- Guardar builds del sandbox.
